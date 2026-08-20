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

/// 진행 바. 트랙 2px에 채운 만큼만 자켓색.
///
/// 손잡이 동그라미를 두지 않는다. 인쇄물에 튀어나온 부품이 없다. 누르고
/// 끄는 자리는 20px로 넓게 잡되 그리지는 않는다.
///
/// 마크는 막대 **안에서** 처리한다. 점 마크는 잉크 눈금, 구간 마크는 그
/// 구간만 옅게 칠한다. 새 선을 긋지 않으니 화면이 칸으로 안 잘리고,
/// 파형이 필요 없어서 시각 값만 있으면 그려진다.
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.progress,
    this.onSeek,
    this.height = 2,
    this.ticks = const [],
    this.spans = const [],
  });

  final double progress;
  final ValueChanged<double>? onSeek;
  final double height;

  /// 점 마크 자리. 0~1.
  final List<double> ticks;

  /// 구간 마크. 각각 시작과 끝이 0~1이다.
  final List<({double start, double end})> spans;

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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final s in spans)
                      Positioned(
                        left: w * s.start.clamp(0.0, 1.0),
                        width: w * (s.end - s.start).clamp(0.0, 1.0),
                        top: -1,
                        bottom: -1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.accentTint,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: p,
                      child: Container(
                        decoration: BoxDecoration(
                          color: tone.fill,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                    for (final t in ticks)
                      Positioned(
                        left: w * t.clamp(0.0, 1.0) - 0.75,
                        top: -3,
                        child: Container(
                          width: 1.5,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.hair,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
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
