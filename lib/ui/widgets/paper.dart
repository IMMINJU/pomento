import 'package:flutter/material.dart';

import '../theme.dart';

/// 미색 종이.
///
/// 두 겹으로 쌓는다.
///
/// 1. 색면 셋. 자연물은 한 면 안에서 색상이 변한다. 단색 하나로 두면
///    균일해서 인쇄물이 아니라 화면으로 보인다. 반지름을 화면보다 크게
///    잡아야 그라디언트가 아니라 종이 얼룩으로 읽힌다.
/// 2. 얼룩. 저주파 색점. 460 논리픽셀로 깔린다.
///
/// **알갱이는 뺐다.** 시안에서는 7%로 얹혀 있었고 브라우저에서 보기에는
/// 종이 질감이었는데, 실제 폰에서는 밝기가 열일곱 단계로 오르내려서 화면이
/// 지글거렸다. 데스크톱에서 작은 아트보드로 볼 때와 손에 든 화면을 가득
/// 채웠을 때가 다르다. 타일과 굽는 스크립트는 남겨뒀으므로 [PaperTexture]의
/// grain을 켜면 돌아온다.
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
          if (field) const _ColorField(),
          if (texture) const PaperTexture(),
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

  /// 시안 `kit.mjs`의 `.field` 값 그대로다.
  ///
  /// 이 색들을 밝게 바꿔봤다가 미색이 통째로 사라졌다. 종이가 미색으로
  /// 보이는 것은 바탕색이 아니라 여기 얹히는 색면 때문이다.
  static const List<_Wash> _washes = [
    _Wash(Color(0x33CEBE9E), Alignment(-0.80, -0.92), 1.05),
    _Wash(Color(0x308AA6A0), Alignment(0.92, 0.48), 0.95),
    _Wash(Color(0x2BB0A692), Alignment(-0.08, 1.12), 1.00),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final w in _washes)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: w.center,
                  radius: w.radius,
                  colors: [w.color, w.color.withAlpha(0)],
                  stops: const [0.0, 0.72],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Wash {
  const _Wash(this.color, this.center, this.radius);

  final Color color;
  final Alignment center;
  final double radius;
}

/// 얼룩과 알갱이. 곱하기 대신 알파에 구워둔 타일을 일반 합성으로 깐다.
/// 이유는 tool/make_paper.py에 적어뒀다.
class PaperTexture extends StatelessWidget {
  const PaperTexture({super.key, this.grain = false, this.mottle = true});

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
