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
import 'widgets/artwork_tone.dart';
import 'widgets/common.dart';
import 'widgets/paper.dart';
import 'widgets/player_parts.dart';
import 'widgets/screen_header.dart';
import 'widgets/sheet.dart';
import 'widgets/surface.dart';

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

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with NowPlayingScroll {
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
    // 목록에서 지금 곡을 그 곡의 색으로 표시한다
    final playing = ref.watch(playerControllerProvider).current;
    final tone = coverToneOf(ref, playing);

    return CoverScope(
      tone: tone,
      child: Scaffold(
        body: PaperBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                _tabs(),
                Expanded(
                  child: tracksAsync.when(
                    loading: () => const SizedBox.shrink(),
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
        ),
      ),
    );
  }

  Widget _header() {
    final tracks = ref.watch(tracksProvider).value;
    if (_searching) {
      return SizedBox(
        height: 78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  style: AppText.title.copyWith(fontSize: 24),
                  cursorColor: AppColors.ink1,
                  decoration: InputDecoration(
                    hintText: '제목, 아티스트',
                    hintStyle: AppText.title.copyWith(
                      fontSize: 24,
                      color: AppColors.hair,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              RoundButton(
                filled: false,
                onTap: () => setState(() {
                  _searching = false;
                  _query = '';
                }),
                child: const Icon(Icons.close, size: 22, color: AppColors.ink2),
              ),
            ],
          ),
        ),
      );
    }

    return ScreenHeader(
      title: '라이브러리',
      subtitle: tracks == null ? null : '${tracks.length}곡',
      showBack: false,
      actions: [
        RoundButton(
          filled: false,
          onTap: () => setState(() => _searching = true),
          child: const Icon(Icons.search, size: 20, color: AppColors.ink1),
        ),
        RoundButton(
          filled: false,
          onTap: _showMenu,
          child: const Icon(Icons.more_horiz, size: 20, color: AppColors.ink2),
        ),
      ],
    );
  }

  Widget _tabs() {
    // 고른 탭만 굵게 쓰고 아래에 짧은 밑줄. 알약 세그먼트를 쓰지 않는 이유는
    // 탭이 다섯이라 알약으로 만들면 글자가 접혀서다
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        children: [
          for (final t in LibraryTab.values)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _tab = t),
              child: Padding(
                padding: const EdgeInsets.only(right: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      t.label,
                      style: AppText.body.copyWith(
                        fontSize: 15,
                        fontWeight: t == _tab
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: t == _tab ? AppColors.ink1 : AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: 2,
                      width: 18,
                      color: t == _tab ? AppColors.ink1 : Colors.transparent,
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
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.toLowerCase().contains(q) ||
              t.album.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _body(List<Track> all) {
    final tracks = _filtered(all);

    if (all.isEmpty) {
      return EmptyHint(
        icon: Icons.library_music_outlined,
        title: '아직 음악이 없습니다',
        body: '기기에 있는 음원을 가져오거나 파일을 직접 고르세요',
        action: InkButton(label: '음악 넣기', onPressed: _openImport),
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
    final nowId = ref.watch(playerControllerProvider).current?.id;
    // 열자마자 듣던 곡이 보여야 한다. 천 곡 목록에서 맨 위부터 찾을 수 없다
    if (_tab == LibraryTab.songs && _query.isEmpty) {
      moveToNowPlaying(tracks.indexWhere((t) => t.id == nowId));
    }

    return ListView.builder(
      controller: nowScroll,
      padding: EdgeInsets.only(
        top: 4,
        bottom: shellBottomInset(context, ref) + 12,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, i) => TrackRow(
        track: tracks[i],
        savedTempo: tempos[tracks[i].id],
        playing: tracks[i].id == nowId,
        onTap: () {
          ref.read(playerControllerProvider.notifier).playQueue(tracks, i);
          ref.read(activeSourceProvider.notifier).state = PlaybackSource.local;
          backToPlayer(context);
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
        return PaperRow(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _GroupTracksScreen(title: key, tracks: items),
            ),
          ),
          children: [
            Artwork(track: items.first, size: 46),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 4),
                  Text('${items.length}곡', style: AppText.sub),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.hair),
          ],
        );
      },
    );
  }

  Widget _playlistList() {
    final playlists = ref.watch(playlistsProvider);
    return playlists.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('$e', style: AppText.sub)),
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
          itemBuilder: (context, i) => PaperRow(
            height: 64,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _PlaylistScreen(playlist: list[i]),
              ),
            ),
            children: [
              const Icon(Icons.queue_music, size: 22, color: AppColors.ink2),
              Expanded(child: Text(list[i].name, style: AppText.body)),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.hair),
            ],
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
    showPaperSheet<void>(
      context: context,
      children: [
        SheetTile(
          icon: Icons.add,
          title: '음악 넣기',
          onTap: () {
            Navigator.pop(context);
            _openImport();
          },
        ),
        SheetTile(
          icon: Icons.tune,
          title: '프리셋',
          onTap: () {
            Navigator.pop(context);
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PresetsScreen()));
          },
        ),
        SheetTile(
          icon: Icons.sort,
          title: '정렬',
          description: ref.read(trackSortProvider).label,
          onTap: () {
            Navigator.pop(context);
            _sortMenu();
          },
        ),
        SheetTile(
          icon: Icons.cleaning_services_outlined,
          title: '사라진 파일 정리',
          onTap: () async {
            Navigator.pop(context);
            final n = await ref.read(libraryRepositoryProvider).pruneMissing();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(n == 0 ? '정리할 것이 없습니다' : '$n곡 정리됨')),
            );
          },
        ),
      ],
    );
  }

  void _sortMenu() {
    final current = ref.read(trackSortProvider);
    showPaperSheet<void>(
      context: context,
      title: '정렬',
      children: [
        for (final srt in TrackSortValues.all)
          SheetTile(
            title: srt.label,
            selected: srt == current,
            onTap: () {
              ref.read(trackSortProvider.notifier).state = srt;
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  void _trackMenu(Track track) {
    showPaperSheet<void>(
      context: context,
      children: [
        SheetTile(
          leading: Artwork(track: track, size: 46),
          title: track.title,
          description: track.artist,
        ),
        const SizedBox(height: 6),
        SheetTile(
          icon: Icons.image_outlined,
          title: '자켓 바꾸기',
          description: '지정한 자켓은 무엇도 덮어쓰지 않습니다',
          onTap: () async {
            Navigator.pop(context);
            await pickUserArtwork(context, ref, track);
          },
        ),
        if (track.userArtworkPath != null)
          SheetTile(
            icon: Icons.undo,
            title: '원래 자켓으로',
            onTap: () async {
              Navigator.pop(context);
              await ref.read(mediaImporterProvider).clearUserArtwork(track.id);
            },
          ),
        SheetTile(
          icon: Icons.playlist_add,
          title: '재생목록에 넣기',
          onTap: () {
            Navigator.pop(context);
            _addToPlaylist(track);
          },
        ),
        SheetTile(
          icon: Icons.delete_outline,
          title: '라이브러리에서 빼기',
          danger: true,
          onTap: () async {
            Navigator.pop(context);
            await ref.read(libraryRepositoryProvider).deleteTrack(track.id);
          },
        ),
      ],
    );
  }

  Future<void> _addToPlaylist(Track track) async {
    final repo = ref.read(libraryRepositoryProvider);
    final playlists = await repo.watchPlaylists().first;
    if (!mounted) return;

    await showPaperSheet<void>(
      context: context,
      title: '재생목록에 넣기',
      children: [
        for (final pl in playlists)
          SheetTile(
            title: pl.name,
            onTap: () async {
              await repo.addToPlaylist(pl.id, track.id);
              if (mounted) Navigator.pop(context);
            },
          ),
        SheetTile(
          icon: Icons.add,
          title: '새 재생목록',
          onTap: () async {
            Navigator.pop(context);
            final name = await askText(context, title: '새 재생목록', hint: '이름');
            if (name == null || name.isEmpty) return;
            final id = await repo.createPlaylist(name);
            await repo.addToPlaylist(id, track.id);
          },
        ),
      ],
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
    final tone = CoverScope.of(context);
    final tempo = savedTempo;
    return PaperRow(
      onTap: onTap,
      onLongPress: onLongPress,
      children: [
        Artwork(track: track, size: 46),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: playing ? tone.accentInk : AppColors.ink1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sub,
              ),
            ],
          ),
        ),
        // 이 곡에 저장된 배속이 있으면 길이 대신 그것을 적는다. 둘 다 적으면
        // 오른쪽 끝이 복잡해지고, 배속이 걸린 곡은 그 사실이 더 중요하다
        if (tempo != null && !tempo.isNormal)
          ValuePill(label: '${tempo.speed.toStringAsFixed(2)}×', on: true)
        else
          Text(
            formatDuration(Duration(milliseconds: track.durationMs)),
            style: AppText.num.copyWith(fontSize: 12, color: AppColors.ink3),
          ),
      ],
    );
  }
}

class _GroupTracksScreen extends ConsumerWidget {
  const _GroupTracksScreen({required this.title, required this.tracks});

  final String title;
  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tempos =
        ref.watch(savedTemposProvider).value ?? const <int, TempoSettings>{};
    final nowId = ref.watch(playerControllerProvider).current?.id;
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ScreenHeader(title: title, showBack: true),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: shellBottomInset(context, ref) + 12,
                  ),
                  itemCount: tracks.length,
                  itemBuilder: (context, i) => TrackRow(
                    track: tracks[i],
                    savedTempo: tempos[tracks[i].id],
                    playing: tracks[i].id == nowId,
                    onTap: () {
                      ref
                          .read(playerControllerProvider.notifier)
                          .playQueue(tracks, i);
                      ref.read(activeSourceProvider.notifier).state =
                          PlaybackSource.local;
                      backToPlayer(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistScreen extends ConsumerStatefulWidget {
  const _PlaylistScreen({required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<_PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<_PlaylistScreen>
    with NowPlayingScroll {
  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final repo = ref.watch(libraryRepositoryProvider);
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ScreenHeader(
                title: playlist.name,
                showBack: true,
                actions: [
                  RoundButton(
                    filled: false,
                    onTap: () async {
                      await repo.deletePlaylist(playlist.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.ink2,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: StreamBuilder<List<Track>>(
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
                    final nowId = ref
                        .watch(playerControllerProvider)
                        .current
                        ?.id;
                    moveToNowPlaying(tracks.indexWhere((t) => t.id == nowId));
                    return ListView.builder(
                      controller: nowScroll,
                      padding: EdgeInsets.only(
                        bottom: shellBottomInset(context, ref) + 12,
                      ),
                      itemCount: tracks.length,
                      itemBuilder: (context, i) => TrackRow(
                        track: tracks[i],
                        playing: tracks[i].id == nowId,
                        onTap: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .playQueue(tracks, i);
                          ref.read(activeSourceProvider.notifier).state =
                              PlaybackSource.local;
                          backToPlayer(context);
                        },
                      ),
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
}
