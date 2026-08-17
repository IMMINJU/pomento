import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/eq_curve.dart';
import '../theme.dart';

/// 세 층의 EQ 곡선과 합산 결과를 겹쳐 그린다.
///
/// 이 그래프가 이펙트 화면의 핵심이다. 층을 따로 보여줘야 기기 보정과 취향이
/// 어떻게 더해져 지금 소리가 되는지 눈에 들어온다.
class EqGraph extends StatelessWidget {
  const EqGraph({
    super.key,
    required this.device,
    required this.environment,
    required this.taste,
    this.height = 130,
  });

  final EqCurve? device;
  final EqCurve? environment;
  final EqCurve? taste;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _EqGraphPainter(
          device: device,
          environment: environment,
          taste: taste,
        ),
      ),
    );
  }
}

class _EqGraphPainter extends CustomPainter {
  _EqGraphPainter({
    required this.device,
    required this.environment,
    required this.taste,
  });

  final EqCurve? device;
  final EqCurve? environment;
  final EqCurve? taste;

  static const double minFreq = 20;
  static const double maxFreq = 20000;
  static const double maxDb = 12;

  static const List<({double f, String label})> _freqLabels = [
    (f: 20, label: '20Hz'),
    (f: 100, label: '100'),
    (f: 500, label: '500'),
    (f: 2000, label: '2k'),
    (f: 10000, label: '10k'),
    (f: 20000, label: '20k'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 20.0;
    const padR = 8.0;
    const padT = 6.0;
    const padB = 20.0;
    final gw = size.width - padL - padR;
    final gh = size.height - padT - padB;
    final midY = padT + gh / 2;

    double fx(double f) =>
        padL +
        (math.log(f / minFreq) / math.log(maxFreq / minFreq)) * gw;
    double dbY(double db) => midY - (db.clamp(-maxDb, maxDb) / maxDb) * (gh / 2);

    // 0dB 기준선
    canvas.drawLine(
      Offset(padL, midY),
      Offset(size.width - padR, midY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1,
    );

    // ±6dB 안내선
    final guide = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (final db in [6.0, -6.0]) {
      _dashedLine(
        canvas,
        Offset(padL, dbY(db)),
        Offset(size.width - padR, dbY(db)),
        guide,
        dash: 3,
        gap: 6,
      );
    }

    // 주파수 세로 안내선
    final vGuide = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (final item in _freqLabels.sublist(1, _freqLabels.length - 1)) {
      final x = fx(item.f);
      canvas.drawLine(Offset(x, padT), Offset(x, size.height - padB), vGuide);
    }

    // 층별 곡선. 뒤로 갈수록 밝다.
    final layers = <({EqCurve? curve, double alpha})>[
      (curve: device, alpha: 0.35),
      (curve: environment, alpha: 0.45),
      (curve: taste, alpha: 0.55),
    ];
    for (final layer in layers) {
      final c = layer.curve;
      if (c == null || c.isFlat) continue;
      _dashedPath(
        canvas,
        _buildPath(c.gainAt, fx, dbY, padL, size.width - padR),
        Paint()
          ..color = Colors.white.withValues(alpha: layer.alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
    }

    // 합산 곡선
    final active = <EqCurve>[?device, ?environment, ?taste];
    final sumPath = _buildPath(
      (f) => EqCurve.sumGainAt(active, f),
      fx,
      dbY,
      padL,
      size.width - padR,
    );

    canvas.drawPath(
      sumPath,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.27)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      sumPath,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 합산 곡선 위의 조절점
    const handleFreqs = [60.0, 500.0, 1500.0, 5000.0, 12000.0];
    for (final f in handleFreqs) {
      final db = EqCurve.sumGainAt(active, f);
      final center = Offset(fx(f), dbY(db));
      canvas.drawCircle(
        center,
        4,
        Paint()..color = AppColors.accent,
      );
      canvas.drawCircle(
        center,
        4,
        Paint()
          ..color = AppColors.bgBase.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 축 라벨
    for (final item in _freqLabels) {
      _text(
        canvas,
        item.label,
        Offset(fx(item.f), size.height - 14),
        align: TextAlign.center,
      );
    }
    _text(canvas, '+12', Offset(padL - 18, dbY(12) - 4), align: TextAlign.left);
    _text(canvas, '0', Offset(padL - 18, midY - 4), align: TextAlign.left);
    _text(canvas, '-12', Offset(padL - 18, dbY(-12) - 10), align: TextAlign.left);
  }

  Path _buildPath(
    double Function(double freq) gain,
    double Function(double) fx,
    double Function(double) dbY,
    double left,
    double right,
  ) {
    final path = Path();
    const steps = 96;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final f = minFreq * math.pow(maxFreq / minFreq, t).toDouble();
      final x = fx(f);
      final y = dbY(gain(f));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  void _dashedPath(Canvas canvas, Path path, Paint paint,
      {double dash = 4, double gap = 4}) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dash = 3, double gap = 6}) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final next = math.min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * next, paint);
      d = next + gap;
    }
  }

  void _text(Canvas canvas, String text, Offset at,
      {TextAlign align = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          color: Colors.white.withValues(alpha: 0.30),
          fontFamily: 'Pretendard',
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.center => at.dx - tp.width / 2,
      TextAlign.right => at.dx - tp.width,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_EqGraphPainter old) =>
      old.device != device ||
      old.environment != environment ||
      old.taste != taste;
}

/// 프리셋 카드에 들어가는 작은 곡선 썸네일.
class MiniEqCurve extends StatelessWidget {
  const MiniEqCurve({
    super.key,
    required this.curve,
    this.width = 100,
    this.height = 28,
  });

  final EqCurve curve;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _MiniEqPainter(curve)),
      );
}

class _MiniEqPainter extends CustomPainter {
  const _MiniEqPainter(this.curve);

  final EqCurve curve;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const steps = 40;
    final mid = size.height / 2;
    // 미니 썸네일은 ±8dB 범위로 눌러 그린다.
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final f = 20 * math.pow(1000, t).toDouble();
      final db = curve.gainAt(f).clamp(-8.0, 8.0);
      final x = t * size.width;
      final y = mid - (db / 8) * (mid - 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MiniEqPainter old) => old.curve != curve;
}
