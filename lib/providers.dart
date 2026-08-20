import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/audio_handler.dart';
import 'audio/effect_controller.dart';
import 'audio/player_controller.dart';
import 'audio/sleep_timer.dart';
import 'data/db/database.dart';
import 'data/models/tempo.dart';
import 'data/platform/native_media.dart';
import 'data/models/mark.dart';
import 'data/repo/library_repository.dart';
import 'data/repo/mark_repository.dart';
import 'data/models/app_settings.dart';
import 'data/models/preset.dart';
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

/// 시작할 때 넘어간 문제. 없으면 null이다.
///
/// 오디오 엔진이 안 붙어도 앱은 뜨게 해뒀다. 소리가 안 나는 이유를
/// 화면 어딘가에서 읽을 수 있어야 해서 여기에 담아 둔다.
final startupWarningProvider = Provider<String?>((ref) => null);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(appDatabaseProvider)),
);

final presetRepositoryProvider = Provider<PresetRepository>(
  (ref) => PresetRepository(ref.watch(appDatabaseProvider)),
);

final markRepositoryProvider = Provider<MarkRepository>(
  (ref) => MarkRepository(ref.watch(appDatabaseProvider)),
);

/// 지금 걸린 곡의 마크. 곡이 없으면 빈 목록이다.
final marksProvider = StreamProvider<List<Mark>>((ref) {
  final id = ref.watch(playerControllerProvider.select((s) => s.current?.id));
  if (id == null) return Stream.value(const <Mark>[]);
  return ref.watch(markRepositoryProvider).watchForTrack(id);
});

/// 곡마다 마크가 몇 개인지. 라이브러리 배지가 쓴다.
final markCountsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(markRepositoryProvider).watchCounts(),
);

/// 지금 재생 위치가 걸려 있는 마크. 구간 마크가 점 마크보다 우선한다.
final activeMarkProvider = Provider<Mark?>((ref) {
  final marks = ref.watch(marksProvider).value ?? const <Mark>[];
  if (marks.isEmpty) return null;
  final at = ref.watch(playerControllerProvider.select((s) => s.position));
  for (final m in marks) {
    if (m.isLoop && at >= m.position && at < m.end!) return m;
  }
  Mark? last;
  for (final m in marks) {
    if (m.isLoop) continue;
    if (m.position <= at) last = m;
  }
  return last;
});

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
          ref
              .read(playerControllerProvider.notifier)
              .setTempo(preset.tempo ?? TempoSettings.normal, commit: false);
        },
      ),
    );

/// 조작 단위 설정. 스테퍼 폭, 점프 탐색 시간, 속도 슬라이더 범위.
final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>(
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

/// 취향 프리셋 개수. 음향 화면 머리에 붙인다.
final tastePresetCountProvider = Provider<int>((ref) {
  return ref.watch(tastePresetsProvider).value?.length ?? 0;
});

final tastePresetsProvider = StreamProvider<List<Preset>>(
  (ref) => ref.watch(presetRepositoryProvider).watchByLayer(PresetLayer.taste),
);

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

final activeSourceProvider = StateProvider<PlaybackSource>(
  (ref) => PlaybackSource.local,
);

/// Spotify 검색과 App Remote 재생.
/// 두 재생이 겹치지 않게 한다.
///
/// 한쪽이 소리를 내기 직전에 다른 쪽을 멈추고, 지금 어느 쪽이 울고 있는지를
/// activeSourceProvider에 적는다. 앱 뼈대에서 한 번 watch해야 걸린다.
///
/// 화면마다 상대를 멈추던 방식은 한 군데씩 빠진다. 실제로 검색 화면에만
/// 있었고 라이브러리·큐·미니 플레이어에서는 두 소리가 겹쳤다.
final playbackRefereeProvider = Provider<void>((ref) {
  final local = ref.watch(playerControllerProvider.notifier);
  final spotify = ref.watch(spotifySessionProvider.notifier);

  local.onWillPlay = () {
    final s = ref.read(spotifySessionProvider);
    if (s.connected && !s.paused) spotify.pauseNow();
    ref.read(activeSourceProvider.notifier).state = PlaybackSource.local;
  };

  spotify.onWillPlay = () {
    if (ref.read(playerControllerProvider).playing) local.pause();
    ref.read(activeSourceProvider.notifier).state = PlaybackSource.spotify;
  };

  ref.onDispose(() {
    local.onWillPlay = null;
    spotify.onWillPlay = null;
  });
});

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
  return [for (final t in tracks) MatchKey<Track>(t, t.title, t.artist)];
});

final outputDeviceProvider = StreamProvider<OutputDevice>(
  (ref) => NativeMedia.instance.outputDeviceChanges,
);
