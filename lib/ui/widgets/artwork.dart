import 'dart:io';

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

/// 자켓이 없을 때 색과 글자를 만들 문자열.
///
/// 앨범을 쓰되 비어 있으면 제목을 쓴다. 같은 앨범의 곡들이 같은 자리표시자를
/// 갖게 하려는 것이다. 강조색도 같은 씨앗에서 뽑아야 자켓과 색이 맞는다.
String artworkSeedOf(Track? track) {
  if (track == null) return '';
  return track.album.isNotEmpty ? track.album : track.title;
}

/// 자켓이 없을 때 쓸 색. 제목에서 만들어 곡마다 다르게 나온다.
///
/// 종이 위에 놓이므로 예전처럼 어둡게 깔면 화면에서 혼자 튄다. 채도를
/// 낮추고 밝기를 중간에 둔다.
Color placeholderColorOf(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.20, 0.52).toColor();
}

/// 앨범 자켓.
///
/// **자켓 위에는 아무것도 덮지 않는다.** 알갱이도 얼룩도 색면도 올리지
/// 않는다. 태그와 자켓을 가져오는 시점에 복사해서 외부 앱의 영향을 안 받게
/// 해놓고 그 위에 질감을 얹으면 앞뒤가 안 맞는다.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    this.track,
    this.path,
    this.seed,
    required this.size,
    this.radius = AppRadius.thumb,
  });

  /// 곡에서 경로를 뽑는다. [path]를 직접 주면 이쪽이 무시된다.
  final Track? track;

  /// 이미 정해진 자켓 경로.
  final String? path;

  /// 자켓이 없을 때 색과 글자를 만들 문자열.
  final String? seed;

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final resolved = path ?? artworkPathOf(track);
    final br = BorderRadius.circular(radius);

    if (resolved == null) {
      final s = seed ?? artworkSeedOf(track);
      final color = placeholderColorOf(s);
      final letter = s.isEmpty ? '♪' : s.characters.first.toUpperCase();
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              HSLColor.fromColor(color).withLightness(0.34).toColor(),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: AppFont.display,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w500,
            color: AppColors.paperHi.withValues(alpha: 0.78),
          ),
        ),
      );
    }

    // 그릴 크기만큼만 푼다. 이걸 안 걸면 1000px짜리 자켓이 44px 섬네일
    // 자리에서도 통째로 풀려서 한 장에 4MB를 먹는다. 목록을 훑으면
    // 그만큼이 계속 쌓인다.
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return ClipRRect(
      borderRadius: br,
      child: Image.file(
        File(resolved),
        key: ValueKey(resolved),
        width: size,
        height: size,
        cacheWidth: px,
        cacheHeight: px,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            Container(width: size, height: size, color: AppColors.paperLo),
      ),
    );
  }
}
