import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../theme.dart';
import 'artwork.dart';

/// 자켓에서 뽑은 색.
///
/// 예전에는 자켓 평균 밝기를 재서 유리 불투명도를 올렸다. 유리를 걷어냈으니
/// 그 값은 필요 없다. 지금 필요한 것은 두 가지다.
///
/// **앰비언트 판의 두 색.** 자켓 한 장을 뭉개서 깔면 색이 하나로 섞여서
/// 판 안에서 밝기만 오르내린다. 대신 색상 두 개를 뽑아 **명도를 같게**
/// 맞춘다. 명도가 같으면 두 색이 만나는 자리에 경계가 안 생긴다. 눈은
/// 밝기 차이로 경계를 잡는데 그것이 없으니 색상으로만 구분하고, 그래서
/// 두 색이 서로 밀어내는 것처럼 보인다.
///
/// **채움색.** 진행선과 상단바 큐 밑줄, 미니 진행선에 쓴다. 글자에는
/// 쓰지 않는다. 값과 조작부는 [AppColors.accent]가 맡는다. 자켓에서 온
/// 색이 글자까지 칠하면 곡이 바뀔 때마다 화면 전체가 같이 흔들린다.
@immutable
class CoverTone {
  const CoverTone({
    required this.plateA,
    required this.plateB,
    required this.plateBase,
    required this.fill,
  });

  /// 자켓을 아직 못 읽었거나 없는 경우. 시안의 기본값과 같다.
  static const CoverTone fallback = CoverTone(
    plateA: Color(0xFF6E90BE),
    plateB: Color(0xFFC08872),
    plateBase: Color(0xFF95A099),
    fill: AppColors.cover,
  );

  /// 판 왼쪽 위와 오른쪽 아래. 둘의 L*가 같다.
  final Color plateA;
  final Color plateB;

  /// 두 색 사이를 메우는 바탕. 한 단계 밝고 채도가 낮다.
  final Color plateBase;

  /// 채움에만 쓴다. 진행선, 상단바 큐 밑줄, 미니 진행선, 미니 바탕.
  final Color fill;

  @override
  bool operator ==(Object other) =>
      other is CoverTone &&
      other.plateA == plateA &&
      other.plateB == plateB &&
      other.plateBase == plateBase &&
      other.fill == fill;

  @override
  int get hashCode => Object.hash(plateA, plateB, plateBase, fill);
}

/// 판의 밝기. 등명도는 두 색이 서로 같으면 되는 것이지 특정 값일 이유가
/// 없다. 74로 두었더니 자켓이 바뀌어도 화면이 별로 안 달라져서 내렸다.
/// 어두울수록 sRGB에서 채도를 더 쓸 수 있어 색이 확실히 보인다.
const double _plateL = 62;

/// 채움색의 명도. 종이 위 2px 선이라 이 정도면 보인다.
const double _fillL = 46;

/// 자켓에서 색 둘을 뽑는다.
///
/// 32×32로 줄여 읽고 색상환을 24칸으로 나눈다. 채도가 낮은 픽셀은 색상이
/// 불안정하므로 채도를 가중치로 준다. 두 번째 색은 첫 번째와 색상이 충분히
/// 떨어진 칸 중에서 고른다. 같은 색상 두 개를 L*만 맞춰 놓으면 그냥 단색이다.
class CoverAnalyzer {
  const CoverAnalyzer._();

  static final Map<String, CoverTone> _cache = {};

  static Future<CoverTone> of(String path) async {
    final cached = _cache[path];
    if (cached != null) return cached;

    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      final frame = await codec.getNextFrame();
      final data =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return CoverTone.fallback;

      final tone = _analyze(data.buffer.asUint8List());
      _cache[path] = tone;
      return tone;
    } catch (_) {
      return CoverTone.fallback;
    }
  }

  /// 파일이 아니라 바이트로 들어온 자켓. Spotify 자켓이 이쪽이다.
  ///
  /// 같은 그림을 두 번 재지 않게 열쇠로 캐시한다. Spotify는 이미지 id를
  /// 주므로 그것을 쓴다.
  static Future<CoverTone> ofBytes(String key, Uint8List bytes) async {
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      final frame = await codec.getNextFrame();
      final data =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return CoverTone.fallback;
      final tone = _analyze(data.buffer.asUint8List());
      _cache[key] = tone;
      return tone;
    } catch (_) {
      return CoverTone.fallback;
    }
  }

  static CoverTone _analyze(Uint8List px) {
    const bins = 24;
    final weight = List<double>.filled(bins, 0);
    final sumSin = List<double>.filled(bins, 0);
    final sumCos = List<double>.filled(bins, 0);
    var chromaTotal = 0.0;
    var count = 0;

    for (var i = 0; i + 3 < px.length; i += 4) {
      if (px[i + 3] == 0) continue;
      final lab = _rgbToLab(px[i], px[i + 1], px[i + 2]);
      final c = math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
      chromaTotal += c;
      count++;
      if (c < 4) continue; // 회색에 가까우면 색상이 흔들린다
      final h = math.atan2(lab[2], lab[1]);
      final b = ((h / (2 * math.pi) + 1) * bins).floor() % bins;
      weight[b] += c;
      sumSin[b] += math.sin(h) * c;
      sumCos[b] += math.cos(h) * c;
    }

    if (count == 0) return CoverTone.fallback;

    final first = _peak(weight, exclude: -1, bins: bins);
    if (first < 0) return _grayTone(chromaTotal / count);

    // 첫 색상에서 최소 다섯 칸(75도) 떨어진 곳에서 두 번째를 고른다
    final second = _peak(weight, exclude: first, bins: bins, minGap: 5);

    final h1 = math.atan2(sumSin[first], sumCos[first]);
    // 두 번째 색이 없는 자켓(단색 표지)에서는 색상환에서 100도쯤 떨어진
    // 자리를 만들어 쓴다. 한 색만으로는 판 안에서 색상 대비가 안 생긴다
    final h2 = second < 0
        ? h1 + math.pi * 0.55
        : math.atan2(sumSin[second], sumCos[second]);

    // 자켓의 채도를 그대로 옮기면 튀고, 너무 누르면 자켓이 바뀌어도 화면이
    // 안 달라진다. 아래를 올리고 위도 함께 올린다
    final chroma = (chromaTotal / count * 1.5).clamp(16.0, 42.0);
    final c2 = second < 0 ? chroma * 0.8 : chroma;

    return CoverTone(
      plateA: _lch(_plateL, chroma, h1),
      plateB: _lch(_plateL, c2, h2),
      plateBase: _lch(_plateL + 10, chroma * 0.30, (h1 + h2) / 2),
      fill: _lch(_fillL, math.max(chroma, 14) * 1.4, h1),
    );
  }

  /// 색 하나에서 톤을 만든다. 자켓이 없어 자리표시자를 쓸 때.
  static CoverTone fromColor(Color c) {
    final lab = _rgbToLab(
      (c.r * 255).round(),
      (c.g * 255).round(),
      (c.b * 255).round(),
    );
    final h = math.atan2(lab[2], lab[1]);
    final chroma =
        math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]).clamp(8.0, 26.0);
    return CoverTone(
      plateA: _lch(_plateL, chroma, h),
      plateB: _lch(_plateL, chroma * 0.85, h + math.pi * 0.55),
      plateBase: _lch(_plateL + 10, chroma * 0.30, h + math.pi * 0.28),
      fill: _lch(_fillL, math.max(chroma, 14) * 1.4, h),
    );
  }

  /// 색기가 거의 없는 자켓. 흑백 사진이나 단색 표지가 여기 온다.
  static CoverTone _grayTone(double chroma) {
    // 색이 없어도 판이 죽지 않게 종이의 색면과 같은 두 색을 쓴다
    const warm = 0.9; // 라디안. 흙빛 쪽
    const cool = 2.9; // 찬 회녹색 쪽
    return CoverTone(
      plateA: _lch(_plateL, 12, cool),
      plateB: _lch(_plateL, 12, warm),
      plateBase: _lch(_plateL + 10, 4, (warm + cool) / 2),
      fill: _lch(_fillL, 10, cool),
    );
  }

  static int _peak(List<double> w, {required int exclude, required int bins, int minGap = 0}) {
    var best = -1;
    var bestV = 0.0;
    for (var i = 0; i < bins; i++) {
      if (w[i] <= 0) continue;
      if (exclude >= 0) {
        final d = (i - exclude).abs();
        final gap = math.min(d, bins - d);
        if (gap < minGap) continue;
      }
      if (w[i] > bestV) {
        bestV = w[i];
        best = i;
      }
    }
    return best;
  }

  // ── 색 공간 ──────────────────────────────────────────────

  static List<double> _rgbToLab(int r, int g, int b) {
    double lin(int v) {
      final c = v / 255.0;
      return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final rl = lin(r), gl = lin(g), bl = lin(b);
    final x = (0.4124 * rl + 0.3576 * gl + 0.1805 * bl) / 0.95047;
    final y = 0.2126 * rl + 0.7152 * gl + 0.0722 * bl;
    final z = (0.0193 * rl + 0.1192 * gl + 0.9505 * bl) / 1.08883;

    double f(double t) =>
        t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;

    final fx = f(x), fy = f(y), fz = f(z);
    return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  /// LCh(L*, C, h)를 sRGB로. h는 라디안.
  static Color _lch(double l, double c, double h) {
    final a = c * math.cos(h);
    final b = c * math.sin(h);

    final fy = (l + 16) / 116;
    final fx = fy + a / 500;
    final fz = fy - b / 200;

    double g(double t) {
      final t3 = t * t * t;
      return t3 > 0.008856 ? t3 : (t - 16 / 116) / 7.787;
    }

    final x = 0.95047 * g(fx);
    final y = g(fy);
    final z = 1.08883 * g(fz);

    final rl = 3.2406 * x - 1.5372 * y - 0.4986 * z;
    final gl = -0.9689 * x + 1.8758 * y + 0.0415 * z;
    final bl = 0.0557 * x - 0.2040 * y + 1.0570 * z;

    int enc(double v) {
      final s = v <= 0.0031308
          ? 12.92 * v
          : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
      return (s * 255).round().clamp(0, 255);
    }

    return Color.fromARGB(255, enc(rl), enc(gl), enc(bl));
  }
}

/// 곡의 자켓에서 뽑은 색.
///
/// 경로가 없으면 자리표시자 자켓과 **같은 씨앗**에서 뽑는다. 기본값을 그대로
/// 쓰면 자켓은 보라인데 진행바와 판은 파랑인 화면이 나온다.
final coverToneProvider =
    FutureProvider.family<CoverTone, ({String? path, String seed})>(
        (ref, arg) async {
  final path = arg.path;
  if (path == null) {
    return CoverAnalyzer.fromColor(placeholderColorOf(arg.seed));
  }
  return CoverAnalyzer.of(path);
});

/// 곡 하나에 대한 톤. 경로와 씨앗을 매번 꺼내 쓰지 않게 한다.
CoverTone coverToneOf(WidgetRef ref, Track? track) {
  if (track == null) return CoverTone.fallback;
  return ref
          .watch(coverToneProvider(
              (path: artworkPathOf(track), seed: artworkSeedOf(track))))
          .value ??
      CoverTone.fallback;
}

/// 바이트로 들어온 자켓의 색. Spotify가 쓴다.
final coverToneOfBytesProvider =
    FutureProvider.family<CoverTone, ({String key, Uint8List? bytes})>(
        (ref, arg) async {
  final bytes = arg.bytes;
  if (bytes == null || bytes.isEmpty) return CoverTone.fallback;
  return CoverAnalyzer.ofBytes(arg.key, bytes);
});

/// 지금 재생 중인 곡의 id. 목록에서 그 줄을 표시하는 데 쓴다.
///
/// 색이 있으면 재생 중이라는 규칙을 목록에서도 지키려면 어느 줄인지 알아야
/// 한다. 큐의 index가 아니라 곡 id로 본다. 라이브러리 목록의 순서와 큐의
/// 순서는 서로 다르다.

/// 지금 걸린 곡의 색을 화면 아래쪽에 흘린다.
///
/// 강조색을 쓰는 자리가 여러 화면에 흩어져 있어서 인자로 넘기면 길이 길다.
class CoverScope extends InheritedWidget {
  const CoverScope({super.key, required this.tone, required super.child});

  final CoverTone tone;

  static CoverTone of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CoverScope>();
    return scope?.tone ?? CoverTone.fallback;
  }

  @override
  bool updateShouldNotify(CoverScope old) => old.tone != tone;
}
