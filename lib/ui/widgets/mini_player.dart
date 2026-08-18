import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../theme.dart';

/// 탭바 바로 위에 붙는 재생 막대.
///
/// Capriccio처럼 화면 폭을 다 쓰고, 위쪽 가장자리에 진행선을 그리고, 제목은
/// 흰색 아티스트는 링크색으로 쓴다. 오른쪽에는 이전·재생·다음 세 개를 둔다.
/// 카드로 띄우지 않는 이유는 이 막대가 EQ를 만지는 동안에도 계속 붙어 있어야
/// 해서다. 떠 있는 카드는 목록의 마지막 줄을 가린다.
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

    return _Bar(
      progress: state.progress,
      title: track.title,
      subtitle: track.album.isEmpty || track.album == track.artist
          ? track.artist
          : '${track.artist} - ${track.album}',
      playing: state.playing,
      onTap: onTap,
      onPrevious: controller.previous,
      onToggle: controller.togglePlay,
      onNext: controller.next,
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

    return _Bar(
      progress: s.progress,
      title: s.trackName ?? '',
      subtitle: s.artistName ?? '',
      playing: !s.paused,
      onTap: onTap,
      onPrevious: session.previous,
      onToggle: session.togglePlay,
      onNext: session.next,
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.onTap,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
  });

  final double progress;
  final String title;
  final String subtitle;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 반투명으로 두면 뒤의 목록이 그대로 비쳐서 글자가 겹친다.
        // 블러를 걸 수도 있지만 목록 위에서 매 프레임 도는 블러는 보급형
        // 기기에서 프레임을 깎는다.
        decoration: const BoxDecoration(
          color: Color(0xFF101018),
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        // Scaffold는 bottomNavigationBar에 시스템 바 여백을 넣어주지 않는다.
        // 여기서 직접 피하지 않으면 제스처 바나 3버튼 바에 막대가 물린다.
        child: SafeArea(
          top: false,
          child: SizedBox(
        height: 68,
        child: Stack(
          children: [
            // 진행선은 막대 맨 위에 붙는다.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                color: AppColors.trackInactive,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(color: AppColors.accent),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 21 / 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.t1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 17 / 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.skip_previous,
                        size: 26, color: AppColors.t1),
                    onPressed: onPrevious,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                      size: 28,
                      color: AppColors.t1,
                    ),
                    onPressed: onToggle,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.skip_next,
                        size: 26, color: AppColors.t1),
                    onPressed: onNext,
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
