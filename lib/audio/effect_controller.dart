import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/eq_curve.dart';
import '../data/models/preset.dart';
import '../data/models/tempo.dart';
import '../data/platform/native_media.dart';
import '../data/repo/preset_repository.dart';
import 'audio_engine.dart';

@immutable
class EffectState {
  const EffectState({
    this.device = OutputDevice.unknown,
    this.devicePreset,
    this.deviceAuto = true,
    this.deviceEnabled = true,
    this.environmentPreset,
    this.tastePreset,
    this.reverb = ReverbSettings.off,
    this.echo = EchoSettings.off,
    this.loudnessComp = false,
  });

  /// 지금 연결된 출력 기기.
  final OutputDevice device;

  /// 1층. 기기에 맞춰 자동으로 걸린다.
  final Preset? devicePreset;
  final bool deviceAuto;
  final bool deviceEnabled;

  /// 2층.
  final Preset? environmentPreset;

  /// 3층. 이 층만 두 사람이 공유한다.
  final Preset? tastePreset;

  /// 취향 프리셋에서 온 값이지만 슬라이더로 따로 조절할 수 있다.
  final ReverbSettings reverb;
  final EchoSettings echo;
  final bool loudnessComp;

  /// 엔진에 넣을 세 층의 곡선.
  List<EqCurve> get layers => [
        if (deviceEnabled && devicePreset != null) devicePreset!.eq,
        if (environmentPreset != null) environmentPreset!.eq,
        if (tastePreset != null) tastePreset!.eq,
      ];

  /// 합산된 최종 곡선을 [freq]에서 평가한다. 그래프를 그릴 때 쓴다.
  double summedGainAt(double freq) => EqCurve.sumGainAt(layers, freq);

  /// 재생 화면 하단에 한 줄로 보여줄 요약.
  String get summary {
    final parts = <String>[
      if (deviceEnabled && devicePreset != null) devicePreset!.name
      else device.label,
      if (environmentPreset != null &&
          environmentPreset!.id != 'env_quiet')
        environmentPreset!.name,
      if (tastePreset != null && tastePreset!.id != 'taste_none')
        tastePreset!.name,
    ];
    return parts.isEmpty ? '원음' : parts.join(' · ');
  }

  EffectState copyWith({
    OutputDevice? device,
    Preset? devicePreset,
    bool clearDevicePreset = false,
    bool? deviceAuto,
    bool? deviceEnabled,
    Preset? environmentPreset,
    Preset? tastePreset,
    ReverbSettings? reverb,
    EchoSettings? echo,
    bool? loudnessComp,
  }) =>
      EffectState(
        device: device ?? this.device,
        devicePreset:
            clearDevicePreset ? null : (devicePreset ?? this.devicePreset),
        deviceAuto: deviceAuto ?? this.deviceAuto,
        deviceEnabled: deviceEnabled ?? this.deviceEnabled,
        environmentPreset: environmentPreset ?? this.environmentPreset,
        tastePreset: tastePreset ?? this.tastePreset,
        reverb: reverb ?? this.reverb,
        echo: echo ?? this.echo,
        loudnessComp: loudnessComp ?? this.loudnessComp,
      );
}

/// 세 층의 음향 설정을 모아 엔진에 반영한다.
class EffectController extends StateNotifier<EffectState> {
  EffectController(this._presets, {this.onTastePresetTempo})
      : super(const EffectState()) {
    _bootstrap();
  }

  final PresetRepository _presets;

  /// 취향 프리셋에 배속이 들어 있으면 재생 쪽에 넘긴다.
  final void Function(Preset preset)? onTastePresetTempo;

  StreamSubscription<OutputDevice>? _deviceSub;
  Timer? _saveTimer;

  Future<void> _bootstrap() async {
    // 지난번에 듣던 조합을 그대로 이어간다.
    final saved = await _presets.loadSelection();
    final env = await _presets.byId(saved?['env'] as String? ?? 'env_quiet') ??
        await _presets.byId('env_quiet');
    final taste =
        await _presets.byId(saved?['taste'] as String? ?? 'taste_none') ??
            await _presets.byId('taste_none');
    if (!mounted) return;

    state = state.copyWith(
      environmentPreset: env,
      tastePreset: taste,
      reverb: saved?['reverb'] == null
          ? (taste?.reverb ?? ReverbSettings.off)
          : ReverbSettings.fromJson(
              Map<String, dynamic>.from(saved!['reverb'] as Map)),
      echo: saved?['echo'] == null
          ? (taste?.echo ?? EchoSettings.off)
          : EchoSettings.fromJson(
              Map<String, dynamic>.from(saved!['echo'] as Map)),
      loudnessComp: saved?['loudness'] as bool? ?? false,
      deviceEnabled: saved?['deviceOn'] as bool? ?? true,
    );

    await refreshDevice();
    _deviceSub = NativeMedia.instance.outputDeviceChanges.listen((d) {
      _onDeviceChanged(d);
    });
    _apply();
  }

  /// 슬라이더를 끄는 동안 매번 쓰지 않도록 잠깐 모았다가 저장한다.
  void _persistSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      _presets.saveSelection({
        'env': state.environmentPreset?.id,
        'taste': state.tastePreset?.id,
        'reverb': state.reverb.toJson(),
        'echo': state.echo.toJson(),
        'loudness': state.loudnessComp,
        'deviceOn': state.deviceEnabled,
      });
    });
  }

  Future<void> refreshDevice() async {
    final d = await NativeMedia.instance.currentOutputDevice();
    await _onDeviceChanged(d);
  }

  Future<void> _onDeviceChanged(OutputDevice d) async {
    if (!mounted) return;
    if (!state.deviceAuto) {
      state = state.copyWith(device: d);
      return;
    }
    final matched = await _presets.matchDevice(d.descriptor);
    if (!mounted) return;
    state = matched == null
        ? state.copyWith(device: d, clearDevicePreset: true)
        : state.copyWith(device: d, devicePreset: matched);
    _apply();
  }

  // ── 층별 선택 ──────────────────────────────────────────────────────

  void selectDevicePreset(Preset? p) {
    state = p == null
        ? state.copyWith(deviceAuto: false, clearDevicePreset: true)
        : state.copyWith(deviceAuto: false, devicePreset: p);
    _apply();
  }

  Future<void> enableDeviceAuto() async {
    state = state.copyWith(deviceAuto: true);
    await refreshDevice();
  }

  void setDeviceEnabled(bool enabled) {
    state = state.copyWith(deviceEnabled: enabled);
    _apply();
  }

  void selectEnvironment(Preset p) {
    state = state.copyWith(
      environmentPreset: p,
      loudnessComp: p.loudnessComp || (state.tastePreset?.loudnessComp ?? false),
    );
    _apply();
  }

  void selectTaste(Preset p) {
    state = state.copyWith(
      tastePreset: p,
      reverb: p.reverb,
      echo: p.echo,
      loudnessComp:
          p.loudnessComp || (state.environmentPreset?.loudnessComp ?? false),
    );
    _apply();
    // 배속이 없는 프리셋이어도 알려야 한다. 그래야 이전 프리셋이 걸어둔
    // 배속이 원래대로 돌아간다.
    onTastePresetTempo?.call(p);
  }

  /// 취향 층 곡선을 직접 고쳐 쓴다.
  ///
  /// 기기와 환경 층은 우리가 만들어 넣은 보정이라 사용자가 만지지 않는다.
  /// 내장 프리셋을 고친 결과는 아직 저장하지 않고 상태에만 둔다. 저장은
  /// [saveAsTastePreset]이 새 이름으로 받는다.
  void setTasteCurve(EqCurve eq) {
    final base = state.tastePreset;
    if (base == null) return;
    state = state.copyWith(tastePreset: base.copyWith(eq: eq));
    _apply();
  }

  // ── 개별 조절 ──────────────────────────────────────────────────────

  void setReverbWet(double v) {
    state = state.copyWith(reverb: state.reverb.copyWith(wet: v));
    _apply();
  }

  void setReverbRoomSize(double v) {
    state = state.copyWith(reverb: state.reverb.copyWith(roomSize: v));
    _apply();
  }

  /// 스테레오 넓이. BS2B 크로스피드가 엔진에 없어서 이 값으로 대신한다.
  void setWidth(double v) {
    state = state.copyWith(reverb: state.reverb.copyWith(width: v));
    _apply();
  }

  void setEchoWet(double v) {
    state = state.copyWith(echo: state.echo.copyWith(wet: v));
    _apply();
  }

  void setEchoDelay(double v) {
    state = state.copyWith(echo: state.echo.copyWith(delay: v));
    _apply();
  }

  void setLoudnessComp(bool v) {
    state = state.copyWith(loudnessComp: v);
    _apply();
  }

  /// 세 층과 개별 조절을 모두 처음 상태로 되돌린다.
  ///
  /// 프리셋을 몇 번 건드리면 지금 소리가 어디서 왔는지 알기 어려워진다.
  /// 확실하게 원점으로 돌아가는 길이 하나는 있어야 한다.
  Future<void> resetAll() async {
    final env = await _presets.byId('env_quiet');
    final taste = await _presets.byId('taste_none');
    if (!mounted) return;
    state = state.copyWith(
      environmentPreset: env,
      tastePreset: taste,
      reverb: ReverbSettings.off,
      echo: EchoSettings.off,
      loudnessComp: false,
      deviceEnabled: true,
      deviceAuto: true,
    );
    _apply();
    await refreshDevice();
    // 배속도 같이 되돌린다. 취향 프리셋이 걸어둔 값이 남으면 안 된다.
    if (taste != null) onTastePresetTempo?.call(taste);
  }

  /// 지금 상태를 새 취향 프리셋으로 저장한다.
  ///
  /// [tempo]를 주면 배속과 피치까지 프리셋에 담긴다. 나중에 이 프리셋을
  /// 고르면 소리와 속도가 한 번에 그때로 돌아온다.
  Future<Preset> saveAsTastePreset(
    String name, {
    String? author,
    TempoSettings? tempo,
  }) async {
    final id = 'taste_${DateTime.now().millisecondsSinceEpoch}';
    final base = state.tastePreset;
    final preset = Preset(
      id: id,
      name: name,
      layer: PresetLayer.taste,
      eq: base?.eq ?? EqCurve.flat,
      reverb: state.reverb,
      echo: state.echo,
      tempo: (tempo != null && !tempo.isNormal) ? tempo : base?.tempo,
      loudnessComp: state.loudnessComp,
      author: author,
      updatedAt: DateTime.now(),
    );
    await _presets.save(preset);
    state = state.copyWith(tastePreset: preset);
    return preset;
  }

  void _apply() {
    AudioEngine.instance.applyEffects(
      layers: state.layers,
      reverb: state.reverb,
      echo: state.echo,
      loudnessComp: state.loudnessComp,
    );
    _persistSoon();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _deviceSub?.cancel();
    super.dispose();
  }
}
