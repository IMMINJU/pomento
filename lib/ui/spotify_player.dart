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
import 'widgets/common.dart';
import 'widgets/gesture_layer.dart';
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

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
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
                    final size = math.min(box.maxWidth - 40, box.maxHeight - 8);
                    if (size < 96) return const SizedBox.shrink();
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedSwitcher(
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
                          child: _artwork(
                            key: ValueKey<String>(s.trackUri ?? ''),
                            imageId: s.imageId ?? '',
                            size: size,
                          ),
                        ),
                        if (panelOpen)
                          Positioned(
                            left: 4,
                            right: 4,
                            bottom: 4,
                            child: _ControlPanel(
                              state: s,
                              session: _session,
                              short: settings.seekShortSeconds,
                              long: settings.seekLongSeconds,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              _titleRow(s),
              const SizedBox(height: 12),
              _progress(s),
              const SizedBox(height: 16),
              _transport(s, match),
              SizedBox(height: bottomInset + 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, bool panelOpen) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'Spotify',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1DB954),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _RoundIcon(
              icon: Icons.compare_arrows,
              filled: panelOpen,
              onTap: () =>
                  ref.read(controlPanelOpenProvider.notifier).state = !panelOpen,
            ),
            const Spacer(),
            _RoundIcon(
              icon: Icons.search,
              onTap: () => openSearchScreen(context),
            ),
            const SizedBox(width: 8),
            _RoundIcon(
              icon: Icons.settings,
              onTap: () => openSettingsScreen(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artwork({
    required Key key,
    required String imageId,
    required double size,
  }) {
    final image = ref.watch(spotifyImageProvider(imageId)).value;
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(20),
      child: image == null
          ? Container(
              width: size,
              height: size,
              color: AppColors.glass,
              child:
                  const Icon(Icons.music_note, size: 48, color: AppColors.t3),
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

  Widget _titleRow(SpotifyState s) {
    return Padding(
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
          const SizedBox(height: 4),
          Text(
            s.artistName ?? '',
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
    );
  }

  Widget _progress(SpotifyState s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ThinProgressBar(
            progress: s.progress,
            onSeek: (p) => _session.seek(
              Duration(milliseconds: (s.duration.inMilliseconds * p).round()),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                formatDuration(s.position),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  fontFeatures: tabularFigures,
                ),
              ),
              const Spacer(),
              Text(
                formatDuration(s.duration),
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

  Widget _transport(SpotifyState s, TrackMatch<Track>? match) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundIcon(
            icon: Icons.folder_outlined,
            filled: true,
            onTap: () => openLibraryScreen(context),
          ),
          IconButton(
            iconSize: 30,
            icon: const Icon(Icons.skip_previous, color: AppColors.t1),
            onPressed: () {
              setState(() => _slideDir = -1);
              _session.previous();
            },
          ),
          GestureDetector(
            onTap: _session.togglePlay,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
              child: Icon(
                s.paused ? Icons.play_arrow : Icons.pause,
                size: 30,
                color: AppColors.t1,
              ),
            ),
          ),
          IconButton(
            iconSize: 30,
            icon: const Icon(Icons.skip_next, color: AppColors.t1),
            onPressed: () {
              setState(() => _slideDir = 1);
              _session.next();
            },
          ),
          // 같은 곡을 가지고 있으면 그쪽으로 넘어간다. 없으면 자리만 지킨다.
          Opacity(
            opacity: match == null ? 0.3 : 1,
            child: _RoundIcon(
              icon: Icons.swap_horiz,
              filled: match != null,
              onTap: () {
                if (match == null) return;
                _session.togglePlay();
                ref
                    .read(playerControllerProvider.notifier)
                    .playQueue([match.track], 0);
                ref.read(activeSourceProvider.notifier).state =
                    PlaybackSource.local;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 자켓 위에 얹는 컨트롤. Spotify에서는 탐색과 구간 반복만 된다.
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

    return GlassSurface(
      radius: AppRadius.panel,
      blur: AppBlur.sheet,
      opacity: 0.20,
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
                onTap: () => session.seekBy(Duration(seconds: -long)),
              ),
              _JumpButton(
                seconds: short,
                back: true,
                onTap: () => session.seekBy(Duration(seconds: -short)),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (state.loopA == null) {
                    session.setLoopA();
                  } else if (state.loopB == null) {
                    session.setLoopB();
                  } else {
                    session.clearLoop();
                  }
                },
                onLongPress: session.clearLoop,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: looping
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: looping
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
                      color: looping ? AppColors.bgBase : AppColors.t1,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ),
              ),
              _JumpButton(
                seconds: short,
                back: false,
                onTap: () => session.seekBy(Duration(seconds: short)),
              ),
              _JumpButton(
                seconds: long,
                back: false,
                onTap: () => session.seekBy(Duration(seconds: long)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              looping
                  ? '구간 반복은 위치를 다시 보내는 방식이라 조금 어긋납니다'
                  : '소리가 Spotify 앱에서 납니다. 배속 · 피치 · 음향 보정은 꺼져 있습니다',
              textAlign: TextAlign.center,
              style: AppText.small,
            ),
          ),
        ],
      ),
    );
  }
}

/// 점프 탐색 버튼. 재생 화면과 같은 모양이다.
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
            ? (seconds >= 10
                ? Icons.keyboard_double_arrow_left
                : Icons.keyboard_arrow_left)
            : (seconds >= 10
                ? Icons.keyboard_double_arrow_right
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
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: back
            ? [circle, const SizedBox(width: 4), text]
            : [text, const SizedBox(width: 4), circle],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
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
          color:
              filled ? AppColors.accent : Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: filled
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.24),
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
