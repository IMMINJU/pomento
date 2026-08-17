// Flutter의 RepeatMode(애니메이션용)와 이름이 겹쳐서 가린다.
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/player_controller.dart';
import '../data/models/tempo.dart';
import '../providers.dart';
import 'effects_sheet.dart';
import 'speed_sheet.dart';
import 'theme.dart';
import 'widgets/artwork.dart';
import 'widgets/artwork_tone.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final effects = ref.watch(effectControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = state.current;

    if (track == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: Text('재생 중인 곡이 없습니다', style: AppText.caption),
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
                    ((_dragSpeed ?? 1.0) + speedStep).clamp(0.5, 1.5);
                _dragSpeed = next;

                // 두 손가락 가로: 피치(센트).
                final pitchStep = delta.dx * 0.35;
                final nextPitch =
                    ((_dragPitch ?? 0) + pitchStep).clamp(-100.0, 100.0);
                _dragPitch = nextPitch;

                var snapped = (next * 200).round() / 200;
                if ((snapped - 1.0).abs() < 0.012) snapped = 1.0;

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
                  _topBar(context, state),
                  const SizedBox(height: 28),
                  Center(child: Artwork(track: track, size: 300, radius: 20)),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        Text(track.artist, style: AppText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _progress(context, state, controller, tone),
                  const SizedBox(height: 20),
                  _controls(state, controller, tone),
                  const Spacer(),
                  _statusPanel(context, effects.summary, tone),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // 제스처가 있다는 표시
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 2,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context, PlayerState state) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                size: 28, color: AppColors.t1),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              '재생 중',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.t3),
            ),
          ),
          IconButton(
            icon: Icon(
              state.loopA != null ? Icons.repeat_one_on : Icons.queue_music,
              size: 22,
              color: state.loopA != null ? AppColors.accent : AppColors.t2,
            ),
            onPressed: () => _showQueue(context),
          ),
        ],
      ),
    );
  }

  Widget _progress(
    BuildContext context,
    PlayerState state,
    PlayerController controller,
    ArtworkTone tone,
  ) {
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
          Row(
            children: [
              Text(formatDuration(state.position), style: AppText.mono),
              const Spacer(),
              Text('-${formatDuration(state.remainingWallClock)}',
                  style: AppText.mono),
              if (!state.tempo.isNormal) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => openSpeedSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: tone.glassOpacity + 0.02),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: tone.borderBoost),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${state.tempo.speed.toStringAsFixed(2)}x',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.t2,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          state.tempo.mode == TempoMode.linked
                              ? Icons.link
                              : Icons.lock_outline,
                          size: 9,
                          color: AppColors.t3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _controls(
    PlayerState state,
    PlayerController controller,
    ArtworkTone tone,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 28,
          icon: const Icon(Icons.skip_previous, color: AppColors.t1),
          onPressed: controller.previous,
        ),
        const SizedBox(width: 24),
        GlassSurface(
          radius: 36,
          width: 72,
          height: 72,
          opacity: tone.glassOpacity + 0.04,
          onTap: controller.togglePlay,
          child: Icon(
            state.playing ? Icons.pause : Icons.play_arrow,
            size: 28,
            color: AppColors.t1,
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          iconSize: 28,
          icon: const Icon(Icons.skip_next, color: AppColors.t1),
          onPressed: controller.next,
        ),
      ],
    );
  }

  Widget _statusPanel(
    BuildContext context,
    String summary,
    ArtworkTone tone,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassSurface(
        radius: AppRadius.panel,
        blur: AppBlur.sheet,
        opacity: tone.glassOpacity,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: () => openEffectsSheet(context),
        child: Row(
          children: [
            const Icon(Icons.headphones, size: 20, color: AppColors.t2),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
            ),
            const Icon(Icons.tune, size: 18, color: AppColors.t2),
          ],
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text('재생 목록', style: AppText.display),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: state.shuffle
                              ? AppColors.accent
                              : AppColors.t3,
                        ),
                        onPressed: controller.toggleShuffle,
                      ),
                      IconButton(
                        icon: Icon(
                          switch (state.repeat) {
                            RepeatMode.one => Icons.repeat_one,
                            _ => Icons.repeat,
                          },
                          color: state.repeat == RepeatMode.off
                              ? AppColors.t3
                              : AppColors.accent,
                        ),
                        onPressed: controller.cycleRepeat,
                      ),
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
                            color: i == state.index
                                ? AppColors.accent
                                : AppColors.t1,
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
