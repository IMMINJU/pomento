import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/db/database.dart';
import '../theme.dart';

/// 곡의 자켓 경로를 정한다.
///
/// 순서: 사용자가 직접 지정한 것 → 파일 태그에서 뽑아둔 것 → 없음.
/// 온라인 조회는 하지 않는다. 자켓이 저절로 바뀌는 동작이 이 앱에서 피하려는
/// 바로 그 문제다.
String? artworkPathOf(Track? track) {
  if (track == null) return null;
  for (final path in [track.userArtworkPath, track.artworkPath]) {
    if (path == null) continue;
    if (File(path).existsSync()) return path;
  }
  return null;
}

/// 자켓이 없을 때 쓸 색. 제목에서 만들어 곡마다 다르게 나온다.
Color placeholderColorOf(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.32, 0.28).toColor();
}

class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.track,
    required this.size,
    this.radius = 10,
  });

  final Track? track;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = artworkPathOf(track);
    final br = BorderRadius.circular(radius);

    if (path == null) {
      final seed = track?.album.isNotEmpty == true
          ? track!.album
          : (track?.title ?? '');
      final color = placeholderColorOf(seed);
      final letter = seed.isEmpty ? '♪' : seed.characters.first;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, AppColors.bgBase, 0.55)!],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: br,
      child: Image.file(
        File(path),
        key: ValueKey(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: const Color(0xFF1A1A2E),
        ),
      ),
    );
  }
}

/// 앨범아트를 크게 블러 처리해 화면 전체에 깐 배경.
///
/// 유리가 굴절시킬 대상이 있어야 글래스모피즘이 눈에 보인다. 배경이 평평한
/// 검정이면 블러가 할 일이 없어서 유리가 그냥 반투명 사각형으로 보인다.
class BlurredBackdrop extends StatelessWidget {
  const BlurredBackdrop({
    super.key,
    required this.track,
    this.topOverlay = 0.18,
    this.bottomOverlay = 0.72,
    this.blur = AppBlur.backdrop,
    this.opacity = 1.0,
  });

  final Track? track;
  final double topOverlay;
  final double bottomOverlay;
  final double blur;

  /// 라이브러리 화면처럼 은은하게만 깔 때 낮춘다.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final path = artworkPathOf(track);
    final seed = track?.album.isNotEmpty == true
        ? track!.album
        : (track?.title ?? 'player');
    final fallback = placeholderColorOf(seed);

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: opacity,
              child: path == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.7),
                          radius: 1.1,
                          colors: [
                            fallback.withValues(alpha: 0.55),
                            AppColors.bgBase,
                          ],
                        ),
                      ),
                    )
                  : ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: blur / 2,
                        sigmaY: blur / 2,
                        tileMode: TileMode.clamp,
                      ),
                      child: Transform.scale(
                        scale: 1.25,
                        child: Image.file(
                          File(path),
                          key: ValueKey('bg_$path'),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.bgBase),
                        ),
                      ),
                    ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: topOverlay),
                    Colors.black.withValues(alpha: bottomOverlay),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
