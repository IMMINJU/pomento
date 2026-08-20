import 'package:flutter/material.dart';

import '../../data/models/mark.dart';
import '../theme.dart';
import 'common.dart';

/// 마크 조각들.
///
/// 이름이 없다. 시각이 이름 자리를 대신하고, 값이 걸린 마크만 값을 뒤에
/// 붙인다. 왼쪽 표시로 점과 구간을 가른다.
///
/// 색은 전부 [AppColors.accent]다. 자켓색을 쓰지 않는다. 마크는 곡이
/// 아니라 내가 걸어둔 설정이고, 곡이 바뀔 때 같이 움직일 이유가 없다.

/// 마크가 붙는 값을 짧게 적는다. 값이 없으면 null.
String? markValueLabel(Mark m) {
  if (!m.hasValue) return null;
  if (m.speed != null) return '${m.speed!.toStringAsFixed(2)}×';
  final c = m.pitchCents!;
  return '${c > 0 ? '+' : ''}${c.toStringAsFixed(1)}¢';
}

String markTimeLabel(Mark m) => m.isLoop
    ? '${formatDuration(m.position)}–${formatDuration(m.end!)}'
    : formatDuration(m.position);

/// 점 마크는 동그라미, 구간 마크는 가로줄.
class _MarkGlyph extends StatelessWidget {
  const _MarkGlyph({required this.loop, required this.color});

  final bool loop;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (loop) {
      return SizedBox(
        width: 14,
        height: 8,
        child: Center(
          child: Container(
            height: 2.4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 진행바 아래에 놓이는 칩 하나. 44px.
class MarkChip extends StatelessWidget {
  const MarkChip({
    super.key,
    required this.mark,
    required this.on,
    this.onTap,
    this.onLongPress,
  });

  final Mark mark;

  /// 지금 재생 위치가 이 마크에 걸려 있는지.
  final bool on;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final value = markValueLabel(mark);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: AppSpace.tap,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? AppColors.accentTint : AppColors.paperLo,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MarkGlyph(
              loop: mark.isLoop,
              color: on ? AppColors.accent : AppColors.hair,
            ),
            const SizedBox(width: 8),
            Text(
              markTimeLabel(mark),
              style: AppText.num.copyWith(
                fontSize: 14,
                color: on ? AppColors.accent : AppColors.ink2,
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(
                value,
                style: AppText.num.copyWith(
                  fontSize: 13,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 칩 줄. 칩만 옆으로 밀리고 + 는 오른쪽 끝에 남는다.
///
/// 같이 밀리면 마크가 많은 곡에서 찍을 길이 없어진다. 마크가 없으면
/// 줄 자체를 안 그린다. 그때는 패널의 마크 탭이 진입점을 맡는다.
class MarkChipRow extends StatelessWidget {
  const MarkChipRow({
    super.key,
    required this.marks,
    required this.activeId,
    required this.onTap,
    required this.onAdd,
    this.onLongPress,
  });

  final List<Mark> marks;
  final int? activeId;
  final ValueChanged<Mark> onTap;
  final ValueChanged<Mark>? onLongPress;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (marks.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: AppSpace.tap,
      child: Row(
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.95, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: AppSpace.gutter),
                itemCount: marks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final m = marks[i];
                  return MarkChip(
                    mark: m,
                    on: m.id == activeId,
                    onTap: () => onTap(m),
                    onLongPress:
                        onLongPress == null ? null : () => onLongPress!(m),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.gutter),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAdd,
              child: Container(
                width: AppSpace.tap,
                height: AppSpace.tap,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.paperLo,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 19, color: AppColors.ink3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 패널 안의 마크 목록 한 줄. 44px.
///
/// 표시 · 시각 · 값 세 칸이다. 길게 누르면 지운다.
class MarkListRow extends StatelessWidget {
  const MarkListRow({
    super.key,
    required this.mark,
    required this.on,
    this.onTap,
    this.onLongPress,
  });

  final Mark mark;
  final bool on;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final value = markValueLabel(mark);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: AppSpace.tap,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: on ? AppColors.accentTint : AppColors.paperHi,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: Center(
                child: _MarkGlyph(
                  loop: mark.isLoop,
                  color: on ? AppColors.accent : AppColors.hair,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                markTimeLabel(mark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.num.copyWith(
                  fontSize: 15,
                  color: on ? AppColors.accent : AppColors.ink1,
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: AppText.num.copyWith(
                  fontSize: 14,
                  color: on ? AppColors.accent : AppColors.ink1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
