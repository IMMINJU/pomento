import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/db/database.dart';
import '../data/platform/native_media.dart';
import '../data/storage/media_importer.dart';
import '../providers.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/surface.dart';

/// 음원을 라이브러리에 넣는 시트.
///
/// 안드로이드는 기기에 이미 있는 음원을 훑어서 고르게 하고, iOS는 파일 앱에서
/// 앱 폴더로 옮기는 방법을 안내한다. iOS에서 애플뮤직 보관함에는 접근하지
/// 않는다. Info.plist에 NSAppleMusicUsageDescription을 넣지 않아 접근 자체가
/// 막혀 있다.
class ImportSheet extends ConsumerStatefulWidget {
  const ImportSheet({super.key});

  @override
  ConsumerState<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<ImportSheet> {
  List<NativeAudioItem>? _found;
  final Set<String> _selected = {};
  bool _busy = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: const BoxDecoration(
        color: Color(0xF014141C),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const SheetHandle(),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('음악 넣기', style: AppText.title),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _content()),
          if (_found != null && _found!.isNotEmpty) _bottomBar(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  Widget _content() {
    if (_busy) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.cover,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(_status, style: AppText.sub),
          ],
        ),
      );
    }

    if (_found == null) return _chooser();

    if (_found!.isEmpty) {
      return const EmptyHint(
        icon: Icons.search_off,
        title: '기기에서 음원을 찾지 못했습니다',
        body: '파일에서 직접 고르거나, 권한을 허용했는지 확인하세요',
      );
    }

    return ListView.builder(
      itemCount: _found!.length,
      itemBuilder: (context, i) {
        final item = _found![i];
        final checked = _selected.contains(item.uri);
        return CheckboxListTile(
          value: checked,
          onChanged: (v) => setState(() {
            if (v == true) {
              _selected.add(item.uri);
            } else {
              _selected.remove(item.uri);
            }
          }),
          activeColor: AppColors.cover,
          checkColor: AppColors.paper,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body,
          ),
          subtitle: Text(
            '${item.artist} · ${formatDuration(Duration(milliseconds: item.durationMs))}'
            '${item.path == null ? ' · 복사 필요' : ''}',
            style: AppText.sub,
          ),
        );
      },
    );
  }

  Widget _chooser() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (Platform.isAndroid) ...[
          _option(
            icon: Icons.phone_android,
            title: '기기에 있는 음악 찾기',
            body: '폰에 저장된 음원을 훑어서 고를 수 있게 보여줍니다',
            onTap: _scanDevice,
          ),
          const SizedBox(height: 12),
        ],
        _option(
          icon: Icons.folder_open,
          title: '파일에서 고르기',
          body: 'mp3, flac, wav, ogg, m4a 파일을 직접 선택합니다',
          onTap: _pickFiles,
        ),
        const SizedBox(height: 12),
        _option(
          icon: Icons.refresh,
          title: '앱 폴더 다시 훑기',
          body: Platform.isIOS
              ? '파일 앱으로 Pomento 폴더에 넣은 음원을 찾습니다'
              : '앱이 가지고 있는 음원을 다시 확인합니다',
          onTap: _scanAppFolder,
        ),
        const SizedBox(height: 24),
        if (Platform.isIOS) ...[
          const SectionLabel('아이폰에 파일 넣는 방법'),
          const SizedBox(height: 12),
          _step(1, '파일 앱 열기', '아이폰 기본 파일 앱을 실행하세요'),
          _step(2, '내 iPhone 폴더로', "위치 목록에서 '내 iPhone'을 누르면 Pomento 폴더가 보입니다"),
          _step(3, '음원 옮겨놓기', 'mp3나 flac 파일을 그 폴더에 넣으면 앱에서 바로 보입니다'),
          const SizedBox(height: 20),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8C8C).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: const Color(0xFFFF8C8C).withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 20, color: Color(0xFFFF8C8C)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('음악 앱을 거치지 마세요', style: AppText.body),
                    const SizedBox(height: 4),
                    Text(
                      '애플뮤직 보관함 동기화가 켜져 있으면 앨범 자켓과 곡 정보가 '
                      '애플 카탈로그 것으로 바뀝니다. 파일 앱에서 직접 넣으면 '
                      '원본 그대로 유지됩니다.',
                      style: AppText.sub.copyWith(color: AppColors.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return Sunken(
      radius: AppRadius.card,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.cover),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body),
                const SizedBox(height: 2),
                Text(body, style: AppText.sub),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.ink3),
        ],
      ),
    );
  }

  Widget _step(int n, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.cover,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$n',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.paper,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body),
                const SizedBox(height: 2),
                Text(body, style: AppText.sub),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (_selected.length == _found!.length) {
                _selected.clear();
              } else {
                _selected
                  ..clear()
                  ..addAll(_found!.map((e) => e.uri));
              }
            }),
            child: Text(
              _selected.length == _found!.length ? '전체 해제' : '전체 선택',
              style: const TextStyle(fontSize: 14, color: AppColors.ink2),
            ),
          ),
          const Spacer(),
          InkButton(
            label: '${_selected.length}곡 넣기',
            onPressed: _selected.isEmpty ? null : _importSelected,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _scanAppFolder() async {
    setState(() {
      _busy = true;
      _status = '앱 폴더를 훑는 중';
    });

    final result = await ref.read(mediaImporterProvider).scanAppFolder();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = '';
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.added == 0 && result.skipped == 0
              ? '앱 폴더에 새 음원이 없습니다'
              : result.summary,
        ),
      ),
    );
  }

  Future<void> _scanDevice() async {
    setState(() {
      _busy = true;
      _status = '권한을 확인하는 중';
    });

    final granted = await _ensureAudioPermission();
    if (!granted) {
      setState(() {
        _busy = false;
        _status = '';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음악 파일 권한이 필요합니다')),
      );
      return;
    }

    setState(() => _status = '기기를 훑는 중');
    final items = await NativeMedia.instance.scanDeviceAudio();

    // 이미 라이브러리에 있는 곡은 빼고 보여준다.
    final existing = await ref.read(libraryRepositoryProvider).allTracks();
    final have = existing.map((t) => t.filePath).toSet();
    final fresh = items
        .where((i) => i.path == null || !have.contains(i.path))
        .toList();

    if (!mounted) return;
    setState(() {
      _found = fresh;
      _selected
        ..clear()
        ..addAll(fresh.map((e) => e.uri));
      _busy = false;
      _status = '';
    });
  }

  Future<bool> _ensureAudioPermission() async {
    if (!Platform.isAndroid) return true;
    // Android 13(API 33)부터 음악은 READ_MEDIA_AUDIO로 분리됐다.
    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<void> _importSelected() async {
    final items =
        _found!.where((e) => _selected.contains(e.uri)).toList();
    setState(() {
      _busy = true;
      _status = '0 / ${items.length}';
    });

    final importer = ref.read(mediaImporterProvider);
    var added = 0;
    for (var i = 0; i < items.length; i++) {
      final ok = await importer.importNativeItem(items[i]);
      if (ok) added++;
      if (!mounted) return;
      setState(() => _status = '${i + 1} / ${items.length}');
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$added곡 추가됨')),
    );
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: MediaImporter.supportedExtensions
          .map((e) => e.substring(1))
          .toList(),
    );
    if (files.isEmpty) return;

    setState(() {
      _busy = true;
      _status = '0 / ${files.length}';
    });

    final importer = ref.read(mediaImporterProvider);
    var added = 0;
    for (var i = 0; i < files.length; i++) {
      final path = files[i].path;
      if (path == null) continue;
      // 파일 선택기로 고른 것은 앱 저장소로 복사한다. 원본이 캐시나 외부
      // 저장소에 있어 사라질 수 있기 때문이다.
      final ok = await importer.importFile(path, copyIntoApp: true);
      if (ok) added++;
      if (!mounted) return;
      setState(() => _status = '${i + 1} / ${files.length}');
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$added곡 추가됨')),
    );
  }
}

/// 곡의 자켓을 사용자가 고른 이미지로 바꾼다.
Future<void> pickUserArtwork(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final file = await FilePicker.pickFile(type: FileType.image);
  final path = file?.path;
  if (path == null) return;
  await ref.read(mediaImporterProvider).setUserArtwork(track.id, path);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('자켓을 바꿨습니다')),
  );
}
