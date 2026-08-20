// Flutter의 RepeatMode(애니메이션용)와 이름이 겹쳐서 가린다.
import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/player_controller.dart';
import '../data/models/gesture_settings.dart';
import '../data/models/app_settings.dart';
import '../data/models/tempo.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'spotify_player.dart';
import '../data/models/mark.dart';
import 'theme.dart';
import 'widgets/ambient_plate.dart';
import 'widgets/artwork.dart';
import 'widgets/artwork_tone.dart';
import 'widgets/common.dart';
import 'widgets/gesture_layer.dart';
import 'widgets/marquee_text.dart';
import 'widgets/paper.dart';
import 'widgets/player_parts.dart';
import 'widgets/surface.dart';
import 'widgets/value_unit.dart';

/// 재생 컨트롤 패널을 펼쳐 두었는지.
///
/// 열면 앨범아트 아래에 구간 반복, 점프 탐색, 속도, 피치가 한 줄씩 붙는다.
/// 화면을 옮기지 않고 그 자리에서 값을 바꾼다.
///
/// 기본은 접어둔다. 늘 펼쳐두면 피치와 구간 반복을 스치듯 눌러 잘못 걸리는
/// 일이 잦다. 앨범아트를 길게 누르거나 상단 바의 둥근 버튼으로 연다.
final controlPanelOpenProvider = StateProvider<bool>((ref) => false);

/// 패널 안에서 지금 보고 있는 탭. 0 속도, 1 구간, 2 마크.
///
/// 마크를 네 번째 줄로 넣으면 자켓이 또 준다. 대신 내용만 바꾼다.
final controlPanelTabProvider = StateProvider<int>((ref) => 0);

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
    // 곡이 바뀌면 패널을 닫는다.
    //
    // 열어둔 채로 넘어가면 새 곡이 자켓이 줄어든 상태로 나타나고, 패널에
    // 뜬 배속과 구간은 아직 앞 곡 것으로 보인다. 곡별로 값을 기억하므로
    // 실제로도 다른 값이다.
    //
    // 조건 없이 닫는다. 다음 곡으로 자동으로 넘어갈 때도 마찬가지다.
    // 어느 쪽이든 화면에 뜬 값이 방금까지 만지던 그 값이 아니게 된다.
    //
    // 빌드 도중에 프로바이더를 건드릴 수 없으므로 listen으로 받는다.
    // 이 호출은 조기 반환보다 앞에 있어야 매 빌드마다 같은 자리에 걸린다.
    ref.listen(playerControllerProvider.select((s) => s.current?.id), (
      before,
      after,
    ) {
      if (before == null || after == null || before == after) return;
      ref.read(controlPanelOpenProvider.notifier).state = false;
    });

    // Spotify 앱이 소리를 내는 동안에는 그쪽 화면을 보여준다. 우리 전송
    // 버튼으로 남의 프로세스를 조종할 수는 없다.
    final source = ref.watch(activeSourceProvider);
    final spotifyHasTrack = ref.watch(
      spotifySessionProvider.select((s) => s.hasTrack),
    );
    if (source == PlaybackSource.spotify && spotifyHasTrack) {
      return const SpotifyPlayerView();
    }

    // 재생 위치는 250ms마다 바뀐다. 여기서 상태를 통째로 보면 자켓과
    // 앰비언트 판까지 초당 네 번 다시 그린다. 위치가 필요한 조각만
    // 각자 보게 두고 이 빌드는 곡이 바뀔 때만 돈다.
    final controller = ref.read(playerControllerProvider.notifier);
    final track = ref.watch(playerControllerProvider.select((s) => s.current));
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
    final marks = ref.watch(marksProvider).value ?? const <Mark>[];

    return CoverScope(
      tone: tone,
      child: Scaffold(
        body: PaperBackground(
          child: SafeArea(
            bottom: false,
            child: _GestureLayer(
              onScaleStart: (details) {
                _twoFinger = false;
                final tempo = ref.read(playerControllerProvider).tempo;
                _dragSpeed = tempo.speed;
                _dragPitch = tempo.pitchCents;
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

                final tempo = ref.read(playerControllerProvider).tempo;
                controller.setTempo(
                  tempo.copyWith(
                    speed: snapped,
                    pitchCents: tempo.mode == TempoMode.independent
                        ? nextPitch.roundToDouble()
                        : tempo.pitchCents,
                  ),
                );
              },
              onScaleEnd: () {
                if (_twoFinger) {
                  HapticFeedback.selectionClick();
                  controller.setTempo(
                    ref.read(playerControllerProvider).tempo,
                    commit: true,
                  );
                }
                _twoFinger = false;
              },
              onTwoFingerDoubleTap: () {
                controller.setTempoMode(
                  ref.read(playerControllerProvider).tempo.mode ==
                          TempoMode.linked
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
                    const _TopBar(),
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
                    _TitleRow(controller: controller),
                    const SizedBox(height: 20),
                    _Progress(controller: controller, marks: marks),
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
                                  _ControlPanel(controller: controller),
                                ],
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Transport(
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
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 큐 자리만 본다. 레코드는 값으로 견주므로 곡이 바뀔 때만 다시 그린다.
    final (at, total) = ref.watch(
      playerControllerProvider.select((s) => (s.index, s.queue.length)),
    );
    final panelOpen = ref.watch(controlPanelOpenProvider);

    return PlayerTopBar(
      leading: QueuePill(at: total == 0 ? 0 : at + 1, total: total),
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
class _TitleRow extends ConsumerWidget {
  const _TitleRow({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playerControllerProvider.select((s) => s.current))!;
    final (speed, repeat, shuffle) = ref.watch(
      playerControllerProvider.select(
        (s) => (s.tempo.speed, s.repeat, s.shuffle),
      ),
    );
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
                    if (speed != 1.0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${speed.toStringAsFixed(2)}×',
                        style: AppText.num.copyWith(
                          fontSize: 12,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 제목 덩어리의 오른쪽 아래. 제목 줄을 비켜 있으면서도 이 곡에
              // 딸린 설정이라는 것이 읽힌다
              ToggleIcon(
                icon: switch (repeat) {
                  RepeatMode.one => Icons.repeat_one,
                  _ => Icons.repeat,
                },
                on: repeat != RepeatMode.off,
                onTap: controller.cycleRepeat,
              ),
              ToggleIcon(
                icon: Icons.shuffle,
                on: shuffle,
                onTap: controller.toggleShuffle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress({required this.controller, required this.marks});

  final PlayerController controller;
  final List<Mark> marks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 위치를 실제로 쓰는 자리라 250ms마다 다시 그린다. 진행바와 시간 줄
    // 둘뿐이라 바깥까지 끌고 가지 않는다.
    final state = ref.watch(playerControllerProvider);
    final total = state.duration.inMilliseconds;
    double at(Duration d) =>
        total <= 0 ? 0 : (d.inMilliseconds / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(
        children: [
          ThinProgressBar(
            ticks: [
              for (final m in marks)
                if (!m.isLoop) at(m.position),
            ],
            spans: [
              for (final m in marks)
                if (m.isLoop) (start: at(m.position), end: at(m.end!)),
            ],
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
  const _ControlPanel({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 구간과 마크가 지금 위치를 쓴다. 패널은 접힌 상태가 기본이라
    // 열려 있을 때만 이 빌드가 250ms마다 돈다.
    final state = ref.watch(playerControllerProvider);
    final settings = ref.watch(settingsProvider);
    final tempo = state.tempo;
    final tab = ref.watch(controlPanelTabProvider);
    final marks = ref.watch(marksProvider).value ?? const <Mark>[];
    final trackId = state.current?.id;

    final linked = tempo.mode == TempoMode.linked;
    final hasLoop = state.loopA != null || state.loopB != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Sunken(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueSegment(
              index: tab,
              onChanged: (i) {
                HapticFeedback.selectionClick();
                ref.read(controlPanelTabProvider.notifier).state = i;
              },
              items: [
                SegmentItem('속도', changed: !tempo.isNormal),
                SegmentItem('구간', changed: hasLoop),
                SegmentItem('마크', changed: marks.isNotEmpty),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: switch (tab) {
                1 => _loopUnits(state),
                2 => _markUnits(ref, state, trackId, marks),
                _ => _speedUnits(state, settings, linked),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 왼쪽이 템포, 오른쪽이 피치다. 한 값의 두 축이라 한 줄에 둔다.
  List<Widget> _speedUnits(
    PlayerState state,
    AppSettings settings,
    bool linked,
  ) {
    final tempo = state.tempo;
    return [
      ValueUnit(
        minus: '−',
        plus: '+',
        value: '${tempo.speed.toStringAsFixed(2)}×',
        label: linked ? '연동' : '고정',
        // 0.5~2.0 을 폭으로 본다
        position: ((tempo.speed - 0.5) / 1.5).clamp(0.0, 1.0),
        changed: tempo.speed != 1.0,
        onMinus: () => _bumpSpeed(tempo, -1, settings.speedStep),
        onPlus: () => _bumpSpeed(tempo, 1, settings.speedStep),
        onTap: () {
          HapticFeedback.selectionClick();
          controller.setTempoMode(
            linked ? TempoMode.independent : TempoMode.linked,
          );
        },
      ),
      const SizedBox(width: 10),
      ValueUnit(
        // 피치는 -/+ 가 아니라 내림표와 올림표다
        minus: '♭',
        plus: '♯',
        value: tempo.pitchCents.toStringAsFixed(1),
        label: linked ? '고정으로' : '센트',
        position: ((tempo.pitchCents + 200) / 400).clamp(0.0, 1.0),
        changed: tempo.pitchCents != 0,
        onMinus: linked
            ? null
            : () => _bumpPitch(tempo, -1, settings.pitchStepCents.toDouble()),
        onPlus: linked
            ? null
            : () => _bumpPitch(tempo, 1, settings.pitchStepCents.toDouble()),
        onTap: () {
          HapticFeedback.selectionClick();
          if (linked) controller.setTempoMode(TempoMode.independent);
        },
      ),
    ];
  }

  List<Widget> _loopUnits(PlayerState state) {
    final total = state.duration.inMilliseconds;
    double at(Duration? d) =>
        (d == null || total <= 0) ? 0 : (d.inMilliseconds / total);
    return [
      ValueUnit(
        minus: '−',
        plus: '+',
        value: state.loopA == null ? '—' : formatDuration(state.loopA!),
        label: 'A',
        position: at(state.loopA),
        changed: state.loopA != null,
        onMinus: () => controller.setLoopA(
          (state.loopA ?? state.position) - const Duration(milliseconds: 250),
        ),
        onPlus: () => controller.setLoopA(
          (state.loopA ?? state.position) + const Duration(milliseconds: 250),
        ),
        onTap: controller.setLoopA,
      ),
      const SizedBox(width: 10),
      ValueUnit(
        minus: '−',
        plus: '+',
        value: state.loopB == null ? '—' : formatDuration(state.loopB!),
        label: 'B',
        position: at(state.loopB),
        changed: state.loopB != null,
        onMinus: () => controller.setLoopB(
          (state.loopB ?? state.position) - const Duration(milliseconds: 250),
        ),
        onPlus: () => controller.setLoopB(
          (state.loopB ?? state.position) + const Duration(milliseconds: 250),
        ),
        onTap: controller.setLoopB,
      ),
    ];
  }

  /// 이전 마크 · 여기에 찍기 · 다음 마크. 스테퍼의 양끝 자리를 이동이 쓴다.
  List<Widget> _markUnits(
    WidgetRef ref,
    PlayerState state,
    int? trackId,
    List<Mark> marks,
  ) {
    final repo = ref.read(markRepositoryProvider);
    final at = state.position;
    Mark? before;
    Mark? after;
    for (final m in marks) {
      if (m.position < at - const Duration(milliseconds: 400)) before = m;
      if (after == null &&
          m.position > at + const Duration(milliseconds: 400)) {
        after = m;
      }
    }
    return [
      SquareIconButton(
        icon: Icons.first_page,
        onTap: before == null ? null : () => controller.seek(before!.position),
      ),
      const SizedBox(width: 3),
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: trackId == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  repo.add(trackId, at);
                },
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_add_outlined,
                  size: 17,
                  color: AppColors.ink2,
                ),
                Expanded(
                  child: Text(
                    '여기에 찍기',
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(
                      fontSize: 15,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                Text(
                  formatDuration(at),
                  style: AppText.num.copyWith(
                    fontSize: 12,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 3),
      SquareIconButton(
        icon: Icons.last_page,
        onTap: after == null ? null : () => controller.seek(after!.position),
      ),
    ];
  }

  void _bumpSpeed(TempoSettings tempo, int dir, double step) {
    var next = tempo.speed + step * dir;
    next = (next * 1000).round() / 1000;
    if ((next - 1.0).abs() < step * 0.4) next = 1.0;
    HapticFeedback.selectionClick();
    controller.setSpeed(next.clamp(0.5, 2.0), commit: true);
  }

  void _bumpPitch(TempoSettings tempo, int dir, double stepCents) {
    final next = (tempo.pitchCents + stepCents * dir).clamp(-200.0, 200.0);
    HapticFeedback.selectionClick();
    controller.setPitchCents(next.toDouble(), commit: true);
  }
}

/// `[폴더] 이전 재생 다음 [재생목록]`.
class _Transport extends ConsumerWidget {
  const _Transport({
    required this.controller,
    required this.onPrevious,
    required this.onNext,
  });

  final PlayerController controller;

  /// 미끄러지는 방향을 화면이 정해야 해서 바깥에서 받는다.
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TransportRow(
      playing: ref.watch(playerControllerProvider.select((s) => s.playing)),
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
    return Material(
      color: on ? AppColors.accentTint : AppColors.paperLo,
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
              color: on ? AppColors.accent : AppColors.ink1,
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
                                  color: now
                                      ? AppColors.accent
                                      : AppColors.ink1,
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
