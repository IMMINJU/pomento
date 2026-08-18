import 'package:flutter/material.dart';

import '../theme.dart';
import 'artwork_tone.dart';

/// 종이 위의 면들.
///
/// 유리를 대체한다. 판을 종이 **위에 얹지 않고 가라앉힌다.** 테두리를 긋는
/// 대신 한 단계 어두운 종이(`paperLo`)로 칠한다. 선을 그으면 화면이
/// 칸으로 잘려 보이고, 그것이 산타 마리아 노벨라 같은 사이트와 우리
/// 화면을 가르던 차이였다.
///
/// 선을 남긴 자리는 EQ 범례 하나뿐이다. 점선과 파선과 실선이 각각 어느
/// 층인지 보여주는 견본이라 지우면 뜻이 사라진다.

/// 가라앉은 면. 카드와 패널이 이것을 쓴다.
class Sunken extends StatelessWidget {
  const Sunken({
    super.key,
    required this.child,
    this.radius = AppRadius.card,
    this.padding,
    this.color,
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  /// 기본은 `paperLo`. 선택된 상태에서만 강조색 틴트를 넣는다.
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.paperLo,
        borderRadius: br,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: content),
      );
    }
    return content;
  }
}

/// 값 하나를 담는 작은 알약. 높이 26.
class ValuePill extends StatelessWidget {
  const ValuePill({
    super.key,
    required this.label,
    this.on = false,
    this.style,
  });

  final String label;

  /// 켜져 있으면 강조색 틴트. 색이 있으면 재생 중이거나 값이 바뀐 상태다.
  final bool on;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final tone = CoverScope.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? tone.accentTint : AppColors.paperLo,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: (style ?? AppText.num).copyWith(
          fontSize: 12,
          color: on ? tone.accentInk : AppColors.ink3,
        ),
      ),
    );
  }
}

/// 44px 동그란 버튼. 눌리는 자리는 전부 44px 이상이어야 한다.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.child,
    this.onTap,
    this.on = false,
    this.filled = true,
    this.size = AppSpace.tap,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// 켜진 상태. 잉크로 채우고 아이콘을 종이색으로 뒤집는다.
  final bool on;

  /// false면 바탕 없이 아이콘만. 손가락 자리는 그대로 44px이다.
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: !filled
          ? Colors.transparent
          : (on ? AppColors.ink1 : AppColors.paperLo),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// 아티스트 줄처럼 누를 수 있는 글자.
///
/// 링크색을 쓰지 않는다. 색은 재생 상태를 말하는 데 이미 쓰고 있어서,
/// 누를 수 있다는 것까지 색으로 말하면 둘이 섞인다. 밑줄이 대신한다.
class LinkText extends StatelessWidget {
  const LinkText({
    super.key,
    required this.text,
    this.onTap,
    this.style,
  });

  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xB3A8ADA5), width: 1),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style ?? AppText.sub,
      ),
    );
    if (onTap == null) return t;
    return GestureDetector(onTap: onTap, child: t);
  }
}

/// 목록 행. 높이 76, 좌우 26. 행 사이에 선을 긋지 않는다.
class PaperRow extends StatelessWidget {
  const PaperRow({
    super.key,
    required this.children,
    this.onTap,
    this.onLongPress,
    this.height = AppSpace.row,
  });

  final List<Widget> children;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 알약 세그먼트. `±8% | ±16% | 넓게` 같은 자리.
///
/// 고른 칸은 종이 하이라이트로 띄우고 나머지는 트랙에 잠긴다. 트랙 자체가
/// 가라앉은 면이라 여기서도 테두리가 필요 없다.
class SegmentBar extends StatelessWidget {
  const SegmentBar({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.height = 40,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.paperLo,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  height: height,
                  alignment: Alignment.center,
                  decoration: i == index
                      ? BoxDecoration(
                          color: AppColors.paperHi,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A232620),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        )
                      : null,
                  child: Text(
                    labels[i],
                    style: AppText.body.copyWith(
                      fontSize: 13,
                      fontWeight:
                          i == index ? FontWeight.w600 : FontWeight.w500,
                      color: i == index ? AppColors.ink1 : AppColors.ink2,
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

/// 누를 수 있는 알약. 고르면 강조색 틴트가 든다.
///
/// 유리 알약을 대신한다. 테두리가 없고, 고르지 않은 상태는 가라앉은 면이다.
class PaperPill extends StatelessWidget {
  const PaperPill({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tone = CoverScope.of(context);
    return Material(
      color: selected ? tone.accentTint : AppColors.paperLo,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 켜고 끄는 스위치.
///
/// Material의 Switch를 쓰지 않는다. 켜진 상태를 강조색으로 칠해버려서
/// "색이 있으면 재생 중"이라는 규칙을 깬다. 켜짐은 잉크로 채운다.
class PaperSwitch extends StatelessWidget {
  const PaperSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 46,
        height: 28,
        decoration: BoxDecoration(
          color: value ? AppColors.ink1 : AppColors.paperLo,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.paperHi,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33232620),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
