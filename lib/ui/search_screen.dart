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
import 'widgets/common.dart';

/// Spotify 검색 결과와 내 파일을 겹쳐 보여준다.
///
/// 검색과 자켓은 Spotify에서 오고, 소리는 되도록 내 파일에서 낸다. 내가 가진
/// 곡에서만 배속·피치·구간 반복이 열리기 때문이다. Spotify로 트는 소리는
/// Spotify 앱에서 나와서 우리 처리를 지나지 않는다.
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
    if (q.trim() == _lastQuery && _results.isNotEmpty) return;
    if (q.trim().isEmpty) {
      setState(() {
        _results = const [];
        _lastQuery = '';
      });
      return;
    }
    setState(() => _loading = true);
    final found =
        await ref.read(spotifySessionProvider.notifier).searchTracks(q);
    if (!mounted) return;
    setState(() {
      _results = found;
      _loading = false;
      _lastQuery = q.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final spotify = ref.watch(spotifySessionProvider);
    final keys = ref.watch(matchKeysProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _searchBar(),
            if (spotify.error != null) _errorBar(spotify.error!),
            Expanded(child: _body(spotify.isConfigured, keys)),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.t3),
            const SizedBox(width: 10),
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

  Widget _body(bool configured, List<MatchKey<Track>> keys) {
    if (!configured) {
      return EmptyHint(
        icon: Icons.key_off,
        title: 'Spotify Client ID가 없습니다',
        body: '설정에서 Client ID를 넣으면 검색이 열립니다',
        action: AccentButton(
          label: '설정으로',
          onPressed: () => ref.read(shellTabProvider.notifier).state = 3,
        ),
      );
    }

    if (_results.isEmpty) {
      return EmptyHint(
        icon: Icons.search,
        title: _lastQuery.isEmpty ? '무엇을 들을까요' : '결과가 없습니다',
        body: _lastQuery.isEmpty
            ? '내가 가진 곡에는 LOCAL 표가 붙습니다'
            : '철자를 바꿔 보세요',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: shellBottomInset(context, ref) + 12),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final t = _results[i];
        final match = bestMatch<Track>(
          keys,
          title: t.title,
          artist: t.artist,
          isrc: t.isrc,
        );
        return _ResultRow(
          spotify: t,
          match: match,
          onTap: () => _open(t, match),
        );
      },
    );
  }

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
    ref.read(shellTabProvider.notifier).state = 0;
  }

  Future<void> _playOnSpotify(SpotifyTrack t) async {
    final session = ref.read(spotifySessionProvider.notifier);
    ref.read(playerControllerProvider.notifier).pause();
    await session.play(t.appUri);
    if (!mounted) return;

    final err = ref.read(spotifySessionProvider).error;
    if (err == null) {
      ref.read(activeSourceProvider.notifier).state = PlaybackSource.spotify;
      ref.read(shellTabProvider.notifier).state = 0;
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
