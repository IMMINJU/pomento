import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/models/tempo.dart';
import '../data/repo/library_repository.dart';
import 'audio_engine.dart';
import 'audio_handler.dart';

enum RepeatMode {
  off,
  all,
  one;

  String get label => switch (this) {
        RepeatMode.off => '반복 없음',
        RepeatMode.all => '전체 반복',
        RepeatMode.one => '한 곡 반복',
      };
}

@immutable
class PlayerState {
  const PlayerState({
    this.queue = const [],
    this.index = -1,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.tempo = TempoSettings.normal,
    this.repeat = RepeatMode.off,
    this.shuffle = false,
    this.loopA,
    this.loopB,
    this.volume = 1.0,
    this.rememberTempo = true,
  });

  final List<Track> queue;
  final int index;
  final bool playing;
  final Duration position;
  final Duration duration;
  final TempoSettings tempo;
  final RepeatMode repeat;
  final bool shuffle;

  /// A-B 구간 반복. 둘 다 정해져야 동작한다.
  final Duration? loopA;
  final Duration? loopB;

  final double volume;

  /// 이 곡에 배속을 기억해둘지.
  final bool rememberTempo;

  Track? get current =>
      index >= 0 && index < queue.length ? queue[index] : null;

  bool get hasNext => queue.isNotEmpty && (repeat != RepeatMode.off || index < queue.length - 1);

  bool get hasPrevious => queue.isNotEmpty && (repeat != RepeatMode.off || index > 0);

  /// 남은 시간은 배속을 반영한 실제 시간이다. 0.5배면 두 배로 걸린다.
  Duration get remainingWallClock {
    final left = duration - position;
    if (left.isNegative) return Duration.zero;
    final speed = tempo.speed <= 0 ? 1.0 : tempo.speed;
    return Duration(microseconds: (left.inMicroseconds / speed).round());
  }

  double get progress => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  PlayerState copyWith({
    List<Track>? queue,
    int? index,
    bool? playing,
    Duration? position,
    Duration? duration,
    TempoSettings? tempo,
    RepeatMode? repeat,
    bool? shuffle,
    Duration? loopA,
    Duration? loopB,
    bool clearLoop = false,
    double? volume,
    bool? rememberTempo,
  }) =>
      PlayerState(
        queue: queue ?? this.queue,
        index: index ?? this.index,
        playing: playing ?? this.playing,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        tempo: tempo ?? this.tempo,
        repeat: repeat ?? this.repeat,
        shuffle: shuffle ?? this.shuffle,
        loopA: clearLoop ? null : (loopA ?? this.loopA),
        loopB: clearLoop ? null : (loopB ?? this.loopB),
        volume: volume ?? this.volume,
        rememberTempo: rememberTempo ?? this.rememberTempo,
      );
}

class PlayerController extends StateNotifier<PlayerState> {
  PlayerController(this._repo, this._handler) : super(const PlayerState()) {
    _wireHandler();
    _finishedSub = AudioEngine.instance.trackFinished.listen((_) => _onFinished());
  }

  final LibraryRepository _repo;
  final PlayerAudioHandler? _handler;

  /// 곡이 끝났을 때 다음 곡으로 넘어가도 되는지 묻는다.
  ///
  /// 참을 돌려주면 여기서 멈춘다. 슬립 타이머의 "이 곡까지"가 쓴다. 타이머를
  /// 오디오 계층에 직접 넣지 않으려고 고리만 뚫어둔다.
  bool Function()? shouldStopAfterTrack;

  final AudioEngine _engine = AudioEngine.instance;

  Timer? _ticker;
  StreamSubscription<void>? _finishedSub;
  List<int> _shuffleOrder = [];

  /// 연속으로 열지 못한 곡 수.
  ///
  /// 열리지 않는 곡에서 자동으로 다음 곡으로 넘어가는데, 라이브러리 전체가
  /// 못 여는 형식이면 끝까지 훑으며 돌게 된다. 몇 번 실패하면 멈춘다.
  int _consecutiveFailures = 0;

  /// 마지막으로 재생에 실패한 이유. UI에서 보여준다.
  String? lastError;

  void _wireHandler() {
    final h = _handler;
    if (h == null) return;
    h.onPlay = resume;
    h.onPause = pause;
    h.onNext = next;
    h.onPrevious = previous;
    h.onStop = stop;
    h.onSeek = seek;
  }

  // ── 큐 ─────────────────────────────────────────────────────────────

  Future<void> playQueue(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    state = state.copyWith(
      queue: tracks,
      index: startIndex.clamp(0, tracks.length - 1),
      clearLoop: true,
    );
    _rebuildShuffle();
    await _loadCurrent();
  }

  void _rebuildShuffle() {
    _shuffleOrder = List.generate(state.queue.length, (i) => i);
    if (state.shuffle) {
      _shuffleOrder.shuffle(math.Random());
      // 지금 곡을 맨 앞으로 옮겨서 바로 바뀌지 않게 한다.
      final cur = state.index;
      _shuffleOrder
        ..remove(cur)
        ..insert(0, cur);
    }
  }

  Future<void> _loadCurrent() async {
    final track = state.current;
    if (track == null) return;

    if (!File(track.filePath).existsSync()) {
      debugPrint('파일이 없다: ${track.filePath}');
      await _failCurrent('파일을 찾을 수 없습니다');
      return;
    }

    // 이 곡에 저장해둔 배속이 있으면 꺼내 쓴다. 미세 조정이 중요한 앱에서
    // 매번 다시 맞추게 하면 그게 제일 성가신 일이 된다.
    final saved = await _repo.tempoFor(track.id);
    final tempo = saved ?? state.tempo;
    _engine.applyTempo(tempo, smooth: false);

    try {
      final len = await _engine.playFile(track.filePath);
      state = state.copyWith(
        duration: len.inMilliseconds > 0
            ? len
            : Duration(milliseconds: track.durationMs),
        position: Duration.zero,
        playing: true,
        tempo: tempo,
        clearLoop: true,
      );
      _engine.setLooping(state.repeat == RepeatMode.one);
      _consecutiveFailures = 0;
      lastError = null;
      _startTicker();
      _publish();
    } catch (e) {
      debugPrint('재생 실패 [${track.filePath}]: $e');
      await _failCurrent('이 파일을 열지 못했습니다');
    }
  }

  /// 지금 곡을 열지 못했을 때. 몇 번 이어지면 멈춘다.
  Future<void> _failCurrent(String reason) async {
    lastError = reason;
    _consecutiveFailures++;
    if (_consecutiveFailures >= 3 || state.queue.length <= 1) {
      _consecutiveFailures = 0;
      _stopTicker();
      state = state.copyWith(playing: false);
      _handler?.publishIdle();
      return;
    }
    await next();
  }

  // ── 재생 제어 ──────────────────────────────────────────────────────

  void resume() {
    if (!_engine.hasTrack) return;
    _engine.resume();
    state = state.copyWith(playing: true);
    _startTicker();
    _publish();
  }

  void pause() {
    _engine.pause();
    state = state.copyWith(playing: false);
    _stopTicker();
    _publish();
  }

  void togglePlay() => state.playing ? pause() : resume();

  Future<void> stop() async {
    _stopTicker();
    await _engine.stop();
    state = state.copyWith(playing: false, position: Duration.zero);
    _handler?.publishIdle();
  }

  void seek(Duration position) {
    _engine.seek(position);
    state = state.copyWith(position: position);
    _publish();
  }

  void seekBy(Duration delta) {
    var target = state.position + delta;
    if (target.isNegative) target = Duration.zero;
    if (target > state.duration) target = state.duration;
    seek(target);
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;
    final n = _nextIndex();
    if (n == null) {
      pause();
      return;
    }
    state = state.copyWith(index: n);
    await _loadCurrent();
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;
    // 3초 넘게 재생됐으면 곡 처음으로 돌아간다. 흔한 동작이다.
    if (state.position > const Duration(seconds: 3)) {
      seek(Duration.zero);
      return;
    }
    final p = _previousIndex();
    if (p == null) {
      seek(Duration.zero);
      return;
    }
    state = state.copyWith(index: p);
    await _loadCurrent();
  }

  int? _nextIndex() {
    final len = state.queue.length;
    if (len == 0) return null;
    if (state.shuffle) {
      final pos = _shuffleOrder.indexOf(state.index);
      if (pos < 0) return _shuffleOrder.first;
      if (pos + 1 < _shuffleOrder.length) return _shuffleOrder[pos + 1];
      return state.repeat == RepeatMode.off ? null : _shuffleOrder.first;
    }
    if (state.index + 1 < len) return state.index + 1;
    return state.repeat == RepeatMode.off ? null : 0;
  }

  int? _previousIndex() {
    final len = state.queue.length;
    if (len == 0) return null;
    if (state.shuffle) {
      final pos = _shuffleOrder.indexOf(state.index);
      if (pos > 0) return _shuffleOrder[pos - 1];
      return state.repeat == RepeatMode.off ? null : _shuffleOrder.last;
    }
    if (state.index > 0) return state.index - 1;
    return state.repeat == RepeatMode.off ? null : len - 1;
  }

  Future<void> _onFinished() async {
    if (shouldStopAfterTrack?.call() ?? false) {
      pause();
      seek(Duration.zero);
      return;
    }
    if (state.repeat == RepeatMode.one) {
      // 엔진이 반복을 못 거는 경우(플랫폼 디코더로 트는 곡)에는 다시 연다.
      if (_engine.supportsEngineLooping) return;
      await _loadCurrent();
      return;
    }
    await next();
  }

  // ── 배속과 피치 ─────────────────────────────────────────────────────

  /// 미세 조정 중에는 [commit]을 거짓으로 두고, 손을 뗄 때 참으로 한 번 부른다.
  /// 그래야 드래그하는 내내 DB에 쓰지 않는다.
  void setTempo(TempoSettings t, {bool commit = false}) {
    state = state.copyWith(tempo: t);
    _engine.applyTempo(t);
    _publish();
    if (commit) _persistTempo();
  }

  void setSpeed(double speed, {bool commit = false}) =>
      setTempo(state.tempo.copyWith(speed: speed), commit: commit);

  void setPitchCents(double cents, {bool commit = false}) =>
      setTempo(state.tempo.copyWith(pitchCents: cents), commit: commit);

  void setTempoMode(TempoMode mode) =>
      setTempo(state.tempo.copyWith(mode: mode), commit: true);

  void resetTempo() =>
      setTempo(const TempoSettings(mode: TempoMode.linked), commit: true);

  void setRememberTempo(bool value) {
    state = state.copyWith(rememberTempo: value);
    final track = state.current;
    if (track == null) return;
    if (value) {
      _repo.saveTempoFor(track.id, state.tempo);
    } else {
      _repo.clearTempoFor(track.id);
    }
  }

  void _persistTempo() {
    if (!state.rememberTempo) return;
    final track = state.current;
    if (track == null) return;
    if (state.tempo.isNormal) {
      _repo.clearTempoFor(track.id);
    } else {
      _repo.saveTempoFor(track.id, state.tempo);
    }
  }

  // ── 그 외 ──────────────────────────────────────────────────────────

  void setVolume(double v) {
    _engine.volume = v;
    state = state.copyWith(volume: v);
  }

  void cycleRepeat() {
    final next = switch (state.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeat: next);
    _engine.setLooping(next == RepeatMode.one);
  }

  void toggleShuffle() {
    state = state.copyWith(shuffle: !state.shuffle);
    _rebuildShuffle();
  }

  /// A-B 구간 반복. 한 번 누르면 A, 다시 누르면 B, 또 누르면 해제.
  void markLoopPoint() {
    if (state.loopA == null) {
      state = state.copyWith(loopA: state.position);
    } else if (state.loopB == null) {
      final a = state.loopA!;
      final b = state.position;
      if (b <= a) {
        state = state.copyWith(loopA: b, loopB: a);
      } else {
        state = state.copyWith(loopB: b);
      }
      _engine.setLoopRegion(state.loopA, state.loopB);
    } else {
      clearLoop();
    }
  }

  /// 시작점만 따로 찍는다.
  ///
  /// 한 버튼을 두 번 눌러 A와 B를 찍는 방식은 지금 어느 쪽을 찍는 차례인지
  /// 화면만 보고 알 수 없다. 두 버튼으로 나누면 각각 다시 찍을 수도 있다.
  void setLoopA([Duration? at]) {
    final a = at ?? state.position;
    final b = state.loopB;
    if (b != null && a >= b) {
      // 끝점보다 뒤를 찍으면 끝점을 버린다. 뒤바꾸면 사용자가 방금 찍은
      // 자리가 시작점이 아니게 되어 더 헷갈린다.
      state = state.copyWith(clearLoop: true).copyWith(loopA: a);
    } else {
      state = state.copyWith(loopA: a);
    }
    _engine.setLoopRegion(state.loopA, state.loopB);
  }

  void setLoopB([Duration? at]) {
    final b = at ?? state.position;
    final a = state.loopA;
    if (a == null) {
      // 시작점이 없으면 곡 처음부터로 본다.
      state = state.copyWith(loopA: Duration.zero, loopB: b);
    } else if (b <= a) {
      return;
    } else {
      state = state.copyWith(loopB: b);
    }
    _engine.setLoopRegion(state.loopA, state.loopB);
  }

  /// 반복 구간의 시작으로 되돌린다. 방금 놓친 마디를 다시 듣는 데 쓴다.
  void restartLoop() {
    final a = state.loopA;
    if (a == null) return;
    seek(a);
  }

  void clearLoop() {
    state = state.copyWith(clearLoop: true);
    _engine.setLoopRegion(null, null);
    _engine.setLooping(state.repeat == RepeatMode.one);
  }

  // ── 진행 상황 ──────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final pos = _engine.position;

      // 엔진이 구간 반복을 못 거는 경우(플랫폼 디코더로 트는 곡)에는 끝점을
      // 지나는지 직접 보고 되돌린다.
      final a = state.loopA;
      final b = state.loopB;
      if (a != null && b != null && pos >= b) {
        _engine.seek(a);
        state = state.copyWith(position: a);
        return;
      }

      if (pos != state.position) {
        state = state.copyWith(position: pos);
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _publish() {
    final h = _handler;
    final track = state.current;
    if (h == null || track == null) return;
    h.publishItem(
      MediaItem(
        id: track.id.toString(),
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: state.duration,
        artUri: _artUri(track),
      ),
    );
    h.publish(
      playing: state.playing,
      position: state.position,
      speed: state.tempo.speed,
      hasNext: state.hasNext,
      hasPrevious: state.hasPrevious,
    );
  }

  Uri? _artUri(Track t) {
    final path = t.userArtworkPath ?? t.artworkPath;
    if (path == null) return null;
    if (!File(path).existsSync()) return null;
    return Uri.file(path);
  }

  @override
  void dispose() {
    _stopTicker();
    _finishedSub?.cancel();
    super.dispose();
  }
}
