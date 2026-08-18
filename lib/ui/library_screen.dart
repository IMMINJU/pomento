import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../data/db/database.dart';
import '../data/models/tempo.dart';
import '../data/repo/library_repository.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'import_sheet.dart';
import 'presets_screen.dart';
import 'theme.dart';
import 'widgets/artwork.dart';
import 'widgets/common.dart';

enum LibraryTab {
  songs('곡'),
  albums('앨범'),
  artists('아티스트'),
  folders('폴더'),
  playlists('재생목록');

  const LibraryTab(this.label);

  final String label;
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryTab _tab = LibraryTab.songs;
  String _query = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // 잠금화면과 알림의 재생 컨트롤은 알림 권한이 있어야 뜬다.
    // Android 13(API 33)부터 사용자가 직접 허용해야 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!Platform.isAndroid) return;
      final status = await Permission.notification.status;
      if (status.isDenied) await Permission.notification.request();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // 상단 accent 라디얼
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1),
                    radius: 1.0,
                    colors: [
                      AppColors.accent.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                _tabs(),
                Container(height: 1, color: AppColors.divider),
                Expanded(
                  child: tracksAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    ),
                    error: (e, _) => EmptyHint(
                      icon: Icons.error_outline,
                      title: '라이브러리를 읽지 못했습니다',
                      body: '$e',
                    ),
                    data: (tracks) => _body(tracks),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          if (_searching)
            Expanded(
              child: TextField(
                autofocus: true,
                style: AppText.body,
                cursorColor: AppColors.accent,
                decoration: const InputDecoration(
                  hintText: '제목, 아티스트 검색',
                  hintStyle: TextStyle(color: AppColors.t3, fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            )
          else
            const Expanded(child: Text('라이브러리', style: AppText.display)),
          IconButton(
            icon: Icon(
              _searching ? Icons.close : Icons.search,
              size: 22,
              color: AppColors.t2,
            ),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_horiz,
              size: 22,
              color: AppColors.t2,
            ),
            onPressed: _showMenu,
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final t in LibraryTab.values)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _tab = t),
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 15,
                        height: 22 / 15,
                        fontWeight:
                            t == _tab ? FontWeight.w600 : FontWeight.w400,
                        color: t == _tab ? AppColors.t1 : AppColors.t3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2,
                      width: t.label.length * 15.0,
                      decoration: BoxDecoration(
                        color:
                            t == _tab ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Track> _filtered(List<Track> tracks) {
    if (_query.trim().isEmpty) return tracks;
    final q = _query.toLowerCase();
    return tracks
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q) ||
            t.album.toLowerCase().contains(q))
        .toList();
  }

  Widget _body(List<Track> all) {
    final tracks = _filtered(all);

    if (all.isEmpty) {
      return EmptyHint(
        icon: Icons.library_music_outlined,
        title: '아직 음악이 없습니다',
        body: '기기에 있는 음원을 가져오거나 파일을 직접 고르세요',
        action: AccentButton(
          label: '음악 넣기',
          onPressed: _openImport,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    }

    switch (_tab) {
      case LibraryTab.songs:
        return _trackList(tracks);
      case LibraryTab.albums:
        return _groupList(tracks, (t) => t.album.isEmpty ? '앨범 없음' : t.album);
      case LibraryTab.artists:
        return _groupList(tracks, (t) => t.artist);
      case LibraryTab.folders:
        return _groupList(tracks, (t) => p.basename(p.dirname(t.filePath)));
      case LibraryTab.playlists:
        return _playlistList();
    }
  }

  Widget _trackList(List<Track> tracks) {
    final temposAsync = ref.watch(savedTemposProvider);
    final tempos = temposAsync.value ?? const <int, TempoSettings>{};

    return ListView.builder(
      padding: EdgeInsets.only(
        top: 4,
        bottom: shellBottomInset(context, ref) + 12,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, i) => TrackRow(
        track: tracks[i],
        savedTempo: tempos[tracks[i].id],
        onTap: () {
          ref
              .read(playerControllerProvider.notifier)
              .playQueue(tracks, i);
          ref.read(activeSourceProvider.notifier).state =
              PlaybackSource.local;
          ref.read(shellTabProvider.notifier).state = 0;
        },
        onLongPress: () => _trackMenu(tracks[i]),
      ),
    );
  }

  Widget _groupList(List<Track> tracks, String Function(Track) keyOf) {
    final groups = <String, List<Track>>{};
    for (final t in tracks) {
      groups.putIfAbsent(keyOf(t), () => []).add(t);
    }
    final keys = groups.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.only(
        top: 4,
        bottom: shellBottomInset(context, ref) + 12,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final key = keys[i];
        final items = groups[key]!;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Artwork(track: items.first, size: 48),
          title: Text(key, style: AppText.body, overflow: TextOverflow.ellipsis),
          subtitle: Text('${items.length}곡', style: AppText.caption),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _GroupTracksScreen(title: key, tracks: items),
            ),
          ),
        );
      },
    );
  }

  Widget _playlistList() {
    final playlists = ref.watch(playlistsProvider);
    return playlists.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('$e', style: AppText.caption)),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyHint(
            icon: Icons.queue_music_outlined,
            title: '재생목록이 없습니다',
            body: '곡을 길게 눌러 재생목록에 넣을 수 있습니다',
          );
        }
        return ListView.builder(
          padding: EdgeInsets.only(
        top: 4,
        bottom: shellBottomInset(context, ref) + 12,
      ),
          itemCount: list.length,
          itemBuilder: (context, i) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.queue_music, color: AppColors.t2),
            title: Text(list[i].name, style: AppText.body),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _PlaylistScreen(playlist: list[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openImport() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ImportSheet(),
    );
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.t2),
              title: const Text('음악 넣기', style: AppText.body),
              onTap: () {
                Navigator.pop(sheetContext);
                _openImport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune, color: AppColors.t2),
              title: const Text('프리셋', style: AppText.body),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PresetsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort, color: AppColors.t2),
              title: const Text('정렬', style: AppText.body),
              subtitle: Text(
                ref.read(trackSortProvider).label,
                style: AppText.caption,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _sortMenu();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined,
                  color: AppColors.t2),
              title: const Text('사라진 파일 정리', style: AppText.body),
              onTap: () async {
                Navigator.pop(sheetContext);
                final n =
                    await ref.read(libraryRepositoryProvider).pruneMissing();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(n == 0 ? '정리할 것이 없습니다' : '$n곡 정리됨')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _sortMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            const SizedBox(height: 8),
            for (final s in TrackSortValues.all)
              ListTile(
                title: Text(s.label, style: AppText.body),
                trailing: ref.read(trackSortProvider) == s
                    ? const Icon(Icons.check, color: AppColors.accent, size: 20)
                    : null,
                onTap: () {
                  ref.read(trackSortProvider.notifier).state = s;
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _trackMenu(Track track) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            const SizedBox(height: 12),
            ListTile(
              leading: Artwork(track: track, size: 40),
              title: Text(track.title,
                  style: AppText.body, overflow: TextOverflow.ellipsis),
              subtitle: Text(track.artist, style: AppText.caption),
            ),
            const Divider(color: AppColors.divider, height: 1),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.t2),
              title: const Text('자켓 바꾸기', style: AppText.body),
              subtitle: const Text(
                '지정한 자켓은 무엇도 덮어쓰지 않습니다',
                style: AppText.small,
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await pickUserArtwork(context, ref, track);
              },
            ),
            if (track.userArtworkPath != null)
              ListTile(
                leading: const Icon(Icons.undo, color: AppColors.t2),
                title: const Text('원래 자켓으로', style: AppText.body),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ref
                      .read(mediaImporterProvider)
                      .clearUserArtwork(track.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppColors.t2),
              title: const Text('재생목록에 넣기', style: AppText.body),
              onTap: () {
                Navigator.pop(sheetContext);
                _addToPlaylist(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF8C8C)),
              title: const Text(
                '라이브러리에서 빼기',
                style: TextStyle(fontSize: 15, color: Color(0xFFFF8C8C)),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref
                    .read(libraryRepositoryProvider)
                    .deleteTrack(track.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _addToPlaylist(Track track) async {
    final repo = ref.read(libraryRepositoryProvider);
    final playlists = await repo.watchPlaylists().first;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            const SizedBox(height: 8),
            for (final pl in playlists)
              ListTile(
                title: Text(pl.name, style: AppText.body),
                onTap: () async {
                  await repo.addToPlaylist(pl.id, track.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.accent),
              title: const Text('새 재생목록', style: AppText.body),
              onTap: () async {
                Navigator.pop(sheetContext);
                final name = await _askText('새 재생목록', '이름');
                if (name == null || name.isEmpty) return;
                final id = await repo.createPlaylist(name);
                await repo.addToPlaylist(id, track.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _askText(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: Text(title, style: AppText.body),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppText.body,
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.t3),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소', style: TextStyle(color: AppColors.t2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('확인', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

/// TrackSort는 enum이지만 UI에서 순회하려면 목록이 필요하다.
class TrackSortValues {
  const TrackSortValues._();

  static const List<TrackSort> all = TrackSort.values;
}

class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    this.savedTempo,
    this.onTap,
    this.onLongPress,
    this.playing = false,
  });

  final Track track;
  final TempoSettings? savedTempo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 68,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Artwork(track: track, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 22 / 15,
                        color: playing ? AppColors.accent : AppColors.t1,
                      ),
                    ),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 이 곡에 저장된 배속이 있으면 배지로 알린다.
              if (savedTempo != null && !savedTempo!.isNormal) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    '${savedTempo!.speed.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.t3,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                formatDuration(Duration(milliseconds: track.durationMs)),
                style: AppText.mono,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTracksScreen extends ConsumerWidget {
  const _GroupTracksScreen({required this.title, required this.tracks});

  final String title;
  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tempos = ref.watch(savedTemposProvider).value ??
        const <int, TempoSettings>{};
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(title, style: AppText.body),
        iconTheme: const IconThemeData(color: AppColors.t1),
      ),
      body: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (context, i) => TrackRow(
          track: tracks[i],
          savedTempo: tempos[tracks[i].id],
          onTap: () {
            ref.read(playerControllerProvider.notifier).playQueue(tracks, i);
            ref.read(activeSourceProvider.notifier).state =
              PlaybackSource.local;
          ref.read(shellTabProvider.notifier).state = 0;
          },
        ),
      ),
    );
  }
}

class _PlaylistScreen extends ConsumerWidget {
  const _PlaylistScreen({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(libraryRepositoryProvider);
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(playlist.name, style: AppText.body),
        iconTheme: const IconThemeData(color: AppColors.t1),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.t2),
            onPressed: () async {
              await repo.deletePlaylist(playlist.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Track>>(
        stream: repo.watchPlaylistTracks(playlist.id),
        builder: (context, snapshot) {
          final tracks = snapshot.data ?? const <Track>[];
          if (tracks.isEmpty) {
            return const EmptyHint(
              icon: Icons.queue_music_outlined,
              title: '비어 있습니다',
              body: '곡을 길게 눌러 이 재생목록에 넣으세요',
            );
          }
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, i) => TrackRow(
              track: tracks[i],
              onTap: () {
                ref
                    .read(playerControllerProvider.notifier)
                    .playQueue(tracks, i);
                ref.read(activeSourceProvider.notifier).state =
              PlaybackSource.local;
          ref.read(shellTabProvider.notifier).state = 0;
              },
            ),
          );
        },
      ),
    );
  }
}
