import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/tempo.dart';
import '../providers.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';
import 'widgets/speed_dial.dart';

void openSpeedSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    builder: (_) => const SpeedSheet(),
  );
}

class SpeedSheet extends ConsumerWidget {
  const SpeedSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final tempo = state.tempo;
    final isLinked = tempo.mode == TempoMode.linked;

    return Container(
      height: MediaQuery.of(context).size.height * 0.58,
      decoration: const BoxDecoration(
        color: Color(0xBF0E0E16),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 12),
              const SheetHandle(),
              const SizedBox(height: 20),

              // 연동 / 고정
              GlassSegment(
                labels: [TempoMode.linked.label, TempoMode.independent.label],
                selectedIndex: isLinked ? 0 : 1,
                onSelect: (i) => controller.setTempoMode(
                  i == 0 ? TempoMode.linked : TempoMode.independent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tempo.mode.hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 18 / 13,
                  color: AppColors.t3,
                ),
              ),
              const SizedBox(height: 20),

              SpeedDial(
                value: tempo.speed,
                subLabel: isLinked
                    ? '${tempo.impliedSemitones >= 0 ? '+' : ''}'
                        '${tempo.impliedSemitones.toStringAsFixed(1)} 반음'
                    : '음 높이 유지',
                onChanged: (v) =>
                    controller.setTempo(tempo.copyWith(speed: v)),
                onChangeEnd: (v) => controller.setTempo(
                  tempo.copyWith(speed: v),
                  commit: true,
                ),
              ),
              const SizedBox(height: 24),

              // 피치 미세 조정. 고정 모드에서만 쓴다.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Opacity(
                  opacity: isLinked ? 0.35 : 1,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            '피치',
                            style: TextStyle(fontSize: 15, color: AppColors.t2),
                          ),
                          const Spacer(),
                          Text(
                            tempo.pitchCents.round().toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.t2,
                              fontFeatures: tabularFigures,
                            ),
                          ),
                        ],
                      ),
                      CenterDetentSlider(
                        value: tempo.pitchCents,
                        enabled: !isLinked,
                        onChanged: (v) => controller.setTempo(
                          tempo.copyWith(pitchCents: v),
                        ),
                        onChangeEnd: (v) => controller.setTempo(
                          tempo.copyWith(pitchCents: v),
                          commit: true,
                        ),
                      ),
                      const Row(
                        children: [
                          Text('-100', style: AppText.small),
                          Spacer(),
                          Text('센트', style: AppText.small),
                          Spacer(),
                          Text('+100', style: AppText.small),
                        ],
                      ),
                      if (isLinked)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            '고정 모드에서 조절할 수 있습니다',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.t3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // A=432Hz 같은 흔한 튜닝을 한 번에 맞추는 지름길.
              if (!isLinked)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (final preset in const [
                        (label: 'A=432', cents: -31.8),
                        (label: '-1 반음', cents: -100.0),
                        (label: '0', cents: 0.0),
                        (label: '+1 반음', cents: 100.0),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GlassPill(
                            selected:
                                (tempo.pitchCents - preset.cents).abs() < 0.5,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            onTap: () => controller.setTempo(
                              tempo.copyWith(pitchCents: preset.cents),
                              commit: true,
                            ),
                            child: Text(
                              preset.label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.t2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (!isLinked) const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassSurface(
                        radius: AppRadius.card,
                        height: 48,
                        onTap: controller.resetTempo,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, size: 16, color: AppColors.t2),
                            SizedBox(width: 8),
                            Text('1.00으로',
                                style: TextStyle(
                                    fontSize: 15, color: AppColors.t1)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassSurface(
                        radius: AppRadius.card,
                        height: 48,
                        padding:
                            const EdgeInsets.only(left: 14, right: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.bookmark_added_outlined,
                                size: 16, color: AppColors.t2),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                '이 곡에 기억',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.t2),
                              ),
                            ),
                            GlassSwitch(
                              value: state.rememberTempo,
                              onChanged: controller.setRememberTempo,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // A-B 구간 반복
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassSurface(
                  radius: AppRadius.card,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  onTap: controller.markLoopPoint,
                  child: Row(
                    children: [
                      Icon(
                        Icons.repeat,
                        size: 16,
                        color: state.loopA != null
                            ? AppColors.accent
                            : AppColors.t2,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          switch ((state.loopA, state.loopB)) {
                            (null, _) => '구간 반복 시작점 찍기',
                            (final a?, null) =>
                              'A ${formatDuration(a)} · 끝점을 찍으세요',
                            (final a?, final b?) =>
                              '${formatDuration(a)} ~ ${formatDuration(b)} 반복 중',
                          },
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.t2),
                        ),
                      ),
                      if (state.loopA != null)
                        GestureDetector(
                          onTap: controller.clearLoop,
                          child: const Icon(Icons.close,
                              size: 16, color: AppColors.t3),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }
}
