import 'package:flutter/material.dart';

/// 디자인 시스템 토큰.
///
/// 미색 종이 위에 잉크로 찍은 인쇄물을 기준으로 삼는다. 글래스모피즘을
/// 걷어내면서 어두운 배경과 반투명 흰 판을 전부 버렸다. 값은 디자인
/// 캔버스의 `kit.mjs` TOKENS 블록과 같다. 시안이 바뀌면 여기만 고친다.
class AppColors {
  const AppColors._();

  /// 종이 세 단계. 판을 종이 위에 얹지 않고 가라앉혀서 구분한다.
  /// 테두리를 쓰지 않는 이유가 이것이다.
  static const Color paper = Color(0xFFF6F7F4);

  /// PaperBackground가 실제로 칠하는 바탕. [paper]보다 조금 밝다.
  ///
  /// 색면이 얹히면 결과가 [paper]가 된다. 여기에 [paper]를 그대로 넣으면
  /// 화면이 그만큼 어두워진다. 한 번 그렇게 두었다가 종이가 열네 단계
  /// 내려앉았다.
  static const Color paperBase = Color(0xFFFFFCF9);
  static const Color paperHi = Color(0xFFFBFCF9);
  static const Color paperLo = Color(0xFFEAECE7);

  /// 선을 그을 일이 남았을 때만 쓴다. EQ 범례 정도다.
  static const Color line = Color(0xFFE0E3DD);

  /// 잉크 네 단계.
  static const Color ink1 = Color(0xFF232620);
  static const Color ink2 = Color(0xFF4A4F48);
  static const Color ink3 = Color(0xFF6E736B);
  static const Color hair = Color(0xFFA8ADA5);

  /// 자켓에서 뽑는 색의 기본값. 실제 값은 [CoverAnalyzer]가 준다.
  ///
  /// **채움에만 쓴다.** 앰비언트 판, 진행선, 상단바 큐 밑줄, 미니 진행선
  /// 넷이 전부다. 글자에는 안 쓴다. 곡이 바뀌면 색이 같이 바뀌는데, 값과
  /// 조작부까지 따라 움직이면 화면 모양이 곡마다 흔들린다. 한때 이 색이
  /// 배속 숫자와 알약 배경까지 다 칠해서 68군데에 걸려 있었다.
  static const Color cover = Color(0xFF4E7095);

  /// 값과 설정에 쓰는 고정 강조색.
  ///
  /// 배속·피치 숫자, 값 알약, A-B, 마크, 슬라이더, EQ 막대, 배지, 목록에서
  /// 지금 걸린 곡. 곡이 바뀌어도 안 바뀐다.
  ///
  /// 아이콘의 [brand]를 한 단 올린 값이다. 원래 남색은 종이 대비 11.5라
  /// 잉크(14.3)와 구별이 안 돼서 그냥 검정으로 읽힌다. 이 값은 7.5라
  /// 색으로 읽히고 12px 글자도 AA를 통과한다.
  static const Color accent = Color(0xFF364E86);
  static const Color accentTint = Color(0x1F364E86); // 0.12
  static const Color accentEdge = Color(0x57364E86); // 0.34

  static const Color warn = Color(0xFF8C4A2E);

  /// 앱 아이콘의 바탕. 화면에서는 쓰지 않는다.
  static const Color brand = Color(0xFF26325C);
}

class AppFont {
  const AppFont._();

  /// 제목과 숫자. 세리프가 종이 느낌을 만든다.
  static const String display = 'Newsreader';

  /// 본문과 한글 전부.
  static const String ui = 'Pretendard';
}

class AppRadius {
  const AppRadius._();

  static const double card = 20;
  static const double panel = 20;
  static const double sheet = 28;

  /// 앨범아트와 섬네일. 크게 둥글리지 않는다. 인쇄물의 모서리다.
  static const double plate = 10;
  static const double thumb = 10;
  static const double pill = 999;
}

class AppSpace {
  const AppSpace._();

  /// 화면 좌우 여백. 목록 행과 본문이 같은 값을 쓴다.
  static const double gutter = 26;
  static const double row = 76;
  static const double tap = 44;
  static const double mini = 68;
}

/// 숫자를 고정폭으로 쓴다. 배속 표시가 0.88에서 0.89로 바뀔 때 자리가
/// 흔들리면 미세 조정이 불편해진다.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

class AppText {
  const AppText._();

  /// 화면 머리와 곡 제목.
  ///
  /// Newsreader에는 한글이 없다. 폴백을 안 주면 시스템 기본 서체로 떨어져서
  /// 본문과 얼굴이 달라진다.
  static const TextStyle title = TextStyle(
    fontFamily: AppFont.display,
    fontFamilyFallback: [AppFont.ui],
    fontSize: 34,
    height: 1.18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.88,
    color: AppColors.ink1,
  );

  static const TextStyle body = TextStyle(
    fontFamily: AppFont.ui,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.ink1,
  );

  static const TextStyle sub = TextStyle(
    fontFamily: AppFont.ui,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AppColors.ink3,
  );

  /// 섹션 라벨. 대문자로 쓰지 않고 자간만 벌린다.
  static const TextStyle label = TextStyle(
    fontFamily: AppFont.ui,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.72,
    color: AppColors.ink3,
  );

  /// 시간, 배속, 센트. 세리프 숫자를 고정폭으로 쓴다.
  static const TextStyle num = TextStyle(
    fontFamily: AppFont.display,
    fontFamilyFallback: [AppFont.ui],
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.ink1,
    fontFeatures: tabularFigures,
  );

  /// 연습 화면의 큰 숫자.
  static const TextStyle numLarge = TextStyle(
    fontFamily: AppFont.display,
    fontFamilyFallback: [AppFont.ui],
    fontSize: 40,
    height: 1.1,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.6,
    color: AppColors.ink1,
    fontFeatures: tabularFigures,
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.ink1,
    secondary: AppColors.accent,
    surface: AppColors.paper,
    onPrimary: AppColors.paperHi,
    onSurface: AppColors.ink1,
    error: AppColors.warn,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    fontFamily: AppFont.ui,
    splashFactory: InkRipple.splashFactory,
    // 종이 위에서는 물결이 튀어 보인다. 눌린 자리만 아주 옅게 어두워진다.
    splashColor: const Color(0x0F232620),
    highlightColor: const Color(0x0A232620),
    sliderTheme: const SliderThemeData(
      trackHeight: 2,
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.paperLo,
      thumbColor: AppColors.accent,
      overlayColor: AppColors.accentTint,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
      trackShape: RectangularSliderTrackShape(),
    ),
    textTheme: const TextTheme(
      titleLarge: AppText.title,
      bodyMedium: AppText.body,
      bodySmall: AppText.sub,
      labelSmall: AppText.label,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink1,
      contentTextStyle: TextStyle(
        fontFamily: AppFont.ui,
        color: AppColors.paperHi,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
