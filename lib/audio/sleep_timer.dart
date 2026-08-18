import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 슬립 타이머 상태.
class SleepTimerState {
  const SleepTimerState({this.remaining, this.untilTrackEnd = false});

  static const SleepTimerState off = SleepTimerState();

  /// 남은 시간. null이면 꺼져 있다.
  final Duration? remaining;

  /// 남은 시간 대신 지금 곡이 끝나면 멈추는 방식.
  final bool untilTrackEnd;

  bool get isOn => remaining != null || untilTrackEnd;

  String get label {
    if (untilTrackEnd) return '이 곡까지';
    final r = remaining;
    if (r == null) return '꺼짐';
    final m = r.inMinutes;
    final sec = r.inSeconds % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

/// 정해둔 시간이 지나면 재생을 멈춘다.
///
/// 소리를 서서히 줄이지 않고 그냥 멈춘다. 페이드아웃을 넣으면 엔진의 볼륨을
/// 건드려야 하는데, 그 값은 등청감 보정이 함께 보고 있어서 잠든 뒤에도
/// 보정이 어긋난 채로 남는다.
class SleepTimerController extends StateNotifier<SleepTimerState> {
  SleepTimerController(this._onFire) : super(SleepTimerState.off);

  final void Function() _onFire;
  Timer? _ticker;

  void start(Duration duration) {
    _ticker?.cancel();
    state = SleepTimerState(remaining: duration);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = state.remaining;
      if (left == null) return;
      final next = left - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        cancel();
        _onFire();
      } else {
        state = SleepTimerState(remaining: next);
      }
    });
  }

  /// 지금 곡이 끝날 때까지만.
  void startUntilTrackEnd() {
    _ticker?.cancel();
    _ticker = null;
    state = const SleepTimerState(untilTrackEnd: true);
  }

  /// 곡이 끝났다고 알려온다. 켜져 있으면 여기서 멈춘다.
  ///
  /// 다음 곡으로 넘어가기 전에 불러야 한다.
  bool consumeTrackEnd() {
    if (!state.untilTrackEnd) return false;
    cancel();
    _onFire();
    return true;
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    state = SleepTimerState.off;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
