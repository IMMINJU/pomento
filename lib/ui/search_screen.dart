import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/db/database.dart';
import '../data/spotify/spotify_track.dart';
import '../data/spotify/track_match.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/artwork.dart';
import 'widgets/common.dart';

/// 내 파일과 Spotify를 함께 찾는다.
///
/// 내 파일이 먼저 나온다. 거기서만 배속·피치·구간 반복이 열리기 때문이다.
/// Spotify로 트는 소리는 그쪽 앱에서 나와서 우리 처리를 지나지 않는다.
///
/// Spotify를 연결하지 않았거나 인터넷이 없어도 내 파일 검색은 그대로 된다.
/// 한쪽이 막혔다고 검색창이 아무것도 안 하면 안 된다.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _text = TextEditingController();
  Timer? _debounce;

  List<SpotifyTrack> _results = const [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    // 한 글자 칠 때마다 부르면 요청 한도에 금방 닿는다.
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(q));
  }

  Future<void> _run(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _lastQuery = '';
      });
      return;
    }
    // 내 파일은 기다릴 것이 없다. 검색어를 먼저 반영해 목록을 바로 바꾼다.
    setState(() {
      _lastQuery = trimmed;
      _loading = ref.read(spotifySessionProvider).isConfigured;
    });
    if (!ref.read(spotifySessionProvider).isConfigured) return;

    final found =
        await ref.read(spotifySessionProvider.notifier).searchTracks(trimmed);
    if (!mounted) return;
    setState(() {
      _results = found;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spotify = ref.watch(spotifySessionProvider);
    final keys = ref.watch(matchKeysProvider);
    final local = _localMatches(ref.watch(tracksProvider).value);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _searchBar(),
            if (spotify.error != null) _errorBar(spotify.error!),
            Expanded(child: _body(spotify.isConfigured, keys, local)),
          ],
        ),
      ),
    );
  }

  /// 라이브러리에서 제목, 아티스트, 앨범에 검색어가 들어간 곡.
  ///
  /// 여기는 정규화까지 하지 않는다. 목록 검색은 친 글자가 그대로 들어 있는
  /// 것을 기대하는 자리다. 판본 표기를 지우는 정규화는 Spotify 결과와 같은
  /// 곡인지 가릴 때만 쓴다.
  List<Track> _localMatches(List<Track>? all) {
    final q = _lastQuery.toLowerCase();
    if (q.isEmpty || all == null) return const [];
    return all
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q) ||
            t.album.toLowerCase().contains(q))
        .take(30)
        .toList();
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.only(left: 6, right: 14),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left, size: 24,
                  color: AppColors.t1),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: TextField(
                controller: _text,
                style: AppText.body,
                cursorColor: AppColors.accent,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _run,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '곡, 아티스트',
                  hintStyle: TextStyle(color: AppColors.t3, fontSize: 15),
                ),
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else if (_text.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _text.clear();
                  setState(() {
                    _results = const [];
                    _lastQuery = '';
                  });
                },
                child: const Icon(Icons.close, size: 18, color: AppColors.t3),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorBar(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: AppText.caption)),
            GestureDetector(
              onTap: ref.read(spotifySessionProvider.notifier).clearError,
              child: const Icon(Icons.close, size: 16, color: AppColors.t3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    bool configured,
    List<MatchKey<Track>> keys,
    List<Track> local,
  ) {
    if (_lastQuery.isEmpty) {
      return const EmptyHint(
        icon: Icons.search,
        title: '무엇을 들을까요',
        body: '내 파일을 먼저 보여주고, 그 아래에 Spotify 결과를 놓습니다',
      );
    }

    // 내 파일로 이미 보여준 곡은 Spotify 쪽에서 뺀다. 같은 곡이 두 줄로
    // 나오면 어느 것을 눌러야 하는지 헷갈린다.
    final shownIds = local.map((t) => t.id).toSet();
    // Spotify는 같은 곡을 싱글과 정규와 재발매로 여러 번 준다. 목록에서는
    // 한 줄이면 된다.
    final seen = <String>{};
    final remote = <({SpotifyTrack track, TrackMatch<Track>? match})>[];
    for (final t in _results) {
      final fingerprint =
          '${normalizeTitle(t.title)}|${normalizeArtist(t.artist)}';
      if (!seen.add(fingerprint)) continue;

      final m = bestMatch<Track>(
        keys,
        title: t.title,
        artist: t.artist,
        isrc: t.isrc,
      );
      if (m != null && shownIds.contains(m.track.id)) continue;
      remote.add((track: t, match: m));
    }

    if (local.isEmpty && remote.isEmpty && !_loading) {
      return EmptyHint(
        icon: Icons.search_off,
        title: '결과가 없습니다',
        body: configured
            ? '철자를 바꿔 보세요'
            : '설정에서 Spotify를 연결하면 더 넓게 찾습니다',
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: shellBottomInset(context, ref) + 12),
      children: [
        if (local.isNotEmpty) ...[
          _sectionLabel('내 파일 ${local.length}'),
          for (final t in local)
            _LocalRow(track: t, onTap: () => _playLocal(t)),
        ],
        if (configured) ...[
          _sectionLabel(_loading ? 'Spotify 찾는 중' : 'Spotify'),
          if (_loading && remote.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          for (final r in remote)
            _ResultRow(
              spotify: r.track,
              match: r.match,
              onTap: () => _open(r.track, r.match),
            ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'Spotify를 연결하면 내가 없는 곡도 함께 찾습니다',
              style: AppText.small,
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      );

  Future<void> _open(SpotifyTrack t, TrackMatch<Track>? match) async {
    if (match == null) {
      await _playOnSpotify(t);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: AppText.body),
                  const SizedBox(height: 2),
                  Text(t.artist, style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.tune, color: AppColors.accent),
              title: const Text('내 파일로 재생', style: AppText.body),
              subtitle: Text(
                match.confidence == MatchConfidence.loose
                    ? '${match.track.title} · 판본이 다를 수 있습니다'
                    : '배속 · 피치 · 구간 반복이 열립니다',
                style: AppText.small,
              ),
              onTap: () {
                Navigator.pop(sheet);
                _playLocal(match.track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq, color: AppColors.t2),
              title: const Text('Spotify로 재생', style: AppText.body),
              subtitle:
                  const Text('배속과 음향 보정은 걸리지 않습니다', style: AppText.small),
              onTap: () {
                Navigator.pop(sheet);
                _playOnSpotify(t);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _playLocal(Track track) {
    // 두 재생이 겹치면 소리가 포개진다. 켜는 쪽이 반대쪽을 멈춘다.
    final spotify = ref.read(spotifySessionProvider);
    if (spotify.connected && !spotify.paused) {
      ref.read(spotifySessionProvider.notifier).togglePlay();
    }
    // 검색에서 고른 곡 하나만 큐에 넣는다. 목록 전체를 넣으면 다음 곡으로
    // 엉뚱한 검색 결과가 이어진다.
    ref.read(playerControllerProvider.notifier).playQueue([track], 0);
    ref.read(activeSourceProvider.notifier).state = PlaybackSource.local;
    backToPlayer(context);
  }

  Future<void> _playOnSpotify(SpotifyTrack t) async {
    final session = ref.read(spotifySessionProvider.notifier);
    ref.read(playerControllerProvider.notifier).pause();
    await session.play(t.appUri);
    if (!mounted) return;

    final err = ref.read(spotifySessionProvider).error;
    if (err == null) {
      ref.read(activeSourceProvider.notifier).state = PlaybackSource.spotify;
      backToPlayer(context);
      return;
    }

    // App Remote가 안 붙으면 Spotify 앱을 그냥 연다. 이쪽은 SDK도 Premium도
    // 필요 없다.
    final uri = Uri.parse(t.appUri);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      session.clearError();
    } else {
      await launchUrl(
        Uri.parse(t.webUrl),
        mode: LaunchMode.externalApplication,
      );
      session.clearError();
    }
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.spotify,
    required this.match,
    required this.onTap,
  });

  final SpotifyTrack spotify;
  final TrackMatch<Track>? match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = match != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: spotify.artworkUrl == null
                  ? Container(
                      width: 44,
                      height: 44,
                      color: AppColors.glass,
                      child: const Icon(Icons.music_note,
                          size: 18, color: AppColors.t3),
                    )
                  : Image.network(
                      spotify.artworkUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 44,
                        height: 44,
                        color: AppColors.glass,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spotify.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: local ? AppColors.t1 : AppColors.t2,
                      fontWeight: local ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${spotify.artist} · ${spotify.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (local)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  match!.confidence.label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 0.4,
                  ),
                ),
              )
            else
              Text(
                formatDuration(spotify.duration),
                style: AppText.mono,
              ),
          ],
        ),
      ),
    );
  }
}

/// 내 파일 한 줄.
class _LocalRow extends StatelessWidget {
  const _LocalRow({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Artwork(track: track, size: 44, radius: 6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.t1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.album.isEmpty || track.album == track.artist
                        ? track.artist
                        : '${track.artist} · ${track.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.45),
                ),
              ),
              child: const Text(
                'LOCAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
