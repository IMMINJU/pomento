import 'dart:math' as math;

/// EQ 곡선 위의 한 점. 주파수(Hz)와 이득(dB).
class EqPoint {
  const EqPoint(this.freq, this.gainDb);

  final double freq;
  final double gainDb;

  Map<String, dynamic> toJson() => {'f': freq, 'g': gainDb};

  factory EqPoint.fromJson(Map<String, dynamic> j) =>
      EqPoint((j['f'] as num).toDouble(), (j['g'] as num).toDouble());

  @override
  String toString() => '${freq.toStringAsFixed(0)}Hz ${gainDb >= 0 ? '+' : ''}'
      '${gainDb.toStringAsFixed(1)}dB';
}

/// 주파수별 이득 곡선.
///
/// 엔진의 파라메트릭 EQ는 밴드 중심 주파수가 30Hz~16kHz 로그 분포로 고정돼
/// 있다. 프리셋은 임의 주파수의 점으로 정의하고, 엔진에 넣을 때 밴드 중심에서
/// 값을 뽑아 쓴다. 보간은 로그 주파수 축에서 선형으로 한다.
class EqCurve {
  const EqCurve(this.points);

  final List<EqPoint> points;

  static const EqCurve flat = EqCurve([]);

  bool get isFlat => points.isEmpty || points.every((p) => p.gainDb == 0);

  /// [freq]에서의 이득(dB). 범위 밖은 양 끝 값을 그대로 쓴다.
  double gainAt(double freq) {
    if (points.isEmpty) return 0;
    if (points.length == 1) return points.first.gainDb;

    final sorted = [...points]..sort((a, b) => a.freq.compareTo(b.freq));
    if (freq <= sorted.first.freq) return sorted.first.gainDb;
    if (freq >= sorted.last.freq) return sorted.last.gainDb;

    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (freq >= a.freq && freq <= b.freq) {
        final la = math.log(a.freq);
        final lb = math.log(b.freq);
        final lf = math.log(freq);
        if (lb - la == 0) return a.gainDb;
        final t = (lf - la) / (lb - la);
        return a.gainDb + (b.gainDb - a.gainDb) * t;
      }
    }
    return 0;
  }

  /// 여러 층의 곡선을 dB 축에서 더한다.
  static double sumGainAt(Iterable<EqCurve> curves, double freq) {
    var total = 0.0;
    for (final c in curves) {
      total += c.gainAt(freq);
    }
    return total;
  }

  List<Map<String, dynamic>> toJson() => points.map((p) => p.toJson()).toList();

  factory EqCurve.fromJson(List<dynamic> j) => EqCurve(
        j
            .map((e) => EqPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  EqCurve scaled(double factor) =>
      EqCurve(points.map((p) => EqPoint(p.freq, p.gainDb * factor)).toList());
}
