import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../data/models/eq_curve.dart';
import '../data/models/preset.dart';
import '../data/models/tempo.dart';
import 'platform_decoder.dart';

/// SoLoud 엔진을 감싼 재생기.
///
/// 필터는 전역으로 한 번만 붙이고 이후에는 파라미터만 바꾼다. 재생 중에
/// 필터를 붙였다 떼면 그 순간 소리가 튄다. 값 변경도 대부분 fade로 넘겨서
/// 미세 조정을 계속 움직여도 클릭 잡음이 생기지 않게 한다.
class AudioEngine {
  AudioEngine._();

  static final AudioEngine instance = AudioEngine._();

  SoLoud get _soloud => SoLoud.instance;

  AudioSource? _source;
  SoundHandle? _handle;
  StreamSubscription<void>? _finishedSub;

  final StreamController<void> _finishedController =
      StreamController<void>.broadcast();

  /// 곡이 끝까지 재생됐을 때 알린다. 사용자가 멈춘 경우에는 오지 않는다.
  Stream<void> get trackFinished => _finishedController.stream;

  bool _initialized = false;
  bool _pitchActive = false;
  bool _stopping = false;
  double _volume = 1.0;
  TempoSettings _tempo = TempoSettings.normal;

  // 볼륨이 바뀌면 등청감 보정 곡선이 달라져서 다시 계산해야 한다.
  List<EqCurve> _lastLayers = const [];
  ReverbSettings _lastReverb = ReverbSettings.off;
  EchoSettings _lastEcho = EchoSettings.off;
  bool _lastLoudnessComp = false;

  // ── 플랫폼 디코더로 재생 중일 때 쓰는 상태 ────────────────────────
  //
  // 엔진 내장 디코더는 mp3, wav, ogg, flac만 읽는다. m4a(AAC) 같은 것은
  // 플랫폼 코덱으로 PCM을 뽑아 버퍼 스트림에 밀어넣는다.
  DecoderHandle? _decoder;
  bool _streaming = false;

  /// 탐색한 지점. 버퍼 스트림은 재생 위치가 항상 0이라 직접 더해야 한다.
  Duration _streamBase = Duration.zero;
  Duration _streamDuration = Duration.zero;

  /// 탐색하면 이전 펌프 루프를 버려야 해서 세대를 센다.
  int _pumpGeneration = 0;

  // 다이얼을 돌리는 동안 엔진 호출이 몰리지 않게 묶는다.
  Timer? _tempoThrottle;
  TempoSettings? _pendingTempo;

  /// 엔진 EQ의 밴드 수. 30Hz~16kHz를 로그 간격으로 나눈다.
  static const int bandCount = 10;

  /// 각 밴드의 중심 주파수. 엔진 내부 계산과 같은 식이다.
  static final List<double> bandFrequencies = List.generate(bandCount, (i) {
    const f0 = 30.0;
    const f1 = 16000.0;
    final t = i / (bandCount - 1);
    return f0 * math.pow(f1 / f0, t).toDouble();
  });

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    // 음악 재생에는 지연시간보다 안정성이 중요하다. lowLatency를 끄고 버퍼를
    // 키워야 필터를 여러 개 걸어도 끊기지 않는다.
    // freeverb는 2채널에서만 동작하므로 stereo로 초기화해야 한다.
    await _soloud.init(
      sampleRate: 44100,
      bufferSize: 4096,
      channels: Channels.stereo,
      lowLatency: false,
    );
    _setupFilters();
    _initialized = true;
  }

  /// 필터를 고정된 순서로 한 번만 붙인다.
  ///
  /// 순서: 피치 → EQ → 리버브 → 에코 → 리미터.
  /// 리미터를 맨 끝에 두는 이유는 세 층의 EQ를 더하면 이득이 +10dB를 넘길 수
  /// 있어서다. 그대로 두면 클리핑이 난다.
  void _setupFilters() {
    final f = _soloud.filters;

    f.pitchShiftFilter.activate();
    f.pitchShiftFilter.wet.value = 0;
    f.pitchShiftFilter.semitones.value = 0;

    f.parametricEqFilter.activate();
    f.parametricEqFilter.stftWindowSize.value = 1024;
    f.parametricEqFilter.numBands.value = bandCount.toDouble();
    for (var i = 0; i < bandCount; i++) {
      f.parametricEqFilter.bandGain(i).value = 1;
    }
    f.parametricEqFilter.wet.value = 1;

    f.freeverbFilter.activate();
    f.freeverbFilter.wet.value = 0;
    f.freeverbFilter.roomSize.value = 0.5;
    f.freeverbFilter.damp.value = 0.5;
    f.freeverbFilter.width.value = 1;

    f.echoFilter.activate();
    f.echoFilter.wet.value = 0;
    f.echoFilter.delay.value = 0.3;
    f.echoFilter.decay.value = 0.5;

    f.limiterFilter.activate();
    f.limiterFilter.wet.value = 1;
    f.limiterFilter.threshold.value = -3;
    f.limiterFilter.outputCeiling.value = -0.5;
    f.limiterFilter.kneeWidth.value = 3;
    f.limiterFilter.attackTime.value = 1;
    f.limiterFilter.releaseTime.value = 120;
  }

  // ── 재생 ────────────────────────────────────────────────────────────

  /// 파일을 열고 바로 재생한다. 이전 곡은 정리한다.
  Future<Duration> playFile(String path) async {
    await init();
    await _disposeCurrent();

    if (PlatformDecoder.needsPlatformDecoder(path)) {
      final decoded = await _playViaPlatformDecoder(path);
      if (decoded != null) return decoded;
      // 플랫폼도 못 열면 엔진에 한 번 맡겨본다. 확장자가 틀렸을 수 있다.
    }

    final source = await _soloud.loadFile(path);
    _source = source;

    // 일시정지 상태로 시작해서 배속을 먼저 걸고 푼다. 재생 후에 걸면
    // 처음 몇십 밀리초가 원래 속도로 나온다.
    final handle = _soloud.play(source, volume: _volume, paused: true);
    _handle = handle;
    _applyTempoTo(handle, _tempo, smooth: false);
    _soloud.setPause(handle, false);

    _watchFinish(source);
    return _soloud.getLength(source);
  }

  /// 플랫폼 코덱으로 PCM을 받아 버퍼 스트림으로 재생한다.
  ///
  /// 파일을 통째로 풀지 않는다. 7시간짜리 음원을 PCM으로 다 풀면 몇 기가가
  /// 되므로, 재생에 필요한 만큼만 앞서서 채운다.
  Future<Duration?> _playViaPlatformDecoder(String path) async {
    final dec = await PlatformDecoder.instance.open(path);
    if (dec == null) return null;

    _decoder = dec;
    _streaming = true;
    _streamBase = Duration.zero;
    _streamDuration = dec.duration;

    final source = _soloud.setBufferStream(
      // released는 재생이 끝난 부분의 메모리를 놓아준다. 긴 음원을 틀려면
      // 이 방식이어야 한다. 대신 재생 위치가 항상 0으로 보고되므로
      // getStreamTimeConsumed로 따로 계산한다.
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 2,
      maxBufferSizeBytes: 2000000000,
      sampleRate: dec.sampleRate,
      channels: dec.channels <= 1 ? Channels.mono : Channels.stereo,
      format: BufferType.s16le,
    );
    _source = source;

    // 재생을 시작하기 전에 몇 초치를 미리 채운다. 비어 있는 상태로 틀면
    // 곧바로 버퍼링에 걸린다.
    await _fillAhead(source, dec, seconds: 3);

    final handle = _soloud.play(source, volume: _volume, paused: true);
    _handle = handle;
    _applyTempoTo(handle, _tempo, smooth: false);
    _soloud.setPause(handle, false);

    _watchFinish(source);
    _startPump();

    return dec.duration;
  }

  void _watchFinish(AudioSource source) {
    _stopping = false;
    _finishedSub = source.allInstancesFinished.listen((_) {
      if (!_stopping) _finishedController.add(null);
    });
  }

  /// 버퍼가 [seconds]만큼 찰 때까지 읽어 넣는다.
  Future<bool> _fillAhead(
    AudioSource source,
    DecoderHandle dec, {
    required double seconds,
  }) async {
    // 엔진은 내부적으로 float으로 들고 있어서 채널당 4바이트다.
    final bytesPerSecond = dec.sampleRate * dec.channels * 4;
    var guard = 0;
    while (guard++ < 200) {
      final buffered = _soloud.getBufferSize(source) / bytesPerSecond;
      if (buffered >= seconds) return false;
      final chunk = await PlatformDecoder.instance.read(dec.id);
      if (chunk.data.isNotEmpty) {
        _soloud.addAudioDataStream(source, chunk.data);
      }
      if (chunk.finished) {
        _soloud.setDataIsEnded(source);
        return true;
      }
    }
    return false;
  }

  void _startPump() {
    final gen = ++_pumpGeneration;
    unawaited(_pump(gen));
  }

  Future<void> _pump(int gen) async {
    while (_streaming && gen == _pumpGeneration) {
      final source = _source;
      final dec = _decoder;
      if (source == null || dec == null) return;
      try {
        final ended = await _fillAhead(source, dec, seconds: 8);
        if (ended) return;
      } catch (e) {
        debugPrint('스트림 채우기 실패: $e');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _disposeCurrent() async {
    _stopping = true;
    _pumpGeneration++;
    _streaming = false;
    await _finishedSub?.cancel();
    _finishedSub = null;

    final dec = _decoder;
    _decoder = null;
    _streamBase = Duration.zero;
    _streamDuration = Duration.zero;

    final s = _source;
    _source = null;
    _handle = null;
    if (s != null) {
      try {
        await _soloud.disposeSource(s);
      } catch (e) {
        debugPrint('disposeSource 실패: $e');
      }
    }
    if (dec != null) {
      await PlatformDecoder.instance.close(dec.id);
    }
  }

  Future<void> stop() => _disposeCurrent();

  void pause() {
    final h = _handle;
    if (h != null) _soloud.setPause(h, true);
  }

  void resume() {
    final h = _handle;
    if (h != null) _soloud.setPause(h, false);
  }

  bool get isPlaying {
    final h = _handle;
    if (h == null) return false;
    if (!_soloud.getIsValidVoiceHandle(h)) return false;
    return !_soloud.getPause(h);
  }

  bool get hasTrack => _handle != null;

  void seek(Duration position) {
    if (_streaming) {
      unawaited(_seekStream(position));
      return;
    }
    final h = _handle;
    if (h != null) _soloud.seek(h, position);
  }

  /// 버퍼 스트림은 되감을 수 없으므로 디코더를 옮기고 버퍼를 비워 다시 채운다.
  Future<void> _seekStream(Duration to) async {
    final dec = _decoder;
    final source = _source;
    if (dec == null || source == null) return;

    _pumpGeneration++; // 돌고 있던 펌프를 버린다
    final actual = await PlatformDecoder.instance.seek(dec.id, to);
    if (_source != source) return; // 그 사이 곡이 바뀌었다

    _soloud.resetBufferStream(source);
    _streamBase = actual;
    await _fillAhead(source, dec, seconds: 3);
    _startPump();
  }

  Duration get position {
    if (_streaming) {
      final s = _source;
      if (s == null) return _streamBase;
      try {
        return _streamBase + _soloud.getStreamTimeConsumed(s);
      } catch (_) {
        return _streamBase;
      }
    }
    final h = _handle;
    if (h == null) return Duration.zero;
    if (!_soloud.getIsValidVoiceHandle(h)) return Duration.zero;
    return _soloud.getPosition(h);
  }

  Duration get duration {
    if (_streaming) return _streamDuration;
    final s = _source;
    if (s == null) return Duration.zero;
    return _soloud.getLength(s);
  }

  double get volume => _volume;

  set volume(double v) {
    _volume = v.clamp(0.0, 1.0);
    final h = _handle;
    if (h != null) _soloud.setVolume(h, _volume);
    // 등청감 보정은 볼륨에 따라 곡선이 달라지므로 다시 계산해야 한다.
    if (_lastLoudnessComp) _reapplyEffects();
  }

  // ── 배속과 피치 ─────────────────────────────────────────────────────

  TempoSettings get tempo => _tempo;

  /// 배속과 피치를 적용한다.
  ///
  /// [smooth]가 참이면 값을 짧게 보간해서 넘긴다. 다이얼을 계속 돌리는 동안
  /// 매번 즉시 반영하면 리샘플러가 끊겨 딱 소리가 난다.
  void applyTempo(TempoSettings t, {bool smooth = true}) {
    _tempo = t;
    final h = _handle;
    if (h == null) return;

    if (!smooth) {
      _tempoThrottle?.cancel();
      _tempoThrottle = null;
      _pendingTempo = null;
      _applyTempoTo(h, t, smooth: false);
      return;
    }

    // 다이얼을 돌리는 동안에는 초당 수십 번 값이 들어온다. 그때마다 새
    // 페이드를 걸면 엔진이 밀린다. 처음 한 번은 즉시 반영하고 이후에는
    // 60ms마다 마지막 값만 보낸다.
    if (_tempoThrottle != null) {
      _pendingTempo = t;
      return;
    }
    _applyTempoTo(h, t, smooth: true);
    _tempoThrottle = Timer(const Duration(milliseconds: 60), () {
      _tempoThrottle = null;
      final pending = _pendingTempo;
      _pendingTempo = null;
      if (pending != null) applyTempo(pending);
    });
  }

  void _applyTempoTo(SoundHandle h, TempoSettings t, {required bool smooth}) {
    final speed = t.speed.clamp(0.25, 4.0);
    if (smooth) {
      _soloud.fadeRelativePlaySpeed(h, speed, const Duration(milliseconds: 90));
    } else {
      _soloud.setRelativePlaySpeed(h, speed);
    }

    final ps = _soloud.filters.pitchShiftFilter;
    final want = t.needsPitchFilter;
    final semis = t.filterSemitones.clamp(-36.0, 36.0);

    if (want) {
      if (!_pitchActive) {
        // 꺼져 있던 상태에서 켜는 경우. 반음 값을 먼저 확정하고 wet만 올린다.
        ps.semitones.value = semis;
        if (smooth) {
          ps.wet.fadeFilterParameter(
            to: 1,
            time: const Duration(milliseconds: 80),
          );
        } else {
          ps.wet.value = 1;
        }
        _pitchActive = true;
      } else {
        if (smooth) {
          ps.semitones.fadeFilterParameter(
            to: semis,
            time: const Duration(milliseconds: 90),
          );
        } else {
          ps.semitones.value = semis;
        }
      }
    } else if (_pitchActive) {
      if (smooth) {
        ps.wet.fadeFilterParameter(
          to: 0,
          time: const Duration(milliseconds: 80),
        );
      } else {
        ps.wet.value = 0;
      }
      _pitchActive = false;
    }
  }

  // ── 이펙트 ──────────────────────────────────────────────────────────

  /// 세 층의 EQ 곡선을 dB 축에서 더해 엔진 밴드에 넣는다.
  ///
  /// 프리셋은 임의 주파수의 점으로 정의돼 있고 엔진 밴드는 고정이라,
  /// 밴드 중심 주파수에서 각 층의 값을 뽑아 더한다.
  void applyEffects({
    required List<EqCurve> layers,
    ReverbSettings reverb = ReverbSettings.off,
    EchoSettings echo = EchoSettings.off,
    bool loudnessComp = false,
    bool smooth = true,
  }) {
    if (!_initialized) return;
    _lastLayers = layers;
    _lastReverb = reverb;
    _lastEcho = echo;
    _lastLoudnessComp = loudnessComp;
    final f = _soloud.filters;

    final curves = <EqCurve>[
      ...layers,
      if (loudnessComp) loudnessCurve(_volume),
    ];

    for (var i = 0; i < bandCount; i++) {
      final db = EqCurve.sumGainAt(curves, bandFrequencies[i]);
      final gain = _dbToGain(db);
      final param = f.parametricEqFilter.bandGain(i);
      if (smooth) {
        param.fadeFilterParameter(
          to: gain,
          time: const Duration(milliseconds: 120),
        );
      } else {
        param.value = gain;
      }
    }

    const ramp = Duration(milliseconds: 120);

    final reverbWet = reverb.wet.clamp(0.0, 1.0);
    if (smooth) {
      f.freeverbFilter.wet.fadeFilterParameter(to: reverbWet, time: ramp);
    } else {
      f.freeverbFilter.wet.value = reverbWet;
    }
    f.freeverbFilter.roomSize.value = reverb.roomSize.clamp(0.0, 1.0);
    f.freeverbFilter.damp.value = reverb.damp.clamp(0.0, 1.0);
    f.freeverbFilter.width.value = reverb.width.clamp(0.0, 1.0);

    final echoWet = echo.wet.clamp(0.0, 1.0);
    if (smooth) {
      f.echoFilter.wet.fadeFilterParameter(to: echoWet, time: ramp);
    } else {
      f.echoFilter.wet.value = echoWet;
    }
    f.echoFilter.delay.value = echo.delay.clamp(0.001, 2.0);
    f.echoFilter.decay.value = echo.decay.clamp(0.001, 1.0);
  }

  void _reapplyEffects() => applyEffects(
        layers: _lastLayers,
        reverb: _lastReverb,
        echo: _lastEcho,
        loudnessComp: _lastLoudnessComp,
      );

  /// 엔진 밴드 이득은 0~4 배수다. 1이 원음이고 4가 약 +12dB.
  static double _dbToGain(double db) {
    final g = math.pow(10, db / 20).toDouble();
    return g.clamp(0.05, 4.0);
  }

  /// 등청감 보정 곡선.
  ///
  /// 볼륨이 작을수록 귀가 저역과 고역을 덜 듣는다. 볼륨이 낮을 때만
  /// 양 끝을 올려서 작게 틀어도 소리가 얇아지지 않게 한다.
  static EqCurve loudnessCurve(double volume) {
    final k = (1.0 - volume).clamp(0.0, 1.0);
    if (k <= 0.01) return EqCurve.flat;
    return EqCurve([
      EqPoint(30, 6.0 * k),
      EqPoint(120, 3.0 * k),
      EqPoint(400, 0),
      EqPoint(2000, 0),
      EqPoint(6000, 1.5 * k),
      EqPoint(14000, 4.0 * k),
    ]);
  }

  // ── A-B 구간 반복 ───────────────────────────────────────────────────

  /// A-B 구간 반복과 한 곡 반복을 엔진에 맡길 수 있는지.
  ///
  /// 버퍼 스트림은 이미 재생한 데이터를 놓아주기 때문에 되감을 수 없다.
  /// 플랫폼 디코더로 트는 곡(m4a 등)에서는 반복을 재생 컨트롤러가 직접
  /// 탐색으로 처리해야 한다.
  bool get supportsEngineLooping => !_streaming;

  /// [a]부터 [b]까지 반복한다. 둘 중 하나가 null이면 반복을 끈다.
  void setLoopRegion(Duration? a, Duration? b) {
    if (_streaming) return;
    final h = _handle;
    if (h == null) return;
    if (a == null || b == null || b <= a) {
      _soloud.setLooping(h, false);
      _soloud.setLoopEndPoint(h, null);
      return;
    }
    _soloud.setLoopPoint(h, a);
    _soloud.setLoopEndPoint(h, b);
    _soloud.setLooping(h, true);
    if (position < a || position > b) {
      _soloud.seek(h, a);
    }
  }

  /// 한 곡 반복.
  void setLooping(bool enabled) {
    if (_streaming) return;
    final h = _handle;
    if (h == null) return;
    if (enabled) {
      _soloud.setLoopPoint(h, Duration.zero);
      _soloud.setLoopEndPoint(h, null);
    }
    _soloud.setLooping(h, enabled);
  }

  Future<void> dispose() async {
    _tempoThrottle?.cancel();
    _tempoThrottle = null;
    await _disposeCurrent();
    await _finishedController.close();
    if (_initialized) {
      await _soloud.deinitAsync();
      _initialized = false;
    }
  }
}
