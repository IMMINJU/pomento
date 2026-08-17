import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// 라이브러리에 들어온 음원 한 곡.
///
/// 태그와 자켓은 가져오는 시점에 파일에서 읽어 여기에 복사해둔다. 이후 원본
/// 파일의 태그가 바뀌어도 앱이 보여주는 값은 그대로다.
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 재생할 파일의 절대 경로.
  TextColumn get filePath => text()();

  /// true면 앱 저장소로 복사해온 파일이고, false면 기기의 원본을 참조만 한다.
  /// iOS는 항상 true. 안드로이드는 읽을 수 있는 경로면 false로 두어 용량을
  /// 두 배로 쓰지 않는다.
  BoolColumn get managed => boolean().withDefault(const Constant(false))();

  TextColumn get title => text()();
  TextColumn get artist => text().withDefault(const Constant(''))();
  TextColumn get album => text().withDefault(const Constant(''))();
  TextColumn get albumArtist => text().withDefault(const Constant(''))();
  IntColumn get year => integer().nullable()();
  IntColumn get trackNo => integer().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  /// 파일 태그에서 뽑아 저장한 자켓 경로.
  TextColumn get artworkPath => text().nullable()();

  /// 사용자가 직접 지정한 자켓. 무엇도 이 값을 덮어쓰지 않는다.
  TextColumn get userArtworkPath => text().nullable()();

  /// 아티스트·앨범·제목을 정규화한 키. 두 사람 사이에 곡을 맞출 때 쓴다.
  TextColumn get contentKey => text().withDefault(const Constant(''))();

  DateTimeColumn get importedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {filePath},
      ];
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class PlaylistEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
}

/// 프리셋. 중첩 구조라 본문은 JSON으로 넣고, 조회에 쓰는 값만 컬럼으로 뺐다.
class PresetRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get layer => text()();
  TextColumn get author => text().nullable()();
  TextColumn get deviceMatch => text().nullable()();
  BoolColumn get builtin => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get payload => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 곡별로 기억해둔 배속과 피치.
///
/// 미세 조정이 중요한 앱이라 매번 다시 맞추는 게 가장 성가신 부분이 된다.
class TrackSettingsRows extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get tempoMode => text().withDefault(const Constant('linked'))();
  RealColumn get speed => real().withDefault(const Constant(1.0))();
  RealColumn get pitchCents => real().withDefault(const Constant(0.0))();
  TextColumn get tastePresetId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {trackId};
}

class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Tracks,
    Playlists,
    PlaylistEntries,
    PresetRows,
    TrackSettingsRows,
    KeyValues,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _open() => driftDatabase(name: 'player');
}
