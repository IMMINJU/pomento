import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify_sdk/models/image_uri.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import '../data/db/database.dart';
import '../data/spotify/spotify_session.dart';
import '../data/spotify/track_match.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';

/// Spotify 자켓. App Remote가 이미지 데이터를 직접 준다.
final spotifyImageProvider =
    FutureProvider.family<Uint8List?, String>((ref, imageId) async {
  if (imageId.isEmpty) return null;
  try {
    return await SpotifySdk.getImage(
      imageUri: ImageUri(imageId),
      dimension: ImageDimension.large,
    );
  } catch (_) {
    return null;
  }
});

/// Spotify 앱이 소리를 낼 때 보여주는 화면.
///
/// 소리가 우리 프로세스를 지나지 않아서 배속, 피치, 3층 보정이 걸리지 않는다.
/// 되는 것과 안 되는 것을 화면에 적어둔다. 안 그러면 다이얼을 돌려도 소리가
/// 안 바뀌는 고장으로 보인다.
class SpotifyPlayerView extends ConsumerWidget {
  const SpotifyPlayerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(spotifySessionProvider);
    final session = ref.read(spotifySessionProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final bottomInset = shellBottomInset(context, ref);

    // 같은 곡을 내 파일로도 가지고 있으면 넘어갈 길을 준다. 그쪽으로 가야
    // 배속과 구간 반복이 열린다.
    final match = bestMatch<Track>(
      ref.watch(matchKeysProvider),
      title: s.trackName ?? '',
      artist: s.artistName ?? '',
    );

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context, ref),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = math.min(box.maxWidth - 56, box.maxHeight);
                  return Center(
                    child: _artwork(ref, s.imageId ?? '', math.max(size, 120)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.trackName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.artistName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  ThinProgressBar(
                    progress: s.progress,
                    onSeek: (p) => session.seek(
                      Duration(
                        milliseconds:
                            (s.duration.inMilliseconds * p).round(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(formatDuration(s.position), style: AppText.mono),
                      const Spacer(),
                      Text(formatDuration(s.duration), style: AppText.mono),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _notice(s.loopA != null || s.loopB != null),
            const SizedBox(height: 12),
            _loopAndJump(session, s.loopA, s.loopB, settings.seekShortSeconds),
            const SizedBox(height: 14),
            _transport(session, s.paused),
            if (match != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AccentButton(
                  label: '내 파일로 바꾸기',
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  onPressed: () {
                    session.togglePlay();
                    ref
                        .read(playerControllerProvider.notifier)
                        .playQueue([match.track], 0);
                    ref.read(activeSourceProvider.notifier).state =
                        PlaybackSource.local;
                  },
                ),
              ),
            ],
            SizedBox(height: bottomInset + 8),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'Spotify',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1DB954),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '내 라이브러리로',
              icon: const Icon(Icons.library_music_outlined,
                  size: 22, color: AppColors.t2),
              onPressed: () {
                ref.read(activeSourceProvider.notifier).state =
                    PlaybackSource.local;
                openLibraryScreen(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _artwork(WidgetRef ref, String imageId, double size) {
    final image = ref.watch(spotifyImageProvider(imageId)).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: image == null
          ? Container(
              width: size,
              height: size,
              color: AppColors.glass,
              child: const Icon(Icons.music_note,
                  size: 48, color: AppColors.t3),
            )
          : Image.memory(
              image,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
  }

  Widget _notice(bool looping) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 15, color: AppColors.t3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                looping
                    ? '구간 반복은 Spotify에 위치를 다시 보내는 방식이라 조금 어긋납니다'
                    : '소리가 Spotify 앱에서 나옵니다. 배속 · 피치 · 음향 보정은 꺼져 있습니다',
                style: AppText.small,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loopAndJump(
    SpotifySession session,
    Duration? a,
    Duration? b,
    int jump,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _Chip(
              label: a == null ? 'A' : 'A ${formatDuration(a)}',
              active: a != null,
              onTap: () {
                HapticFeedback.selectionClick();
                session.setLoopA();
              },
              onLongPress: session.clearLoop,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Chip(
              label: b == null ? 'B' : 'B ${formatDuration(b)}',
              active: b != null,
              onTap: () {
                HapticFeedback.selectionClick();
                session.setLoopB();
              },
              onLongPress: session.clearLoop,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Chip(
              label: '-$jump',
              active: false,
              onTap: () => session.seekBy(Duration(seconds: -jump)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Chip(
              label: '+$jump',
              active: false,
              onTap: () => session.seekBy(Duration(seconds: jump)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transport(SpotifySession session, bool paused) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 30,
          icon: const Icon(Icons.skip_previous, color: AppColors.t1),
          onPressed: session.previous,
        ),
        const SizedBox(width: 20),
        GlassSurface(
          radius: 34,
          width: 68,
          height: 68,
          onTap: session.togglePlay,
          child: Icon(
            paused ? Icons.play_arrow : Icons.pause,
            size: 30,
            color: AppColors.t1,
          ),
        ),
        const SizedBox(width: 20),
        IconButton(
          iconSize: 30,
          icon: const Icon(Icons.skip_next, color: AppColors.t1),
          onPressed: session.next,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.45)
                : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: active ? AppColors.accent : AppColors.t1,
            fontFeatures: tabularFigures,
          ),
        ),
      ),
    );
  }
}
