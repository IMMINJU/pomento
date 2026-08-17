import 'eq_curve.dart';
import 'tempo.dart';

/// 프리셋이 속한 층.
///
/// 세 층의 EQ를 dB 축에서 더해서 최종 곡선을 만든다. 층을 나눈 이유는 기기
/// 보정과 취향을 분리하기 위해서다. 취향만 두 사람이 공유하고 기기 보정은
/// 각자 폰에 남는다. 완성된 곡선을 통째로 주고받으면 상대 기기에서 어긋난다.
enum PresetLayer {
  /// 출력 기기의 주파수 특성을 되돌리는 보정. 자동 전환되고 공유하지 않는다.
  device,

  /// 소음 환경 보정.
  environment,

  /// 장르와 취향. 이 층만 공유한다.
  taste;

  String get label => switch (this) {
        PresetLayer.device => '기기',
        PresetLayer.environment => '환경',
        PresetLayer.taste => '취향',
      };

  /// 두 사람 사이에 동기화할 층인지.
  bool get shareable => this == PresetLayer.taste;
}

/// 리버브 설정. 엔진의 freeverb 필터에 대응한다.
class ReverbSettings {
  const ReverbSettings({
    this.wet = 0.0,
    this.roomSize = 0.5,
    this.damp = 0.5,
    this.width = 1.0,
  });

  static const ReverbSettings off = ReverbSettings();

  /// 섞이는 정도 0~1.
  final double wet;

  /// 공간 크기 0~1.
  final double roomSize;

  /// 고역 감쇠 0~1.
  final double damp;

  /// 스테레오 넓이 0~1. BS2B 크로스피드가 엔진에 없어서 이 값으로 대신한다.
  final double width;

  bool get isOff => wet <= 0.001;

  ReverbSettings copyWith({
    double? wet,
    double? roomSize,
    double? damp,
    double? width,
  }) =>
      ReverbSettings(
        wet: wet ?? this.wet,
        roomSize: roomSize ?? this.roomSize,
        damp: damp ?? this.damp,
        width: width ?? this.width,
      );

  Map<String, dynamic> toJson() =>
      {'wet': wet, 'roomSize': roomSize, 'damp': damp, 'width': width};

  factory ReverbSettings.fromJson(Map<String, dynamic> j) => ReverbSettings(
        wet: (j['wet'] as num?)?.toDouble() ?? 0.0,
        roomSize: (j['roomSize'] as num?)?.toDouble() ?? 0.5,
        damp: (j['damp'] as num?)?.toDouble() ?? 0.5,
        width: (j['width'] as num?)?.toDouble() ?? 1.0,
      );
}

/// 에코 설정. 엔진의 echo 필터에 대응한다.
class EchoSettings {
  const EchoSettings({
    this.wet = 0.0,
    this.delay = 0.3,
    this.decay = 0.5,
  });

  static const EchoSettings off = EchoSettings();

  final double wet;

  /// 지연 시간(초). 엔진 최솟값이 0.001이다.
  final double delay;

  /// 감쇠 0.001~1.
  final double decay;

  bool get isOff => wet <= 0.001;

  EchoSettings copyWith({double? wet, double? delay, double? decay}) =>
      EchoSettings(
        wet: wet ?? this.wet,
        delay: delay ?? this.delay,
        decay: decay ?? this.decay,
      );

  Map<String, dynamic> toJson() => {'wet': wet, 'delay': delay, 'decay': decay};

  factory EchoSettings.fromJson(Map<String, dynamic> j) => EchoSettings(
        wet: (j['wet'] as num?)?.toDouble() ?? 0.0,
        delay: (j['delay'] as num?)?.toDouble() ?? 0.3,
        decay: (j['decay'] as num?)?.toDouble() ?? 0.5,
      );
}

/// 음향 프리셋 한 벌.
class Preset {
  const Preset({
    required this.id,
    required this.name,
    required this.layer,
    this.eq = EqCurve.flat,
    this.reverb = ReverbSettings.off,
    this.echo = EchoSettings.off,
    this.tempo,
    this.loudnessComp = false,
    this.deviceMatch,
    this.author,
    this.builtin = false,
    this.updatedAt,
  });

  final String id;
  final String name;
  final PresetLayer layer;
  final EqCurve eq;
  final ReverbSettings reverb;
  final EchoSettings echo;

  /// 취향 층에서만 쓴다. 프리셋을 고르면 배속까지 같이 걸린다.
  final TempoSettings? tempo;

  /// 볼륨이 낮을 때 저역과 고역을 보강한다(등청감 보정).
  final bool loudnessComp;

  /// 기기 층에서 어떤 출력 기기에 붙는 보정인지. 부분 일치로 찾는다.
  final String? deviceMatch;

  final String? author;
  final bool builtin;
  final DateTime? updatedAt;

  Preset copyWith({
    String? id,
    String? name,
    PresetLayer? layer,
    EqCurve? eq,
    ReverbSettings? reverb,
    EchoSettings? echo,
    TempoSettings? tempo,
    bool clearTempo = false,
    bool? loudnessComp,
    String? deviceMatch,
    String? author,
    bool? builtin,
    DateTime? updatedAt,
  }) =>
      Preset(
        id: id ?? this.id,
        name: name ?? this.name,
        layer: layer ?? this.layer,
        eq: eq ?? this.eq,
        reverb: reverb ?? this.reverb,
        echo: echo ?? this.echo,
        tempo: clearTempo ? null : (tempo ?? this.tempo),
        loudnessComp: loudnessComp ?? this.loudnessComp,
        deviceMatch: deviceMatch ?? this.deviceMatch,
        author: author ?? this.author,
        builtin: builtin ?? this.builtin,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// 목록에서 한 줄로 보여줄 요약.
  String get summary {
    final parts = <String>[];
    if (tempo != null && !tempo!.isNormal) parts.add(tempo.toString());
    if (!reverb.isOff) {
      parts.add('리버브 ${(reverb.wet * 100).round()}%');
    }
    if (!echo.isOff) parts.add('에코 ${(echo.wet * 100).round()}%');
    if (loudnessComp) parts.add('등청감 보정');
    if (parts.isEmpty && !eq.isFlat) parts.add('EQ ${eq.points.length}점');
    return parts.isEmpty ? '변화 없음' : parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'layer': layer.name,
        'eq': eq.toJson(),
        'reverb': reverb.toJson(),
        'echo': echo.toJson(),
        if (tempo != null) 'tempo': tempo!.toJson(),
        'loudnessComp': loudnessComp,
        if (deviceMatch != null) 'deviceMatch': deviceMatch,
        if (author != null) 'author': author,
        'builtin': builtin,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory Preset.fromJson(Map<String, dynamic> j) => Preset(
        id: j['id'] as String,
        name: j['name'] as String,
        layer: PresetLayer.values.firstWhere(
          (l) => l.name == j['layer'],
          orElse: () => PresetLayer.taste,
        ),
        eq: j['eq'] == null
            ? EqCurve.flat
            : EqCurve.fromJson(j['eq'] as List<dynamic>),
        reverb: j['reverb'] == null
            ? ReverbSettings.off
            : ReverbSettings.fromJson(
                Map<String, dynamic>.from(j['reverb'] as Map)),
        echo: j['echo'] == null
            ? EchoSettings.off
            : EchoSettings.fromJson(
                Map<String, dynamic>.from(j['echo'] as Map)),
        tempo: j['tempo'] == null
            ? null
            : TempoSettings.fromJson(
                Map<String, dynamic>.from(j['tempo'] as Map)),
        loudnessComp: j['loudnessComp'] as bool? ?? false,
        deviceMatch: j['deviceMatch'] as String?,
        author: j['author'] as String?,
        builtin: j['builtin'] as bool? ?? false,
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.tryParse(j['updatedAt'] as String),
      );
}
