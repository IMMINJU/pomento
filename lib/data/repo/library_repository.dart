import 'dart:io';

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/tempo.dart';

/// 라이브러리 정렬 기준.
enum TrackSort { title, artist, album, recent }

extension TrackSortLabel on TrackSort {
  String get label => switch (this) {
        TrackSort.title => '제목',
        TrackSort.artist => '아티스트',
        TrackSort.album => '앨범',
        TrackSort.recent => '최근 추가',
      };
}

class LibraryRepository {
  LibraryRepository(this.db);

  final AppDatabase db;

  Stream<List<Track>> watchTracks({TrackSort sort = TrackSort.title}) {
    final q = db.select(db.tracks);
    switch (sort) {
      case TrackSort.title:
        q.orderBy([(t) => OrderingTerm(expression: t.title)]);
      case TrackSort.artist:
        q.orderBy([
          (t) => OrderingTerm(expression: t.artist),
          (t) => OrderingTerm(expression: t.title),
        ]);
      case TrackSort.album:
        q.orderBy([
          (t) => OrderingTerm(expression: t.album),
          (t) => OrderingTerm(expression: t.trackNo),
          (t) => OrderingTerm(expression: t.title),
        ]);
      case TrackSort.recent:
        q.orderBy([
          (t) => OrderingTerm(
                expression: t.importedAt,
                mode: OrderingMode.desc,
              ),
        ]);
    }
    return q.watch();
  }

  Future<List<Track>> allTracks() => db.select(db.tracks).get();

  Future<Track?> trackById(int id) =>
      (db.select(db.tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 파일이 사라진 곡을 정리한다. managed가 아닌 트랙은 기기에서 파일이
  /// 지워졌을 수 있다.
  Future<int> pruneMissing() async {
    final all = await allTracks();
    var removed = 0;
    for (final t in all) {
      if (!File(t.filePath).existsSync()) {
        await deleteTrack(t.id, deleteFile: false);
        removed++;
      }
    }
    return removed;
  }

  Future<void> deleteTrack(int id, {bool deleteFile = true}) async {
    final t = await trackById(id);
    if (t == null) return;
    // 앱이 복사해온 파일만 지운다. 기기 원본은 우리 것이 아니다.
    if (deleteFile && t.managed) {
      try {
        final f = File(t.filePath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    for (final path in [t.artworkPath, t.userArtworkPath]) {
      if (path == null) continue;
      try {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    await (db.delete(db.tracks)..where((r) => r.id.equals(id))).go();
  }

  // ── 곡별 설정 ──────────────────────────────────────────────────────

  /// 곡에 저장해둔 배속과 피치. 없으면 null.
  Future<TempoSettings?> tempoFor(int trackId) async {
    final row = await (db.select(db.trackSettingsRows)
          ..where((r) => r.trackId.equals(trackId)))
        .getSingleOrNull();
    if (row == null) return null;
    return TempoSettings(
      mode: TempoMode.values.firstWhere(
        (m) => m.name == row.tempoMode,
        orElse: () => TempoMode.linked,
      ),
      speed: row.speed,
      pitchCents: row.pitchCents,
    );
  }

  Stream<List<TrackSettingsRow>> watchAllTrackSettings() =>
      db.select(db.trackSettingsRows).watch();

  Future<void> saveTempoFor(int trackId, TempoSettings t) async {
    await db.into(db.trackSettingsRows).insertOnConflictUpdate(
          TrackSettingsRowsCompanion.insert(
            trackId: Value(trackId),
            tempoMode: Value(t.mode.name),
            speed: Value(t.speed),
            pitchCents: Value(t.pitchCents),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> clearTempoFor(int trackId) =>
      (db.delete(db.trackSettingsRows)..where((r) => r.trackId.equals(trackId)))
          .go();

  // ── 재생목록 ──────────────────────────────────────────────────────

  Stream<List<Playlist>> watchPlaylists() => (db.select(db.playlists)
        ..orderBy([(p) => OrderingTerm(expression: p.name)]))
      .watch();

  Future<int> createPlaylist(String name) => db.into(db.playlists).insert(
        PlaylistsCompanion.insert(name: name, createdAt: DateTime.now()),
      );

  Future<void> deletePlaylist(int id) =>
      (db.delete(db.playlists)..where((p) => p.id.equals(id))).go();

  Future<void> addToPlaylist(int playlistId, int trackId) async {
    final count = await (db.select(db.playlistEntries)
          ..where((e) => e.playlistId.equals(playlistId)))
        .get();
    await db.into(db.playlistEntries).insert(
          PlaylistEntriesCompanion.insert(
            playlistId: playlistId,
            trackId: trackId,
            position: count.length,
          ),
        );
  }

  Future<void> removeFromPlaylist(int entryId) =>
      (db.delete(db.playlistEntries)..where((e) => e.id.equals(entryId))).go();

  Stream<List<Track>> watchPlaylistTracks(int playlistId) {
    final query = db.select(db.playlistEntries).join([
      innerJoin(db.tracks, db.tracks.id.equalsExp(db.playlistEntries.trackId)),
    ])
      ..where(db.playlistEntries.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm(expression: db.playlistEntries.position)]);
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(db.tracks)).toList(),
        );
  }

  // ── 간단한 키·값 저장 ──────────────────────────────────────────────

  Future<String?> getValue(String key) async {
    final row = await (db.select(db.keyValues)..where((r) => r.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) => db
      .into(db.keyValues)
      .insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));
}
