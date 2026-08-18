import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify_sdk/models/image_uri.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import '../data/db/database.dart';
import '../data/models/gesture_settings.dart';
import '../data/spotify/spotify_session.dart';
import '../data/spotify/track_match.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'player_screen.dart';
import 'theme.dart';
import 'widgets/paper.dart';
import 'widgets/player_parts.dart';
import 'widgets/common.dart';
import 'widgets/gesture_layer.dart';
import 'widgets/ambient_plate.dart';
import 'widgets/artwork_tone.dart';
import 'widgets/jump_button.dart';
import 'widgets/marquee_text.dart';
import 'widgets/surface.dart';

/// Spotify 자켓. App Remote가 이미지 데이터를 직접 준다.
final spotifyImageProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  imageId,
) async {
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
/// 배치는 우리 재생 화면과 같게 맞췄다. 자켓이 남는 자리를 다 쓰고, 컨트롤은
/// 그 위에 얹히고, 전송은 맨 아래에 붙는다. 제스쳐도 같은 설정을 읽는다.
/// 소리를 어느 쪽이 내느냐에 따라 조작이 달라지면 매번 다시 익혀야 한다.
///
/// 다만 소리가 Spotify 앱 프로세스에서 나오므로 배속, 피치, 3층 보정이 걸리지
/// 않는다. 그 자리는 비워두고 무엇이 꺼져 있는지 적는다.
class SpotifyPlayerView extends ConsumerStatefulWidget {
  const SpotifyPlayerView({super.key});

  @override
  ConsumerState<SpotifyPlayerView> createState() => _SpotifyPlayerViewState();
}

class _SpotifyPlayerViewState extends ConsumerState<SpotifyPlayerView> {
  /// 곡이 바뀔 때 자켓이 어느 쪽으로 미끄러질지.
  int _slideDir = 1;

  /// 이어 끌기를 시작할 때의 값.
  double? _dragBase;

  SpotifySession get _session => ref.read(spotifySessionProvider.notifier);

  /// 설정에 걸어둔 동작 중 Spotify에서 되는 것만 실행한다.
  ///
  /// 배속과 피치는 남의 프로세스가 내는 소리라 손댈 수 없다. 조용히 넘긴다.
  void _run(GestureAction action) {
    final s = ref.read(spotifySessionProvider);
    final settings = ref.read(settingsProvider);

    switch (action) {
      case GestureAction.playPause:
        _session.togglePlay();
      case GestureAction.previous:
        setState(() => _slideDir = -1);
        _session.previous();
      case GestureAction.next:
        setState(() => _slideDir = 1);
        _session.next();
      case GestureAction.seekBack1:
        _session.seekBy(Duration(seconds: -settings.seekShortSeconds));
      case GestureAction.seekBack2:
        _session.seekBy(Duration(seconds: -settings.seekLongSeconds));
      case GestureAction.seekForward1:
        _session.seekBy(Duration(seconds: settings.seekShortSeconds));
      case GestureAction.seekForward2:
        _session.seekBy(Duration(seconds: settings.seekLongSeconds));
      case GestureAction.toggleControls:
        final open = ref.read(controlPanelOpenProvider);
        ref.read(controlPanelOpenProvider.notifier).state = !open;
      case GestureAction.toggleLoop:
        if (s.loopA == null) {
          _session.setLoopA();
        } else if (s.loopB == null) {
          _session.setLoopB();
        } else {
          _session.clearLoop();
        }
      // 아래는 Spotify가 내는 소리에 걸 수 없다.
      case GestureAction.none:
      case GestureAction.volumeUp:
      case GestureAction.volumeDown:
      case GestureAction.speedUp:
      case GestureAction.speedDown:
      case GestureAction.pitchUp:
      case GestureAction.pitchDown:
      case GestureAction.toggleQueue:
        return;
    }
    HapticFeedback.selectionClick();
  }

  void _drag(DragProgress p) {
    if (p.done) {
      _dragBase = null;
      return;
    }
    // 탐색만 받는다. 음량과 배속은 Spotify 쪽 몫이다.
    if (p.action != DragAction.seek) return;

    final s = ref.read(spotifySessionProvider);
    final total = s.duration.inMilliseconds;
    if (total <= 0) return;
    _dragBase ??= s.position.inMilliseconds.toDouble();

    final span = MediaQuery.of(context).size.width / 2;
    final t = (p.delta / span).clamp(-1.5, 1.5);
    final at = (_dragBase! + t * total * 0.25).clamp(0.0, total.toDouble());
    _session.seek(Duration(milliseconds: at.round()));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(spotifySessionProvider);
    final settings = ref.watch(settingsProvider);
    final bottomInset = shellBottomInset(context, ref);
    final panelOpen = ref.watch(controlPanelOpenProvider);

    // 같은 곡을 내 파일로도 가지고 있으면 넘어갈 길을 준다. 그쪽으로 가야
    // 배속과 3층 보정이 열린다.
    final match = bestMatch<Track>(
      ref.watch(matchKeysProvider),
      title: s.trackName ?? '',
      artist: s.artistName ?? '',
    );

    // Spotify 자켓은 파일이 아니라 바이트로 온다
    final art = ref.watch(spotifyImageProvider(s.imageId ?? '')).value;
    final tone =
        ref
            .watch(coverToneOfBytesProvider((key: s.imageId ?? '', bytes: art)))
            .value ??
        CoverTone.fallback;

    return CoverScope(
      tone: tone,
      child: Scaffold(
        body: PaperBackground(
          child: SafeArea(
            bottom: false,
            child: ConfigurableGestureLayer(
              settings: settings.gestures,
              onAction: _run,
              onDrag: _drag,
              child: Column(
                children: [
                  _topBar(context, panelOpen),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = math.min(
                          box.maxWidth - 68,
                          box.maxHeight - 56,
                        );
                        if (size < 96) return const SizedBox.shrink();
                        return AmbientPlate(
                          tone: tone,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final incoming =
                                  (child.key as ValueKey<String>?)?.value ==
                                  (s.trackUri ?? '');
                              final from = incoming ? _slideDir : -_slideDir;
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: Offset(from * 0.3, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: ArtPlate(
                              key: ValueKey<String>(s.trackUri ?? ''),
                              size: size,
                              child: _artwork(image: art, size: size),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _titleRow(s),
                  const SizedBox(height: 20),
                  _progress(s),
                  // 패널을 자켓 위에 얹지 않는다. 불투명한 카드라 자켓을 덮는다
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: panelOpen
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 16),
                                _ControlPanel(
                                  state: s,
                                  session: _session,
                                  short: settings.seekShortSeconds,
                                  long: settings.seekLongSeconds,
                                ),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _transport(s, match),
                  SizedBox(height: bottomInset + 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, bool panelOpen) {
    return PlayerTopBar(
      // Spotify 초록을 쓰지 않는다. 이 화면에서 색은 재생 상태를 말하는 데
      // 쓰고 있어서, 출처까지 색으로 말하면 둘이 섞인다. 우리 처리가 꺼져
      // 있다는 것은 패널의 글자가 적어준다
      leading: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paperLo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Spotify',
          style: AppText.body.copyWith(fontSize: 14, color: AppColors.ink2),
        ),
      ),
      panelOpen: panelOpen,
      onTogglePanel: () =>
          ref.read(controlPanelOpenProvider.notifier).state = !panelOpen,
      onSearch: () => openSearchScreen(context),
      onSettings: () => openSettingsScreen(context),
    );
  }

  Widget _artwork({required Uint8List? image, required double size}) {
    if (image == null) {
      return Container(
        width: size,
        height: size,
        color: AppColors.paperLo,
        child: const Icon(Icons.music_note, size: 44, color: AppColors.hair),
      );
    }
    return Image.memory(
      image,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }

  Widget _titleRow(SpotifyState s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarqueeText(text: s.trackName ?? '', style: AppText.title),
          const SizedBox(height: 6),
          LinkText(text: s.artistName ?? ''),
        ],
      ),
    );
  }

  Widget _progress(SpotifyState s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(
        children: [
          ThinProgressBar(
            progress: s.progress,
            onSeek: (p) => _session.seek(
              Duration(milliseconds: (s.duration.inMilliseconds * p).round()),
            ),
          ),
          const SizedBox(height: 2),
          TimeRow(position: s.position, total: s.duration),
        ],
      ),
    );
  }

  Widget _transport(SpotifyState s, TrackMatch<Track>? match) {
    return TransportRow(
      playing: !s.paused,
      onToggle: _session.togglePlay,
      onPrevious: () {
        setState(() => _slideDir = -1);
        _session.previous();
      },
      onNext: () {
        setState(() => _slideDir = 1);
        _session.next();
      },
      leading: RoundButton(
        onTap: () => openLibraryScreen(context),
        child: const Icon(
          Icons.folder_outlined,
          size: 20,
          color: AppColors.ink2,
        ),
      ),
      // 같은 곡을 가지고 있으면 그쪽으로 넘어간다. 없으면 자리만 지킨다
      trailing: Opacity(
        opacity: match == null ? 0.35 : 1,
        child: RoundButton(
          onTap: () {
            if (match == null) return;
            ref.read(playerControllerProvider.notifier).playQueue([
              match.track,
            ], 0);
          },
          child: Icon(
            Icons.swap_horiz,
            size: 20,
            color: match == null ? AppColors.hair : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

/// Spotify에서는 탐색과 구간 반복만 된다.
///
/// 배속과 3층 보정은 여기에 없다. App Remote는 기기에 깔린 Spotify 앱을
/// 원격 조종하는 방식이라 오디오가 우리 프로세스를 지나지 않는다.
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.state,
    required this.session,
    required this.short,
    required this.long,
  });

  final SpotifyState state;
  final SpotifySession session;
  final int short;
  final int long;

  @override
  Widget build(BuildContext context) {
    final looping = state.loopA != null || state.loopB != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Sunken(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                JumpButton(
                  seconds: long,
                  back: true,
                  onTap: () => session.seekBy(Duration(seconds: -long)),
                ),
                JumpButton(
                  seconds: short,
                  back: true,
                  onTap: () => session.seekBy(Duration(seconds: -short)),
                ),
                Expanded(
                  child: AbPill(
                    loopA: state.loopA,
                    loopB: state.loopB,
                    onSetA: session.setLoopA,
                    onSetB: session.setLoopB,
                    onClear: session.clearLoop,
                  ),
                ),
                JumpButton(
                  seconds: short,
                  back: false,
                  onTap: () => session.seekBy(Duration(seconds: short)),
                ),
                JumpButton(
                  seconds: long,
                  back: false,
                  onTap: () => session.seekBy(Duration(seconds: long)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                looping
                    ? '구간 반복은 위치를 다시 보내는 방식이라 조금 어긋납니다'
                    : '소리가 Spotify 앱에서 납니다. 배속 · 피치 · 음향 보정은 '
                          '꺼져 있습니다',
                textAlign: TextAlign.center,
                style: AppText.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
