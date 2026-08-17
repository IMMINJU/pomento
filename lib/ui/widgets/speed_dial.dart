import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 배속 다이얼.
///
/// 미세 조정이 목적이라 세로 슬라이더 대신 원형을 쓴다. 같은 화면 면적에서
/// 손가락이 지나는 거리가 훨씬 길어 해상도가 나온다.
///
/// 세 가지가 같이 들어가 있다.
/// - 가속 곡선: 천천히 끌면 0.005 단위, 빠르게 끌면 굵게 붙는다
/// - 1.00 디텐트: 지나갈 때 진동을 주고 값이 살짝 붙잡힌다
/// - 항상 보이는 숫자: 소수 둘째 자리까지 고정폭으로
class SpeedDial extends StatefulWidget {
  const SpeedDial({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.centerLabel,
    this.subLabel,
    this.min = 0.5,
    this.max = 1.5,
    this.size = 240,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  /// 가운데 큰 숫자 아래에 붙는 설명. 예: "-2.2 반음".
  final String? subLabel;
  final String? centerLabel;

  final double min;
  final double max;
  final double size;

  @override
  State<SpeedDial> createState() => _SpeedDialState();
}

class _SpeedDialState extends State<SpeedDial> {
  static const double _startAngle = 135;
  static const double _sweep = 270;

  /// 1.00을 지나갈 때 붙잡히는 폭.
  static const double _detentWidth = 0.012;

  double _accum = 0;
  double? _lastAngle;
  bool _detentFired = false;

  double get _range => widget.max - widget.min;

  Offset get _center => Offset(widget.size / 2, widget.size / 2);

  /// 다이얼 중심에서 [p]를 바라본 각도(도).
  double _angleAt(Offset p) {
    final v = p - _center;
    return math.atan2(v.dy, v.dx) * 180 / math.pi;
  }

  void _onPanStart(DragStartDetails d) {
    _accum = widget.value;
    _lastAngle = _angleAt(d.localPosition);
    _detentFired = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final angle = _angleAt(d.localPosition);
    final last = _lastAngle;
    if (last == null) {
      _lastAngle = angle;
      return;
    }

    // 각도 차이를 -180~180으로 되돌린다. 그래야 아래쪽 틈을 지날 때 값이
    // 한 바퀴 튀지 않는다.
    var delta = angle - last;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    _lastAngle = angle;

    // 손가락이 중심에서 멀수록 같은 각도가 만드는 변화가 작아진다. 노브를
    // 바깥쪽으로 잡으면 곱게 돌아가는 것과 같은 감각이다.
    final radius = (d.localPosition - _center).distance;
    final fine = (widget.size / 2 / math.max(radius, 1)).clamp(0.35, 1.0);

    _accum = (_accum + delta / _sweep * _range * fine)
        .clamp(widget.min, widget.max);

    var next = _accum;

    // 1.00 근처에서는 값이 붙는다. 화면을 안 보고도 원위치를 찾을 수 있다.
    if ((next - 1.0).abs() < _detentWidth) {
      next = 1.0;
      if (!_detentFired) {
        HapticFeedback.selectionClick();
        _detentFired = true;
      }
    } else {
      _detentFired = false;
    }

    final rounded = (next * 200).round() / 200; // 0.005 단위
    if (rounded != widget.value) widget.onChanged(rounded);
  }

  void _onPanEnd(DragEndDetails _) {
    _lastAngle = null;
    widget.onChangeEnd(widget.value);
  }

  /// 버튼으로 한 칸씩. 손으로 정확히 맞추기 어려운 값을 짚을 때 쓴다.
  void _nudge(double step) {
    final next = ((widget.value + step) * 100).round() / 100;
    final clamped = next.clamp(widget.min, widget.max);
    HapticFeedback.selectionClick();
    widget.onChanged(clamped);
    widget.onChangeEnd(clamped);
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    widget.onChanged(1.0);
    widget.onChangeEnd(1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NudgeButton(
          icon: Icons.remove,
          onTap: () => _nudge(-0.01),
          onLongPress: () => _nudge(-0.05),
        ),
        const SizedBox(width: 4),
        _dial(),
        const SizedBox(width: 4),
        _NudgeButton(
          icon: Icons.add,
          onTap: () => _nudge(0.01),
          onLongPress: () => _nudge(0.05),
        ),
      ],
    );
  }

  Widget _dial() {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onDoubleTap: _reset,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(widget.size),
              painter: _DialPainter(
                value: widget.value,
                min: widget.min,
                max: widget.max,
                startAngle: _startAngle,
                sweep: _sweep,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.value.toStringAsFixed(2),
                      style: AppText.numeric,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4, left: 2),
                      child: Text(
                        'x',
                        style: TextStyle(fontSize: 13, color: AppColors.t3),
                      ),
                    ),
                  ],
                ),
                if (widget.subLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      widget.subLabel!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        color: AppColors.t3,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 다이얼 옆의 한 칸 이동 버튼. 짧게 누르면 0.01, 길게 누르면 0.05.
class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.icon,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, size: 20, color: AppColors.t2),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.startAngle,
    required this.sweep,
  });

  final double value;
  final double min;
  final double max;
  final double startAngle;
  final double sweep;

  double _angleOf(double v) =>
      startAngle + ((v - min) / (max - min)) * sweep;

  static double _rad(double deg) => deg * math.pi / 180;

  Offset _pt(Offset c, double r, double deg) =>
      Offset(c.dx + r * math.cos(_rad(deg)), c.dy + r * math.sin(_rad(deg)));

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final ringOuter = size.width / 2;
    final ringInner = ringOuter - 20;
    final arcR = ringOuter - 10;

    // 유리 링
    canvas.drawCircle(
      c,
      ringOuter,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
    canvas.drawCircle(
      c,
      ringOuter - 0.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      c,
      ringInner,
      Paint()..color = AppColors.bgBase.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      c,
      ringInner,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final arcRect = Rect.fromCircle(center: c, radius: arcR);

    // 전체 트랙
    canvas.drawArc(
      arcRect,
      _rad(startAngle),
      _rad(sweep),
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // 1.00에서 현재 값까지 채운 호
    if ((value - 1.0).abs() > 0.001) {
      final a1 = _angleOf(1.0);
      final a2 = _angleOf(value);
      canvas.drawArc(
        arcRect,
        _rad(math.min(a1, a2)),
        _rad((a2 - a1).abs()),
        false,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // 눈금. 0.05마다 짧게, 0.25마다 길게, 1.00은 accent로 가장 길게.
    const steps = 20;
    for (var i = 0; i <= steps; i++) {
      final v = min + (max - min) * i / steps;
      final ang = _angleOf(v);
      final isCenter = (v - 1.0).abs() < 0.001;
      final isLong = i % 5 == 0;
      final outerR = ringInner - 2;
      final innerR = outerR - (isCenter ? 14 : (isLong ? 10 : 5));
      canvas.drawLine(
        _pt(c, outerR, ang),
        _pt(c, innerR, ang),
        Paint()
          ..color = isCenter
              ? AppColors.accent
              : Colors.white.withValues(alpha: isLong ? 0.45 : 0.22)
          ..strokeWidth = isCenter ? 2.5 : (isLong ? 1.5 : 1)
          ..strokeCap = StrokeCap.round,
      );
    }

    // 1.00 마커
    final oneAngle = _angleOf(1.0);
    canvas.drawLine(
      _pt(c, ringOuter, oneAngle),
      _pt(c, ringInner - 4, oneAngle),
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // 현재 값 핸들
    final handle = _pt(c, (ringInner + ringOuter) / 2, _angleOf(value));
    canvas.drawCircle(
      handle,
      10,
      Paint()..color = AppColors.accent.withValues(alpha: 0.27),
    );
    canvas.drawCircle(
      handle,
      7,
      Paint()
        ..color = AppColors.accent
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.value != value;
}

/// 중앙에 디텐트가 있는 가로 슬라이더. 피치 미세 조정에 쓴다.
class CenterDetentSlider extends StatelessWidget {
  const CenterDetentSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = -100,
    this.max = 100,
    this.enabled = true,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        activeTrackColor: enabled ? AppColors.accent : AppColors.trackInactive,
        inactiveTrackColor: AppColors.trackInactive,
        thumbColor:
            enabled ? AppColors.accent : Colors.white.withValues(alpha: 0.40),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        // 0을 지날 때 붙잡아준다.
        onChanged: enabled
            ? (v) {
                final snapped = v.abs() < 3 ? 0.0 : v.roundToDouble();
                if (snapped == 0 && value != 0) HapticFeedback.selectionClick();
                onChanged(snapped);
              }
            : null,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}
