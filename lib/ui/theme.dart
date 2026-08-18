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

  /// 자켓에서 뽑는 강조색의 기본값. 실제 값은 [ArtworkTone]이 준다.
  /// 색이 있으면 재생 중이라는 뜻이다. 정지 상태에는 잉크만 쓴다.
  static const Color cover = Color(0xFF4E7095);
  static const Color coverInk = Color(0xFF3C5A7B);
  static const Color coverTint = Color(0x1C4E7095); // 0.11
  static const Color coverEdge = Color(0x524E7095); // 0.32

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
    secondary: AppColors.cover,
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
      activeTrackColor: AppColors.cover,
      inactiveTrackColor: AppColors.paperLo,
      thumbColor: AppColors.cover,
      overlayColor: Color(0x1C4E7095),
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
