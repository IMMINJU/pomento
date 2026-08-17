import AVFoundation
import Flutter
import UIKit

/// 오디오 파일을 16비트 PCM으로 풀어내는 디코더.
///
/// 재생 엔진(SoLoud)이 내장한 디코더는 mp3, wav, ogg, flac뿐이라 m4a(AAC)를
/// 못 읽는다. AVAudioFile은 AAC를 기본으로 지원하므로 여기서 PCM을 뽑아
/// 엔진의 버퍼 스트림에 밀어넣는다. 안드로이드의 PcmDecoder.kt와 같은 역할이다.
///
/// 파일 전체를 미리 풀지 않는다. 7시간짜리 음원을 PCM으로 다 풀면 몇 기가가
/// 된다. 재생에 필요한 만큼만 조금씩 읽어간다.
private final class PcmDecoder {
  private let file: AVAudioFile
  private let converter: AVAudioConverter
  private let outFormat: AVAudioFormat

  let sampleRate: Int
  let channels: Int
  let durationUs: Int64

  private(set) var finished = false

  init?(path: String) {
    guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else {
      return nil
    }
    let inFormat = file.processingFormat
    let channelCount = min(max(Int(inFormat.channelCount), 1), 2)

    guard
      let outFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: inFormat.sampleRate,
        channels: AVAudioChannelCount(channelCount),
        interleaved: true
      ),
      let converter = AVAudioConverter(from: inFormat, to: outFormat)
    else {
      return nil
    }

    self.file = file
    self.converter = converter
    self.outFormat = outFormat
    self.sampleRate = Int(inFormat.sampleRate)
    self.channels = channelCount
    self.durationUs = inFormat.sampleRate > 0
      ? Int64(Double(file.length) / inFormat.sampleRate * 1_000_000)
      : 0
  }

  /// PCM을 [maxBytes]에 가깝게 모아서 돌려준다. 더 낼 것이 없으면 빈 데이터.
  func read(maxBytes: Int) -> Data {
    if finished { return Data() }

    let bytesPerFrame = 2 * channels
    let frames = AVAudioFrameCount(max(maxBytes / bytesPerFrame, 4096))

    guard
      let inBuffer = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat, frameCapacity: frames)
    else {
      finished = true
      return Data()
    }

    do {
      try file.read(into: inBuffer, frameCount: frames)
    } catch {
      finished = true
      return Data()
    }

    if inBuffer.frameLength == 0 {
      finished = true
      return Data()
    }
    if file.framePosition >= file.length {
      finished = true
    }

    guard
      let outBuffer = AVAudioPCMBuffer(
        pcmFormat: outFormat, frameCapacity: inBuffer.frameLength)
    else {
      return Data()
    }

    // 표본율이 같으므로 한 번에 변환하는 형태를 쓸 수 있다.
    do {
      try converter.convert(to: outBuffer, from: inBuffer)
    } catch {
      return Data()
    }

    guard let samples = outBuffer.int16ChannelData else { return Data() }
    // 인터리브 형식이라 첫 채널 포인터가 전체 데이터를 가리킨다.
    let count = Int(outBuffer.frameLength) * channels
    return Data(bytes: samples[0], count: count * MemoryLayout<Int16>.size)
  }

  /// 실제로 이동한 위치를 마이크로초로 돌려준다.
  func seek(us: Int64) -> Int64 {
    let rate = file.processingFormat.sampleRate
    guard rate > 0 else { return 0 }
    let target = AVAudioFramePosition(Double(us) / 1_000_000 * rate)
    let clamped = max(0, min(target, file.length))
    file.framePosition = clamped
    converter.reset()
    finished = false
    return Int64(Double(clamped) / rate * 1_000_000)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private var decoders: [Int: PcmDecoder] = [:]
  private var nextDecoderId = 1
  private let decodersLock = NSLock()
  private var routeObserver: NSObjectProtocol?
  private var deviceSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard
      let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PomentoNative")
    else {
      return
    }
    let messenger = registrar.messenger()

    setUpMediaChannel(messenger)
    setUpDecoderChannel(messenger)
    setUpOutputDeviceChannel(messenger)
  }

  // MARK: - 미디어 채널
  //
  // 안드로이드는 MediaStore를 훑지만 iOS에는 대응하는 것이 없다. 애플뮤직
  // 보관함(MPMediaLibrary)에는 의도적으로 접근하지 않는다. Info.plist에
  // NSAppleMusicUsageDescription을 넣지 않아 접근 자체가 막혀 있다. 음원은
  // 파일 앱에서 앱 폴더로 직접 옮겨 넣는다.

  private func setUpMediaChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.pomento.app/media", binaryMessenger: messenger)

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "scanAudio":
        result([])
      case "copyUri":
        result(false)
      case "currentOutput":
        result(self?.currentOutput() ?? ["type": "unknown", "productName": ""])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - 디코더 채널

  private func setUpDecoderChannel(_ messenger: FlutterBinaryMessenger) {
    // 디코딩이 메인 스레드를 막지 않도록 별도 큐에서 처리한다.
    let queue = messenger.makeBackgroundTaskQueue?()
    let channel = FlutterMethodChannel(
      name: "com.pomento.app/decoder",
      binaryMessenger: messenger,
      codec: FlutterStandardMethodCodec.sharedInstance(),
      taskQueue: queue
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      let args = call.arguments as? [String: Any] ?? [:]

      switch call.method {
      case "open":
        guard let path = args["path"] as? String,
          let decoder = PcmDecoder(path: path)
        else {
          result(nil)
          return
        }
        self.decodersLock.lock()
        let id = self.nextDecoderId
        self.nextDecoderId += 1
        self.decoders[id] = decoder
        self.decodersLock.unlock()

        result([
          "id": id,
          "sampleRate": decoder.sampleRate,
          "channels": decoder.channels,
          "durationUs": decoder.durationUs,
        ])

      case "read":
        let id = args["id"] as? Int ?? -1
        let maxBytes = args["maxBytes"] as? Int ?? (128 * 1024)
        guard let decoder = self.decoder(id) else {
          result(nil)
          return
        }
        let data = decoder.read(maxBytes: maxBytes)
        result([
          "data": FlutterStandardTypedData(bytes: data),
          "finished": decoder.finished,
        ])

      case "seek":
        let id = args["id"] as? Int ?? -1
        let us = (args["us"] as? NSNumber)?.int64Value ?? 0
        result(Int(self.decoder(id)?.seek(us: us) ?? 0))

      case "close":
        let id = args["id"] as? Int ?? -1
        self.decodersLock.lock()
        self.decoders.removeValue(forKey: id)
        self.decodersLock.unlock()
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func decoder(_ id: Int) -> PcmDecoder? {
    decodersLock.lock()
    defer { decodersLock.unlock() }
    return decoders[id]
  }

  // MARK: - 출력 기기

  private func setUpOutputDeviceChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterEventChannel(
      name: "com.pomento.app/output_device", binaryMessenger: messenger)
    channel.setStreamHandler(self)
  }

  /// 지금 소리가 나가는 출력 기기.
  private func currentOutput() -> [String: Any] {
    let route = AVAudioSession.sharedInstance().currentRoute
    guard let output = route.outputs.first else {
      return ["type": "unknown", "productName": ""]
    }
    return [
      "type": Self.normalize(output.portType),
      "productName": output.portName,
    ]
  }

  private static func normalize(_ port: AVAudioSession.Port) -> String {
    switch port {
    case .builtInSpeaker, .builtInReceiver:
      return "speaker"
    case .headphones, .headsetMic:
      return "wired"
    case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
      return "bluetooth"
    case .usbAudio:
      return "usb"
    case .carAudio:
      return "car"
    default:
      return "unknown"
    }
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    deviceSink = events
    routeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      self.deviceSink?(self.currentOutput())
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = routeObserver {
      NotificationCenter.default.removeObserver(observer)
      routeObserver = nil
    }
    deviceSink = nil
    return nil
  }
}
