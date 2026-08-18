// Flutter의 RepeatMode(애니메이션용)와 이름이 겹쳐서 가린다.
import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/player_controller.dart';
import '../data/models/tempo.dart';
import '../providers.dart';
import 'effects_screen.dart';
import 'home_shell.dart';
import 'practice_screen.dart';
import 'spotify_player.dart';
import 'theme.dart';
import 'widgets/artwork.dart';
import 'widgets/artwork_tone.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';
import 'widgets/practice_blocks.dart';
import 'widgets/sound_quick_panel.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // 제스처 중 임시로 쌓는 값. 손을 뗄 때 한 번만 저장한다.
  double? _dragSpeed;
  double? _dragPitch;
  bool _twoFinger = false;

  /// 지금 펼쳐진 패널. null이면 접혀 있다.
  ///
  /// 값을 바꾸러 다른 화면으로 옮겨가지 않는다. 앨범아트가 줄어들 뿐 곡과
  /// 진행바와 전송 버튼은 그대로 남는다.
  _Panel? _panel;

  void _toggle(_Panel p) => setState(() => _panel = _panel == p ? null : p);

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

    if (track == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Center(
            child: EmptyHint(
              icon: Icons.music_note,
              title: '재생 중인 곡이 없습니다',
              body: '라이브러리 탭에서 곡을 고르세요',
              action: AccentButton(
                label: '라이브러리로',
                onPressed: () =>
                    ref.read(shellTabProvider.notifier).state = 1,
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
              onSwipeLeft: controller.next,
              onSwipeRight: controller.previous,
              onDoubleTap: controller.togglePlay,
              onTwoFingerDoubleTap: () {
                controller.setTempoMode(
                  state.tempo.mode == TempoMode.linked
                      ? TempoMode.independent
                      : TempoMode.linked,
                );
                HapticFeedback.mediumImpact();
              },
              child: Column(
                children: [
                  _TopBar(state: state, tone: tone),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size =
                            math.min(box.maxWidth - 56, box.maxHeight - 8);
                        // 패널을 펼치면 자리가 좁아진다. 억지로 밀어 넣지
                        // 않고 접는다.
                        if (size < 96) return const SizedBox.shrink();
                        return Center(
                          child: Artwork(
                            track: track,
                            size: size,
                            radius: 20,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TitleRow(state: state, controller: controller),
                  const SizedBox(height: 12),
                  _Progress(state: state, controller: controller),
                  const SizedBox(height: 10),
                  _PanelTabs(
                    state: state,
                    tone: tone,
                    open: _panel,
                    onToggle: _toggle,
                  ),
                  _InlinePanel(
                    panel: _panel,
                    state: state,
                    controller: controller,
                    tone: tone,
                  ),
                  const SizedBox(height: 12),
                  _Transport(state: state, controller: controller, tone: tone),
                  SizedBox(height: bottomInset + 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 큐 위치와 재생 목록.
///
/// Capriccio처럼 왼쪽에 `3 / 27`을 두고 그 아래에 진행 밑줄을 그린다. 곡의
/// 진행이 아니라 큐 안에서의 위치다.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state, required this.tone});

  final PlayerState state;
  final ArtworkTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = state.queue.length;
    final at = total == 0 ? 0 : state.index + 1;

    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$at / $total',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.t2,
                    fontFeatures: tabularFigures,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  height: 2,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: total == 0 ? 0 : at / total,
                    child: Container(color: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            _RoundIcon(
              icon: Icons.queue_music,
              tone: tone,
              onTap: () => showQueueSheet(context),
            ),
            const SizedBox(width: 8),
            _RoundIcon(
              icon: Icons.speed,
              tone: tone,
              onTap: () => openPracticeScreen(context),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 22, color: AppColors.t2),
              onPressed: () => showMoreSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상단 바의 `⋮`. 자주 쓰지 않지만 어딘가에는 있어야 하는 것들.
void showMoreSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF14141C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final timer = ref.watch(sleepTimerProvider);
          final settings = ref.watch(settingsProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const SheetHandle(),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.bedtime_outlined,
                  color: timer.isOn ? AppColors.accent : AppColors.t2,
                ),
                title: const Text('슬립 타이머', style: AppText.body),
                trailing: Text(
                  timer.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: timer.isOn ? AppColors.accent : AppColors.t3,
                    fontFeatures: tabularFigures,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  showSleepTimerSheet(context);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.brightness_high_outlined,
                    color: AppColors.t2),
                title: const Text('화면 꺼짐 방지', style: AppText.body),
                subtitle: const Text('가사를 보거나 연주를 따라갈 때',
                    style: AppText.small),
                activeThumbColor: AppColors.accent,
                value: settings.keepScreenOn,
                onChanged: ref.read(settingsProvider.notifier).setKeepScreenOn,
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    ),
  );
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
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              switch (state.repeat) {
                RepeatMode.one => Icons.repeat_one,
                _ => Icons.repeat,
              },
              size: 20,
              color:
                  state.repeat == RepeatMode.off ? AppColors.t3 : AppColors.accent,
            ),
            onPressed: controller.cycleRepeat,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.shuffle,
              size: 20,
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
          const SizedBox(height: 2),
          Row(
            children: [
              Text(formatDuration(state.position), style: AppText.mono),
              const Spacer(),
              // Capriccio처럼 오른쪽에 곡 전체 길이를 둔다.
              Text(formatDuration(state.totalWallClock), style: AppText.mono),
            ],
          ),
        ],
      ),
    );
  }
}

/// 진행바 아래에서 펼쳐지는 패널의 종류.
enum _Panel { speed, pitch, loop, sound }

/// 값을 바꾸는 자리로 들어가는 칩 네 개.
///
/// 누르면 화면을 옮기지 않고 바로 아래가 펼쳐진다. 칩 자체가 지금 값을
/// 보여주므로 접힌 상태에서도 무엇이 걸려 있는지 읽을 수 있다.
class _PanelTabs extends StatelessWidget {
  const _PanelTabs({
    required this.state,
    required this.tone,
    required this.open,
    required this.onToggle,
  });

  final PlayerState state;
  final ArtworkTone tone;
  final _Panel? open;
  final ValueChanged<_Panel> onToggle;

  @override
  Widget build(BuildContext context) {
    final tempo = state.tempo;
    final looping = state.loopA != null || state.loopB != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _TabChip(
              tone: tone,
              open: open == _Panel.speed,
              marked: tempo.speed != 1.0,
              onTap: () => onToggle(_Panel.speed),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${tempo.speed.toStringAsFixed(2)}×',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tempo.speed == 1.0
                          ? AppColors.t1
                          : AppColors.accent,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    tempo.mode == TempoMode.linked
                        ? Icons.link
                        : Icons.lock_outline,
                    size: 12,
                    color: AppColors.t3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 3,
            child: _TabChip(
              tone: tone,
              open: open == _Panel.pitch,
              marked: tempo.pitchCents != 0,
              onTap: () => onToggle(_Panel.pitch),
              child: Text(
                '${tempo.pitchCents > 0 ? '+' : ''}'
                '${tempo.pitchCents.toStringAsFixed(0)}¢',
                style: TextStyle(
                  fontSize: 13,
                  color: tempo.pitchCents == 0
                      ? AppColors.t1
                      : AppColors.accent,
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 3,
            child: _TabChip(
              tone: tone,
              open: open == _Panel.loop,
              marked: looping,
              onTap: () => onToggle(_Panel.loop),
              child: Text(
                'A–B',
                style: TextStyle(
                  fontSize: 13,
                  color: looping ? AppColors.accent : AppColors.t1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 3,
            child: _TabChip(
              tone: tone,
              open: open == _Panel.sound,
              marked: false,
              onTap: () => onToggle(_Panel.sound),
              child: const Icon(Icons.tune, size: 17, color: AppColors.t1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.child,
    required this.tone,
    required this.open,
    required this.marked,
    required this.onTap,
  });

  final Widget child;
  final ArtworkTone tone;

  /// 이 칩의 패널이 펼쳐져 있는지.
  final bool open;

  /// 값이 기본에서 벗어나 있는지.
  final bool marked;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = open || marked;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: open
              ? AppColors.accent.withValues(alpha: 0.22)
              : (marked
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: tone.glassOpacity)),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: highlight
                ? AppColors.accent.withValues(alpha: open ? 0.6 : 0.4)
                : Colors.white.withValues(alpha: tone.borderBoost),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// 칩 바로 아래에서 펼쳐지는 실제 컨트롤.
class _InlinePanel extends ConsumerWidget {
  const _InlinePanel({
    required this.panel,
    required this.state,
    required this.controller,
    required this.tone,
  });

  final _Panel? panel;
  final PlayerState state;
  final PlayerController controller;
  final ArtworkTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: panel == null
          ? const SizedBox(width: double.infinity, height: 0)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: tone.glassOpacity + 0.02),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: _body(context, ref),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => panel == _Panel.sound
                            ? openEffectsScreen(context)
                            : openPracticeScreen(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '자세히',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final tempo = state.tempo;

    switch (panel!) {
      case _Panel.speed:
        return Column(
          children: [
            Center(
              child: GlassSegment(
                labels: [
                  TempoMode.linked.label,
                  TempoMode.independent.label,
                ],
                selectedIndex: tempo.mode == TempoMode.linked ? 0 : 1,
                onSelect: (i) => controller.setTempoMode(
                  i == 0 ? TempoMode.linked : TempoMode.independent,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SpeedBlock(
              tempo: tempo,
              settings: settings,
              controller: controller,
              onRangeChange: (r) =>
                  ref.read(settingsProvider.notifier).setSpeedRange(r),
            ),
          ],
        );
      case _Panel.pitch:
        return PitchBlock(
          tempo: tempo,
          settings: settings,
          controller: controller,
        );
      case _Panel.loop:
        return Column(
          children: [
            LoopBlock(state: state, controller: controller),
            const SizedBox(height: 12),
            JumpRow(settings: settings, controller: controller),
          ],
        );
      case _Panel.sound:
        return const SoundQuickPanel();
    }
  }
}

/// 전송 행.
///
/// 값을 바꾸는 버튼은 위 칩으로 올라갔다. 여기는 곡을 넘기고 멈추는 일만
/// 한다. 패널을 펼쳐도 이 줄은 그대로 남는다.
class _Transport extends StatelessWidget {
  const _Transport({
    required this.state,
    required this.controller,
    required this.tone,
  });

  final PlayerState state;
  final PlayerController controller;
  final ArtworkTone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Capriccio가 폴더를 놓은 자리. 곡을 고르러 가는 길이다.
          Consumer(
            builder: (context, ref, _) => _RoundIcon(
              icon: Icons.folder_outlined,
              tone: tone,
              onTap: () => ref.read(shellTabProvider.notifier).state = 1,
            ),
          ),
          IconButton(
            iconSize: 30,
            icon: const Icon(Icons.skip_previous, color: AppColors.t1),
            onPressed: controller.previous,
          ),
          GlassSurface(
            radius: 34,
            width: 68,
            height: 68,
            opacity: tone.glassOpacity + 0.04,
            onTap: controller.togglePlay,
            child: Icon(
              state.playing ? Icons.pause : Icons.play_arrow,
              size: 30,
              color: AppColors.t1,
            ),
          ),
          IconButton(
            iconSize: 30,
            icon: const Icon(Icons.skip_next, color: AppColors.t1),
            onPressed: controller.next,
          ),
          _RoundIcon(
            icon: Icons.tune,
            tone: tone,
            onTap: () => openEffectsScreen(context),
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
  });

  final IconData icon;
  final ArtworkTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: tone.glassOpacity),
          border: Border.all(
            color: Colors.white.withValues(alpha: tone.borderBoost),
          ),
        ),
        child: Icon(icon, size: 20, color: AppColors.t1),
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
                        controller.playQueue(state.queue, i);
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

/// 제스처를 한 곳에서 받는다.
///
/// 두 손가락 동작(배속·피치)과 한 손가락 동작(곡 이동)을 구분해야 해서
/// ScaleGestureRecognizer의 pointerCount를 본다.
class _GestureLayer extends StatefulWidget {
  const _GestureLayer({
    required this.child,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onDoubleTap,
    required this.onTwoFingerDoubleTap,
  });

  final Widget child;
  final void Function(ScaleStartDetails) onScaleStart;
  final void Function(ScaleUpdateDetails, Offset delta) onScaleUpdate;
  final VoidCallback onScaleEnd;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onDoubleTap;
  final VoidCallback onTwoFingerDoubleTap;

  @override
  State<_GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends State<_GestureLayer> {
  Offset _lastFocal = Offset.zero;
  Offset _startFocal = Offset.zero;
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
        onDoubleTap: () {
          if (_maxPointers >= 2) {
            widget.onTwoFingerDoubleTap();
          } else {
            widget.onDoubleTap();
          }
          _maxPointers = 0;
        },
        onScaleStart: (d) {
          _lastFocal = d.focalPoint;
          _startFocal = d.focalPoint;
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
          final total = _lastFocal - _startFocal;
          // 한 손가락으로 가로로 크게 쓸면 곡을 넘긴다. 두 손가락이었다면
          // 배속 조작이므로 곡을 넘기지 않는다.
          if (_maxPointers <= 1 &&
              total.dx.abs() > 80 &&
              total.dx.abs() > total.dy.abs() * 2) {
            if (total.dx < 0) {
              widget.onSwipeLeft();
            } else {
              widget.onSwipeRight();
            }
          }
          widget.onScaleEnd();
          _maxPointers = 0;
        },
        child: widget.child,
      ),
    );
  }
}
