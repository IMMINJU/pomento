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
import 'widgets/screen_header.dart';
import 'widgets/settings_list.dart';

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

  /// 프리셋 이름 걸러내기. 비어 있으면 검색칸을 접는다.
  bool _searching = false;
  String _query = '';

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
                  title: '효과 · ${ref.watch(tastePresetCountProvider)}',
                  actions: [
                    if (_tab == 0)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _searching ? Icons.search_off : Icons.search,
                          size: 22,
                          color: _searching ? AppColors.accent : AppColors.t2,
                        ),
                        onPressed: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) _query = '';
                        }),
                      ),
                    // 저장과 초기화는 자주 쓰지 않는다. 머리를 비우려고
                    // 더보기 안으로 넣었다.
                    PopupMenuButton<int>(
                      icon: const Icon(Icons.more_vert,
                          size: 22, color: AppColors.t2),
                      color: const Color(0xFF25252D),
                      onSelected: (v) async {
                        if (v == 0) {
                          await _saveDialog(context);
                          return;
                        }
                        await controller.resetAll();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('음향을 원래대로 되돌렸습니다')),
                        );
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 0,
                          child: Text('취향 프리셋으로 저장',
                              style: AppText.body),
                        ),
                        PopupMenuItem(
                          value: 1,
                          child: Text('원래대로 되돌리기', style: AppText.body),
                        ),
                      ],
                    ),
                  ],
                ),
                _EffectTabs(
                  index: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    state.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      _PresetListTab(
                        state: state,
                        controller: controller,
                        bottomInset: bottomInset,
                        searching: _searching,
                        query: _query,
                        onQuery: (q) => setState(() => _query = q),
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
/// 취향 프리셋 평면 목록.
///
/// Capriccio의 Sound Effects 탭과 같은 모양이다. 이름만 한 줄씩 놓고 지금
/// 걸린 것을 accent로 표시한다. 누르면 바로 바뀐다.
///
/// 기기와 환경 층은 이 목록에 없다. 세 층을 dB 축에서 더하는 구조는 그대로
/// 살아 있고, 기기 층은 연결된 기기를 보고 자동으로 붙는다. 환경 층은 추가
/// 효과 탭으로 옮겼다. 첫 화면에서 고를 것을 하나로 줄이려는 선택이다.
class _PresetListTab extends ConsumerStatefulWidget {
  const _PresetListTab({
    required this.state,
    required this.controller,
    required this.bottomInset,
    required this.searching,
    required this.query,
    required this.onQuery,
  });

  final EffectState state;
  final EffectController controller;
  final double bottomInset;
  final bool searching;
  final String query;
  final ValueChanged<String> onQuery;

  @override
  ConsumerState<_PresetListTab> createState() => _PresetListTabState();
}

class _PresetListTabState extends ConsumerState<_PresetListTab> {
  /// 내장 프리셋을 볼지, 내가 저장한 것을 볼지.
  bool _custom = false;

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.state.tastePreset?.id;

    return StreamBuilder<List<Preset>>(
      stream: ref
          .watch(presetRepositoryProvider)
          .watchByLayer(PresetLayer.taste),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Preset>[];
        final q = widget.query.trim().toLowerCase();
        final list = all
            .where((p) => p.builtin != _custom)
            .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
            .toList();

        return ListView(
          padding: EdgeInsets.only(bottom: widget.bottomInset + 24),
          children: [
            if (widget.searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  autofocus: true,
                  style: AppText.body,
                  cursorColor: AppColors.accent,
                  onChanged: widget.onQuery,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '프리셋 이름',
                    hintStyle: TextStyle(color: AppColors.t3, fontSize: 15),
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  for (final entry in const [
                    (false, '기본 효과'),
                    (true, '커스텀 효과'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _FilterPill(
                        label: entry.$2,
                        selected: _custom == entry.$1,
                        onTap: () => setState(() => _custom = entry.$1),
                      ),
                    ),
                ],
              ),
            ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '저장해둔 것이 없습니다. 소리를 맞춘 뒤 위의 저장을 누르세요',
                  style: AppText.small,
                ),
              )
            else
              for (final p in list)
                _PresetRow(
                  preset: p,
                  selected: p.id == selectedId,
                  onTap: () => widget.controller.selectTaste(p),
                ),
          ],
        );
      },
    );
  }
}

/// 목록 한 줄. 장식을 넣지 않는다.
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final Preset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.accent : AppColors.t1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 층 밖의 처리와, 첫 화면에서 접어둔 두 층.
///
/// Capriccio의 추가 효과 탭과 같은 목록 문법을 쓴다. 섹션 라벨에 밑줄,
/// 행마다 굵은 제목과 회색 설명, 오른쪽에 지금 값. 다만 리버브처럼 0에서
/// 100까지 이어지는 값은 목록으로 고르면 손해라 제목 아래에 슬라이더를
/// 그대로 둔다.
class _ExtrasTab extends ConsumerWidget {
  const _ExtrasTab({
    required this.state,
    required this.controller,
    required this.bottomInset,
  });

  final EffectState state;
  final EffectController controller;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetRepositoryProvider);

    return ListView(
      padding: EdgeInsets.only(bottom: bottomInset + 24),
      children: [
        SettingsSection(
          title: '기기 보정',
          children: [
            SettingsSwitchRow(
              title: state.devicePreset?.name ?? state.device.label,
              description: state.deviceAuto
                  ? '연결된 기기를 보고 자동으로 붙습니다'
                  : '직접 고른 보정입니다',
              value: state.deviceEnabled,
              onChanged: controller.setDeviceEnabled,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
              child: SizedBox(
                height: 34,
                child: FutureBuilder<List<Preset>>(
                  future: presets.byLayer(PresetLayer.device),
                  builder: (context, snap) {
                    final list = snap.data ?? const <Preset>[];
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _Chip(
                          label: '자동',
                          selected: state.deviceAuto,
                          onTap: controller.enableDeviceAuto,
                        ),
                        for (final p in list)
                          _Chip(
                            label: p.name,
                            selected: !state.deviceAuto &&
                                state.devicePreset?.id == p.id,
                            onTap: () => controller.selectDevicePreset(p),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        SettingsSection(
          title: '환경 보정',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: StreamBuilder<List<Preset>>(
                stream: presets.watchByLayer(PresetLayer.environment),
                builder: (context, snap) {
                  final list = snap.data ?? const <Preset>[];
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in list)
                        _Chip(
                          label: p.name,
                          selected: state.environmentPreset?.id == p.id,
                          onTap: () => controller.selectEnvironment(p),
                          margin: EdgeInsets.zero,
                        ),
                    ],
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                '지하철 보정이 저역을 깎는 것은 의도한 것입니다. 지하철 소음이 '
                '저역이라 저역을 더 올리면 소음과 겹쳐 뭉갭니다.',
                style: AppText.caption,
              ),
            ),
          ],
        ),

        SettingsSection(
          title: '공간과 보정',
          children: [
            _SliderRow(
              title: '리버브',
              description: '연동 배속을 낮췄을 때 잘 어울립니다',
              value: state.reverb.wet,
              onChanged: controller.setReverbWet,
            ),
            _SliderRow(
              title: '공간 크기',
              value: state.reverb.roomSize,
              onChanged: controller.setReverbRoomSize,
            ),
            _SliderRow(
              title: '에코',
              value: state.echo.wet,
              onChanged: controller.setEchoWet,
            ),
            _SliderRow(
              title: '공간 넓이',
              // 시안의 크로스피드 자리. 엔진에 BS2B가 없어서 스테레오 넓이로
              // 대신한다.
              description: '스테레오를 벌리거나 좁힙니다',
              value: state.reverb.width,
              onChanged: controller.setWidth,
            ),
            SettingsSwitchRow(
              title: '등청감 보정',
              description: '볼륨이 낮을 때 저역과 고역을 보강합니다',
              value: state.loudnessComp,
              onChanged: controller.setLoudnessComp,
            ),
          ],
        ),

        SettingsSection(
          title: '이퀄라이저',
          children: [
            SettingsLinkRow(
              title: '취향 층 EQ 고치기',
              description: '점과 종 모양 밴드로 곡선을 만듭니다',
              onTap: state.tastePreset == null
                  ? () {}
                  : () => openEqEditorScreen(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// 제목과 설명 아래에 슬라이더를 둔 행.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String title;
  final String? description;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.t1,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(description!, style: AppText.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(value: value.clamp(0, 1), onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// 가로로 늘어놓는 작은 알약.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.margin = const EdgeInsets.only(right: 8),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.bgBase : AppColors.t2,
            ),
          ),
        ),
      ),
    );
  }
}

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

/// 아이콘이 붙은 탭 세 개.
///
/// Capriccio는 알약 세그먼트가 아니라 위쪽만 둥근 탭을 쓰고 아래에 가로선을
/// 그어 본문과 나눈다.
class _EffectTabs extends StatelessWidget {
  const _EffectTabs({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _tabs = [
    (icon: Icons.tune, label: '음향 효과'),
    (icon: Icons.headphones, label: '추가 효과'),
    (icon: Icons.ios_share, label: '효과 공유'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _tabs[i].icon,
                        size: 17,
                        color: i == index ? AppColors.t1 : AppColors.t3,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _tabs[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == index
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == index ? AppColors.t1 : AppColors.t3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 고른 쪽은 채우고 안 고른 쪽은 테두리만 남긴다.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.accent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.bgBase : AppColors.accent,
          ),
        ),
      ),
    );
  }
}
