/// 속도 슬라이더가 훑는 폭.
///
/// DJ 피치 페이더가 ±8%인 이유와 같다. 1.0 근처만 쓰는 사람에게 0.5~2.0
/// 슬라이더를 주면 한 픽셀이 너무 크게 움직인다. 폭을 좁히면 같은 화면
/// 너비에서 해상도가 그만큼 올라간다.
enum SpeedRange {
  narrow(0.92, 1.08, '±8%'),
  medium(0.84, 1.16, '±16%'),
  wide(0.50, 2.00, '넓게');

  const SpeedRange(this.min, this.max, this.label);

  final double min;
  final double max;
  final String label;
}

/// 사용자가 바꿀 수 있는 조작 단위.
///
/// 미세 조정이 이 앱의 핵심이라 스테퍼 한 번이 얼마나 움직이는지를 사람마다
/// 다르게 잡아야 한다. 반음씩 옮기는 사람과 A=432Hz를 맞추는 사람이 원하는
/// 단위가 다르다.
class AppSettings {
  const AppSettings({
    this.speedStep = 0.05,
    this.pitchStepCents = 10,
    this.seekShortSeconds = 5,
    this.seekLongSeconds = 10,
    this.speedRange = SpeedRange.narrow,
    this.nudgePercent = 2.0,
    this.showGestureHint = true,
    this.keepScreenOn = false,
  });

  static const AppSettings defaults = AppSettings();

  /// 속도 스테퍼 한 번의 폭.
  final double speedStep;

  /// 피치 스테퍼 한 번의 폭(센트). 100이 반음 하나.
  final int pitchStepCents;

  /// 점프 탐색 짧은 쪽(초).
  final int seekShortSeconds;

  /// 점프 탐색 긴 쪽(초).
  final int seekLongSeconds;

  /// 속도 슬라이더가 훑는 폭.
  final SpeedRange speedRange;

  /// 넛지 버튼을 누르고 있는 동안 더해지는 폭(%).
  final double nudgePercent;

  /// 연습 화면에 두 손가락 제스처 안내를 띄울지.
  final bool showGestureHint;

  /// 앱을 보고 있는 동안 화면이 꺼지지 않게 할지.
  final bool keepScreenOn;

  static const List<double> speedStepChoices = [0.01, 0.02, 0.05, 0.10];
  static const List<int> pitchStepChoices = [1, 5, 10, 50, 100];
  static const List<int> seekChoices = [3, 5, 10, 15, 30, 60];
  static const List<double> nudgeChoices = [0.5, 1.0, 2.0, 5.0];

  AppSettings copyWith({
    double? speedStep,
    int? pitchStepCents,
    int? seekShortSeconds,
    int? seekLongSeconds,
    SpeedRange? speedRange,
    double? nudgePercent,
    bool? showGestureHint,
    bool? keepScreenOn,
  }) =>
      AppSettings(
        speedStep: speedStep ?? this.speedStep,
        pitchStepCents: pitchStepCents ?? this.pitchStepCents,
        seekShortSeconds: seekShortSeconds ?? this.seekShortSeconds,
        seekLongSeconds: seekLongSeconds ?? this.seekLongSeconds,
        speedRange: speedRange ?? this.speedRange,
        nudgePercent: nudgePercent ?? this.nudgePercent,
        showGestureHint: showGestureHint ?? this.showGestureHint,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.speedStep == speedStep &&
      other.pitchStepCents == pitchStepCents &&
      other.seekShortSeconds == seekShortSeconds &&
      other.seekLongSeconds == seekLongSeconds &&
      other.speedRange == speedRange &&
      other.nudgePercent == nudgePercent &&
      other.showGestureHint == showGestureHint &&
      other.keepScreenOn == keepScreenOn;

  @override
  int get hashCode => Object.hash(
        speedStep,
        pitchStepCents,
        seekShortSeconds,
        seekLongSeconds,
        speedRange,
        nudgePercent,
        showGestureHint,
        keepScreenOn,
      );
}
