import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';
import 'tokens.dart';

/// 글꼴.
/// - 한글 본문: Noto Sans KR (Moneycraft와 같음)
/// - 숫자(시각·KPI): Poppins — 레퍼런스의 기하학적인 숫자 느낌. 한글이 없는 글꼴이라
///   숫자·영문에만 쓰고, 한글이 섞이면 Noto Sans KR로 자동 대체되게 fallback을 건다.
class AppFonts {
  AppFonts._();

  static String? get body => GoogleFonts.notoSansKr().fontFamily;

  static TextStyle numeric({double? size, FontWeight weight = FontWeight.w300, Color? color}) => GoogleFonts.poppins(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.1,
  ).copyWith(fontFamilyFallback: [?body]);
}

ThemeData buildLightTheme() => _buildTheme(Brightness.light, AppPalette.light);
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark, AppPalette.dark);

/// Material 3 위에 토큰을 얹는다. 컴포넌트 모양(카드·입력창·칩·버튼)은 여기서 한 번만
/// 정하고, 화면에서는 `shape:`/`style:`을 따로 주지 않는 게 기본이다.
ThemeData _buildTheme(Brightness brightness, AppPalette p) {
  final isDark = brightness == Brightness.dark;
  // 대표색은 검정 계열(레퍼런스의 검은 알약 버튼·탭). 강조는 상태색이 맡는다.
  final scheme = ColorScheme.fromSeed(
    seedColor: p.status.info,
    brightness: brightness,
  ).copyWith(primary: p.dock, onPrimary: p.onDock, surface: p.surface, error: p.status.urgent);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final text = GoogleFonts.notoSansKrTextTheme(base.textTheme).apply(
    bodyColor: isDark ? const Color(0xFFEDEDED) : const Color(0xFF151517),
    displayColor: isDark ? const Color(0xFFEDEDED) : const Color(0xFF151517),
  );
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill));

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: p.canvas,
    extensions: [p],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: p.canvas,
      titleTextStyle: text.titleLarge?.copyWith(fontSize: AppText.heading, fontWeight: FontWeight.w700),
    ),
    // 레퍼런스: 테두리·그림자 없는 흰 카드, 큰 라운드. 카드와 바탕의 명도 차이만으로 구분한다.
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    dividerTheme: DividerThemeData(color: p.status.neutral.withValues(alpha: 0.6), thickness: 1, space: 1),
    chipTheme: base.chipTheme.copyWith(
      shape: pill,
      side: BorderSide.none,
      backgroundColor: p.surfaceMuted,
      selectedColor: p.dock,
      labelStyle: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w600, color: text.bodyMedium?.color),
      secondaryLabelStyle: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w600, color: p.onDock),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceMuted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: p.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: p.dock,
        foregroundColor: p.onDock,
        shape: pill,
        textStyle: const TextStyle(fontSize: AppText.bodyLg, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: pill,
        side: BorderSide(color: p.status.neutral),
        textStyle: const TextStyle(fontSize: AppText.bodyLg, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.dock,
      foregroundColor: p.onDock,
      elevation: 0,
      shape: const CircleBorder(),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.dock,
      contentTextStyle: TextStyle(color: p.onDock, fontSize: AppText.body),
      shape: pill,
    ),
  );
}
