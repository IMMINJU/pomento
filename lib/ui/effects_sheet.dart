import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/preset.dart';
import '../providers.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/eq_graph.dart';
import 'widgets/glass.dart';

void openEffectsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const EffectsSheet(),
  );
}

class EffectsSheet extends ConsumerWidget {
  const EffectsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(effectControllerProvider);
    final controller = ref.read(effectControllerProvider.notifier);
    final presets = ref.watch(presetRepositoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xD10C0C14),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        border: Border(top: BorderSide(color: Color(0x29FFFFFF))),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SizedBox(height: 12),
                const SheetHandle(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      const Text('음향', style: AppText.display),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          await controller.resetAll();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('음향을 원래대로 되돌렸습니다')),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.refresh, size: 16,
                                  color: AppColors.t2),
                              SizedBox(width: 6),
                              Text('초기화',
                                  style: TextStyle(
                                      fontSize: 14, color: AppColors.t2)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 1층: 기기 ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('1. 기기'),
                      const SizedBox(height: 8),
                      Container(
                        height: 76,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              child: const Icon(Icons.headphones,
                                  size: 20, color: AppColors.t2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.devicePreset?.name ??
                                        state.device.label,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.t2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    state.deviceAuto
                                        ? '기기 보정 자동 적용'
                                        : '직접 고른 보정',
                                    style: AppText.small,
                                  ),
                                ],
                              ),
                            ),
                            GlassSwitch(
                              value: state.deviceEnabled,
                              onChanged: controller.setDeviceEnabled,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 자동 감지가 틀렸을 때 직접 고를 수 있게 한다.
                      FutureBuilder<List<Preset>>(
                        future: presets.byLayer(PresetLayer.device),
                        builder: (context, snap) {
                          final list = snap.data ?? const <Preset>[];
                          if (list.isEmpty) return const SizedBox.shrink();
                          return SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                GlassPill(
                                  selected: state.deviceAuto,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  onTap: controller.enableDeviceAuto,
                                  child: const Text('자동',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.t2)),
                                ),
                                const SizedBox(width: 6),
                                for (final p in list) ...[
                                  GlassPill(
                                    selected: !state.deviceAuto &&
                                        state.devicePreset?.id == p.id,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    onTap: () =>
                                        controller.selectDevicePreset(p),
                                    child: Text(p.name,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.t2)),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ── 2층: 환경 ────────────────────────────────────
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 20, bottom: 10),
                  child: SectionLabel('2. 환경'),
                ),
                _PresetChips(
                  layer: PresetLayer.environment,
                  selectedId: state.environmentPreset?.id,
                  onSelect: controller.selectEnvironment,
                ),

                // ── 3층: 취향 ────────────────────────────────────
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 20, bottom: 10),
                  child: SectionLabel('3. 취향'),
                ),
                _TastePresetCards(
                  selectedId: state.tastePreset?.id,
                  onSelect: controller.selectTaste,
                ),

                // ── 합산 그래프 ──────────────────────────────────
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 200,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Stack(
                      children: [
                        EqGraph(
                          device: state.deviceEnabled
                              ? state.devicePreset?.eq
                              : null,
                          environment: state.environmentPreset?.eq,
                          taste: state.tastePreset?.eq,
                          height: 150,
                        ),
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: _GraphLegend(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 슬라이더 ─────────────────────────────────────
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      LabeledSlider(
                        label: '리버브',
                        value: state.reverb.wet,
                        valueLabel: '${(state.reverb.wet * 100).round()}%',
                        onChanged: controller.setReverbWet,
                      ),
                      const SizedBox(height: 12),
                      LabeledSlider(
                        label: '공간 크기',
                        value: state.reverb.roomSize,
                        valueLabel:
                            '${(state.reverb.roomSize * 100).round()}%',
                        onChanged: controller.setReverbRoomSize,
                      ),
                      const SizedBox(height: 12),
                      LabeledSlider(
                        label: '에코',
                        value: state.echo.wet,
                        valueLabel: '${(state.echo.wet * 100).round()}%',
                        onChanged: controller.setEchoWet,
                      ),
                      const SizedBox(height: 12),
                      // 시안의 '크로스피드' 자리. 엔진에 BS2B 크로스피드가
                      // 없어서 스테레오 넓이로 대신한다.
                      LabeledSlider(
                        label: '공간 넓이',
                        value: state.reverb.width,
                        valueLabel: '${(state.reverb.width * 100).round()}%',
                        onChanged: controller.setWidth,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '등청감 보정',
                              style: TextStyle(
                                  fontSize: 15, color: AppColors.t2),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              '볼륨이 낮을 때 저역과 고역을 보강합니다',
                              style: AppText.small,
                            ),
                          ),
                          GlassSwitch(
                            value: state.loudnessComp,
                            onChanged: controller.setLoudnessComp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 하단 고정 바
          Container(
            height: 64,
            padding: const EdgeInsets.only(left: 20, right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ),
                AccentButton(
                  label: '저장',
                  onPressed: () => _saveDialog(context, ref),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _saveDialog(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(effectControllerProvider.notifier);
    final current = ref.read(effectControllerProvider).tastePreset;
    final textController =
        TextEditingController(text: '${current?.name ?? '내 설정'} 사본');

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: const Text('취향 프리셋으로 저장', style: AppText.body),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              style: AppText.body,
              cursorColor: AppColors.accent,
              decoration: const InputDecoration(
                hintText: '이름',
                hintStyle: TextStyle(color: AppColors.t3),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '취향 층과 지금 배속이 함께 저장됩니다. '
              '기기 보정은 각자 폰에 남습니다.',
              style: AppText.small,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소', style: TextStyle(color: AppColors.t2)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, textController.text),
            child: const Text('저장',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;
    // 지금 걸린 배속까지 프리셋에 담는다.
    await controller.saveAsTastePreset(
      name.trim(),
      tempo: ref.read(playerControllerProvider).tempo,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name 저장됨')));
  }
}

class _GraphLegend extends StatelessWidget {
  const _GraphLegend();

  @override
  Widget build(BuildContext context) {
    const items = [
      (label: '기기 보정', alpha: 0.35, dashed: true),
      (label: '환경 보정', alpha: 0.45, dashed: true),
      (label: '취향', alpha: 0.55, dashed: true),
      (label: '합산', alpha: 1.0, dashed: false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: item.dashed ? 1 : 2,
                  color: item.dashed
                      ? Colors.white.withValues(alpha: item.alpha)
                      : AppColors.accent,
                ),
                const SizedBox(width: 5),
                Text(item.label,
                    style: const TextStyle(fontSize: 10, color: AppColors.t3)),
              ],
            ),
          ),
      ],
    );
  }
}

class _PresetChips extends ConsumerWidget {
  const _PresetChips({
    required this.layer,
    required this.selectedId,
    required this.onSelect,
  });

  final PresetLayer layer;
  final String? selectedId;
  final ValueChanged<Preset> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Preset>>(
      stream: ref.watch(presetRepositoryProvider).watchByLayer(layer),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <Preset>[];
        return SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => GlassPill(
              selected: list[i].id == selectedId,
              onTap: () => onSelect(list[i]),
              child: Text(
                list[i].name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: list[i].id == selectedId
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: list[i].id == selectedId
                      ? AppColors.t1
                      : AppColors.t2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TastePresetCards extends ConsumerWidget {
  const _TastePresetCards({required this.selectedId, required this.onSelect});

  final String? selectedId;
  final ValueChanged<Preset> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Preset>>(
      stream: ref
          .watch(presetRepositoryProvider)
          .watchByLayer(PresetLayer.taste),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <Preset>[];
        return SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = list[i];
              final sel = p.id == selectedId;
              return GestureDetector(
                onTap: () => onSelect(p),
                child: Container(
                  width: 132,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withValues(alpha: sel ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: sel
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: MiniEqCurve(
                          curve: p.eq,
                          width: 96,
                          height: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight:
                              sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? AppColors.t1 : AppColors.t2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
