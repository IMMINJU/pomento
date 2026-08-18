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

  // Capriccio의 Parametric EQ 그래프와 같은 축이다. 가로는 32Hz에서 16kHz를
  // 한 옥타브씩, 세로는 ±10dB에 5dB 눈금.
  static const double minFreq = 32;
  static const double maxFreq = 16000;
  static const double maxDb = 12;

  static const List<({double f, String label})> _freqLabels = [
    (f: 32, label: '32'),
    (f: 64, label: '64'),
    (f: 128, label: '128'),
    (f: 256, label: '256'),
    (f: 512, label: '512'),
    (f: 1000, label: '1K'),
    (f: 2000, label: '2K'),
    (f: 4000, label: '4K'),
    (f: 8000, label: '8K'),
    (f: 16000, label: '16K'),
  ];

  static const List<double> _dbLines = [10, 5, 0, -5, -10];

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 32.0;
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

    // dB 격자. 0dB만 진하게 둔다.
    final guide = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final zero = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (final db in _dbLines) {
      canvas.drawLine(
        Offset(padL, dbY(db)),
        Offset(size.width - padR, dbY(db)),
        db == 0 ? zero : guide,
      );
    }

    // 주파수 세로 안내선
    final vGuide = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (final item in _freqLabels) {
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
    for (final db in _dbLines) {
      _text(
        canvas,
        '${db.toStringAsFixed(0)} dB',
        Offset(padL - 4, dbY(db) - 5),
        align: TextAlign.right,
      );
    }
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
