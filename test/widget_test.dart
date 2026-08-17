import 'package:flutter_test/flutter_test.dart';
import 'package:pomento/data/models/eq_curve.dart';
import 'package:pomento/data/models/tempo.dart';
import 'package:pomento/presets/builtin_presets.dart';

void main() {
  group('TempoSettings', () {
    test('연동 모드에서는 피치 필터를 쓰지 않는다', () {
      const t = TempoSettings(mode: TempoMode.linked, speed: 0.88);
      expect(t.needsPitchFilter, isFalse);
      // 0.88배로 느려지면 음이 약 2.2반음 내려간다.
      expect(t.impliedSemitones, closeTo(-2.21, 0.02));
    });

    test('고정 모드는 리샘플링이 만든 음 높이 변화를 상쇄한다', () {
      const t = TempoSettings(mode: TempoMode.independent, speed: 0.88);
      expect(t.needsPitchFilter, isTrue);
      expect(t.filterSemitones, closeTo(2.21, 0.02));
    });

    test('A=432Hz는 -31.8센트다', () {
      const t = TempoSettings(
        mode: TempoMode.independent,
        pitchCents: -31.8,
      );
      expect(t.filterSemitones, closeTo(-0.318, 0.001));
    });

    test('1.00배 원음은 아무 처리도 하지 않는다', () {
      expect(const TempoSettings().isNormal, isTrue);
      expect(const TempoSettings().needsPitchFilter, isFalse);
    });
  });

  group('EqCurve', () {
    test('로그 주파수 축에서 보간한다', () {
      const curve = EqCurve([EqPoint(100, 0), EqPoint(10000, 10)]);
      // 100과 10000의 로그 중간은 1000이다.
      expect(curve.gainAt(1000), closeTo(5, 0.01));
    });

    test('범위 밖은 양 끝 값을 쓴다', () {
      const curve = EqCurve([EqPoint(100, -3), EqPoint(1000, 4)]);
      expect(curve.gainAt(20), -3);
      expect(curve.gainAt(20000), 4);
    });

    test('여러 층을 dB 축에서 더한다', () {
      const a = EqCurve([EqPoint(1000, 2)]);
      const b = EqCurve([EqPoint(1000, 3)]);
      expect(EqCurve.sumGainAt([a, b], 1000), 5);
    });
  });

  group('BuiltinPresets', () {
    test('세 층이 모두 채워져 있다', () {
      expect(BuiltinPresets.device.length, 7);
      expect(BuiltinPresets.environment.length, 6);
      expect(BuiltinPresets.taste.length, 7);
    });

    test('id가 겹치지 않는다', () {
      final ids = BuiltinPresets.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('기기 매칭은 구체적인 항목을 먼저 고른다', () {
      // 블루투스로 붙은 버즈는 일반 블루투스가 아니라 버즈 보정을 써야 한다.
      expect(
        BuiltinPresets.matchDevice('bluetooth galaxy buds3 pro')?.id,
        'dev_buds',
      );
      expect(
        BuiltinPresets.matchDevice('bluetooth airpods pro')?.id,
        'dev_airpods',
      );
      expect(
        BuiltinPresets.matchDevice('bluetooth jbl flip')?.id,
        'dev_btspeaker',
      );
      expect(BuiltinPresets.matchDevice('speaker')?.id, 'dev_phone_speaker');
      expect(BuiltinPresets.matchDevice('wired')?.id, 'dev_wired');
    });

    test('폰 스피커 보정은 저역을 올리지 않는다', () {
      // 200Hz 아래가 안 나오는 스피커에 저역을 밀어넣으면 왜곡만 생긴다.
      final p = BuiltinPresets.device.firstWhere(
        (e) => e.id == 'dev_phone_speaker',
      );
      expect(p.eq.gainAt(50), lessThan(0));
      expect(p.eq.gainAt(2000), greaterThan(0));
    });

    test('지하철 보정은 저역이 아니라 중역 명료도를 올린다', () {
      final p = BuiltinPresets.environment.firstWhere(
        (e) => e.id == 'env_subway',
      );
      expect(p.eq.gainAt(50), lessThan(0));
      expect(p.eq.gainAt(3000), greaterThan(2));
    });
  });
}
