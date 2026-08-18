// Flutter의 RepeatMode(애니메이션용)와 이름이 겹쳐서 가린다.
import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/player_controller.dart';
import '../data/models/gesture_settings.dart';
import '../data/models/tempo.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'practice_screen.dart';
import 'spotify_player.dart';
import 'theme.dart';
import 'widgets/ambient_plate.dart';
import 'widgets/artwork.dart';
import 'widgets/artwork_tone.dart';
import 'widgets/common.dart';
import 'widgets/gesture_layer.dart';
import 'widgets/jump_button.dart';
import 'widgets/marquee_text.dart';
import 'widgets/hold_repeat.dart';
import 'widgets/paper.dart';
import 'widgets/player_parts.dart';
import 'widgets/surface.dart';

/// 재생 컨트롤 패널을 펼쳐 두었는지.
///
/// 열면 앨범아트 아래에 구간 반복, 점프 탐색, 속도, 피치가 한 줄씩 붙는다.
/// 화면을 옮기지 않고 그 자리에서 값을 바꾼다.
///
/// 기본은 접어둔다. 늘 펼쳐두면 피치와 구간 반복을 스치듯 눌러 잘못 걸리는
/// 일이 잦다. 앨범아트를 길게 누르거나 상단 바의 둥근 버튼으로 연다.
final controlPanelOpenProvider = StateProvider<bool>((ref) => false);

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // 두 손가락 제스처 중 임시로 쌓는 값. 손을 뗄 때 한 번만 저장한다.
  double? _dragSpeed;
  double? _dragPitch;
  bool _twoFinger = false;

  /// 한 손가락 이어 끌기를 시작할 때의 값. 끌기가 끝나면 버린다.
  double? _dragBase;

  /// 곡이 바뀔 때 자켓이 어느 쪽으로 미끄러질지. 다음 곡이면 왼쪽으로 나간다.
  int _slideDir = 1;

  /// 가로 쓸기가 지금 얼마나 왔는지. 자켓이 손가락을 따라오게 하는 값이다.
  double _swipeDx = 0;

  /// 손가락이 아직 닿아 있는지. 붙어 있는 동안에는 애니메이션 없이 그대로
  /// 따라오고, 떼면 부드럽게 자리를 잡는다.
  bool _swiping = false;

  void _onSwipe(double dx, bool done, bool committed) {
    if (!mounted) return;
    setState(() {
      if (done) {
        _swiping = false;
        // 넘어가는 경우에는 AnimatedSwitcher가 이어받으므로 여기서 자켓을
        // 제자리로 돌린다. 두 연출이 겹치면 자켓이 두 번 움직인다
        _swipeDx = 0;
      } else {
        _swiping = true;
        _swipeDx = dx;
      }
    });
    if (done && committed) HapticFeedback.selectionClick();
  }

  /// 설정에 걸어둔 동작 하나를 실행한다.
  void _run(GestureAction action) {
    final c = ref.read(playerControllerProvider.notifier);
    final state = ref.read(playerControllerProvider);
    final s = ref.read(settingsProvider);

    switch (action) {
      case GestureAction.none:
        return;
      case GestureAction.playPause:
        c.togglePlay();
      case GestureAction.previous:
        _slideDir = -1;
        c.previous();
      case GestureAction.next:
        _slideDir = 1;
        c.next();
      case GestureAction.seekBack1:
        c.seekBy(Duration(seconds: -s.seekShortSeconds));
      case GestureAction.seekBack2:
        c.seekBy(Duration(seconds: -s.seekLongSeconds));
      case GestureAction.seekForward1:
        c.seekBy(Duration(seconds: s.seekShortSeconds));
      case GestureAction.seekForward2:
        c.seekBy(Duration(seconds: s.seekLongSeconds));
      case GestureAction.volumeUp:
        c.setVolume((state.volume + 0.05).clamp(0.0, 1.0));
      case GestureAction.volumeDown:
        c.setVolume((state.volume - 0.05).clamp(0.0, 1.0));
      case GestureAction.speedUp:
        c.setSpeed(
          _snapSpeed(state.tempo.speed + s.speedStep, s.speedStep),
          commit: true,
        );
      case GestureAction.speedDown:
        c.setSpeed(
          _snapSpeed(state.tempo.speed - s.speedStep, s.speedStep),
          commit: true,
        );
      case GestureAction.pitchUp:
        c.setPitchCents(
          (state.tempo.pitchCents + s.pitchStepCents).clamp(-200.0, 200.0),
          commit: true,
        );
      case GestureAction.pitchDown:
        c.setPitchCents(
          (state.tempo.pitchCents - s.pitchStepCents).clamp(-200.0, 200.0),
          commit: true,
        );
      case GestureAction.toggleQueue:
        showQueueSheet(context);
      case GestureAction.toggleControls:
        final open = ref.read(controlPanelOpenProvider);
        ref.read(controlPanelOpenProvider.notifier).state = !open;
      case GestureAction.toggleLoop:
        if (state.loopA == null) {
          c.setLoopA();
        } else if (state.loopB == null) {
          c.setLoopB();
        } else {
          c.clearLoop();
        }
    }
    HapticFeedback.selectionClick();
  }

  static double _snapSpeed(double v, double step) {
    final next = (v.clamp(0.5, 2.0) * 1000).round() / 1000;
    return (next - 1.0).abs() < step * 0.4 ? 1.0 : next;
  }

  /// 손가락을 붙인 채 끌 때. 화면 너비의 절반을 끌면 한 단위 움직인다.
  void _drag(DragProgress p) {
    final c = ref.read(playerControllerProvider.notifier);
    final state = ref.read(playerControllerProvider);
    final span = MediaQuery.of(context).size.width / 2;
    final t = (p.delta / span).clamp(-1.5, 1.5);

    if (p.done) {
      if (_dragBase != null &&
          (p.action == DragAction.speed || p.action == DragAction.pitch)) {
        // 끌기가 끝난 자리를 한 번만 저장한다.
        c.setTempo(state.tempo, commit: true);
      }
      _dragBase = null;
      return;
    }

    switch (p.action) {
      case DragAction.none:
        return;
      case DragAction.seek:
        _dragBase ??= state.position.inMilliseconds.toDouble();
        final total = state.duration.inMilliseconds;
        if (total <= 0) return;
        // 곡 길이의 4분의 1을 화면 절반에 대응시킨다.
        final at = (_dragBase! + t * total * 0.25).clamp(0.0, total.toDouble());
        c.seek(Duration(milliseconds: at.round()));
      case DragAction.volume:
        _dragBase ??= state.volume;
        c.setVolume((_dragBase! + t * 0.8).clamp(0.0, 1.0));
      case DragAction.speed:
        _dragBase ??= state.tempo.speed;
        c.setSpeed((_dragBase! + t * 0.25).clamp(0.5, 2.0));
      case DragAction.pitch:
        _dragBase ??= state.tempo.pitchCents;
        c.setPitchCents((_dragBase! + t * 150).clamp(-200.0, 200.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Spotify 앱이 소리를 내는 동안에는 그쪽 화면을 보여준다. 우리 전송
    // 버튼으로 남의 프로세스를 조종할 수는 없다.
    final source = ref.watch(activeSourceProvider);
    final spotifyHasTrack = ref.watch(
      spotifySessionProvider.select((s) => s.hasTrack),
    );
    if (source == PlaybackSource.spotify && spotifyHasTrack) {
      return const SpotifyPlayerView();
    }

    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = state.current;
    final bottomInset = shellBottomInset(context, ref);
    final panelOpen = ref.watch(controlPanelOpenProvider);

    if (track == null) {
      return Scaffold(
        body: PaperBackground(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Center(
              child: EmptyHint(
                icon: Icons.music_note,
                title: '재생 중인 곡이 없습니다',
                body: '아래 폴더 버튼으로 곡을 고르세요',
                action: InkButton(
                  label: '라이브러리로',
                  onPressed: () => openLibraryScreen(context),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final tone = coverToneOf(ref, track);

    return CoverScope(
      tone: tone,
      child: Scaffold(
        body: PaperBackground(
          child: SafeArea(
            bottom: false,
            child: _GestureLayer(
              onScaleStart: (details) {
                _twoFinger = false;
                _dragSpeed = state.tempo.speed;
                _dragPitch = state.tempo.pitchCents;
              },
              onScaleUpdate: (details, delta) {
                // 두 번째 손가락은 제스처가 시작된 뒤에 닿는 경우가 많아서
                // 시작 시점이 아니라 진행 중에 판단한다.
                if (details.pointerCount >= 2) _twoFinger = true;
                if (!_twoFinger) return;
                // 두 손가락 세로: 배속. 가속 곡선을 넣어 천천히 끌면 곱게,
                // 빠르게 끌면 굵게 움직인다.
                final speedStep =
                    -delta.dy * (0.0006 + (delta.distance / 80) * 0.004);
                final next = ((_dragSpeed ?? 1.0) + speedStep).clamp(0.5, 2.0);
                _dragSpeed = next;

                // 두 손가락 가로: 피치(센트).
                final pitchStep = delta.dx * 0.35;
                final nextPitch = ((_dragPitch ?? 0) + pitchStep).clamp(
                  -200.0,
                  200.0,
                );
                _dragPitch = nextPitch;

                var snapped = (next * 1000).round() / 1000;
                if ((snapped - 1.0).abs() < 0.004) snapped = 1.0;

                controller.setTempo(
                  state.tempo.copyWith(
                    speed: snapped,
                    pitchCents: state.tempo.mode == TempoMode.independent
                        ? nextPitch.roundToDouble()
                        : state.tempo.pitchCents,
                  ),
                );
              },
              onScaleEnd: () {
                if (_twoFinger) {
                  HapticFeedback.selectionClick();
                  controller.setTempo(state.tempo, commit: true);
                }
                _twoFinger = false;
              },
              onTwoFingerDoubleTap: () {
                controller.setTempoMode(
                  state.tempo.mode == TempoMode.linked
                      ? TempoMode.independent
                      : TempoMode.linked,
                );
                HapticFeedback.mediumImpact();
              },
              child: ConfigurableGestureLayer(
                settings: ref.watch(settingsProvider.select((s) => s.gestures)),
                onAction: _run,
                onDrag: _drag,
                onSwipe: _onSwipe,
                child: Column(
                  children: [
                    _TopBar(state: state),
                    // 남는 세로 공간을 전부 자켓과 그 뒤의 판에 준다.
                    // 자켓이 작아지면 제스처를 받을 면적도 같이 줄어든다.
                    Expanded(
                      child: _Band(
                        tone: tone,
                        track: track,
                        slideDir: _slideDir,
                        swipeDx: _swipeDx,
                        swiping: _swiping,
                        onLongPress: () =>
                            ref.read(controlPanelOpenProvider.notifier).state =
                                !panelOpen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TitleRow(state: state, controller: controller),
                    const SizedBox(height: 20),
                    _Progress(state: state, controller: controller),
                    // 패널이 열리고 닫힐 때 자켓이 함께 줄고 늘어난다.
                    // 높이가 튀면 자켓이 순간이동한 것처럼 보인다
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
                                    state: state,
                                    controller: controller,
                                  ),
                                ],
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Transport(
                      state: state,
                      controller: controller,
                      onPrevious: () {
                        _slideDir = -1;
                        controller.previous();
                      },
                      onNext: () {
                        _slideDir = 1;
                        controller.next();
                      },
                    ),
                    SizedBox(height: bottomInset + 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 앨범아트와 그 뒤에 깔리는 색 판.
class _Band extends StatelessWidget {
  const _Band({
    required this.tone,
    required this.track,
    required this.slideDir,
    required this.swipeDx,
    required this.swiping,
    required this.onLongPress,
  });

  final CoverTone tone;
  final dynamic track;
  final int slideDir;

  /// 손가락이 온 거리. 자켓이 그 절반쯤만 따라온다. 그대로 따라오면 손을
  /// 떼지 않고 화면 밖까지 끌 수 있어서 무엇이 일어나는지 알기 어렵다.
  final double swipeDx;
  final bool swiping;

  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(box.maxWidth - 68, box.maxHeight - 56);
        if (size < 96) return const SizedBox.shrink();
        final width = MediaQuery.of(context).size.width;
        final t = (swipeDx / width).clamp(-1.0, 1.0);

        return AmbientPlate(
          tone: tone,
          // 자켓을 판 아래쪽에 붙인다. 가운데에 두면 자켓과 제목 사이가
          // 벌어져서 제목이 허공에 떠 보인다
          align: const Alignment(0, 0.55),
          child: AnimatedSlide(
            offset: Offset(t * 0.42, 0),
            duration: swiping
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: 1 - (t.abs() * 0.5).clamp(0.0, 0.5),
              duration: swiping
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              child: GestureDetector(
                onLongPress: onLongPress,
                // 곡이 바뀌면 옆으로 미끄러진다. 쓸어 넘긴 방향과 같은 쪽으로
                // 나가야 손짓과 화면이 맞물린다.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final incoming =
                        (child.key as ValueKey<int>?)?.value == track.id;
                    final from = incoming ? slideDir : -slideDir;
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(from * 0.3, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: ArtPlate(
                    key: ValueKey<int>(track.id),
                    size: size,
                    child: Artwork(track: track, size: size, radius: 0),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 큐 위치, 컨트롤 패널 토글, 검색, 설정.
///
/// 왼쪽 알약의 밑줄은 곡의 진행이 아니라 큐 안에서의 위치다. 자주 쓰지
/// 않는 것을 위로 올린다. 아래쪽은 재생 조작 몫이다.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state});

  final PlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = state.queue.length;
    final panelOpen = ref.watch(controlPanelOpenProvider);

    return PlayerTopBar(
      leading: QueuePill(at: total == 0 ? 0 : state.index + 1, total: total),
      panelOpen: panelOpen,
      onTogglePanel: () =>
          ref.read(controlPanelOpenProvider.notifier).state = !panelOpen,
      onSearch: () => openSearchScreen(context),
      onSettings: () => openSettingsScreen(context),
    );
  }
}

/// 제목과 아티스트. 그 오른쪽에 반복과 셔플.
///
/// 제목과 전송을 카드로 묶지 않는다. 한 번 묶어봤는데 Capriccio는 그렇게
/// 하지 않는다.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.state, required this.controller});

  final PlayerState state;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final tone = CoverScope.of(context);
    final track = state.current!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목은 폭을 다 쓴다. 옆에 버튼을 두면 훑을 자리가 줄고, 긴
          // 제목일수록 한 바퀴가 오래 걸린다
          MarqueeText(text: track.title, style: AppText.title),
          const SizedBox(height: 6),
          Row(
            children: [
              // 글자 셋을 한 덩어리로 묶는다. 형제로 두면 Flexible끼리
              // 남는 폭을 나눠 가져서 Spacer가 제 몫을 못 받는다
              Expanded(
                child: Row(
                  children: [
                    // 아티스트는 밑줄로 누를 수 있음을 말한다. 앨범은 그냥 회색
                    Flexible(child: LinkText(text: track.artist)),
                    if (track.album.isNotEmpty && track.album != track.artist)
                      Flexible(
                        child: Text(
                          ' · ${track.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sub,
                        ),
                      ),
                    if (state.tempo.speed != 1.0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${state.tempo.speed.toStringAsFixed(2)}×',
                        style: AppText.num.copyWith(
                          fontSize: 12,
                          color: tone.accentInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 제목 덩어리의 오른쪽 아래. 제목 줄을 비켜 있으면서도 이 곡에
              // 딸린 설정이라는 것이 읽힌다
              ToggleIcon(
                icon: switch (state.repeat) {
                  RepeatMode.one => Icons.repeat_one,
                  _ => Icons.repeat,
                },
                on: state.repeat != RepeatMode.off,
                onTap: controller.cycleRepeat,
              ),
              ToggleIcon(
                icon: Icons.shuffle,
                on: state.shuffle,
                onTap: controller.toggleShuffle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state, required this.controller});

  final PlayerState state;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(
        children: [
          ThinProgressBar(
            progress: state.progress,
            onSeek: (p) => controller.seek(
              Duration(
                milliseconds: (state.duration.inMilliseconds * p).round(),
              ),
            ),
          ),
          const SizedBox(height: 2),
          TimeRow(position: state.position, total: state.totalWallClock),
        ],
      ),
    );
  }
}

/// 재생 컨트롤 패널.
///
/// 위 줄은 점프 탐색과 구간 반복, 아래 두 줄은 속도와 피치다. 값을 바꾸러
/// 다른 화면으로 가지 않는다.
///
/// 예전에는 이 패널을 자켓 위에 유리로 얹었다. 유리를 걷어냈으니 불투명한
/// 카드가 되는데, 그러면 자켓을 덮는다. 자켓 위에 아무것도 올리지 않기로
/// 했으므로 패널이 열리면 자켓이 줄고 패널이 진행바 아래로 들어간다.
class _ControlPanel extends ConsumerWidget {
  const _ControlPanel({required this.state, required this.controller});

  final PlayerState state;
  final PlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final tempo = state.tempo;
    final short = settings.seekShortSeconds;
    final long = settings.seekLongSeconds;

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
                  onTap: () => controller.seekBy(Duration(seconds: -long)),
                ),
                JumpButton(
                  seconds: short,
                  back: true,
                  onTap: () => controller.seekBy(Duration(seconds: -short)),
                ),
                Expanded(
                  child: AbPill(
                    loopA: state.loopA,
                    loopB: state.loopB,
                    onSetA: controller.setLoopA,
                    onSetB: controller.setLoopB,
                    onClear: controller.clearLoop,
                  ),
                ),
                JumpButton(
                  seconds: short,
                  back: false,
                  onTap: () => controller.seekBy(Duration(seconds: short)),
                ),
                JumpButton(
                  seconds: long,
                  back: false,
                  onTap: () => controller.seekBy(Duration(seconds: long)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ValueStepper(
              // 아이콘을 누르면 연동과 고정이 바뀐다
              icon: tempo.mode == TempoMode.linked
                  ? Icons.link
                  : Icons.link_off,
              value: '${tempo.speed.toStringAsFixed(2)}×',
              aux: tempo.speed == 1.0
                  ? ''
                  : '${tempo.speed > 1 ? '+' : ''}'
                        '${((tempo.speed - 1) * 100).toStringAsFixed(1)}%',
              changed: tempo.speed != 1.0,
              onMinus: () => _bumpSpeed(-1, settings.speedStep),
              onPlus: () => _bumpSpeed(1, settings.speedStep),
              onIconTap: () {
                HapticFeedback.selectionClick();
                controller.setTempoMode(
                  tempo.mode == TempoMode.linked
                      ? TempoMode.independent
                      : TempoMode.linked,
                );
              },
            ),
            const SizedBox(height: 8),
            _ValueStepper(
              icon: Icons.piano,
              value:
                  '${tempo.pitchCents >= 0 ? '+' : ''}'
                  '${tempo.pitchCents.toStringAsFixed(1)}¢',
              // 연동 모드에서는 피치가 잠긴다. 리샘플링이라 음질 손실이
              // 없다는 것이 그 모드의 존재 이유인데 피치시프트를 얹으면
              // 피하려던 잡음을 도로 들이게 된다.
              // 잠긴 줄을 누르면 고정으로 바꿔준다
              aux: tempo.mode == TempoMode.linked
                  ? '고정으로'
                  : (tempo.pitchCents == 0
                        ? ''
                        : 'A=${(440 * math.pow(2, tempo.pitchCents / 1200)).round()}'),
              changed: tempo.pitchCents != 0,
              enabled: tempo.mode == TempoMode.independent,
              onMinus: () => _bumpPitch(-1, settings.pitchStepCents.toDouble()),
              onPlus: () => _bumpPitch(1, settings.pitchStepCents.toDouble()),
              onIconTap: () => openPracticeScreen(context),
              onDisabledTap: () {
                HapticFeedback.selectionClick();
                controller.setTempoMode(TempoMode.independent);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _bumpSpeed(int dir, double step) {
    var next = state.tempo.speed + step * dir;
    next = (next * 1000).round() / 1000;
    if ((next - 1.0).abs() < step * 0.4) next = 1.0;
    HapticFeedback.selectionClick();
    controller.setSpeed(next.clamp(0.5, 2.0), commit: true);
  }

  void _bumpPitch(int dir, double stepCents) {
    final next = (state.tempo.pitchCents + stepCents * dir).clamp(
      -200.0,
      200.0,
    );
    HapticFeedback.selectionClick();
    controller.setPitchCents(next.toDouble(), commit: true);
  }
}

/// `⊖ 아이콘 값 보조 ⊕` 한 벌. 속도와 피치가 같은 모양을 쓴다.
///
/// 알약 안을 `아이콘 | 값 | 보조값` 셋으로 나눈다. 가운데를 비워두면
/// 218px짜리 알약에 68px어치 글자만 든 꼴이 된다.
class _ValueStepper extends StatelessWidget {
  const _ValueStepper({
    required this.icon,
    required this.value,
    required this.aux,
    required this.changed,
    required this.onMinus,
    required this.onPlus,
    required this.onIconTap,
    this.enabled = true,
    this.onDisabledTap,
  });

  final IconData icon;
  final String value;

  /// 오른쪽 끝에 붙는 보조값. 배속의 퍼센트, 피치의 기준음.
  final String aux;

  /// 기본값에서 벗어나 있으면 값을 강조색으로 쓴다.
  final bool changed;

  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onIconTap;
  final bool enabled;

  /// 꺼져 있을 때 눌렀을 때. 왜 안 되는지 알 길이 없으면 고장으로 보인다.
  /// 피치는 연동 모드에서 잠기는데, 여기를 누르면 고정으로 바꿔준다.
  final VoidCallback? onDisabledTap;

  @override
  Widget build(BuildContext context) {
    final tone = CoverScope.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Row(
        children: [
          IgnorePointer(
            ignoring: !enabled,
            child: _CircleStep(icon: Icons.remove, onTap: onMinus),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: enabled ? onIconTap : onDisabledTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: AppSpace.tap,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: changed ? tone.accentTint : AppColors.paperHi,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Icon(icon, size: 16, color: AppColors.ink2),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: AppText.num.copyWith(
                          fontSize: 17,
                          color: changed ? tone.accentInk : AppColors.ink1,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        aux,
                        textAlign: TextAlign.right,
                        style: AppText.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IgnorePointer(
            ignoring: !enabled,
            child: _CircleStep(icon: Icons.add, onTap: onPlus),
          ),
        ],
      ),
    );
  }
}

class _CircleStep extends StatelessWidget {
  const _CircleStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoldRepeat(
      onTrigger: onTap,
      child: Container(
        width: AppSpace.tap,
        height: AppSpace.tap,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.paperHi,
        ),
        child: Icon(icon, size: 20, color: AppColors.ink1),
      ),
    );
  }
}

/// `[폴더] 이전 재생 다음 [재생목록]`.
class _Transport extends StatelessWidget {
  const _Transport({
    required this.state,
    required this.controller,
    required this.onPrevious,
    required this.onNext,
  });

  final PlayerState state;
  final PlayerController controller;

  /// 미끄러지는 방향을 화면이 정해야 해서 바깥에서 받는다.
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return TransportRow(
      playing: state.playing,
      onToggle: controller.togglePlay,
      onPrevious: onPrevious,
      onNext: onNext,
      // Capriccio가 폴더를 놓은 자리. 곡을 고르러 가는 길이다
      leading: RoundButton(
        onTap: () => openLibraryScreen(context),
        child: const Icon(
          Icons.folder_outlined,
          size: 20,
          color: AppColors.ink2,
        ),
      ),
      trailing: RoundButton(
        onTap: () => showQueueSheet(context),
        child: const Icon(Icons.queue_music, size: 20, color: AppColors.ink2),
      ),
    );
  }
}

/// 슬립 타이머.
void showSleepTimerSheet(BuildContext context) {
  const minutes = [5, 10, 15, 30, 45, 60, 90];

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheet) => _Sheet(
      child: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(sleepTimerProvider.notifier);
          final timer = ref.watch(sleepTimerProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              12,
              AppSpace.gutter,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: SheetHandle()),
                const SizedBox(height: 20),
                const Text('슬립 타이머', style: AppText.title),
                const SizedBox(height: 6),
                Text(
                  timer.isOn ? '${timer.label} 뒤에 멈춥니다' : '꺼져 있습니다',
                  style: AppText.sub,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in minutes)
                      _SheetPill(
                        label: '$m분',
                        onTap: () {
                          controller.start(Duration(minutes: m));
                          Navigator.pop(sheet);
                        },
                      ),
                    _SheetPill(
                      label: '이 곡까지',
                      on: timer.untilTrackEnd,
                      onTap: () {
                        controller.startUntilTrackEnd();
                        Navigator.pop(sheet);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (timer.isOn)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        controller.cancel();
                        Navigator.pop(sheet);
                      },
                      child: Text(
                        '타이머 끄기',
                        style: AppText.body.copyWith(color: AppColors.ink3),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _SheetPill extends StatelessWidget {
  const _SheetPill({required this.label, required this.onTap, this.on = false});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = CoverScope.of(context);
    return Material(
      color: on ? tone.accentTint : AppColors.paperLo,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: AppSpace.tap,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.body.copyWith(
              color: on ? tone.accentInk : AppColors.ink1,
            ),
          ),
        ),
      ),
    );
  }
}

/// 시트의 종이 껍데기. 위 모서리만 둥글다.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      child: SizedBox(
        height: height,
        child: PaperBackground(child: SafeArea(top: false, child: child)),
      ),
    );
  }
}

/// 재생 목록.
void showQueueSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(playerControllerProvider);
        final controller = ref.read(playerControllerProvider.notifier);
        final tone = CoverScope.of(context);
        return _Sheet(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 12),
              const SheetHandle(),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: Row(children: [Text('재생 목록', style: AppText.title)]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: state.queue.length,
                  itemBuilder: (context, i) {
                    final t = state.queue[i];
                    final now = i == state.index;
                    return PaperRow(
                      onTap: () {
                        controller.playIndex(i);
                        Navigator.pop(sheetContext);
                      },
                      children: [
                        Artwork(track: t, size: 46),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(
                                  color: now ? tone.accentInk : AppColors.ink1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.sub,
                              ),
                            ],
                          ),
                        ),
                        if (now)
                          ValuePill(
                            label: '${state.tempo.speed.toStringAsFixed(2)}×',
                            on: true,
                          )
                        else
                          Text(
                            formatDuration(
                              Duration(milliseconds: t.durationMs),
                            ),
                            style: AppText.num.copyWith(
                              fontSize: 12,
                              color: AppColors.ink3,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// 두 손가락 동작만 받는다.
///
/// 한 손가락은 안쪽의 ConfigurableGestureLayer가 설정대로 처리한다. 두 층을
/// 나눈 이유는 손가락 수를 세는 일과 설정을 읽는 일이 섞이면 어느 쪽이
/// 걸렸는지 따라가기 어려워서다.
class _GestureLayer extends StatefulWidget {
  const _GestureLayer({
    required this.child,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onTwoFingerDoubleTap,
  });

  final Widget child;
  final void Function(ScaleStartDetails) onScaleStart;
  final void Function(ScaleUpdateDetails, Offset delta) onScaleUpdate;
  final VoidCallback onScaleEnd;
  final VoidCallback onTwoFingerDoubleTap;

  @override
  State<_GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends State<_GestureLayer> {
  Offset _lastFocal = Offset.zero;
  int _pointers = 0;

  /// 한 번의 제스처 동안 동시에 닿았던 손가락의 최대 수.
  ///
  /// onScaleEnd 시점에는 이미 손을 뗐기 때문에 그때 세면 항상 0이다. 한 손가락
  /// 스와이프(곡 이동)와 두 손가락 조작(배속)을 가르려면 진행 중에 기록해둬야
  /// 한다.
  int _maxPointers = 0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        _pointers++;
        if (_pointers > _maxPointers) _maxPointers = _pointers;
      },
      onPointerUp: (_) => _pointers = (_pointers - 1).clamp(0, 10),
      onPointerCancel: (_) => _pointers = (_pointers - 1).clamp(0, 10),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // 한 손가락 두드림은 안쪽 층이 받는다. 여기서는 두 손가락만 본다.
        onDoubleTap: () {
          if (_maxPointers >= 2) widget.onTwoFingerDoubleTap();
          _maxPointers = 0;
        },
        onScaleStart: (d) {
          _lastFocal = d.focalPoint;
          _maxPointers = d.pointerCount;
          widget.onScaleStart(d);
        },
        onScaleUpdate: (d) {
          if (d.pointerCount > _maxPointers) _maxPointers = d.pointerCount;
          final delta = d.focalPoint - _lastFocal;
          _lastFocal = d.focalPoint;
          widget.onScaleUpdate(d, delta);
        },
        onScaleEnd: (d) {
          widget.onScaleEnd();
          _maxPointers = 0;
        },
        child: widget.child,
      ),
    );
  }
}
