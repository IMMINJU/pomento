import 'dart:math' as math;

/// EQ 곡선의 한 항목. 주파수(Hz)와 이득(dB).
///
/// [bandwidthOct]가 0이면 곡선 위의 점이다. 점끼리 로그 주파수 축에서 이어
/// 곡선을 만든다. 내장 프리셋 19개가 이 방식으로 그려져 있다.
///
/// 0보다 크면 그 주파수를 가운데 둔 종 모양 밴드가 된다. 폭은 옥타브 단위다.
/// 1.0이면 중심 주파수의 절반에서 두 배까지 걸친다. 흔히 쓰는 파라메트릭
/// EQ와 같은 모양이고, 이쪽은 곡선 위에 더해진다.
///
/// 두 방식을 함께 두는 이유는 내장 프리셋을 그대로 두기 위해서다. 전부
/// 종 모양으로 바꾸면 이미 귀로 맞춰둔 19개의 소리가 다 달라진다.
class EqPoint {
  const EqPoint(this.freq, this.gainDb, {this.bandwidthOct = 0});

  final double freq;
  final double gainDb;

  /// 종 모양 밴드의 폭(옥타브). 0이면 곡선 위의 점이다.
  final double bandwidthOct;

  bool get isBell => bandwidthOct > 0;

  /// 이 밴드가 [freq]에 주는 이득. 곡선 위의 점이면 0이다.
  ///
  /// 옥타브 거리를 폭으로 나눈 값에 가우시안을 씌운다. 중심에서 폭의 절반쯤
  /// 떨어진 자리에서 이득이 절반으로 떨어진다.
  double bellGainAt(double at) {
    if (!isBell || freq <= 0 || at <= 0) return 0;
    final octaves = (math.log(at / freq) / math.ln2).abs();
    final t = octaves / (bandwidthOct / 2);
    // 4폭 밖은 0으로 잘라 쓸데없는 계산을 줄인다.
    if (t > 4) return 0;
    // t=1, 곧 중심에서 폭의 절반만큼 떨어진 자리에서 정확히 절반이 되도록
    // 2·ln2를 쓴다.
    return gainDb * math.exp(-0.5 * t * t * 2 * math.ln2);
  }

  EqPoint copyWith({double? freq, double? gainDb, double? bandwidthOct}) =>
      EqPoint(
        freq ?? this.freq,
        gainDb ?? this.gainDb,
        bandwidthOct: bandwidthOct ?? this.bandwidthOct,
      );

  Map<String, dynamic> toJson() => {
        'f': freq,
        'g': gainDb,
        if (bandwidthOct > 0) 'bw': bandwidthOct,
      };

  factory EqPoint.fromJson(Map<String, dynamic> j) => EqPoint(
        (j['f'] as num).toDouble(),
        (j['g'] as num).toDouble(),
        bandwidthOct: (j['bw'] as num?)?.toDouble() ?? 0,
      );

  @override
  String toString() => '${freq.toStringAsFixed(0)}Hz ${gainDb >= 0 ? '+' : ''}'
      '${gainDb.toStringAsFixed(1)}dB'
      '${isBell ? ' ${bandwidthOct.toStringAsFixed(1)}oct' : ''}';
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

  /// 곡선 위의 점들. 종 모양 밴드는 빼고 본다.
  List<EqPoint> get anchors =>
      points.where((p) => !p.isBell).toList()
        ..sort((a, b) => a.freq.compareTo(b.freq));

  /// 종 모양 밴드들.
  List<EqPoint> get bells => points.where((p) => p.isBell).toList();

  /// [freq]에서의 이득(dB).
  ///
  /// 곡선 위의 점은 이어서 보간하고, 종 모양 밴드는 그 위에 더한다.
  double gainAt(double freq) {
    var total = 0.0;
    for (final b in points) {
      if (b.isBell) total += b.bellGainAt(freq);
    }
    return total + _anchorGainAt(freq);
  }

  /// 점을 이어 만든 곡선의 값. 범위 밖은 양 끝 값을 그대로 쓴다.
  double _anchorGainAt(double freq) {
    final sorted = anchors;
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first.gainDb;

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

  EqCurve scaled(double factor) => EqCurve(
        points
            .map((p) => p.copyWith(gainDb: p.gainDb * factor))
            .toList(),
      );
}
