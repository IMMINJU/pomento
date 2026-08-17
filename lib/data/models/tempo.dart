import 'dart:math' as math;

/// 배속을 다루는 두 방식.
enum TempoMode {
  /// 리샘플링. 속도와 음 높이가 같이 움직인다. LP판 회전수를 바꾸는 것과 같고
  /// 원리상 음질 손실이 없다.
  linked,

  /// 타임스트레치. 음 높이를 붙잡고 시간만 늘리거나 줄인다. 1.0에서 멀어질수록
  /// 잡음이 생긴다.
  independent;

  String get label => switch (this) {
        TempoMode.linked => '연동',
        TempoMode.independent => '고정',
      };

  String get hint => switch (this) {
        TempoMode.linked => '속도를 바꾸면 음이 같이 움직입니다',
        TempoMode.independent => '음 높이를 유지합니다',
      };
}

/// 배속과 피치 설정 한 벌.
class TempoSettings {
  const TempoSettings({
    this.mode = TempoMode.linked,
    this.speed = 1.0,
    this.pitchCents = 0.0,
  });

  static const TempoSettings normal = TempoSettings();

  final TempoMode mode;

  /// 재생 속도 배수. 0.5 ~ 1.5 범위를 UI에서 쓴다.
  final double speed;

  /// 사용자가 추가로 준 피치 오프셋(센트). 고정 모드에서만 의미가 있다.
  /// 100센트 = 반음 하나. A=432Hz로 맞추려면 -31.8.
  final double pitchCents;

  bool get isNormal => speed == 1.0 && pitchCents == 0.0;

  /// 연동 모드에서 배속 때문에 따라 움직인 음 높이(반음).
  double get impliedSemitones => 12 * (math.log(speed) / math.ln2);

  /// 엔진의 pitchShift 필터에 넣을 반음 값.
  ///
  /// 연동 모드에서는 리샘플링이 만든 음 높이 변화를 그대로 두므로 사용자
  /// 오프셋만 적용한다. 고정 모드에서는 그 변화를 상쇄해야 원래 음이 된다.
  double get filterSemitones {
    final user = pitchCents / 100.0;
    return switch (mode) {
      TempoMode.linked => user,
      TempoMode.independent => -impliedSemitones + user,
    };
  }

  /// 피치 필터를 켤 필요가 있는지. 꺼둘 수 있으면 꺼야 음질에 이롭다.
  bool get needsPitchFilter => filterSemitones.abs() > 0.001;

  TempoSettings copyWith({
    TempoMode? mode,
    double? speed,
    double? pitchCents,
  }) =>
      TempoSettings(
        mode: mode ?? this.mode,
        speed: speed ?? this.speed,
        pitchCents: pitchCents ?? this.pitchCents,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'speed': speed,
        'pitchCents': pitchCents,
      };

  factory TempoSettings.fromJson(Map<String, dynamic> j) => TempoSettings(
        mode: TempoMode.values.firstWhere(
          (m) => m.name == j['mode'],
          orElse: () => TempoMode.linked,
        ),
        speed: (j['speed'] as num?)?.toDouble() ?? 1.0,
        pitchCents: (j['pitchCents'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  bool operator ==(Object other) =>
      other is TempoSettings &&
      other.mode == mode &&
      other.speed == speed &&
      other.pitchCents == pitchCents;

  @override
  int get hashCode => Object.hash(mode, speed, pitchCents);

  @override
  String toString() =>
      '${speed.toStringAsFixed(2)}x ${mode.label}'
      '${pitchCents == 0 ? '' : ' ${pitchCents > 0 ? '+' : ''}'
          '${pitchCents.toStringAsFixed(0)}c'}';
}
