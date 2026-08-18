import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../theme.dart';
import 'artwork.dart';
import 'artwork_tone.dart';
import 'surface.dart';

/// 재생 화면 위에 무언가 쌓였을 때만 나오는 재생 막대.
///
/// 화면 폭을 다 쓴다. 떠 있는 카드가 아니다. EQ를 만지는 동안에도 계속
/// 붙어 있어야 해서 목록의 마지막 줄을 가리면 안 된다.
///
/// 바탕은 종이보다 아주 조금 밝고, 자켓 색이 6%만 섞인다. 예전에는 자켓을
/// 흐리게 깔고 86%로 덮었는데 파란 자켓에서는 막대 전체가 파랗게 떴다.
/// 무엇이 걸려 있는지는 왼쪽 섬네일과 위 가장자리 진행선이 말해주므로
/// 바탕까지 색일 필요가 없다.
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
          : '${track.artist} · ${track.album}',
      artworkPath: artworkPathOf(track),
      // 배속이 1.0이 아닐 때만 적는다. 기본값을 굳이 보여줄 이유가 없다
      badge: state.tempo.speed == 1.0
          ? null
          : '${state.tempo.speed.toStringAsFixed(2)}×',
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
/// 배속 표시가 없다. App Remote는 기기에 깔린 Spotify 앱을 원격 조종하는
/// 방식이라 오디오가 우리 프로세스를 지나지 않는다. 그 곡에는 배속이
/// 걸리지 않는다.
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
      artworkPath: null,
      badge: 'Spotify',
      playing: !s.paused,
      onTap: onTap,
      onPrevious: session.previous,
      onToggle: session.togglePlay,
      onNext: session.next,
    );
  }
}

class _Bar extends ConsumerWidget {
  const _Bar({
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.artworkPath,
    required this.badge,
    required this.playing,
    required this.onTap,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
  });

  final double progress;
  final String title;
  final String subtitle;
  final String? artworkPath;
  final String? badge;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref
        .watch(coverToneProvider((path: artworkPath, seed: title)))
        .maybeWhen(data: (t) => t, orElse: () => CoverTone.fallback);

    return CoverScope(
      tone: tone,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // 종이 하이라이트에 자켓 색을 아주 옅게 섞는다
            color: Color.alphaBlend(
              tone.accent.withValues(alpha: 0.06),
              AppColors.paperHi,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D232620),
                blurRadius: 28,
                offset: Offset(0, -12),
              ),
            ],
          ),
          // Scaffold는 bottomNavigationBar에 시스템 바 여백을 넣어주지 않는다.
          // 여기서 직접 피하지 않으면 제스처 바나 3버튼 바에 막대가 물린다.
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: AppSpace.mini,
              child: Stack(
                children: [
                  // 진행선은 막대 맨 위에 붙는다. 여기만 강조색이다
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      color: AppColors.paperLo,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: ColoredBox(color: tone.accent),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 2, 8, 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.thumb - 1),
                            child: Artwork(path: artworkPath, size: 44),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Flexible(child: LinkText(text: subtitle)),
                                  if (badge != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      badge!,
                                      style: AppText.num.copyWith(
                                        fontSize: 12,
                                        color: tone.accentInk,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        RoundButton(
                          filled: false,
                          onTap: onPrevious,
                          child: const Icon(Icons.skip_previous,
                              size: 24, color: AppColors.ink1),
                        ),
                        RoundButton(
                          filled: false,
                          onTap: onToggle,
                          child: Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            size: 26,
                            color: AppColors.ink1,
                          ),
                        ),
                        RoundButton(
                          filled: false,
                          onTap: onNext,
                          child: const Icon(Icons.skip_next,
                              size: 24, color: AppColors.ink1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
