import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/gesture_settings.dart';

/// 조작 단위 설정을 SharedPreferences에 담는다.
///
/// drift에 넣지 않는 이유는 값이 대여섯 개뿐이고 스키마 변경 비용이 아깝기
/// 때문이다.
class SettingsController extends StateNotifier<AppSettings> {
  SettingsController() : super(AppSettings.defaults) {
    _load();
  }

  static const _kSpeedStep = 'settings.speedStep';
  static const _kPitchStep = 'settings.pitchStepCents';
  static const _kSeekShort = 'settings.seekShortSeconds';
  static const _kSeekLong = 'settings.seekLongSeconds';
  static const _kSpeedRange = 'settings.speedRange';
  static const _kNudge = 'settings.nudgePercent';
  static const _kGestureHint = 'settings.showGestureHint';
  static const _kKeepScreenOn = 'settings.keepScreenOn';
  static const _kGestures = 'settings.gestures';

  SharedPreferences? _prefs;

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    if (!mounted) return;
    state = AppSettings(
      speedStep: p.getDouble(_kSpeedStep) ?? AppSettings.defaults.speedStep,
      pitchStepCents:
          p.getInt(_kPitchStep) ?? AppSettings.defaults.pitchStepCents,
      seekShortSeconds:
          p.getInt(_kSeekShort) ?? AppSettings.defaults.seekShortSeconds,
      seekLongSeconds:
          p.getInt(_kSeekLong) ?? AppSettings.defaults.seekLongSeconds,
      speedRange: SpeedRange.values.firstWhere(
        (r) => r.name == p.getString(_kSpeedRange),
        orElse: () => AppSettings.defaults.speedRange,
      ),
      nudgePercent:
          p.getDouble(_kNudge) ?? AppSettings.defaults.nudgePercent,
      showGestureHint:
          p.getBool(_kGestureHint) ?? AppSettings.defaults.showGestureHint,
      keepScreenOn:
          p.getBool(_kKeepScreenOn) ?? AppSettings.defaults.keepScreenOn,
      gestures: _readGestures(p),
    );
  }

  void setSpeedStep(double v) {
    state = state.copyWith(speedStep: v);
    _prefs?.setDouble(_kSpeedStep, v);
  }

  void setPitchStep(int cents) {
    state = state.copyWith(pitchStepCents: cents);
    _prefs?.setInt(_kPitchStep, cents);
  }

  void setSeekShort(int seconds) {
    state = state.copyWith(seekShortSeconds: seconds);
    _prefs?.setInt(_kSeekShort, seconds);
  }

  void setSeekLong(int seconds) {
    state = state.copyWith(seekLongSeconds: seconds);
    _prefs?.setInt(_kSeekLong, seconds);
  }

  void setSpeedRange(SpeedRange r) {
    state = state.copyWith(speedRange: r);
    _prefs?.setString(_kSpeedRange, r.name);
  }

  void setNudgePercent(double v) {
    state = state.copyWith(nudgePercent: v);
    _prefs?.setDouble(_kNudge, v);
  }

  void setShowGestureHint(bool v) {
    state = state.copyWith(showGestureHint: v);
    _prefs?.setBool(_kGestureHint, v);
  }

  static GestureSettings _readGestures(SharedPreferences p) {
    final raw = p.getString(_kGestures);
    if (raw == null) return GestureSettings.defaults;
    try {
      return GestureSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return GestureSettings.defaults;
    }
  }

  void setGestures(GestureSettings g) {
    state = state.copyWith(gestures: g);
    _prefs?.setString(_kGestures, jsonEncode(g.toJson()));
  }

  void setKeepScreenOn(bool v) {
    state = state.copyWith(keepScreenOn: v);
    _prefs?.setBool(_kKeepScreenOn, v);
  }
}
