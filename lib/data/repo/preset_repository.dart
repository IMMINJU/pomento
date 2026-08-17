import 'dart:convert';

import 'package:drift/drift.dart';

import '../../presets/builtin_presets.dart';
import '../db/database.dart';
import '../models/preset.dart';

class PresetRepository {
  PresetRepository(this.db);

  final AppDatabase db;

  /// 기본 프리셋을 DB에 넣는다. 이미 있으면 건드리지 않는다.
  ///
  /// 사용자가 기본 프리셋을 고쳤을 수 있으므로 덮어쓰지 않고, 없는 것만
  /// 채운다.
  Future<void> seedBuiltins() async {
    final existing = await db.select(db.presetRows).get();
    final have = existing.map((e) => e.id).toSet();
    for (final p in BuiltinPresets.all) {
      if (have.contains(p.id)) continue;
      await _insert(p);
    }
  }

  Future<void> _insert(Preset p) async {
    await db.into(db.presetRows).insertOnConflictUpdate(
          PresetRowsCompanion.insert(
            id: p.id,
            name: p.name,
            layer: p.layer.name,
            author: Value(p.author),
            deviceMatch: Value(p.deviceMatch),
            builtin: Value(p.builtin),
            updatedAt: p.updatedAt ?? DateTime.now(),
            payload: jsonEncode(p.toJson()),
          ),
        );
  }

  Preset _decode(PresetRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    return Preset.fromJson(json);
  }

  Stream<List<Preset>> watchByLayer(PresetLayer layer) =>
      (db.select(db.presetRows)
            ..where((r) => r.layer.equals(layer.name))
            ..orderBy([
              (r) => OrderingTerm(expression: r.builtin, mode: OrderingMode.desc),
              (r) => OrderingTerm(expression: r.name),
            ]))
          .watch()
          .map((rows) => rows.map(_decode).toList());

  Stream<List<Preset>> watchAll() => db
      .select(db.presetRows)
      .watch()
      .map((rows) => rows.map(_decode).toList());

  Future<List<Preset>> byLayer(PresetLayer layer) async {
    final rows = await (db.select(db.presetRows)
          ..where((r) => r.layer.equals(layer.name)))
        .get();
    return rows.map(_decode).toList();
  }

  Future<Preset?> byId(String id) async {
    final row = await (db.select(db.presetRows)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _decode(row);
  }

  Future<void> save(Preset p) => _insert(p.copyWith(updatedAt: DateTime.now()));

  Future<void> delete(String id) =>
      (db.delete(db.presetRows)..where((r) => r.id.equals(id))).go();

  /// 연결된 출력 기기에 맞는 기기 프리셋을 찾는다.
  Future<Preset?> matchDevice(String descriptor) async {
    final presets = await byLayer(PresetLayer.device);
    final d = descriptor.toLowerCase();
    // 기본 목록의 순서를 따라야 구체적인 항목이 먼저 걸린다.
    for (final builtin in BuiltinPresets.device) {
      final token = builtin.deviceMatch;
      if (token == null || !d.contains(token)) continue;
      return presets.firstWhere(
        (p) => p.id == builtin.id,
        orElse: () => builtin,
      );
    }
    // 사용자가 직접 만든 기기 프리셋도 검사한다.
    for (final p in presets) {
      final token = p.deviceMatch;
      if (token != null && token.isNotEmpty && d.contains(token.toLowerCase())) {
        return p;
      }
    }
    return null;
  }

  // ── 마지막으로 고른 조합 ───────────────────────────────────────────
  //
  // 앱을 껐다 켜도 듣던 소리 그대로 이어지게 한다.

  static const String _selectionKey = 'effect_selection';

  Future<void> saveSelection(Map<String, dynamic> value) => db
      .into(db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion.insert(
          key: _selectionKey,
          value: jsonEncode(value),
        ),
      );

  Future<Map<String, dynamic>?> loadSelection() async {
    final row = await (db.select(db.keyValues)
          ..where((r) => r.key.equals(_selectionKey)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return jsonDecode(row.value) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── 내보내기와 가져오기 ────────────────────────────────────────────
  //
  // 두 사람 사이의 동기화는 취향 층만 대상으로 한다. 기기 보정은 각자 폰의
  // 이어폰 특성에 맞춘 값이라 상대에게 보내면 오히려 어긋난다.
  //
  // Firestore를 붙일 자리도 여기다. 지금은 파일로 주고받는다.

  Future<String> exportShareable() async {
    final presets = await byLayer(PresetLayer.taste);
    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'presets': presets.where((p) => !p.builtin).map((p) => p.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// 가져온 프리셋 개수를 돌려준다.
  Future<int> importShareable(String jsonText, {String? author}) async {
    final data = jsonDecode(jsonText) as Map<String, dynamic>;
    final list = (data['presets'] as List<dynamic>?) ?? const [];
    var count = 0;
    for (final e in list) {
      try {
        final p = Preset.fromJson(Map<String, dynamic>.from(e as Map));
        if (!p.layer.shareable) continue;
        await _insert(
          p.copyWith(
            author: author ?? p.author,
            builtin: false,
            updatedAt: DateTime.now(),
          ),
        );
        count++;
      } catch (_) {
        continue;
      }
    }
    return count;
  }
}
