import '../data/models/eq_curve.dart';
import '../data/models/preset.dart';
import '../data/models/tempo.dart';

/// 기본 제공 프리셋.
///
/// 세 층을 곱하면 조합이 수백 가지가 되므로 층마다 몇 개씩만 만든다.
/// 기기 7 + 환경 6 + 취향 6 = 19개로 252가지 조합이 나온다.
class BuiltinPresets {
  const BuiltinPresets._();

  static List<Preset> get all => [...device, ...environment, ...taste];

  // ── 1층: 기기 보정 ────────────────────────────────────────────────
  //
  // 출력 기기의 튜닝을 평탄하게 되돌리는 방향으로 만든다. 연결된 기기를
  // 감지해 자동으로 걸리고, 두 사람 사이에 공유하지 않는다. 같은 곡선을
  // 서로 다른 이어폰에 걸면 어긋나기 때문이다.
  //
  // deviceMatch는 감지된 기기 설명 문자열에 대한 부분 일치다. 목록 앞쪽이
  // 더 구체적인 항목이라 먼저 검사한다.

  static const List<Preset> device = [
    Preset(
      id: 'dev_airpods',
      layer: PresetLayer.device,
      name: 'AirPods',
      deviceMatch: 'airpods',
      builtin: true,
      eq: EqCurve([
        EqPoint(40, -1.0),
        EqPoint(80, -2.0),
        EqPoint(150, -1.5),
        EqPoint(400, 0),
        EqPoint(1000, 0),
        EqPoint(3000, 0.5),
        EqPoint(8000, 0),
        EqPoint(16000, 0),
      ]),
    ),
    Preset(
      id: 'dev_buds',
      layer: PresetLayer.device,
      name: 'Galaxy Buds',
      deviceMatch: 'buds',
      builtin: true,
      eq: EqCurve([
        EqPoint(40, 0),
        EqPoint(100, -0.5),
        EqPoint(500, 0),
        EqPoint(2000, 0.5),
        EqPoint(4000, -2.0),
        EqPoint(6000, -1.5),
        EqPoint(10000, 0),
      ]),
    ),
    Preset(
      id: 'dev_wired',
      layer: PresetLayer.device,
      name: '유선 이어폰',
      deviceMatch: 'wired',
      builtin: true,
      eq: EqCurve([
        EqPoint(60, 0.5),
        EqPoint(200, 0),
        EqPoint(1000, 0),
        EqPoint(5000, 0),
        EqPoint(12000, 0.5),
      ]),
    ),
    Preset(
      id: 'dev_overear',
      layer: PresetLayer.device,
      name: '오버이어 헤드폰',
      deviceMatch: 'overear',
      builtin: true,
      eq: EqCurve([
        EqPoint(40, 0),
        EqPoint(200, 0),
        EqPoint(1000, 0),
        EqPoint(2500, 1.0),
        EqPoint(6000, 0),
        EqPoint(12000, 0.5),
      ]),
    ),
    Preset(
      id: 'dev_car',
      layer: PresetLayer.device,
      name: '차량',
      deviceMatch: 'car',
      builtin: true,
      eq: EqCurve([
        EqPoint(60, -2.0),
        EqPoint(150, -1.5),
        EqPoint(400, 1.0),
        EqPoint(1500, 2.0),
        EqPoint(4000, 1.5),
        EqPoint(10000, 1.0),
      ]),
    ),
    Preset(
      id: 'dev_btspeaker',
      layer: PresetLayer.device,
      name: '블루투스 스피커',
      deviceMatch: 'bluetooth',
      builtin: true,
      eq: EqCurve([
        EqPoint(50, -2.0),
        EqPoint(120, -2.5),
        EqPoint(400, 0),
        EqPoint(2000, 0.5),
        EqPoint(8000, 0.5),
      ]),
    ),
    // 폰 스피커는 200Hz 아래가 사실상 안 나온다. 저역을 올려도 소리는 안
    // 커지고 왜곡만 생기므로 잘라내고, 중역 쪽에서 두께와 명료도를 만든다.
    Preset(
      id: 'dev_phone_speaker',
      layer: PresetLayer.device,
      name: '폰 스피커',
      deviceMatch: 'speaker',
      builtin: true,
      eq: EqCurve([
        EqPoint(30, -6.0),
        EqPoint(80, -5.0),
        EqPoint(150, -2.0),
        EqPoint(300, 2.0),
        EqPoint(800, 1.0),
        EqPoint(2000, 2.0),
        EqPoint(5000, 1.0),
        EqPoint(10000, 0),
      ]),
    ),
  ];

  // ── 2층: 환경 보정 ────────────────────────────────────────────────

  static const List<Preset> environment = [
    Preset(
      id: 'env_quiet',
      layer: PresetLayer.environment,
      name: '조용한 실내',
      builtin: true,
    ),
    // 지하철 소음은 저역이다. 저역을 더 올리면 소음과 겹쳐 뭉개진다.
    // 소음에 묻히는 건 중역 명료도라 그쪽을 올린다.
    Preset(
      id: 'env_subway',
      layer: PresetLayer.environment,
      name: '지하철',
      builtin: true,
      eq: EqCurve([
        EqPoint(30, -4.0),
        EqPoint(80, -3.0),
        EqPoint(200, -1.0),
        EqPoint(800, 1.0),
        EqPoint(1500, 3.0),
        EqPoint(3000, 3.5),
        EqPoint(5000, 2.0),
        EqPoint(10000, 0),
      ]),
    ),
    Preset(
      id: 'env_cafe',
      layer: PresetLayer.environment,
      name: '카페',
      builtin: true,
      eq: EqCurve([
        EqPoint(50, -1.5),
        EqPoint(200, 0),
        EqPoint(1000, 1.5),
        EqPoint(2500, 2.0),
        EqPoint(6000, 1.0),
      ]),
    ),
    Preset(
      id: 'env_outdoor',
      layer: PresetLayer.environment,
      name: '야외',
      builtin: true,
      eq: EqCurve([
        EqPoint(40, -3.0),
        EqPoint(100, -1.5),
        EqPoint(500, 0),
        EqPoint(2000, 2.0),
        EqPoint(4000, 1.5),
        EqPoint(8000, 0),
      ]),
    ),
    Preset(
      id: 'env_workout',
      layer: PresetLayer.environment,
      name: '운동',
      builtin: true,
      eq: EqCurve([
        EqPoint(50, 3.0),
        EqPoint(100, 2.5),
        EqPoint(300, -1.0),
        EqPoint(1000, 0),
        EqPoint(3000, 1.5),
        EqPoint(8000, 1.0),
      ]),
    ),
    // 작은 볼륨에서는 귀가 저역과 고역을 덜 듣는다(등청감곡선). 고역을
    // 부드럽게 깎고 등청감 보정을 켜서 밤에 작게 틀어도 얇아지지 않게 한다.
    Preset(
      id: 'env_bedtime',
      layer: PresetLayer.environment,
      name: '잠들기 전',
      builtin: true,
      loudnessComp: true,
      eq: EqCurve([
        EqPoint(40, 1.0),
        EqPoint(150, 1.0),
        EqPoint(800, 0),
        EqPoint(3000, -2.0),
        EqPoint(6000, -4.0),
        EqPoint(12000, -6.0),
      ]),
    ),
  ];

  // ── 3층: 취향 ─────────────────────────────────────────────────────
  //
  // 이 층만 두 사람이 공유한다.

  static const List<Preset> taste = [
    Preset(
      id: 'taste_none',
      layer: PresetLayer.taste,
      name: '원음',
      builtin: true,
    ),
    Preset(
      id: 'taste_classic',
      layer: PresetLayer.taste,
      name: '클래식',
      builtin: true,
      eq: EqCurve([
        EqPoint(40, -0.5),
        EqPoint(200, 0),
        EqPoint(1000, 0),
        EqPoint(4000, 0.5),
        EqPoint(10000, 1.5),
      ]),
    ),
    Preset(
      id: 'taste_acoustic',
      layer: PresetLayer.taste,
      name: '재즈·어쿠스틱',
      builtin: true,
      eq: EqCurve([
        EqPoint(60, 1.0),
        EqPoint(200, 1.0),
        EqPoint(800, 0.5),
        EqPoint(3000, 0.5),
        EqPoint(10000, 1.0),
      ]),
    ),
    Preset(
      id: 'taste_pop',
      layer: PresetLayer.taste,
      name: '팝',
      builtin: true,
      eq: EqCurve([
        EqPoint(60, 2.0),
        EqPoint(200, 0),
        EqPoint(1000, -0.5),
        EqPoint(3000, 1.0),
        EqPoint(10000, 2.0),
      ]),
    ),
    Preset(
      id: 'taste_bass',
      layer: PresetLayer.taste,
      name: '힙합·EDM',
      builtin: true,
      eq: EqCurve([
        EqPoint(40, 4.0),
        EqPoint(80, 3.0),
        EqPoint(200, 0),
        EqPoint(1000, -1.0),
        EqPoint(4000, 1.0),
        EqPoint(10000, 2.0),
      ]),
    ),
    Preset(
      id: 'taste_vocal',
      layer: PresetLayer.taste,
      name: '보컬',
      builtin: true,
      eq: EqCurve([
        EqPoint(60, -1.5),
        EqPoint(200, 0),
        EqPoint(800, 1.5),
        EqPoint(2500, 2.5),
        EqPoint(5000, 1.0),
        EqPoint(10000, 0),
      ]),
    ),
    // 연동 배속으로 느리게 하면 음이 같이 내려가 소리가 두꺼워진다.
    // 거기에 리버브를 얹은 조합.
    Preset(
      id: 'taste_slowed',
      layer: PresetLayer.taste,
      name: '밤에 느리게',
      builtin: true,
      tempo: TempoSettings(mode: TempoMode.linked, speed: 0.88),
      reverb: ReverbSettings(wet: 0.30, roomSize: 0.6, damp: 0.4),
      eq: EqCurve([
        EqPoint(40, 1.5),
        EqPoint(150, 1.0),
        EqPoint(1000, 0),
        EqPoint(4000, -1.5),
        EqPoint(10000, -2.5),
      ]),
    ),
  ];

  /// 감지된 출력 기기 설명에 맞는 기기 프리셋을 찾는다.
  /// 목록 앞쪽이 더 구체적이므로 순서대로 검사한다.
  static Preset? matchDevice(String descriptor) {
    final d = descriptor.toLowerCase();
    for (final p in device) {
      final token = p.deviceMatch;
      if (token != null && d.contains(token)) return p;
    }
    return null;
  }
}
