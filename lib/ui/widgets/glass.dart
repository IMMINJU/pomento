import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 유리 테두리를 그린다.
///
/// 시안은 테두리 위쪽만 더 밝다. Flutter의 BoxDecoration은 모서리가 둥글면
/// 변마다 다른 테두리를 못 쓰므로 직접 그린다.
class _GlassBorderPainter extends CustomPainter {
  const _GlassBorderPainter(this.radius, this.topColor, this.sideColor);

  final BorderRadius radius;
  final Color topColor;
  final Color sideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        [topColor, sideColor],
        const [0.0, 0.55],
      );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GlassBorderPainter old) =>
      old.radius != radius ||
      old.topColor != topColor ||
      old.sideColor != sideColor;
}

/// 유리 판.
///
/// 겹쳐 쓰지 않는다. 한 화면에 두 겹을 넘으면 안드로이드에서 프레임이
/// 떨어진다.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.panel,
    this.blur = AppBlur.panel,
    this.opacity = 0.10,
    this.borderColor,
    this.shadow = true,
    this.padding,
    this.width,
    this.height,
    this.onTap,
  });

  final Widget child;
  final double radius;
  final double blur;

  /// 흰색 채움의 불투명도. 밝은 앨범아트 위에서는 높여야 글자가 읽힌다.
  final double opacity;

  /// 선택 상태를 표시할 때 accent를 넣는다.
  final Color? borderColor;

  final bool shadow;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);

    Widget content = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur / 2.5, sigmaY: blur / 2.5),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: br,
          ),
          child: child,
        ),
      ),
    );

    // 테두리는 표면 전체를 감싸고 그려야 한다. 자식 위젯을 감싸면 안쪽
    // 여백만큼 작은 테두리가 하나 더 생겨서 알약 안에 알약이 든 것처럼 보인다.
    content = CustomPaint(
      foregroundPainter: _GlassBorderPainter(
        br,
        borderColor ?? AppColors.glassBorderTop,
        borderColor ?? AppColors.glassBorder,
      ),
      child: content,
    );

    if (shadow) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: br,
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: content,
      );
    }

    if (onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

/// 작은 알약. 배속 표시나 칩에 쓴다.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// 시안의 44×26 스위치.
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: SizedBox(
        width: 44,
        height: 26,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: value
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(13),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 연동 / 고정 같은 두 칸짜리 선택.
class GlassSegment extends StatelessWidget {
  const GlassSegment({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    this.width = 220,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 18,
      width: width,
      height: 36,
      shadow: false,
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? AppColors.glassRaised
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: i == selectedIndex
                          ? AppColors.accent
                          : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == selectedIndex
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: i == selectedIndex ? AppColors.t1 : AppColors.t3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 시안의 슬라이더 한 행. [라벨] [트랙] [값].
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.enabled = true,
  });

  final String label;
  final double value;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppColors.t2),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: enabled ? onChanged : null,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: AppText.mono,
            ),
          ),
        ],
      ),
    );
  }
}
