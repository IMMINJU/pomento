import 'dart:async';

import 'package:flutter/widgets.dart';

/// 누르고 있으면 계속 실행되는 버튼.
///
/// 배속을 0.05씩 올리려고 열 번 두드리게 두면 안 된다. 처음 한 번은 바로
/// 실행하고, 조금 기다렸다가 빠르게 반복한다. 기다리는 구간이 없으면 한 번만
/// 누르려던 것이 두세 번 실행된다.
///
/// 재생 화면의 ⊖ ⊕ 와 연습 화면의 스테퍼가 같은 것을 쓴다.
class HoldRepeat extends StatefulWidget {
  const HoldRepeat({
    super.key,
    required this.child,
    required this.onTrigger,
    this.delay = const Duration(milliseconds: 420),
    this.interval = const Duration(milliseconds: 75),
  });

  final Widget child;
  final VoidCallback onTrigger;

  /// 반복이 시작되기까지 기다리는 시간.
  final Duration delay;

  /// 반복 간격.
  final Duration interval;

  @override
  State<HoldRepeat> createState() => _HoldRepeatState();
}

class _HoldRepeatState extends State<HoldRepeat> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _down() {
    widget.onTrigger();
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      _timer = Timer.periodic(widget.interval, (_) => widget.onTrigger());
    });
  }

  void _up() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      child: widget.child,
    );
  }
}
