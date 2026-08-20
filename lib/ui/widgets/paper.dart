import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 미색 종이.
///
/// 세 겹으로 쌓는다.
///
/// 1. 색면 셋. 자연물은 한 면 안에서 색상이 변한다. 단색 하나로 두면
///    균일해서 인쇄물이 아니라 화면으로 보인다. 반지름을 화면보다 크게
///    잡아야 그라디언트가 아니라 종이 얼룩으로 읽힌다.
/// 2. 얼룩. 저주파 색점. 460 논리픽셀로 깔린다.
///
/// 3. 알갱이. 한 텍셀이 화면 한 픽셀이 되게 깔린다.
///
/// **알갱이 세기는 진폭으로 정한다.** 시안의 7%는 밝기가 열일곱 단계로
/// 오르내려서 실제 폰에서 화면이 지글거렸고, 4.5%도 열한 단계라 보였다.
/// 지금은 2.4%로 진폭이 여섯 단계다. 데스크톱에서 작은 아트보드로 볼 때와
/// 손에 든 화면을 가득 채웠을 때가 다르다.
///
/// 이 층이 없으면 종이가 시안보다 1 L\* 밝게 앉는다. 알갱이는 곱하기라
/// 평균적으로 종이를 세 단계 어둡게 만드는데, 그 몫이 빠지기 때문이다.
///
/// 질감은 내용 **아래**에 깔린다. 자켓 위에 아무것도 덮지 않기로 한 규칙을
/// 지키려면 그래야 한다.
class PaperBackground extends StatelessWidget {
  const PaperBackground({
    super.key,
    required this.child,
    this.field = true,
    this.texture = true,
  });

  final Widget child;

  /// 색면 셋. 시트처럼 좁은 자리에서는 끄는 편이 낫다.
  final bool field;

  /// 얼룩과 알갱이.
  final bool texture;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.paper,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 바탕은 한 번 그리면 끝이다. 경계를 안 두면 위에서 진행바가
          // 250ms마다 다시 칠할 때 색면 셋과 타일 둘이 같은 층이라
          // 함께 다시 칠해진다.
          if (field) const RepaintBoundary(child: _ColorField()),
          if (texture) const RepaintBoundary(child: PaperTexture()),
          child,
        ],
      ),
    );
  }
}

/// 종이 자체의 색. 왼쪽 위에 따뜻한 미색, 오른쪽 아래에 찬 회녹색,
/// 아래에 흙빛. 각각 20% 언저리라 자켓에서 온 색을 덮지 않는다.
class _ColorField extends StatelessWidget {
  const _ColorField();

  /// 시안 `.field`의 값 그대로다.
  ///
  /// 이 색들을 밝게 바꿔봤다가 미색이 통째로 사라졌다. 종이가 미색으로
  /// 보이는 것은 바탕색이 아니라 여기 얹히는 색면 때문이다.
  ///
  /// CSS는 `radial-gradient(88% 58% ...)`처럼 가로와 세로 반지름을 따로
  /// 준다. 폭의 88%, 높이의 58%짜리 **타원**이다. Flutter의
  /// [RadialGradient.radius]는 **짧은 변** 하나에 대한 비라서 그대로 옮기면
  /// 원이 된다. 1080×2340 화면에서는 그 원이 세로로 20%쯤 모자라서 색면이
  /// 화면 가운데까지 못 오고, 종이가 아래쪽에서 3.5 L\* 밝게 뜬다.
  /// 덧댄 것이 빠진 것처럼 보이는 자리가 여기다.
  static const List<_Wash> _washes = [
    // 따뜻한 색면만 세고 넓게 잡는다. 시안의 .20에 58%로는 가장 진한 자리가
    // 상단바에 가려지고, 남는 몫이 바로 아래 앰비언트 판(50단계 넘음)에
    // 묻혀서 종이가 온기 없이 읽혔다. 넓히면 그 온기가 자켓 옆과 제목
    // 근처까지 내려와 판이 끝나는 자리에 선이 안 생긴다.
    _Wash(Color(0x52CEBE9E), Alignment(-0.80, -0.92), 1.20, 0.90, 0.72),
    _Wash(Color(0x308AA6A0), Alignment(0.92, 0.48), 0.74, 0.56, 0.74),
    _Wash(Color(0x2BB0A692), Alignment(-0.08, 1.12), 0.96, 0.46, 0.70),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final short = math.min(c.maxWidth, c.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              for (final w in _washes)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: w.center,
                      // 짧은 변 기준이므로 가로 반지름을 그 단위로 환산한다
                      radius: w.rx * c.maxWidth / short,
                      colors: [w.color, w.color.withAlpha(0)],
                      stops: [0.0, w.end],
                      transform: _Ellipse(
                        w.center,
                        (w.ry * c.maxHeight) / (w.rx * c.maxWidth),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 원을 세로로 늘려 CSS와 같은 타원으로 만든다.
class _Ellipse extends GradientTransform {
  const _Ellipse(this.center, this.k);

  final Alignment center;

  /// 세로 배율. 1이면 원 그대로다.
  final double k;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    if ((k - 1).abs() < 0.002) return null;
    final c = center.withinRect(bounds);
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(1, k, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }
}

class _Wash {
  const _Wash(this.color, this.center, this.rx, this.ry, this.end);

  final Color color;
  final Alignment center;

  /// 폭에 대한 가로 반지름 비.
  final double rx;

  /// 높이에 대한 세로 반지름 비.
  final double ry;

  /// 색이 0이 되는 자리.
  final double end;
}

/// 얼룩과 알갱이. 곱하기 대신 알파에 구워둔 타일을 일반 합성으로 깐다.
/// 이유는 tool/make_paper.py에 적어뒀다.
class PaperTexture extends StatelessWidget {
  const PaperTexture({super.key, this.grain = true, this.mottle = true});

  final bool grain;
  final bool mottle;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 얼룩은 큼직하게. 논리픽셀 그대로 깔고 부드럽게 늘린다
          if (mottle)
            const _Tile('assets/paper/mottle.png',
                scale: 1, smooth: true),
          // 알갱이는 한 텍셀이 화면 한 픽셀이 되게. 논리픽셀로 깔면
          // DPR 배수만큼 덩어리져서 필름 그레인이 아니라 모래알이 된다
          if (grain)
            _Tile('assets/paper/grain.png',
                scale: MediaQuery.devicePixelRatioOf(context)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.asset, {required this.scale, this.smooth = false});

  final String asset;

  /// 논리픽셀당 텍셀 수. 1이면 타일 크기가 곧 논리픽셀 크기다.
  final double scale;

  /// 늘릴 때 보간할지. 알갱이는 보간하면 뭉개진다.
  final bool smooth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(asset),
          repeat: ImageRepeat.repeat,
          scale: scale,
          filterQuality: smooth ? FilterQuality.low : FilterQuality.none,
        ),
      ),
    );
  }
}
