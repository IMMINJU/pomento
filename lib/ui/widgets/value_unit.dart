import 'package:flutter/material.dart';

import '../theme.dart';

/// Anytune 조절부를 옮긴 조각.
///
/// 양끝 글자 버튼과 가운데 값 블록으로 한 세트다. 값 아래에 얇은 트랙과
/// 삼각 표시가 있어서 숫자를 읽지 않고도 지금 값이 폭 안 어디쯤인지
/// 보인다. 한 줄에 이 세트가 둘 들어간다.
///
/// **알약이 아니라 모서리 6px 사각이다.** 알약은 다른 화면의 문법이고
/// 재생 화면 아래는 Anytune 배치를 그대로 옮긴 자리다. 색과 글자만
/// 우리 것을 쓴다.
class ValueUnit extends StatelessWidget {
  const ValueUnit({
    super.key,
    required this.minus,
    required this.plus,
    required this.value,
    required this.label,
    required this.position,
    this.onMinus,
    this.onPlus,
    this.onTap,
    this.changed = true,
  });

  /// 양끝 버튼에 찍는 글자. 피치는 −/+ 가 아니라 ♭/♯ 다.
  final String minus;
  final String plus;

  final String value;

  /// 값 옆에 붙는 작은 글자. 무엇을 다루는 값인지 말한다.
  final String label;

  /// 트랙 위 삼각 표시 자리. 0~1.
  final double position;

  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  /// 값 블록을 눌렀을 때. 직접 입력이나 모드 전환에 쓴다.
  final VoidCallback? onTap;

  /// 기본값에서 달라졌는지. 달라진 값만 강조색이다.
  final bool changed;

  static const double _h = 46;
  static const double _r = 6;

  @override
  Widget build(BuildContext context) {
    final tone = changed ? AppColors.accent : AppColors.ink2;
    final fill = changed ? AppColors.accentTint : AppColors.paperHi;

    return Expanded(
      child: Row(
        children: [
          _End(label: minus, onTap: onMinus),
          const SizedBox(width: 3),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                height: _h,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(_r),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.num.copyWith(
                              fontSize: 15,
                              color: tone,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: AppFont.ui,
                            fontSize: 10,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 5,
                      child: _Track(position: position, color: tone),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),
          _End(label: plus, onTap: onPlus),
        ],
      ),
    );
  }
}

class _End extends StatelessWidget {
  const _End({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: ValueUnit._h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paperHi,
          borderRadius: BorderRadius.circular(ValueUnit._r),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppFont.display,
            fontFamilyFallback: [AppFont.ui],
            fontSize: 17,
            color: AppColors.ink1,
          ),
        ),
      ),
    );
  }
}

/// 얇은 선과 그 아래 삼각 하나.
class _Track extends StatelessWidget {
  const _Track({required this.position, required this.color});

  final double position;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 5),
      painter: _TrackPainter(position.clamp(0.0, 1.0), color),
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter(this.position, this.color);

  final double position;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.hair.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 0.75), Offset(size.width, 0.75), line);

    final x = size.width * position;
    final tri = Path()
      ..moveTo(x - 3, 1.5)
      ..lineTo(x + 3, 1.5)
      ..lineTo(x, 5.5)
      ..close();
    canvas.drawPath(tri, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.position != position || old.color != color;
}

/// 조절 행의 양끝에 놓이는 사각 아이콘 버튼. 마크 이동이 쓴다.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 19,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: ValueUnit._h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paperHi,
          borderRadius: BorderRadius.circular(ValueUnit._r),
        ),
        child: Icon(icon, size: size, color: AppColors.ink1),
      ),
    );
  }
}

/// 패널 안의 선택 줄.
///
/// 둥근 트랙에서 고른 칸이 잉크로 찬다. 탭을 바꾸면 그 채움이 미끄러져
/// 옮겨간다. 어느 칸에서 어느 칸으로 갔는지가 보이면 방금 무엇을 눌렀는지
/// 되짚을 필요가 없다.
///
/// 안 고른 칸 중 **기본값에서 달라진 것은 강조색**으로 적는다. 무엇이
/// 걸려 있는지 이 줄만 봐도 안다. 고른 칸은 잉크로 차 있으니 미색이다.
class ValueSegment extends StatelessWidget {
  const ValueSegment({
    super.key,
    required this.index,
    required this.items,
    required this.onChanged,
  });

  final int index;
  final List<SegmentItem> items;
  final ValueChanged<int> onChanged;

  static const double _h = 46;
  static const double _pad = 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _h,
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / items.length;
          return Stack(
            children: [
              // 채움이 먼저 깔리고 글자가 그 위에 온다. 글자를 칸마다
              // 그리면 채움이 지나갈 때 아래로 숨는다
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink1,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontFamily: AppFont.ui,
                              fontSize: 14,
                              fontWeight: i == index
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: i == index
                                  ? AppColors.paperHi
                                  : (items[i].changed
                                        ? AppColors.accent
                                        : AppColors.ink3),
                            ),
                            child: Text(items[i].label),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class SegmentItem {
  const SegmentItem(this.label, {required this.changed});

  final String label;

  /// 기본값에서 달라졌는지. 안 고른 칸만 이 색을 쓴다.
  final bool changed;
}
