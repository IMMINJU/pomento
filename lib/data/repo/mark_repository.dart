import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/mark.dart';

/// 마크를 읽고 쓴다.
///
/// 목록은 항상 시각 순이다. 칩 줄과 패널 목록이 같은 순서를 보여야
/// 하나를 눌렀을 때 어디로 갈지 예측이 된다.
class MarkRepository {
  MarkRepository(this._db);

  final AppDatabase _db;

  Stream<List<Mark>> watchForTrack(int trackId) {
    final q = _db.select(_db.markRows)
      ..where((t) => t.trackId.equals(trackId))
      ..orderBy([(t) => OrderingTerm(expression: t.positionMs)]);
    return q.watch().map((rows) => rows.map(Mark.fromRow).toList());
  }

  /// 곡마다 마크가 몇 개인지. 라이브러리와 연습본 목록이 이 값을 쓴다.
  Stream<Map<int, int>> watchCounts() {
    final count = _db.markRows.id.count();
    final q = _db.selectOnly(_db.markRows)
      ..addColumns([_db.markRows.trackId, count])
      ..groupBy([_db.markRows.trackId]);
    return q.watch().map(
          (rows) => {
            for (final r in rows)
              r.read(_db.markRows.trackId)!: r.read(count) ?? 0,
          },
        );
  }

  /// 지금 위치에 점 마크를 하나 찍는다. 묻는 것이 없다.
  Future<int> add(int trackId, Duration position) {
    return _db.into(_db.markRows).insert(
          MarkRowsCompanion.insert(
            trackId: trackId,
            positionMs: position.inMilliseconds,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> update(Mark m) {
    return (_db.update(_db.markRows)..where((t) => t.id.equals(m.id))).write(
      MarkRowsCompanion(
        positionMs: Value(m.position.inMilliseconds),
        endMs: Value(m.end?.inMilliseconds),
        speed: Value(m.speed),
        pitchCents: Value(m.pitchCents),
      ),
    );
  }

  Future<void> remove(int id) =>
      (_db.delete(_db.markRows)..where((t) => t.id.equals(id))).go();

  Future<void> removeForTrack(int trackId) =>
      (_db.delete(_db.markRows)..where((t) => t.trackId.equals(trackId))).go();
}
