import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/audio_handler.dart';
import 'audio/effect_controller.dart';
import 'audio/player_controller.dart';
import 'audio/sleep_timer.dart';
import 'data/db/database.dart';
import 'data/models/tempo.dart';
import 'data/platform/native_media.dart';
import 'data/repo/library_repository.dart';
import 'data/models/app_settings.dart';
import 'data/repo/preset_repository.dart';
import 'data/repo/settings_repository.dart';
import 'data/spotify/spotify_session.dart';
import 'data/spotify/track_match.dart';
import 'data/storage/media_importer.dart';

/// main에서 실제 인스턴스로 덮어쓴다.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('main에서 override해야 한다'),
);

final audioHandlerProvider = Provider<PlayerAudioHandler>(
  (ref) => throw UnimplementedError('main에서 override해야 한다'),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(appDatabaseProvider)),
);

final presetRepositoryProvider = Provider<PresetRepository>(
  (ref) => PresetRepository(ref.watch(appDatabaseProvider)),
);

final mediaImporterProvider = Provider<MediaImporter>(
  (ref) => MediaImporter(ref.watch(appDatabaseProvider)),
);

final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerState>(
  (ref) => PlayerController(
    ref.watch(libraryRepositoryProvider),
    ref.watch(audioHandlerProvider),
  ),
);

final effectControllerProvider =
    StateNotifierProvider<EffectController, EffectState>(
  (ref) => EffectController(
    ref.watch(presetRepositoryProvider),
    // 프리셋은 소리 전체를 기술한다. 배속이 없는 프리셋을 고르면 배속도
    // 원래대로 돌아가야 한다. 안 그러면 "밤에 느리게"를 한 번 고른 뒤로
    // 무엇을 눌러도 계속 느린 채로 남는다.
    onTastePresetTempo: (preset) {
      ref.read(playerControllerProvider.notifier).setTempo(
            preset.tempo ?? TempoSettings.normal,
            commit: false,
          );
    },
  ),
);

/// 조작 단위 설정. 스테퍼 폭, 점프 탐색 시간, 속도 슬라이더 범위.
final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
  (ref) => SettingsController(),
);

/// 슬립 타이머. 시간이 다 되면 어느 쪽이 소리를 내고 있든 멈춘다.
final sleepTimerProvider =
    StateNotifierProvider<SleepTimerController, SleepTimerState>((ref) {
  final controller = SleepTimerController(() {
    ref.read(playerControllerProvider.notifier).pause();
    final spotify = ref.read(spotifySessionProvider);
    if (spotify.connected && !spotify.paused) {
      ref.read(spotifySessionProvider.notifier).togglePlay();
    }
  });
  // 곡이 끝나는 시점은 재생기가 안다. "이 곡까지"를 그쪽에서 물어보게 한다.
  ref.read(playerControllerProvider.notifier).shouldStopAfterTrack =
      controller.consumeTrackEnd;
  return controller;
});

final trackSortProvider = StateProvider<TrackSort>((ref) => TrackSort.title);

final tracksProvider = StreamProvider<List<Track>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  final sort = ref.watch(trackSortProvider);
  return repo.watchTracks(sort: sort);
});

final playlistsProvider = StreamProvider<List<Playlist>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchPlaylists(),
);

/// 곡별로 저장된 배속. 라이브러리 목록에 배지로 보여준다.
final savedTemposProvider = StreamProvider<Map<int, TempoSettings>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchAllTrackSettings().map(
        (rows) => {
          for (final r in rows)
            r.trackId: TempoSettings(
              mode: TempoMode.values.firstWhere(
                (m) => m.name == r.tempoMode,
                orElse: () => TempoMode.linked,
              ),
              speed: r.speed,
              pitchCents: r.pitchCents,
            ),
        },
      );
});

/// 지금 소리를 내는 쪽.
///
/// 우리 엔진과 Spotify 앱은 서로 모른다. 둘 다 소리를 낼 수 있으므로 화면이
/// 어느 쪽을 보여줄지 여기서 정한다.
enum PlaybackSource { local, spotify }

final activeSourceProvider =
    StateProvider<PlaybackSource>((ref) => PlaybackSource.local);

/// Spotify 검색과 App Remote 재생.
final spotifySessionProvider =
    StateNotifierProvider<SpotifySession, SpotifyState>(
  (ref) => SpotifySession(),
);

/// 지금 보여줄 곡이 있는지. 미니 플레이어를 띄울지 정하는 데 쓴다.
final nowPlayingExistsProvider = Provider<bool>((ref) {
  final source = ref.watch(activeSourceProvider);
  if (source == PlaybackSource.spotify) {
    return ref.watch(spotifySessionProvider.select((s) => s.hasTrack));
  }
  return ref.watch(playerControllerProvider.select((s) => s.current != null));
});

/// 라이브러리를 검색용으로 미리 다듬어 둔 색인.
///
/// Spotify 결과 하나마다 수천 곡의 제목을 다시 소문자로 내리고 괄호를 지우면
/// 목록이 버벅인다. 라이브러리가 바뀔 때만 한 번 만든다.
final matchKeysProvider = Provider<List<MatchKey<Track>>>((ref) {
  final tracks = ref.watch(tracksProvider).value ?? const <Track>[];
  return [
    for (final t in tracks) MatchKey<Track>(t, t.title, t.artist),
  ];
});

final outputDeviceProvider = StreamProvider<OutputDevice>(
  (ref) => NativeMedia.instance.outputDeviceChanges,
);
