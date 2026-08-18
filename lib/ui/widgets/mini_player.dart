import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../theme.dart';
import 'artwork.dart';
import 'glass.dart';

/// 탭바 바로 위에 붙는 재생 막대.
///
/// Capriccio처럼 플레이어가 탭 하나로 상주하므로, 이 막대를 누르면 화면을
/// 새로 쌓지 않고 플레이어 탭으로 옮겨간다.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(activeSourceProvider) == PlaybackSource.spotify) {
      return _SpotifyBar(onTap: onTap);
    }

    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = state.current;
    if (track == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GestureDetector(
        onTap: onTap,
        child: GlassSurface(
          radius: 20,
          blur: AppBlur.sheet,
          opacity: 0.12,
          height: 64,
          child: Stack(
            children: [
              // 진행선은 바 안쪽 맨 위에 붙는다. 바깥에 두면 화면을 가로지르는
              // 선 하나가 떠 있는 것처럼 보인다.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 2,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: state.progress,
                    child: Container(color: AppColors.accent),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Artwork(track: track, size: 40, radius: 8),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 18 / 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.t1,
                            ),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small,
                          ),
                        ],
                      ),
                    ),
                    if (!state.tempo.isNormal)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${state.tempo.speed.toStringAsFixed(2)}×',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.accent,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        state.playing ? Icons.pause : Icons.play_arrow,
                        size: 24,
                        color: AppColors.t1,
                      ),
                      onPressed: controller.togglePlay,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next,
                        size: 20,
                        color: AppColors.t2,
                      ),
                      onPressed: controller.next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spotify가 소리를 낼 때의 막대.
///
/// 배속 표시가 없다. 그 곡에는 배속이 걸리지 않기 때문이다.
class _SpotifyBar extends ConsumerWidget {
  const _SpotifyBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(spotifySessionProvider);
    final session = ref.read(spotifySessionProvider.notifier);
    if (!s.hasTrack) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GestureDetector(
        onTap: onTap,
        child: GlassSurface(
          radius: 20,
          blur: AppBlur.sheet,
          opacity: 0.12,
          height: 64,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 2,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: s.progress,
                    child: Container(color: const Color(0xFF1DB954)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.graphic_eq,
                          size: 18, color: Color(0xFF1DB954)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.trackName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 18 / 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.t1,
                            ),
                          ),
                          Text(
                            s.artistName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        s.paused ? Icons.play_arrow : Icons.pause,
                        size: 24,
                        color: AppColors.t1,
                      ),
                      onPressed: session.togglePlay,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next,
                          size: 20, color: AppColors.t2),
                      onPressed: session.next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
