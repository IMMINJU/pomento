import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앨범아트의 밝기에 맞춘 화면 값들.
///
/// 유리 패널과 흰 글자는 어두운 앨범아트 위에서는 잘 읽히지만, 밝은 자켓 위에
/// 올리면 거의 안 보인다. 자켓 밝기를 재서 덮개 농도와 유리 불투명도를 같이
/// 올린다. 시안의 밝은 자켓 버전이 쓰던 값(0.50 / 0.88 / 0.22)이 밝은 쪽 끝이다.
class ArtworkTone {
  const ArtworkTone(this.luma);

  /// 0(아주 어두움) ~ 1(아주 밝음).
  final double luma;

  static const ArtworkTone dark = ArtworkTone(0);

  double get _t => luma.clamp(0.0, 1.0);

  double get topOverlay => 0.18 + (0.50 - 0.18) * _t;
  double get bottomOverlay => 0.72 + (0.88 - 0.72) * _t;
  double get glassOpacity => 0.10 + (0.22 - 0.10) * _t;

  /// 밝은 자켓에서는 유리 테두리도 조금 더 세워야 형태가 보인다.
  double get borderBoost => 0.18 + (0.30 - 0.18) * _t;
}

/// 이미지 파일의 평균 밝기를 잰다.
///
/// 16×16으로 줄여서 읽기 때문에 큰 자켓이어도 비용이 거의 없다. 한 번 잰
/// 값은 경로별로 들고 있는다.
class ArtworkLuma {
  const ArtworkLuma._();

  static final Map<String, double> _cache = {};

  static Future<double> of(String path) async {
    final cached = _cache[path];
    if (cached != null) return cached;

    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 16,
        targetHeight: 16,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      codec.dispose();
      if (data == null) return 0;

      final pixels = data.buffer.asUint8List();
      var total = 0.0;
      var count = 0;
      for (var i = 0; i + 3 < pixels.length; i += 4) {
        final a = pixels[i + 3];
        if (a == 0) continue;
        // 사람 눈의 민감도에 맞춘 가중치.
        total += (0.2126 * pixels[i] +
                0.7152 * pixels[i + 1] +
                0.0722 * pixels[i + 2]) /
            255.0;
        count++;
      }
      final luma = count == 0 ? 0.0 : total / count;
      _cache[path] = luma;
      return luma;
    } catch (_) {
      return 0;
    }
  }
}

/// 자켓 경로에 대한 화면 값. 경로가 null이면 어두운 쪽 기본값.
final artworkToneProvider =
    FutureProvider.family<ArtworkTone, String?>((ref, path) async {
  if (path == null) return ArtworkTone.dark;
  return ArtworkTone(await ArtworkLuma.of(path));
});
