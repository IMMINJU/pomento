import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// 16비트 PCM을 조금씩 내주는 것. 재생 엔진의 버퍼 스트림에 밀어넣는다.
///
/// 파일에서 읽는 것과 음악 앱 보관함에서 읽는 것이 있다. 앞의 것은
/// AVAudioFile, 뒤의 것은 AVAssetReader를 쓴다. 부르는 쪽은 구분하지 않는다.
private protocol PcmSource: AnyObject {
  var sampleRate: Int { get }
  var channels: Int { get }
  var durationUs: Int64 { get }
  var finished: Bool { get }
  func read(maxBytes: Int) -> Data
  func seek(us: Int64) -> Int64
}

/// 앱이 읽을 수 있는 경로의 음원을 PCM으로 푼다.
///
/// 재생 엔진(SoLoud)이 내장한 디코더는 mp3, wav, ogg, flac뿐이라 m4a(AAC)를
/// 못 읽는다. AVAudioFile은 AAC를 기본으로 지원하므로 여기서 PCM을 뽑아
/// 엔진의 버퍼 스트림에 밀어넣는다. 안드로이드의 PcmDecoder.kt와 같은 역할이다.
///
/// 파일 전체를 미리 풀지 않는다. 7시간짜리 음원을 PCM으로 다 풀면 몇 기가가
/// 된다. 재생에 필요한 만큼만 조금씩 읽어간다.
private final class FilePcmDecoder: PcmSource {
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

/// 음악 앱 보관함의 곡을 PCM으로 푼다.
///
/// 보관함 항목은 파일이 아니라서 AVAudioFile로는 안 열린다. AVAssetReader는
/// ipod-library:// 자산을 직접 읽는다. 앱 폴더로 복사하지 않으므로 용량이
/// 늘지 않고 재인코딩도 없다. mp3면 mp3를 그대로 디코딩한다.
private final class LibraryPcmDecoder: PcmSource {
  private let asset: AVURLAsset
  private let track: AVAssetTrack
  private var reader: AVAssetReader?
  private var output: AVAssetReaderAudioMixOutput?

  /// 요청한 양보다 많이 읽었을 때 남는 부분. 다음 read에서 먼저 나간다.
  private var leftover = Data()

  let sampleRate: Int
  let channels: Int
  let durationUs: Int64

  private(set) var finished = false

  init?(url: URL, durationUs: Int64) {
    let asset = AVURLAsset(url: url)
    // 동기 접근자를 쓴다. iOS 16의 async load를 세마포어로 기다리면 협조
    // 스레드 풀에서 교착될 수 있다. 이 초기화는 배경 큐에서만 부른다.
    guard let track = asset.tracks(withMediaType: .audio).first else { return nil }

    var rate = 44100
    var channelCount = 2
    if let desc = track.formatDescriptions.first as? CMFormatDescription,
      let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee
    {
      if asbd.mSampleRate > 0 { rate = Int(asbd.mSampleRate) }
      if asbd.mChannelsPerFrame > 0 {
        channelCount = min(max(Int(asbd.mChannelsPerFrame), 1), 2)
      }
    }

    self.asset = asset
    self.track = track
    self.sampleRate = rate
    self.channels = channelCount

    let assetUs = Int64(CMTimeGetSeconds(asset.duration) * 1_000_000)
    self.durationUs = durationUs > 0 ? durationUs : max(0, assetUs)

    if !start(fromUs: 0) { return nil }
  }

  deinit {
    reader?.cancelReading()
  }

  /// [us] 지점부터 읽는 리더를 새로 만든다.
  ///
  /// AVAssetReader는 되감을 수 없다. 탐색은 리더를 버리고 다시 만드는
  /// 방식이고, 안드로이드 MediaCodec 쪽에서 하는 것과 같다.
  @discardableResult
  private func start(fromUs us: Int64) -> Bool {
    reader?.cancelReading()
    reader = nil
    output = nil

    guard let reader = try? AVAssetReader(asset: asset) else { return false }

    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: channels,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let out = AVAssetReaderAudioMixOutput(
      audioTracks: [track], audioSettings: settings)

    guard reader.canAdd(out) else { return false }
    reader.add(out)

    if us > 0 {
      let start = CMTime(value: us, timescale: 1_000_000)
      reader.timeRange = CMTimeRange(start: start, duration: .positiveInfinity)
    }

    guard reader.startReading() else { return false }

    self.reader = reader
    self.output = out
    return true
  }

  func read(maxBytes: Int) -> Data {
    var out = Data()
    out.reserveCapacity(maxBytes)

    if !leftover.isEmpty {
      let take = min(maxBytes, leftover.count)
      out.append(leftover.prefix(take))
      leftover.removeFirst(take)
    }

    while out.count < maxBytes && !finished {
      guard let output, let sample = output.copyNextSampleBuffer() else {
        finished = true
        break
      }
      append(sample, to: &out, limit: maxBytes)
      CMSampleBufferInvalidate(sample)
    }

    return out
  }

  private func append(_ sample: CMSampleBuffer, to out: inout Data, limit: Int) {
    guard let block = CMSampleBufferGetDataBuffer(sample) else { return }
    let length = CMBlockBufferGetDataLength(block)
    if length == 0 { return }

    var bytes = [UInt8](repeating: 0, count: length)
    let status = bytes.withUnsafeMutableBytes { raw -> OSStatus in
      guard let base = raw.baseAddress else { return -1 }
      return CMBlockBufferCopyDataBytes(
        block, atOffset: 0, dataLength: length, destination: base)
    }
    guard status == kCMBlockBufferNoErr else { return }

    let room = max(0, limit - out.count)
    if length <= room {
      out.append(contentsOf: bytes)
    } else {
      out.append(contentsOf: bytes[0..<room])
      leftover.append(contentsOf: bytes[room...])
    }
  }

  /// 압축 음원이라 리더가 요청한 지점의 바로 앞뒤에서 시작할 수 있다.
  /// 위치 계산의 기준으로는 요청한 값을 그대로 돌려준다.
  func seek(us: Int64) -> Int64 {
    let clamped = max(0, min(us, durationUs))
    leftover.removeAll()
    finished = false
    if !start(fromUs: clamped) {
      finished = true
    }
    return clamped
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// 음악 앱 보관함의 곡을 가리키는 주소의 머리.
  /// Dart의 lib/core/track_source.dart와 같은 값을 쓴다.
  private static let libraryScheme = "ipod://"

  private var decoders: [Int: PcmSource] = [:]
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
  // 안드로이드는 MediaStore를 훑고 iOS는 음악 앱 보관함(MPMediaLibrary)을
  // 훑는다. 보관함은 읽기만 한다. 이 API에는 원본 파일에 쓰는 길이 없다.
  //
  // 태그와 자켓은 음악 앱이 주는 값보다 파일에 박힌 값을 먼저 본다. 보관함
  // 동기화가 음악 앱 DB의 값을 애플 카탈로그 것으로 바꿔놓았을 수 있어서다.
  // 파일에서 못 읽으면 그때 음악 앱 값으로 떨어지고, 어느 쪽을 썼는지
  // tagSource로 함께 돌려준다.

  private func setUpMediaChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.pomento.app/media", binaryMessenger: messenger)

    channel.setMethodCallHandler { [weak self] call, result in
      let args = call.arguments as? [String: Any] ?? [:]

      switch call.method {
      case "scanAudio":
        self?.scanLibrary(result: result)
      case "libraryMetadata":
        self?.libraryMetadata(uri: args["uri"] as? String ?? "", result: result)
      case "copyUri":
        // 보관함 곡은 복사하지 않고 참조로 재생한다.
        result(false)
      case "currentOutput":
        result(self?.currentOutput() ?? ["type": "unknown", "productName": ""])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 보관함에서 재생 가능한 곡을 훑는다.
  ///
  /// assetURL이 없거나 보호된 항목은 뺀다. 애플뮤직 카탈로그에서 받은 곡이
  /// 여기 해당하고, 어떤 방법으로도 읽을 수 없다.
  private func scanLibrary(result: @escaping FlutterResult) {
    MPMediaLibrary.requestAuthorization { status in
      guard status == .authorized else {
        DispatchQueue.main.async { result([]) }
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        let items = MPMediaQuery.songs().items ?? []
        var out: [[String: Any]] = []
        out.reserveCapacity(items.count)

        for item in items {
          if item.hasProtectedAsset { continue }
          guard item.assetURL != nil else { continue }
          out.append([
            "uri": "\(AppDelegate.libraryScheme)\(item.persistentID)",
            "title": item.title ?? "",
            "artist": item.artist ?? "",
            "album": item.albumTitle ?? "",
            "durationMs": Int(item.playbackDuration * 1000),
            "sizeBytes": 0,
          ])
        }

        DispatchQueue.main.async { result(out) }
      }
    }
  }

  /// 곡 하나의 태그와 자켓. 파일에 박힌 값을 먼저 본다.
  private func libraryMetadata(uri: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let id = AppDelegate.persistentID(from: uri),
        let item = AppDelegate.libraryItem(for: id)
      else {
        DispatchQueue.main.async { result(nil) }
        return
      }

      var meta: [AVMetadataItem] = []
      if let url = item.assetURL {
        meta = AVURLAsset(url: url).metadata
      }

      let fileTitle = AppDelegate.firstString(
        meta,
        [.id3MetadataTitleDescription, .iTunesMetadataSongName, .commonIdentifierTitle])
      let fileArtist = AppDelegate.firstString(
        meta,
        [
          .id3MetadataLeadPerformer, .id3MetadataOriginalArtist,
          .iTunesMetadataArtist, .commonIdentifierArtist,
        ])
      let fileAlbum = AppDelegate.firstString(
        meta, [.id3MetadataAlbumTitle, .iTunesMetadataAlbum, .commonIdentifierAlbumName])
      let fileAlbumArtist = AppDelegate.firstString(
        meta, [.id3MetadataBand, .iTunesMetadataAlbumArtist])
      let fileYear = AppDelegate.firstInt(
        meta,
        [
          .id3MetadataYear, .id3MetadataRecordingTime,
          .iTunesMetadataReleaseDate, .commonIdentifierCreationDate,
        ])
      let fileTrackNo = AppDelegate.firstInt(
        meta, [.id3MetadataTrackNumber, .iTunesMetadataTrackNumber])
      let fileArtwork = AppDelegate.firstData(
        meta,
        [.id3MetadataAttachedPicture, .iTunesMetadataCoverArt, .commonIdentifierArtwork])

      var artwork = fileArtwork
      var artworkSource = fileArtwork == nil ? "none" : "file"
      if artwork == nil {
        artwork = item.artwork?
          .image(at: CGSize(width: 1000, height: 1000))?
          .jpegData(compressionQuality: 0.9)
        if artwork != nil { artworkSource = "library" }
      }

      let artist = fileArtist ?? item.artist ?? ""
      var out: [String: Any] = [
        "title": fileTitle ?? item.title ?? "",
        "artist": artist,
        "album": fileAlbum ?? item.albumTitle ?? "",
        "albumArtist": fileAlbumArtist ?? item.albumArtist ?? artist,
        "durationMs": Int(item.playbackDuration * 1000),
        // 태그를 파일에서 읽었는지 음악 앱 DB에서 읽었는지. 가져오기 결과에
        // 적어서 카탈로그 값이 섞여 들어왔는지 보이게 한다.
        "tagSource": (fileTitle != nil || fileArtist != nil) ? "file" : "library",
        "artworkSource": artworkSource,
      ]

      if let year = fileYear ?? AppDelegate.yearOf(item) {
        out["year"] = year
      }
      if let trackNo = fileTrackNo
        ?? (item.albumTrackNumber > 0 ? item.albumTrackNumber : nil)
      {
        out["trackNo"] = trackNo
      }
      if let artwork {
        out["artwork"] = FlutterStandardTypedData(bytes: artwork)
      }

      DispatchQueue.main.async { result(out) }
    }
  }

  // MARK: - 보관함 조회 도구

  private static func persistentID(from path: String) -> UInt64? {
    guard path.hasPrefix(libraryScheme) else { return nil }
    return UInt64(path.dropFirst(libraryScheme.count))
  }

  /// assetURL은 저장해두지 않는다. 재동기화 후 무효가 될 수 있어서 영구
  /// 식별자만 남기고 여기서 그때그때 다시 푼다.
  private static func libraryItem(for id: UInt64) -> MPMediaItem? {
    guard MPMediaLibrary.authorizationStatus() == .authorized else { return nil }
    let query = MPMediaQuery.songs()
    query.addFilterPredicate(
      MPMediaPropertyPredicate(
        value: NSNumber(value: id),
        forProperty: MPMediaItemPropertyPersistentID))
    return query.items?.first
  }

  private static func firstString(
    _ items: [AVMetadataItem], _ ids: [AVMetadataIdentifier]
  ) -> String? {
    for id in ids {
      for m in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id) {
        let v = m.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let v, !v.isEmpty { return v }
      }
    }
    return nil
  }

  /// 앞쪽 숫자만 떼어낸다. 연도 "1998-05-01"과 트랙 "3/12"가 같은 방식으로
  /// 처리된다.
  private static func firstInt(
    _ items: [AVMetadataItem], _ ids: [AVMetadataIdentifier]
  ) -> Int? {
    for id in ids {
      for m in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id) {
        if let n = m.numberValue { return n.intValue }
        if let s = m.stringValue {
          let digits = s.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
          if let v = Int(digits) { return v }
        }
      }
    }
    return nil
  }

  private static func firstData(
    _ items: [AVMetadataItem], _ ids: [AVMetadataIdentifier]
  ) -> Data? {
    for id in ids {
      for m in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id) {
        if let d = m.dataValue, !d.isEmpty { return d }
        // ID3의 APIC는 값이 딕셔너리로 오기도 한다.
        if let dict = m.value as? [String: Any],
          let d = dict["data"] as? Data, !d.isEmpty
        {
          return d
        }
      }
    }
    return nil
  }

  private static func yearOf(_ item: MPMediaItem) -> Int? {
    guard let date = item.releaseDate else { return nil }
    return Calendar.current.component(.year, from: date)
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
          let decoder = self.makeDecoder(path: path)
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

  /// 주소를 보고 파일 디코더와 보관함 디코더를 가른다.
  private func makeDecoder(path: String) -> PcmSource? {
    guard let id = AppDelegate.persistentID(from: path) else {
      return FilePcmDecoder(path: path)
    }
    guard let item = AppDelegate.libraryItem(for: id),
      let url = item.assetURL
    else {
      return nil
    }
    return LibraryPcmDecoder(
      url: url, durationUs: Int64(item.playbackDuration * 1_000_000))
  }

  private func decoder(_ id: Int) -> PcmSource? {
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
