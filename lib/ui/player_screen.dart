// Flutter의 RepeatMode(애니메이션용)와 이름이 겹쳐서 가린다.
import 'dart:async';
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
import 'widgets/artwork.dart';
import 'widgets/artwork_tone.dart';
import 'widgets/common.dart';
import 'widgets/gesture_layer.dart';
import 'widgets/glass.dart';

/// 재생 컨트롤 패널을 펼쳐 두었는지.
///
/// 열면 앨범아트 아래에 구간 반복, 점프 탐색, 속도, 피치가 한 줄씩 붙는다.
/// 화면을 옮기지 않고 그 자리에서 값을 바꾼다.
///
/// 기본은 접어둔다. 늘 펼쳐두면 앨범아트가 작아지고, 무엇보다 피치와 구간
/// 반복을 스치듯 눌러 잘못 걸리는 일이 잦다. 앨범아트를 길게 누르거나 상단
/// 바의 둥근 버튼으로 연다.
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
    final spotifyHasTrack =
        ref.watch(spotifySessionProvider.select((s) => s.hasTrack));
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
        backgroundColor: AppColors.bgBase,
        body: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Center(
            child: EmptyHint(
              icon: Icons.music_note,
              title: '재생 중인 곡이 없습니다',
              body: '아래 폴더 버튼으로 곡을 고르세요',
              action: AccentButton(
                label: '라이브러리로',
                onPressed: () => openLibraryScreen(context),
              ),
            ),
          ),
        ),
      );
    }

    // 밝은 앨범아트 위에서는 덮개를 진하게, 유리를 두껍게 해야 글자가 읽힌다.
    final tone = ref.watch(artworkToneProvider(artworkPathOf(track))).value ??
        ArtworkTone.dark;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          BlurredBackdrop(
            track: track,
            topOverlay: tone.topOverlay,
            bottomOverlay: tone.bottomOverlay,
          ),
          SafeArea(
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
                final next =
                    ((_dragSpeed ?? 1.0) + speedStep).clamp(0.5, 2.0);
                _dragSpeed = next;

                // 두 손가락 가로: 피치(센트).
                final pitchStep = delta.dx * 0.35;
                final nextPitch =
                    ((_dragPitch ?? 0) + pitchStep).clamp(-200.0, 200.0);
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
                settings: ref.watch(
                  settingsProvider.select((s) => s.gestures),
                ),
                onAction: _run,
                onDrag: _drag,
                child: Column(
                children: [
                  _TopBar(state: state, tone: tone),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size =
                            math.min(box.maxWidth - 40, box.maxHeight - 8);
                        if (size < 96) return const SizedBox.shrink();
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // 곡이 바뀌면 옆으로 미끄러진다. 쓸어 넘긴
                            // 방향과 같은 쪽으로 나가야 손짓과 화면이
                            // 맞물린다.
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final incoming =
                                    (child.key as ValueKey<int>?)?.value ==
                                        track.id;
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
                              child: Artwork(
                                key: ValueKey<int>(track.id),
                                track: track,
                                size: size,
                                radius: 20,
                              ),
                            ),
                            // 컨트롤은 앨범아트 위에 얹는다. 아래로 밀어내면
                            // 자켓이 작아진다. 자켓이 제스쳐를 받는 자리이자
                            // 이 화면에서 볼 것이라 크기를 지킨다.
                            if (panelOpen)
                              Positioned(
                                left: 4,
                                right: 4,
                                bottom: 4,
                                child: _ControlPanel(
                                  state: state,
                                  controller: controller,
                                  tone: tone,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TitleRow(state: state, controller: controller),
                  const SizedBox(height: 12),
                  _Progress(state: state, controller: controller),
                  const SizedBox(height: 16),
                  _Transport(
                    state: state,
                    controller: controller,
                    tone: tone,
                    onPrevious: () {
                      _slideDir = -1;
                      controller.previous();
                    },
                    onNext: () {
                      _slideDir = 1;
                      controller.next();
                    },
                  ),
                  SizedBox(height: bottomInset + 8),
                ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 큐 위치, 재생 목록, 컨트롤 패널 토글, 더보기.
///
/// Capriccio는 왼쪽에 `1 / 1`을 알약 안에 넣고 그 아래에 진행 밑줄을 그린다.
/// 곡의 진행이 아니라 큐 안에서의 위치다. 그 옆 둥근 버튼 둘이 재생 목록과
/// 재생 컨트롤 패널이고, 오른쪽 끝이 더보기다.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state, required this.tone});

  final PlayerState state;
  final ArtworkTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = state.queue.length;
    final at = total == 0 ? 0 : state.index + 1;
    final panelOpen = ref.watch(controlPanelOpenProvider);

    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$at / $total',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.t1,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 3,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: total == 0 ? 0 : at / total,
                        child: Container(color: AppColors.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RoundIcon(
              icon: Icons.compare_arrows,
              tone: tone,
              filled: panelOpen,
              onTap: () => ref
                  .read(controlPanelOpenProvider.notifier)
                  .state = !panelOpen,
            ),
            const Spacer(),
            // 자주 쓰지 않는 것은 위로 올린다. 아래쪽은 재생 조작 몫이다.
            _RoundIcon(
              icon: Icons.search,
              tone: tone,
              onTap: () => openSearchScreen(context),
            ),
            const SizedBox(width: 8),
            _RoundIcon(
              icon: Icons.settings,
              tone: tone,
              onTap: () => openSettingsScreen(context),
            ),
          ],
        ),
      ),
    );
  }
}

void showSleepTimerSheet(BuildContext context) {
  const minutes = [5, 10, 15, 30, 45, 60, 90];

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF14141C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(sleepTimerProvider.notifier);
          final timer = ref.watch(sleepTimerProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: SheetHandle()),
                const SizedBox(height: 16),
                const Text('슬립 타이머', style: AppText.display),
                const SizedBox(height: 4),
                Text(
                  timer.isOn ? '${timer.label} 뒤에 멈춥니다' : '꺼져 있습니다',
                  style: AppText.small,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in minutes)
                      GlassPill(
                        selected: false,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        onTap: () {
                          controller.start(Duration(minutes: m));
                          Navigator.pop(sheet);
                        },
                        child: Text('$m분',
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.t1)),
                      ),
                    GlassPill(
                      selected: timer.untilTrackEnd,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      onTap: () {
                        controller.startUntilTrackEnd();
                        Navigator.pop(sheet);
                      },
                      child: const Text('이 곡까지',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.t1)),
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
                      child: const Text('타이머 끄기',
                          style: TextStyle(color: AppColors.t2)),
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

/// 제목과 아티스트. 아티스트 줄은 링크색으로 쓰고 앨범을 함께 적는다.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.state, required this.controller});

  final PlayerState state;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final track = state.current!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display,
                ),
                const SizedBox(height: 4),
                Text(
                  // 태그가 부실한 파일은 앨범에 아티스트가 그대로 들어 있다.
                  // 같은 글자를 두 번 쓰지 않는다.
                  (track.album.isEmpty || track.album == track.artist)
                      ? track.artist
                      : '${track.artist} - ${track.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 20 / 15,
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
            icon: Icon(
              switch (state.repeat) {
                RepeatMode.one => Icons.repeat_one,
                _ => Icons.repeat,
              },
              size: 24,
              color: state.repeat == RepeatMode.off
                  ? AppColors.t3
                  : AppColors.accent,
            ),
            onPressed: controller.cycleRepeat,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.shuffle,
              size: 24,
              color: state.shuffle ? AppColors.accent : AppColors.t3,
            ),
            onPressed: controller.toggleShuffle,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
          const SizedBox(height: 4),
          Row(
            children: [
              // 지난 시간은 링크색, 전체 길이는 흰색.
              Text(
                formatDuration(state.position),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  fontFeatures: tabularFigures,
                ),
              ),
              const Spacer(),
              Text(
                formatDuration(state.totalWallClock),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.t1,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 앨범아트 아래에 붙는 재생 컨트롤 패널.
///
/// 위 줄은 점프 탐색과 구간 반복, 아래 줄은 속도와 피치다. 값을 바꾸러
/// 다른 화면으로 가지 않는다. 상단 바의 둥근 버튼으로 여닫는다.
class _ControlPanel extends ConsumerWidget {
  const _ControlPanel({
    required this.state,
    required this.controller,
    required this.tone,
  });

  final PlayerState state;
  final PlayerController controller;
  final ArtworkTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final tempo = state.tempo;
    final looping = state.loopA != null || state.loopB != null;
    final short = settings.seekShortSeconds;
    final long = settings.seekLongSeconds;

    // 자켓 위에 얹으므로 유리로 만든다. 뒤에 볼 것이 있어야 블러가 성립하고,
    // 밝은 자켓에서도 글자가 읽힌다.
    return GlassSurface(
      radius: AppRadius.panel,
      blur: AppBlur.sheet,
      opacity: tone.glassOpacity + 0.10,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _JumpButton(
                seconds: long,
                back: true,
                onTap: () => controller.seekBy(Duration(seconds: -long)),
              ),
              _JumpButton(
                seconds: short,
                back: true,
                onTap: () => controller.seekBy(Duration(seconds: -short)),
              ),
              _AbButton(
                state: state,
                controller: controller,
                active: looping,
              ),
              _JumpButton(
                seconds: short,
                back: false,
                onTap: () => controller.seekBy(Duration(seconds: short)),
              ),
              _JumpButton(
                seconds: long,
                back: false,
                onTap: () => controller.seekBy(Duration(seconds: long)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: tone.borderBoost),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _ValueStepper(
                    icon: tempo.mode == TempoMode.linked
                        ? Icons.speed
                        : Icons.lock_outline,
                    label: '${tempo.speed.toStringAsFixed(2)}x',
                    changed: tempo.speed != 1.0,
                    onMinus: () => _bumpSpeed(-1, settings.speedStep),
                    onPlus: () => _bumpSpeed(1, settings.speedStep),
                    // 아이콘을 누르면 연동과 고정이 바뀐다.
                    onIconTap: () {
                      HapticFeedback.selectionClick();
                      controller.setTempoMode(
                        tempo.mode == TempoMode.linked
                            ? TempoMode.independent
                            : TempoMode.linked,
                      );
                    },
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: Colors.white.withValues(alpha: tone.borderBoost),
                ),
                Expanded(
                  child: _ValueStepper(
                    icon: Icons.piano,
                    label: '${tempo.pitchCents >= 0 ? '+' : ''}'
                        '${(tempo.pitchCents / 100).toStringAsFixed(2)}',
                    changed: tempo.pitchCents != 0,
                    enabled: tempo.mode == TempoMode.independent,
                    onMinus: () =>
                        _bumpPitch(-1, settings.pitchStepCents.toDouble()),
                    onPlus: () =>
                        _bumpPitch(1, settings.pitchStepCents.toDouble()),
                    onIconTap: () => openPracticeScreen(context),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final next = (state.tempo.pitchCents + stepCents * dir).clamp(-200.0, 200.0);
    HapticFeedback.selectionClick();
    controller.setPitchCents(next.toDouble(), commit: true);
  }
}

/// 점프 탐색 버튼. 둥근 테두리 안에 화살표, 옆에 초.
class _JumpButton extends StatelessWidget {
  const _JumpButton({
    required this.seconds,
    required this.back,
    required this.onTap,
  });

  final int seconds;
  final bool back;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Icon(
        back
            ? (seconds >= 10 ? Icons.keyboard_double_arrow_left
                : Icons.keyboard_arrow_left)
            : (seconds >= 10 ? Icons.keyboard_double_arrow_right
                : Icons.keyboard_arrow_right),
        size: 20,
        color: AppColors.t1,
      ),
    );
    final text = Text(
      '$seconds"',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.t1,
        fontFeatures: tabularFigures,
      ),
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: back
            ? [circle, const SizedBox(width: 4), text]
            : [text, const SizedBox(width: 4), circle],
      ),
    );
  }
}

/// 구간 반복. 한 번 누르면 A, 다시 누르면 B, 길게 누르면 해제.
class _AbButton extends StatelessWidget {
  const _AbButton({
    required this.state,
    required this.controller,
    required this.active,
  });

  final PlayerState state;
  final PlayerController controller;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (state.loopA == null) {
          controller.setLoopA();
        } else if (state.loopB == null) {
          controller.setLoopB();
        } else {
          controller.clearLoop();
        }
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        controller.clearLoop();
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          switch ((state.loopA, state.loopB)) {
            (null, _) => 'A - B',
            (final a?, null) => 'A ${formatDuration(a)}',
            (final a?, final b?) =>
              '${formatDuration(a)} - ${formatDuration(b)}',
          },
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.bgBase : AppColors.t1,
            fontFeatures: tabularFigures,
          ),
        ),
      ),
    );
  }
}

/// `⊖ 아이콘 값 ⊕` 한 벌. 속도와 피치가 같은 모양을 쓴다.
class _ValueStepper extends StatelessWidget {
  const _ValueStepper({
    required this.icon,
    required this.label,
    required this.changed,
    required this.onMinus,
    required this.onPlus,
    required this.onIconTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;

  /// 기본값에서 벗어나 있으면 값을 accent로 쓴다.
  final bool changed;

  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onIconTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CircleStep(icon: Icons.remove, onTap: onMinus),
            GestureDetector(
              onTap: onIconTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: AppColors.t2),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: changed ? AppColors.accent : AppColors.t1,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            _CircleStep(icon: Icons.add, onTap: onPlus),
          ],
        ),
      ),
    );
  }
}

class _CircleStep extends StatefulWidget {
  const _CircleStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_CircleStep> createState() => _CircleStepState();
}

class _CircleStepState extends State<_CircleStep> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  /// 길게 누르면 계속 움직인다. 0.05씩 열 번 눌러야 하는 일을 막는다.
  void _down() {
    widget.onTap();
    _repeat?.cancel();
    _repeat = Timer(const Duration(milliseconds: 420), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 80),
        (_) => widget.onTap(),
      );
    });
  }

  void _up() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Icon(widget.icon, size: 19, color: AppColors.t1),
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.state,
    required this.controller,
    required this.tone,
    required this.onPrevious,
    required this.onNext,
  });

  final PlayerState state;
  final PlayerController controller;
  final ArtworkTone tone;

  /// 미끄러지는 방향을 화면이 정해야 해서 바깥에서 받는다.
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Capriccio가 폴더를 놓은 자리. 곡을 고르러 가는 길이다.
          _RoundIcon(
            icon: Icons.folder_outlined,
            tone: tone,
            filled: true,
            onTap: () => openLibraryScreen(context),
          ),
          IconButton(
            iconSize: 30,
            icon: const Icon(Icons.skip_previous, color: AppColors.t1),
            onPressed: onPrevious,
          ),
          // 카드가 이미 유리라 여기서 또 블러를 겹치지 않는다. 한 화면에
          // 유리는 두 겹까지다.
          GestureDetector(
            onTap: controller.togglePlay,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white
                    .withValues(alpha: tone.glassOpacity + 0.06),
                border: Border.all(
                  color: Colors.white.withValues(alpha: tone.borderBoost),
                ),
              ),
              child: Icon(
                state.playing ? Icons.pause : Icons.play_arrow,
                size: 30,
                color: AppColors.t1,
              ),
            ),
          ),
          IconButton(
            iconSize: 30,
            icon: const Icon(Icons.skip_next, color: AppColors.t1),
            onPressed: onNext,
          ),
          // 음향은 설정으로 옮겼다. 이 자리는 재생 목록이 쓴다.
          _RoundIcon(
            icon: Icons.queue_music,
            tone: tone,
            filled: true,
            onTap: () => showQueueSheet(context),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tone,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final ArtworkTone tone;
  final VoidCallback onTap;

  /// 켜진 상태를 accent로 채워 보여준다.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? AppColors.accent
              : Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: filled
                ? AppColors.accent
                : Colors.white.withValues(alpha: tone.borderBoost),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: filled ? AppColors.bgBase : AppColors.t1,
        ),
      ),
    );
  }
}

/// 재생 목록.
void showQueueSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF14141C),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(playerControllerProvider);
        final controller = ref.read(playerControllerProvider.notifier);
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 12),
              const SheetHandle(),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('재생 목록', style: AppText.display),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: state.queue.length,
                  itemBuilder: (context, i) {
                    final t = state.queue[i];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      leading: Artwork(track: t, size: 40),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color:
                              i == state.index ? AppColors.accent : AppColors.t1,
                        ),
                      ),
                      subtitle: Text(t.artist, style: AppText.caption),
                      onTap: () {
                        controller.playIndex(i);
                        Navigator.pop(sheetContext);
                      },
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
