import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 점프 탐색 버튼. 원형 화살표 안에 초를 적는다.
///
/// 애플 팟캐스트, 스포티파이, 유튜브가 다 쓰는 모양이다. 그냥 빨리감기
/// 아이콘을 쓰면 짧게(3초)와 길게(10초) 넷이 같은 그림이 돼서 구분이 안
/// 된다.
///
/// 알약 배경을 두지 않는다. 화살표의 원이 테두리를 겸한다. 배경을 깔면
/// 한 줄에 채워진 면이 넷 더 생겨서 구간 반복 알약과 위계가 안 맞는다.
/// 화살표는 흐리게, 숫자는 선명하게. 먼저 읽혀야 하는 것은 숫자다.
class JumpButton extends StatelessWidget {
  const JumpButton({
    super.key,
    required this.seconds,
    required this.back,
    required this.onTap,
  });

  final int seconds;
  final bool back;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: AppSpace.tap,
        height: AppSpace.tap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(40, 40),
              painter: _ArrowRing(back: back),
            ),
            Text(
              '$seconds',
              style: AppText.num.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowRing extends CustomPainter {
  const _ArrowRing({required this.back});

  final bool back;

  /// 24 좌표계로 그리고 마지막에 크기를 맞춘다.
  static const double _box = 24;
  static const double _r = 7.8;

  /// 위쪽에 화살촉 자리를 남기고 나머지를 두른다.
  static const double _sweep = 5.07;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _box);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..color = AppColors.hair;

    canvas.drawArc(
      Rect.fromCircle(center: const Offset(12, 12), radius: _r),
      -math.pi / 2,
      back ? -_sweep : _sweep,
      false,
      stroke,
    );

    final head = Path();
    if (back) {
      head.moveTo(12.7, 0.8);
      head.lineTo(7.6, 4.2);
      head.lineTo(12.7, 7.6);
    } else {
      head.moveTo(11.3, 0.8);
      head.lineTo(16.4, 4.2);
      head.lineTo(11.3, 7.6);
    }
    head.close();
    canvas.drawPath(head, Paint()..color = AppColors.hair);
  }

  @override
  bool shouldRepaint(_ArrowRing old) => old.back != back;
}
