import 'package:audio_service/audio_service.dart';

/// 잠금화면과 알림의 컨트롤을 재생 컨트롤러로 넘겨주는 얇은 층.
///
/// 실제 재생 로직은 [PlayerController]에 있고 여기서는 콜백만 연결한다.
class PlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  void Function()? onPlay;
  void Function()? onPause;
  void Function()? onNext;
  void Function()? onPrevious;
  void Function()? onStop;
  void Function(Duration)? onSeek;

  @override
  Future<void> play() async => onPlay?.call();

  @override
  Future<void> pause() async => onPause?.call();

  @override
  Future<void> skipToNext() async => onNext?.call();

  @override
  Future<void> skipToPrevious() async => onPrevious?.call();

  @override
  Future<void> seek(Duration position) async => onSeek?.call(position);

  @override
  Future<void> stop() async {
    onStop?.call();
    await super.stop();
  }

  /// 재생 상태를 알림에 반영한다.
  void publish({
    required bool playing,
    required Duration position,
    required double speed,
    required bool hasNext,
    required bool hasPrevious,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          if (hasPrevious) MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          if (hasNext) MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: position,
        // 배속을 알려줘야 잠금화면 진행 바가 실제 속도로 움직인다.
        speed: speed,
      ),
    );
  }

  void publishItem(MediaItem item) => mediaItem.add(item);

  void publishIdle() {
    playbackState.add(
      PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }
}
