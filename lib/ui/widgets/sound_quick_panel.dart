import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/preset.dart';
import '../../providers.dart';
import '../theme.dart';
import 'glass.dart';

/// 재생 화면에서 바로 누르는 음향 프리셋.
///
/// 세 층 중 환경과 취향만 둔다. 기기 층은 연결된 이어폰을 보고 자동으로
/// 붙으므로 여기서 고를 일이 없고, 잘못 건드리면 보정이 어긋난다.
class SoundQuickPanel extends ConsumerWidget {
  const SoundQuickPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(effectControllerProvider);
    final controller = ref.read(effectControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PresetRow(
          label: '취향',
          layer: PresetLayer.taste,
          selectedId: state.tastePreset?.id,
          onSelect: controller.selectTaste,
        ),
        const SizedBox(height: 10),
        _PresetRow(
          label: '환경',
          layer: PresetLayer.environment,
          selectedId: state.environmentPreset?.id,
          onSelect: controller.selectEnvironment,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.headphones, size: 14, color: AppColors.t3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                state.devicePreset?.name ?? state.device.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small,
              ),
            ),
            const Text('등청감',
                style: TextStyle(fontSize: 13, color: AppColors.t2)),
            const SizedBox(width: 8),
            GlassSwitch(
              value: state.loudnessComp,
              onChanged: controller.setLoudnessComp,
            ),
          ],
        ),
      ],
    );
  }
}

class _PresetRow extends ConsumerWidget {
  const _PresetRow({
    required this.label,
    required this.layer,
    required this.selectedId,
    required this.onSelect,
  });

  final String label;
  final PresetLayer layer;
  final String? selectedId;
  final ValueChanged<Preset> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Preset>>(
      stream: ref.watch(presetRepositoryProvider).watchByLayer(layer),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <Preset>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              child: Text(label, style: AppText.small),
            ),
            Expanded(
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    final on = p.id == selectedId;
                    return GlassPill(
                      selected: on,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      onTap: () => onSelect(p),
                      child: Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                          color: on ? AppColors.t1 : AppColors.t2,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
