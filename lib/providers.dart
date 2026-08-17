import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/audio_handler.dart';
import 'audio/effect_controller.dart';
import 'audio/player_controller.dart';
import 'data/db/database.dart';
import 'data/models/tempo.dart';
import 'data/platform/native_media.dart';
import 'data/repo/library_repository.dart';
import 'data/repo/preset_repository.dart';
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

final outputDeviceProvider = StreamProvider<OutputDevice>(
  (ref) => NativeMedia.instance.outputDeviceChanges,
);
