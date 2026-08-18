import 'package:flutter/material.dart';

import '../theme.dart';
import 'artwork_tone.dart';

/// 앨범아트 뒤에 깔리는 색 판.
///
/// 예전에는 자켓을 크게 블러해서 깔았다. 유리 뒤에 볼 것이 필요했기
/// 때문인데, 유리를 걷어냈으니 그 이유가 없어졌다. 지금은 자켓에서 뽑은
/// 등명도 두 색을 양쪽 모서리에 놓는다. 자세한 이유는 [CoverTone]에 있다.
///
/// 블러를 쓰지 않는다. 그라디언트는 이미 매끄럽고, 블러는 `saveLayer`를
/// 부른다. 마스크도 쓰지 않는다. 위아래에서 종이색으로 덮어 같은 결과를
/// 낸다. 이 화면에서 가장 자주 다시 그려지는 자리라 값이 싸야 한다.
class AmbientPlate extends StatelessWidget {
  const AmbientPlate({
    super.key,
    required this.tone,
    this.child,
    this.align = Alignment.center,
  });

  final CoverTone tone;

  /// 판 가운데에 놓이는 것. 보통 앨범아트다.
  final Widget? child;

  /// 자켓을 판 안 어디에 둘지. 판이 세로로 길면 가운데에 두었을 때 자켓
  /// 아래에 빈 자리가 남아 제목이 떠 보인다.
  final Alignment align;

  /// 위아래에서 판이 사라지는 구간.
  ///
  /// 종이색으로 덮어서 되돌리면 안 된다. 판 밖의 종이에는 색면이 얹혀
  /// 있어서 순수한 종이색과 다르고, 그 차이가 가로선으로 보인다. 한참
  /// 헤맨 자리다. 덮는 대신 알파를 0으로 만들어 아무것도 안 그린다.
  static const _fade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0xFF000000),
      Color(0xFF000000),
      Color(0x00000000),
    ],
    stops: [0.0, 0.24, 0.70, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 판 전체를 한 번만 그리고 위아래를 깎는다. ShaderMask가 레이어를
        // 하나 만들지만 곡이 바뀔 때만 다시 그리므로 RepaintBoundary로
        // 묶어두면 매 프레임 비용은 없다
        RepaintBoundary(
          child: ShaderMask(
            shaderCallback: _fade.createShader,
            blendMode: BlendMode.dstIn,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 두 색 사이를 메우는 바탕
                ColoredBox(color: tone.plateBase),
                // 왼쪽 위
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.68, -0.52),
                      radius: 1.15,
                      colors: [tone.plateA, tone.plateA.withAlpha(0)],
                      stops: const [0.0, 0.66],
                    ),
                  ),
                ),
                // 오른쪽 아래
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.76, 0.60),
                      radius: 1.10,
                      colors: [tone.plateB, tone.plateB.withAlpha(0)],
                      stops: const [0.0, 0.66],
                    ),
                  ),
                ),
                // 아주 옅게만 덮는다. 많이 덮으면 자켓이 바뀌어도 화면이
                // 안 달라져서 무슨 곡을 듣는지가 화면에 안 드러난다
                const ColoredBox(color: Color(0x1AF6F7F4)),
              ],
            ),
          ),
        ),
        if (child != null) Align(alignment: align, child: child),
      ],
    );
  }
}

/// 앨범아트. 인쇄물처럼 모서리를 조금만 둥글리고 그림자를 두 겹 준다.
///
/// **자켓 위에는 아무것도 덮지 않는다.** 알갱이도 얼룩도 색면도 올리지
/// 않는다. 우리가 보여주는 값이 외부 앱의 영향을 받지 않게 하려고 태그와
/// 자켓을 가져오는 시점에 복사해두는데, 그렇게 지켜온 그림 위에 질감을
/// 얹으면 앞뒤가 안 맞는다.
class ArtPlate extends StatelessWidget {
  const ArtPlate({
    super.key,
    required this.child,
    this.size,
    this.radius = AppRadius.plate,
  });

  final Widget child;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x421C201E), // 0.26
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x381C201E), // 0.22
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}
