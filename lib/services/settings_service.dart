import 'package:shared_preferences/shared_preferences.dart';

import '../app/themes.dart';

abstract final class SettingsService {
  static const _keyTheme = 'theme';
  static const _keyFontScale = 'fontScale';
  static const _keyFont = 'font';
  static const _keyBoardColorScheme = 'boardColorScheme';
  static const _keyBoardPieceSet = 'boardPieceSet';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final themeName = prefs.getString(_keyTheme);
    if (themeName != null) {
      final match = AppThemeOption.values.where((e) => e.name == themeName);
      if (match.isNotEmpty) {
        themeNotifier.value = match.first;
      }
    }

    final fontScale = prefs.getDouble(_keyFontScale);
    if (fontScale != null) {
      uiFontScaleNotifier.value = fontScale;
    }

    final fontName = prefs.getString(_keyFont);
    if (fontName != null) {
      final match = AppFontOption.values.where((e) => e.name == fontName);
      if (match.isNotEmpty) {
        appFontNotifier.value = match.first;
      }
    }

    final boardColorScheme = prefs.getString(_keyBoardColorScheme);
    if (boardColorScheme != null) {
      boardColorSchemeNotifier.value = boardColorScheme;
    }

    final boardPieceSet = prefs.getString(_keyBoardPieceSet);
    if (boardPieceSet != null) {
      boardPieceSetNotifier.value = boardPieceSet;
    }

    themeNotifier.addListener(
      () => prefs.setString(_keyTheme, themeNotifier.value.name),
    );
    uiFontScaleNotifier.addListener(
      () => prefs.setDouble(_keyFontScale, uiFontScaleNotifier.value),
    );
    appFontNotifier.addListener(
      () => prefs.setString(_keyFont, appFontNotifier.value.name),
    );
    boardColorSchemeNotifier.addListener(
      () => prefs.setString(
        _keyBoardColorScheme,
        boardColorSchemeNotifier.value,
      ),
    );
    boardPieceSetNotifier.addListener(
      () => prefs.setString(_keyBoardPieceSet, boardPieceSetNotifier.value),
    );
  }
}
