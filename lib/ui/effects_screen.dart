import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/effect_controller.dart';
import '../data/models/preset.dart';
import '../providers.dart';
import 'eq_editor_screen.dart';
import 'home_shell.dart';
import 'presets_screen.dart';
import 'theme.dart';
import 'widgets/artwork.dart';
import 'widgets/common.dart';
import 'widgets/eq_graph.dart';
import 'widgets/glass.dart';
import 'widgets/screen_header.dart';

/// 재생 화면 위에 쌓는다.
///
/// Capriccio의 Effects 화면이 그렇듯 미니 플레이어와 탭바가 남아 있어야
/// 프리셋을 눌러가며 소리를 바로 견줄 수 있다. 모달로 덮으면 그 비교가
/// 끊긴다.
void openEffectsScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const EffectsScreen()),
  );
}

/// 3층 음향 보정 화면.
///
/// Capriccio의 Effects 화면과 같은 세 갈래로 나눈다. 음향 효과에는 세 층의
/// 프리셋과 합산 곡선을, 추가 효과에는 리버브·에코 같은 층 밖의 처리를,
/// 공유에는 취향 층을 주고받는 길을 둔다.
class EffectsScreen extends ConsumerStatefulWidget {
  const EffectsScreen({super.key});

  @override
  ConsumerState<EffectsScreen> createState() => _EffectsScreenState();
}

class _EffectsScreenState extends ConsumerState<EffectsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(effectControllerProvider);
    final controller = ref.read(effectControllerProvider.notifier);

    final bottomInset = shellBottomInset(context, ref);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // 유리 뒤에 볼 것이 있어야 블러가 성립한다.
          BlurredBackdrop(
            track: ref.watch(playerControllerProvider).current,
            topOverlay: 0.55,
            bottomOverlay: 0.80,
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                ScreenHeader(
                  title: '음향',
                  actions: [
                    HeaderAction(
                      icon: Icons.refresh,
                      label: '초기화',
                      onTap: () async {
                        await controller.resetAll();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('음향을 원래대로 되돌렸습니다')),
                        );
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassSegment(
                    // 세 칸이라 220으로는 글자가 잘린다. 화면 너비를 다 쓴다.
                    width: double.infinity,
                    labels: const ['음향 효과', '추가 효과', '공유'],
                    selectedIndex: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  summary: state.summary,
                  onSave: () => _saveDialog(context),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      _LayersTab(
                        state: state,
                        controller: controller,
                        bottomInset: bottomInset,
                      ),
                      _ExtrasTab(
                        state: state,
                        controller: controller,
                        bottomInset: bottomInset,
                      ),
                      _ShareTab(bottomInset: bottomInset),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDialog(BuildContext context) async {
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

/// 기기 · 환경 · 취향 세 층과 합산 곡선.
class _LayersTab extends ConsumerStatefulWidget {
  const _LayersTab({
    required this.state,
    required this.controller,
    required this.bottomInset,
  });

  final EffectState state;
  final EffectController controller;
  final double bottomInset;

  @override
  ConsumerState<_LayersTab> createState() => _LayersTabState();
}

class _LayersTabState extends ConsumerState<_LayersTab> {
  /// 취향 층에서 내장 프리셋을 볼지, 내가 저장한 것을 볼지.
  bool _custom = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    final bottomInset = widget.bottomInset;
    final presets = ref.watch(presetRepositoryProvider);

    return ListView(
      padding: EdgeInsets.only(bottom: bottomInset + 24),
      children: [
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
                  borderRadius: BorderRadius.circular(AppRadius.card),
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
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Icon(Icons.headphones,
                          size: 20, color: AppColors.t2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.devicePreset?.name ?? state.device.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.t2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.deviceAuto ? '기기 보정 자동 적용' : '직접 고른 보정',
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
                                  fontSize: 12, color: AppColors.t2)),
                        ),
                        const SizedBox(width: 6),
                        for (final p in list) ...[
                          GlassPill(
                            selected: !state.deviceAuto &&
                                state.devicePreset?.id == p.id,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            onTap: () => controller.selectDevicePreset(p),
                            child: Text(p.name,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.t2)),
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
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
          child: Row(
            children: [
              const SectionLabel('3. 취향'),
              const Spacer(),
              // Capriccio의 Presets | Custom Effects 알약.
              for (final entry in const [(false, '프리셋'), (true, '내가 만든 것')])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GlassPill(
                    selected: _custom == entry.$1,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    onTap: () => setState(() => _custom = entry.$1),
                    child: Text(
                      entry.$2,
                      style: TextStyle(
                        fontSize: 12,
                        color: _custom == entry.$1
                            ? AppColors.t1
                            : AppColors.t3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _TastePresetCards(
          selectedId: state.tastePreset?.id,
          onSelect: controller.selectTaste,
          custom: _custom,
        ),

        // ── 합산 그래프 ──────────────────────────────────
        const SizedBox(height: 20),
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
                  device:
                      state.deviceEnabled ? state.devicePreset?.eq : null,
                  environment: state.environmentPreset?.eq,
                  taste: state.tastePreset?.eq,
                  height: 150,
                ),
                const Positioned(top: 0, right: 0, child: _GraphLegend()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _RowButton(
            icon: Icons.graphic_eq,
            label: '취향 층 EQ 직접 고치기',
            sub: '점을 옮겨 곡선을 만듭니다. 기기와 환경 층은 그대로 둡니다',
            onTap: state.tastePreset == null
                ? null
                : () => openEqEditorScreen(context),
          ),
        ),
      ],
    );
  }
}

/// 층 밖의 처리. 리버브, 에코, 넓이, 등청감 보정.
class _ExtrasTab extends StatelessWidget {
  const _ExtrasTab({
    required this.state,
    required this.controller,
    required this.bottomInset,
  });

  final EffectState state;
  final EffectController controller;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 24),
      children: [
        LabeledSlider(
          label: '리버브',
          value: state.reverb.wet,
          valueLabel: '${(state.reverb.wet * 100).round()}%',
          onChanged: controller.setReverbWet,
        ),
        const SizedBox(height: 14),
        LabeledSlider(
          label: '공간 크기',
          value: state.reverb.roomSize,
          valueLabel: '${(state.reverb.roomSize * 100).round()}%',
          onChanged: controller.setReverbRoomSize,
        ),
        const SizedBox(height: 14),
        LabeledSlider(
          label: '에코',
          value: state.echo.wet,
          valueLabel: '${(state.echo.wet * 100).round()}%',
          onChanged: controller.setEchoWet,
        ),
        const SizedBox(height: 14),
        // 시안의 '크로스피드' 자리. 엔진에 BS2B 크로스피드가 없어서 스테레오
        // 넓이로 대신한다.
        LabeledSlider(
          label: '공간 넓이',
          value: state.reverb.width,
          valueLabel: '${(state.reverb.width * 100).round()}%',
          onChanged: controller.setWidth,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text('등청감 보정',
                  style: TextStyle(fontSize: 15, color: AppColors.t2)),
            ),
            const Expanded(
              flex: 2,
              child: Text('볼륨이 낮을 때 저역과 고역을 보강합니다',
                  style: AppText.small),
            ),
            GlassSwitch(
              value: state.loudnessComp,
              onChanged: controller.setLoudnessComp,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          '리버브는 연동 배속을 낮췄을 때 잘 어울립니다. 소리가 두꺼워진 '
          '자리에 공간이 붙습니다.',
          style: AppText.small,
        ),
      ],
    );
  }
}

/// 취향 층을 주고받는 자리.
///
/// 기기 층은 여기 없다. 두 사람의 이어폰 특성이 달라서 완성된 곡선을 통째로
/// 주고받으면 상대 폰에서 어긋난다.
class _ShareTab extends ConsumerWidget {
  const _ShareTab({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 24),
      children: [
        const Text(
          '취향 층만 주고받습니다. 기기 보정은 각자 폰에 남아서, '
          '상대가 좋다고 한 소리가 내 이어폰에서도 좋게 들립니다.',
          style: AppText.small,
        ),
        const SizedBox(height: 16),
        _RowButton(
          icon: Icons.ios_share,
          label: '내 프리셋 내보내기',
          sub: 'JSON을 클립보드에 복사합니다',
          onTap: () async {
            final json =
                await ref.read(presetRepositoryProvider).exportShareable();
            await Clipboard.setData(ClipboardData(text: json));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('클립보드에 복사했습니다')),
            );
          },
        ),
        const SizedBox(height: 10),
        _RowButton(
          icon: Icons.download,
          label: '받은 프리셋 가져오기',
          sub: '복사해둔 JSON을 붙여 넣습니다',
          onTap: () => _importDialog(context, ref),
        ),
        const SizedBox(height: 10),
        _RowButton(
          icon: Icons.folder_open,
          label: '프리셋 관리',
          sub: '저장해둔 취향 프리셋 목록',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PresetsScreen()),
          ),
        ),
      ],
    );
  }

  Future<void> _importDialog(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: const Text('프리셋 가져오기', style: AppText.body),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 6,
          style: AppText.caption,
          cursorColor: AppColors.accent,
          decoration: const InputDecoration(
            hintText: 'JSON 붙여넣기',
            hintStyle: TextStyle(color: AppColors.t3),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소', style: TextStyle(color: AppColors.t2)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, textController.text),
            child: const Text('가져오기',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (text == null || text.trim().isEmpty) return;
    try {
      final count = await ref
          .read(presetRepositoryProvider)
          .importShareable(text, author: '상대');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$count개를 가져왔습니다')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('읽을 수 없는 형식입니다')));
    }
  }
}

/// 지금 걸린 소리를 한 줄로 적고, 그 자리에서 취향 프리셋으로 저장한다.
///
/// 전에는 시트 맨 아래에 붙어 있었다. 이제 그 자리를 미니 플레이어가 쓰므로
/// 위로 올렸다.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary, required this.onSave});

  final String summary;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption,
            ),
          ),
          const SizedBox(width: 10),
          AccentButton(
            label: '저장',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.t2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.t1)),
                    const SizedBox(height: 2),
                    Text(sub, style: AppText.small),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.t3),
            ],
          ),
        ),
      ),
    );
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
  const _TastePresetCards({
    required this.selectedId,
    required this.onSelect,
    this.custom = false,
  });

  final String? selectedId;
  final ValueChanged<Preset> onSelect;

  /// 참이면 내가 저장한 것만, 거짓이면 내장 프리셋만 보여준다.
  final bool custom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Preset>>(
      stream: ref
          .watch(presetRepositoryProvider)
          .watchByLayer(PresetLayer.taste),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Preset>[];
        final list = all.where((p) => p.builtin != custom).toList();
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('저장해둔 것이 없습니다. 소리를 맞춘 뒤 저장을 누르세요',
                style: AppText.small),
          );
        }
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
