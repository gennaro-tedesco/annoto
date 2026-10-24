import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart';
import 'package:google_fonts/google_fonts.dart';

final themeNotifier = ValueNotifier<AppThemeOption>(AppThemeOption.darkSolar);
final uiFontScaleNotifier = ValueNotifier<double>(1.0);
final appFontNotifier = ValueNotifier<AppFontOption>(AppFontOption.system);
final boardColorSchemeNotifier = ValueNotifier<String>('Brown');
final boardPieceSetNotifier = ValueNotifier<String>('cburnett');
final engineThreadsNotifier = ValueNotifier<int>(1);
final engineHashNotifier = ValueNotifier<int>(16);
final engineNameNotifier = ValueNotifier<String?>(null);
final selectedEnginePackageNotifier = ValueNotifier<String?>(null);
final analysisDepthNotifier = ValueNotifier<int>(18);
final keepAnalysisAliveNotifier = ValueNotifier<bool>(true);
final engineArrowsNotifier = ValueNotifier<bool>(true);
final gifPixelRatioNotifier = ValueNotifier<double>(2.0);
final gifFrameDurationNotifier = ValueNotifier<int>(60);

const boardColorSchemes = <(String, ChessboardColorScheme)>[
  ('Brown', ChessboardColorScheme.brown),
  ('Blue', ChessboardColorScheme.blue),
  ('Green', ChessboardColorScheme.green),
  ('Grey', ChessboardColorScheme.grey),
  ('Olive', ChessboardColorScheme.olive),
];

enum AppThemeOption {
  darkSolar,
  lightSolar,
  oceanic,
  palenight,
  lighter,
  dracula,
  monokai,
}

enum AppFontOption { system, lexend, ubuntu, josefinSans, nunito }

extension AppFontOptionExt on AppFontOption {
  String get label => switch (this) {
    AppFontOption.system => 'System',
    AppFontOption.lexend => 'Lexend',
    AppFontOption.ubuntu => 'Ubuntu',
    AppFontOption.josefinSans => 'Josefin Sans',
    AppFontOption.nunito => 'Nunito',
  };

  ThemeData apply(ThemeData theme) {
    TextTheme applyFont(TextTheme base) => switch (this) {
      AppFontOption.system => base,
      AppFontOption.lexend => GoogleFonts.lexendTextTheme(base),
      AppFontOption.ubuntu => GoogleFonts.ubuntuTextTheme(base),
      AppFontOption.josefinSans => GoogleFonts.josefinSansTextTheme(base),
      AppFontOption.nunito => GoogleFonts.nunitoTextTheme(base),
    };

    return theme.copyWith(
      textTheme: applyFont(theme.textTheme),
      primaryTextTheme: applyFont(theme.primaryTextTheme),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: _applyTextStyle(this, theme.appBarTheme.titleTextStyle),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: _applyTextStyle(this, theme.inputDecorationTheme.hintStyle),
      ),
      textButtonTheme: TextButtonThemeData(
        style: theme.textButtonTheme.style?.copyWith(
          textStyle: WidgetStateProperty.resolveWith((states) {
            final base = theme.textButtonTheme.style?.textStyle?.resolve(
              states,
            );
            return _applyTextStyle(this, base);
          }),
        ),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        titleTextStyle: _applyTextStyle(this, theme.dialogTheme.titleTextStyle),
        contentTextStyle: _applyTextStyle(
          this,
          theme.dialogTheme.contentTextStyle,
        ),
      ),
    );
  }
}

TextStyle? _applyTextStyle(AppFontOption option, TextStyle? style) {
  if (style == null) {
    return null;
  }

  return switch (option) {
    AppFontOption.system => style.copyWith(fontFamily: null),
    AppFontOption.lexend => GoogleFonts.lexend(textStyle: style),
    AppFontOption.ubuntu => GoogleFonts.ubuntu(textStyle: style),
    AppFontOption.josefinSans => GoogleFonts.josefinSans(textStyle: style),
    AppFontOption.nunito => GoogleFonts.nunito(textStyle: style),
  };
}

extension AppThemeOptionExt on AppThemeOption {
  String get label => switch (this) {
    AppThemeOption.darkSolar => 'Sol Dark',
    AppThemeOption.lightSolar => 'Sol Light',
    AppThemeOption.oceanic => 'Oceanic',
    AppThemeOption.palenight => 'Palenight',
    AppThemeOption.lighter => 'Lighter',
    AppThemeOption.dracula => 'Dracula',
    AppThemeOption.monokai => 'Monokai',
  };

  ThemeData get themeData => appFontNotifier.value.apply(
    AppThemes.get(this, fontScale: uiFontScaleNotifier.value),
  );
}

class AppThemes {
  AppThemes._();

  static ThemeData get(AppThemeOption option, {double fontScale = 1.0}) =>
      switch (option) {
        AppThemeOption.darkSolar => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF001E28),
          surface: const Color(0xFF002932),
          surfaceContainer: const Color(0xFF002D38),
          primary: const Color(0xFF3BA4F0),
          onPrimary: const Color(0xFF001E28),
          secondary: const Color(0xFF35B8AD),
          text: const Color(0xFF9FABAD),
          subtext: const Color(0xFF586E74),
          error: const Color(0xFFDC312E),
          outline: const Color(0xFF073541),
        ),
        AppThemeOption.lightSolar => _build(
          fontScale: fontScale,
          brightness: Brightness.light,
          background: const Color(0xFFFDF6E2),
          surface: const Color(0xFFEDE7D4),
          surfaceContainer: const Color(0xFFEDE7D4),
          primary: const Color(0xFFB28600),
          onPrimary: const Color(0xFFFDF6E2),
          secondary: const Color(0xFF278BD3),
          text: const Color(0xFF647A82),
          subtext: const Color(0xFFADB8B8),
          error: const Color(0xFFDC312E),
          outline: const Color(0xFFEDE7D4),
        ),
        AppThemeOption.oceanic => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF25363B),
          surface: const Color(0xFF1C2C30),
          surfaceContainer: const Color(0xFF314549),
          primary: const Color(0xFF11BBA3),
          onPrimary: const Color(0xFF25363B),
          secondary: const Color(0xFF82AAFF),
          text: const Color(0xFFB0BEC5),
          subtext: const Color(0xFF7C9EAD),
          error: const Color(0xFFF07178),
          outline: const Color(0xFF355058),
        ),
        AppThemeOption.palenight => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF292D3E),
          surface: const Color(0xFF1B1E2B),
          surfaceContainer: const Color(0xFF414863),
          primary: const Color(0xFFAB47BC),
          onPrimary: const Color(0xFF292D3E),
          secondary: const Color(0xFF82AAFF),
          text: const Color(0xFFA6ACCD),
          subtext: const Color(0xFF717CB4),
          error: const Color(0xFFF07178),
          outline: const Color(0xFF364367),
        ),
        AppThemeOption.lighter => _build(
          fontScale: fontScale,
          brightness: Brightness.light,
          background: const Color(0xFFFAFAFA),
          surface: const Color(0xFFFFFFFF),
          surfaceContainer: const Color(0xFFE7E7E8),
          primary: const Color(0xFF00BCD4),
          onPrimary: const Color(0xFFFAFAFA),
          secondary: const Color(0xFF6182B8),
          text: const Color(0xFF546E7A),
          subtext: const Color(0xFF94A7B0),
          error: const Color(0xFFE53935),
          outline: const Color(0xFFD3E1E8),
        ),
        AppThemeOption.dracula => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF21222C),
          surface: const Color(0xFF282A36),
          surfaceContainer: const Color(0xFF363B40),
          primary: const Color(0xFFA34C81),
          onPrimary: const Color(0xFF21222C),
          secondary: const Color(0xFF04D1F9),
          text: const Color(0xFFF4F3F2),
          subtext: const Color(0xFF6476A6),
          error: const Color(0xFFFF555F),
          outline: const Color(0xFF5144A3),
        ),
        AppThemeOption.monokai => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF262721),
          surface: const Color(0xFF30312A),
          surfaceContainer: const Color(0xFF3E383A),
          primary: const Color(0xFF66D9EF),
          onPrimary: const Color(0xFF262721),
          secondary: const Color(0xFF5594EC),
          text: const Color(0xFFCED1D4),
          subtext: const Color(0xFF75715E),
          error: const Color(0xFFE73C50),
          outline: const Color(0xFF414245),
        ),
      };

  static ThemeData systemDark({double fontScale = 1.0}) =>
      _systemTheme(Brightness.dark, fontScale);

  static ThemeData _systemTheme(Brightness brightness, double fontScale) {
    final base = ThemeData(useMaterial3: true, brightness: brightness);
    return base.copyWith(
      textTheme: TextTheme(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: (base.textTheme.headlineMedium?.fontSize ?? 28) * fontScale,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: (base.textTheme.titleLarge?.fontSize ?? 22) * fontScale,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: (base.textTheme.titleMedium?.fontSize ?? 16) * fontScale,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          fontSize: (base.textTheme.titleSmall?.fontSize ?? 14) * fontScale,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: (base.textTheme.bodyLarge?.fontSize ?? 16) * fontScale,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: (base.textTheme.bodyMedium?.fontSize ?? 14) * fontScale,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: (base.textTheme.bodySmall?.fontSize ?? 12) * fontScale,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: (base.textTheme.labelLarge?.fontSize ?? 14) * fontScale,
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: 80,
        titleTextStyle:
            (base.appBarTheme.titleTextStyle ?? base.textTheme.titleLarge)
                ?.copyWith(
                  fontSize:
                      ((base.appBarTheme.titleTextStyle ??
                                  base.textTheme.titleLarge)
                              ?.fontSize ??
                          20) *
                      fontScale,
                ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle:
            (base.inputDecorationTheme.hintStyle ??
                    const TextStyle(fontSize: 16))
                .copyWith(
                  fontSize:
                      (base.inputDecorationTheme.hintStyle?.fontSize ?? 16) *
                      fontScale,
                ),
      ),
    );
  }

  static ThemeData _build({
    required double fontScale,
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceContainer,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color text,
    required Color subtext,
    required Color error,
    required Color outline,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onPrimary,
      error: error,
      onError: background,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: subtext,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.4),
      primaryContainer: primary.withValues(alpha: 0.2),
      onPrimaryContainer: text,
      secondaryContainer: secondary.withValues(alpha: 0.2),
      onSecondaryContainer: text,
      tertiary: secondary,
      onTertiary: onPrimary,
      tertiaryContainer: secondary.withValues(alpha: 0.2),
      onTertiaryContainer: text,
      errorContainer: error.withValues(alpha: 0.2),
      onErrorContainer: text,
      surfaceDim: surface,
      surfaceBright: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surfaceContainer,
      surfaceContainerHigh: surfaceContainer,
      surfaceContainerHighest: surfaceContainer,
      inverseSurface: text,
      onInverseSurface: background,
      inversePrimary: primary,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: background),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 80,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 22 * fontScale,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: text),
        actionsIconTheme: IconThemeData(color: subtext),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: subtext, fontSize: 15 * fontScale),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        textColor: text,
        iconColor: subtext,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15 * fontScale,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: subtext),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18 * fontScale,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: subtext, fontSize: 14 * fontScale),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: text,
          fontSize: 28 * fontScale,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: text,
          fontSize: 20 * fontScale,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          color: text,
          fontSize: 16 * fontScale,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: subtext,
          fontSize: 14 * fontScale,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: text, fontSize: 16 * fontScale),
        bodyMedium: TextStyle(color: text, fontSize: 14 * fontScale),
        bodySmall: TextStyle(color: subtext, fontSize: 12 * fontScale),
        labelLarge: TextStyle(
          color: text,
          fontSize: 14 * fontScale,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
