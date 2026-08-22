import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/import_log.dart';

/// 마지막 가져오기 결과를 SharedPreferences에 담는다.
///
/// 값 하나뿐이라 drift 스키마를 건드리지 않는다. 설정 값을 담는
/// SettingsController와 같은 이유다.
class ImportLogController extends StateNotifier<ImportLog?> {
  ImportLogController() : super(null) {
    _load();
  }

  static const _key = 'import.last';

  SharedPreferences? _prefs;

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    if (!mounted) return;

    final raw = p.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        state = ImportLog.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('가져오기 기록을 읽지 못했다: $e');
    }
  }

  Future<void> record(ImportLog log) async {
    state = log;
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setString(_key, jsonEncode(log.toJson()));
  }
}
