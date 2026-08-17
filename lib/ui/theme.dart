import 'package:flutter/material.dart';

/// 디자인 시스템 토큰.
///
/// Figma Make로 뽑은 시안의 src/tokens.ts 값을 그대로 옮겼다. 시안이 바뀌면
/// 여기만 고치면 된다.
class AppColors {
  const AppColors._();

  static const Color bgBase = Color(0xFF0B0B0F);
  static const Color accent = Color(0xFFA5B4FC);

  static const Color glass = Color(0x1AFFFFFF); // 0.10
  static const Color glassRaised = Color(0x24FFFFFF); // 0.14
  static const Color glassBorder = Color(0x2EFFFFFF); // 0.18
  static const Color glassBorderTop = Color(0x47FFFFFF); // 0.28

  static const Color t1 = Color(0xF2FFFFFF); // 0.95
  static const Color t2 = Color(0x99FFFFFF); // 0.60
  static const Color t3 = Color(0x61FFFFFF); // 0.38

  static const Color trackInactive = Color(0x2EFFFFFF); // 0.18
  static const Color divider = Color(0x14FFFFFF); // 0.08
}

class AppRadius {
  const AppRadius._();

  static const double panel = 26;
  static const double card = 18;
  static const double pill = 999;
  static const double sheet = 32;
}

class AppBlur {
  const AppBlur._();

  /// 일반 유리 패널.
  static const double panel = 28;

  /// 시트와 미니 플레이어.
  static const double sheet = 40;

  /// 배경 앨범아트.
  static const double backdrop = 60;
}

/// 숫자를 고정폭으로 쓴다. 배속 표시가 0.88에서 0.89로 바뀔 때 자리가
/// 흔들리면 미세 조정이 불편해진다.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

class AppText {
  const AppText._();

  static const TextStyle display = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    color: AppColors.t1,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    color: AppColors.t1,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    color: AppColors.t2,
  );

  static const TextStyle small = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w400,
    color: AppColors.t3,
  );

  /// 배속 숫자용.
  static const TextStyle numeric = TextStyle(
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w500,
    color: AppColors.t1,
    letterSpacing: -0.5,
    fontFeatures: tabularFigures,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    color: AppColors.t3,
    fontFeatures: tabularFigures,
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    secondary: AppColors.accent,
    surface: AppColors.bgBase,
    onPrimary: AppColors.bgBase,
    onSurface: AppColors.t1,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bgBase,
    fontFamily: 'Pretendard',
    splashFactory: InkRipple.splashFactory,
    sliderTheme: const SliderThemeData(
      trackHeight: 2,
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.trackInactive,
      thumbColor: AppColors.accent,
      overlayColor: Color(0x22A5B4FC),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
      trackShape: RectangularSliderTrackShape(),
    ),
    textTheme: const TextTheme(
      titleLarge: AppText.display,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1A1A24),
      contentTextStyle: TextStyle(color: AppColors.t1, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
