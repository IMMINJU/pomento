import 'package:flutter_test/flutter_test.dart';
import 'package:pomento/data/models/eq_curve.dart';

void main() {
  group('대역폭이 없는 점', () {
    test('예전처럼 점을 이어 보간한다', () {
      const curve = EqCurve([EqPoint(100, 0), EqPoint(1000, 6)]);
      // 로그 축에서 딱 가운데인 316Hz에서 절반이 나온다.
      expect(curve.gainAt(316.2), closeTo(3, 0.05));
    });

    test('범위 밖은 양 끝 값을 쓴다', () {
      const curve = EqCurve([EqPoint(100, -3), EqPoint(1000, 6)]);
      expect(curve.gainAt(20), -3);
      expect(curve.gainAt(16000), 6);
    });
  });

  group('종 모양 밴드', () {
    test('중심에서 지정한 이득이 그대로 나온다', () {
      const curve = EqCurve([EqPoint(1000, 6, bandwidthOct: 1)]);
      expect(curve.gainAt(1000), closeTo(6, 0.001));
    });

    test('폭의 절반만큼 떨어진 자리에서 절반으로 준다', () {
      // 1옥타브 폭이면 반옥타브 떨어진 707Hz와 1414Hz에서 절반이다.
      const curve = EqCurve([EqPoint(1000, 6, bandwidthOct: 1)]);
      expect(curve.gainAt(1414), closeTo(3, 0.1));
      expect(curve.gainAt(707), closeTo(3, 0.1));
    });

    test('폭을 좁히면 같은 거리에서 더 빨리 준다', () {
      const wide = EqCurve([EqPoint(1000, 6, bandwidthOct: 2)]);
      const narrow = EqCurve([EqPoint(1000, 6, bandwidthOct: 0.5)]);
      expect(narrow.gainAt(1414), lessThan(wide.gainAt(1414)));
    });

    test('멀리 떨어지면 0으로 잘린다', () {
      const curve = EqCurve([EqPoint(1000, 6, bandwidthOct: 0.5)]);
      expect(curve.gainAt(60), 0);
    });

    test('밴드끼리는 dB 축에서 더해진다', () {
      const curve = EqCurve([
        EqPoint(1000, 3, bandwidthOct: 1),
        EqPoint(1000, 2, bandwidthOct: 1),
      ]);
      expect(curve.gainAt(1000), closeTo(5, 0.001));
    });
  });

  group('두 방식을 섞으면', () {
    test('곡선 위에 종 모양이 더해진다', () {
      const curve = EqCurve([
        EqPoint(100, 2),
        EqPoint(10000, 2),
        EqPoint(1000, 4, bandwidthOct: 1),
      ]);
      // 곡선은 어디서나 2dB, 그 위에 1kHz 종이 4dB.
      expect(curve.gainAt(1000), closeTo(6, 0.05));
      expect(curve.gainAt(100), closeTo(2, 0.05));
    });

    test('종 모양만 있으면 곡선은 평탄하다', () {
      const curve = EqCurve([EqPoint(1000, 4, bandwidthOct: 1)]);
      expect(curve.gainAt(60), 0);
    });
  });

  test('JSON은 대역폭이 있을 때만 담는다', () {
    expect(const EqPoint(100, 3).toJson().containsKey('bw'), isFalse);
    expect(
      const EqPoint(100, 3, bandwidthOct: 1.5).toJson()['bw'],
      1.5,
    );
    final back = EqPoint.fromJson(
      const EqPoint(100, 3, bandwidthOct: 1.5).toJson(),
    );
    expect(back.bandwidthOct, 1.5);
    expect(EqPoint.fromJson(const {'f': 100, 'g': 3}).bandwidthOct, 0);
  });
}
