import 'package:flutter/material.dart';

import '../theme.dart';
import 'artwork_tone.dart';

String formatDuration(Duration d) {
  final total = d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// 시트 위쪽의 손잡이 막대.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.paperLo,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      );
}

/// 진행 바. 트랙 2px에 채운 만큼만 강조색.
///
/// 손잡이 동그라미를 두지 않는다. 인쇄물에 튀어나온 부품이 없다. 누르고
/// 끄는 자리는 20px로 넓게 잡되 그리지는 않는다.
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.progress,
    this.onSeek,
    this.height = 2,
  });

  final double progress;
  final ValueChanged<double>? onSeek;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tone = CoverScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final p = progress.clamp(0.0, 1.0);
        void handle(Offset local) {
          if (onSeek == null) return;
          onSeek!((local.dx / w).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => handle(d.localPosition),
          onHorizontalDragUpdate: (d) => handle(d.localPosition),
          child: SizedBox(
            height: 20,
            child: Center(
              // 폭을 못 박지 않으면 Container가 자식 폭으로 줄어들어서
              // FractionallySizedBox가 기준을 못 받는다
              child: Container(
                width: double.infinity,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.paperLo,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: p,
                  child: Container(
                    decoration: BoxDecoration(
                      color: tone.accent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 섹션 라벨. 자간을 벌린 작은 회색 글자.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppText.label);
}

/// 화면에서 제일 중요한 동작 하나. 잉크로 채운다.
///
/// 강조색으로 채우지 않는다. 강조색은 재생 상태를 말하는 데 쓰고 있어서,
/// 버튼까지 그 색으로 칠하면 무엇이 재생 중이라는 뜻인지 흐려진다.
class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
  });

  final String label;
  final VoidCallback? onPressed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? AppColors.ink1 : AppColors.paperLo,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: padding,
          child: Text(
            label,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.paperHi : AppColors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: AppColors.hair),
              const SizedBox(height: 18),
              Text(
                title,
                style: AppText.title.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(body, style: AppText.sub, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      );
}
