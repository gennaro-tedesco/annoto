import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final themeNotifier = ValueNotifier<AppThemeOption>(AppThemeOption.none);
final uiFontScaleNotifier = ValueNotifier<double>(1.0);
final appFontNotifier = ValueNotifier<AppFontOption>(AppFontOption.system);
final boardColorSchemeNotifier = ValueNotifier<String>('Brown');
final boardPieceSetNotifier = ValueNotifier<String>('cburnett');
final engineThreadsNotifier = ValueNotifier<int>(1);
final engineHashNotifier = ValueNotifier<int>(16);
final engineNameNotifier = ValueNotifier<String?>(null);

enum AppThemeOption {
  none,
  catppuccinMocha,
  catppuccinLatte,
  kanagawa,
  oneDark,
  nord,
  rosePineDawn,
  everforestDark,
  solarizedDark,
  solarizedLight,
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
    AppThemeOption.none => 'None',
    AppThemeOption.catppuccinMocha => 'Catppuccin Mocha',
    AppThemeOption.catppuccinLatte => 'Catppuccin Latte',
    AppThemeOption.kanagawa => 'Kanagawa',
    AppThemeOption.oneDark => 'One Dark',
    AppThemeOption.nord => 'Nord',
    AppThemeOption.rosePineDawn => 'Rosé Pine Dawn',
    AppThemeOption.everforestDark => 'Everforest Dark',
    AppThemeOption.solarizedDark => 'Solarized Dark',
    AppThemeOption.solarizedLight => 'Solarized Light',
  };

  ThemeData get themeData => appFontNotifier.value.apply(
    AppThemes.get(this, fontScale: uiFontScaleNotifier.value),
  );
}

class AppThemes {
  AppThemes._();

  static ThemeData get(AppThemeOption option, {double fontScale = 1.0}) =>
      switch (option) {
        AppThemeOption.none => _systemTheme(Brightness.light, fontScale),
        AppThemeOption.catppuccinMocha => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF1E1E2E),
          surface: const Color(0xFF313244),
          surfaceContainer: const Color(0xFF45475A),
          primary: const Color(0xFFCBA6F7),
          onPrimary: const Color(0xFF1E1E2E),
          secondary: const Color(0xFF89B4FA),
          text: const Color(0xFFCDD6F4),
          subtext: const Color(0xFFA6ADC8),
          error: const Color(0xFFF38BA8),
          outline: const Color(0xFF585B70),
        ),
        AppThemeOption.catppuccinLatte => _build(
          fontScale: fontScale,
          brightness: Brightness.light,
          background: const Color(0xFFEFF1F5),
          surface: const Color(0xFFCCD0DA),
          surfaceContainer: const Color(0xFFBCC0CC),
          primary: const Color(0xFF8839EF),
          onPrimary: const Color(0xFFFFFFFF),
          secondary: const Color(0xFF1E66F5),
          text: const Color(0xFF4C4F69),
          subtext: const Color(0xFF6C6F85),
          error: const Color(0xFFD20F39),
          outline: const Color(0xFFACB0BE),
        ),
        AppThemeOption.kanagawa => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF1F1F28),
          surface: const Color(0xFF223249),
          surfaceContainer: const Color(0xFF2A2A37),
          primary: const Color(0xFF7E9CD8),
          onPrimary: const Color(0xFF1F1F28),
          secondary: const Color(0xFF98BB6C),
          text: const Color(0xFFDCD7BA),
          subtext: const Color(0xFFA6A69C),
          error: const Color(0xFFE46876),
          outline: const Color(0xFF54546D),
        ),
        AppThemeOption.oneDark => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF282C34),
          surface: const Color(0xFF2C313C),
          surfaceContainer: const Color(0xFF31353F),
          primary: const Color(0xFF61AFEF),
          onPrimary: const Color(0xFF282C34),
          secondary: const Color(0xFF98C379),
          text: const Color(0xFFABB2BF),
          subtext: const Color(0xFF848B98),
          error: const Color(0xFFE86671),
          outline: const Color(0xFF5C6370),
        ),
        AppThemeOption.nord => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF2E3440),
          surface: const Color(0xFF3B4252),
          surfaceContainer: const Color(0xFF434C5E),
          primary: const Color(0xFF81A1C1),
          onPrimary: const Color(0xFF2E3440),
          secondary: const Color(0xFF88C0D0),
          text: const Color(0xFFE5E9F0),
          subtext: const Color(0xFFD8DEE9),
          error: const Color(0xFFBF616A),
          outline: const Color(0xFF4C566A),
        ),
        AppThemeOption.rosePineDawn => _build(
          fontScale: fontScale,
          brightness: Brightness.light,
          background: const Color(0xFFFAF4ED),
          surface: const Color(0xFFFFFAF3),
          surfaceContainer: const Color(0xFFF2E9E1),
          primary: const Color(0xFF907AA9),
          onPrimary: const Color(0xFFFFFAF3),
          secondary: const Color(0xFF56949F),
          text: const Color(0xFF575279),
          subtext: const Color(0xFF797593),
          error: const Color(0xFFB4637A),
          outline: const Color(0xFFCECacd),
        ),
        AppThemeOption.everforestDark => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF2D353B),
          surface: const Color(0xFF343F44),
          surfaceContainer: const Color(0xFF3D484D),
          primary: const Color(0xFFA7C080),
          onPrimary: const Color(0xFF2D353B),
          secondary: const Color(0xFF83C092),
          text: const Color(0xFFD3C6AA),
          subtext: const Color(0xFF9DA9A0),
          error: const Color(0xFFE67E80),
          outline: const Color(0xFF4F5B58),
        ),
        AppThemeOption.solarizedDark => _build(
          fontScale: fontScale,
          brightness: Brightness.dark,
          background: const Color(0xFF002B36),
          surface: const Color(0xFF073642),
          surfaceContainer: const Color(0xFF0D3A47),
          primary: const Color(0xFF268BD2),
          onPrimary: const Color(0xFF002B36),
          secondary: const Color(0xFF2AA198),
          text: const Color(0xFFE5E9F0),
          subtext: const Color(0xFFD8DEE9),
          error: const Color(0xFFF6534F),
          outline: const Color(0xFF184C52),
        ),
        AppThemeOption.solarizedLight => _build(
          fontScale: fontScale,
          brightness: Brightness.light,
          background: const Color(0xFFFDF6E3),
          surface: const Color(0xFFEEE8D5),
          surfaceContainer: const Color(0xFFE5DEC8),
          primary: const Color(0xFF268BD2),
          onPrimary: const Color(0xFFFDF6E3),
          secondary: const Color(0xFF2AA198),
          text: const Color(0xFF657B83),
          subtext: const Color(0xFF839496),
          error: const Color(0xFFF6534F),
          outline: const Color(0xFFD0C9B6),
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
