import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/preset.dart';
import '../providers.dart';
import 'theme.dart';
import 'home_shell.dart';
import 'widgets/common.dart';
import 'widgets/eq_graph.dart';
import 'widgets/paper.dart';
import 'widgets/screen_header.dart';
import 'widgets/surface.dart';

/// 프리셋 목록.
///
/// 취향 층만 보여준다. 기기 보정은 각자 폰의 이어폰 특성에 맞춘 값이라
/// 목록에 섞어 두면 주고받을 수 있는 것처럼 보인다.
class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(presetRepositoryProvider);

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ScreenHeader(
                title: '프리셋',
                showBack: true,
                actions: [
                  RoundButton(
                    filled: false,
                    onTap: () async {
                      final json = await repo.exportShareable();
                      await Clipboard.setData(ClipboardData(text: json));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('프리셋을 클립보드에 복사했습니다')),
                      );
                    },
                    child: const Icon(Icons.ios_share,
                        size: 20, color: AppColors.ink2),
                  ),
                  RoundButton(
                    filled: false,
                    onTap: () => _importDialog(context, ref),
                    child: const Icon(Icons.download_outlined,
                        size: 20, color: AppColors.ink2),
                  ),
                ],
              ),
              Expanded(
                child: StreamBuilder<List<Preset>>(
                  stream: repo.watchByLayer(PresetLayer.taste),
                  builder: (context, snapshot) {
                    final all = snapshot.data ?? const <Preset>[];
                    final mine =
                        all.where((p) => p.author == null).toList();
                    final theirs =
                        all.where((p) => p.author != null).toList();

                    return ListView(
                      padding: EdgeInsets.only(
                          bottom: shellBottomInset(context, ref) + 24),
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(
                              AppSpace.gutter, 8, AppSpace.gutter, 12),
                          child: SectionLabel('내 프리셋'),
                        ),
                        for (final p in mine) _PresetCard(preset: p),
                        if (theirs.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpace.gutter, 28, AppSpace.gutter, 12),
                            child: SectionLabel(
                                '${theirs.first.author}이(가) 만든'),
                          ),
                          for (final p in theirs) _PresetCard(preset: p),
                        ],
                        const Padding(
                          padding: EdgeInsets.fromLTRB(
                              AppSpace.gutter, 28, AppSpace.gutter, 0),
                          child: Text(
                            '기기 보정은 각자 폰에만 저장됩니다. 이어폰 특성이 서로 '
                            '달라서 완성된 곡선을 통째로 주고받으면 상대 폰에서 '
                            '어긋납니다.',
                            style: AppText.sub,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paperHi,
        surfaceTintColor: Colors.transparent,
        title: const Text('프리셋 가져오기', style: AppText.body),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 6,
              style: AppText.sub,
              cursorColor: AppColors.ink1,
              decoration: const InputDecoration(
                hintText: '받은 JSON을 붙여넣으세요',
                hintStyle: TextStyle(color: AppColors.hair),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소',
                style: TextStyle(color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child:
                const Text('가져오기',
                    style: TextStyle(
                        color: AppColors.ink1,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (text == null || text.trim().isEmpty) return;
    try {
      final n = await ref
          .read(presetRepositoryProvider)
          .importShareable(text, author: '상대');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$n개 가져왔습니다')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('형식을 읽지 못했습니다')));
    }
  }
}

class _PresetCard extends ConsumerWidget {
  const _PresetCard({required this.preset});

  final Preset preset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Sunken(
        radius: AppRadius.card,
        padding: const EdgeInsets.all(12),
        onTap: () {
          ref.read(effectControllerProvider.notifier).selectTaste(preset);
          Navigator.pop(context);
        },
        child: Row(
          children: [
            Container(
              width: 64,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: MiniEqCurve(curve: preset.eq, width: 56, height: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.name, style: AppText.body),
                  const SizedBox(height: 2),
                  Text(
                    preset.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sub,
                  ),
                ],
              ),
            ),
            if (!preset.builtin)
              IconButton(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: AppColors.ink3),
                onPressed: () => _menu(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  void _menu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paperHi,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.ink2),
              title: const Text('이 프리셋만 복사', style: AppText.body),
              subtitle: const Text('상대에게 붙여넣기로 보낼 수 있습니다',
                  style: AppText.sub),
              onTap: () async {
                Navigator.pop(sheetContext);
                final payload = {
                  'version': 1,
                  'presets': [preset.toJson()],
                };
                await Clipboard.setData(
                  ClipboardData(text: payload.toString()),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('복사했습니다')),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Color(0xFFFF8C8C)),
              title: const Text(
                '삭제',
                style: TextStyle(fontSize: 15, color: Color(0xFFFF8C8C)),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref.read(presetRepositoryProvider).delete(preset.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
