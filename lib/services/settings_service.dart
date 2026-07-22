import 'package:shared_preferences/shared_preferences.dart';

import '../app/themes.dart';

abstract final class SettingsService {
  static const _keyTheme = 'theme';
  static const _keyFontScale = 'fontScale';
  static const _keyFont = 'font';
  static const _keyBoardColorScheme = 'boardColorScheme';
  static const _keyBoardPieceSet = 'boardPieceSet';
  static const _keyEngineThreads = 'engineThreads';
  static const _keyEngineHash = 'engineHash';
  static const _keySelectedEnginePackage = 'selectedEnginePackage';
  static const _keyAnalysisDepth = 'analysisDepth';
  static const _keyKeepAnalysisAlive = 'keepAnalysisAlive';
  static const _keyEngineArrows = 'engineArrows';
  static const _keyGifPixelRatio = 'gifPixelRatio';
  static const _keyGifFrameDuration = 'gifFrameDuration';

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

    final engineThreads = prefs.getInt(_keyEngineThreads);
    if (engineThreads != null) {
      engineThreadsNotifier.value = engineThreads;
    }

    final engineHash = prefs.getInt(_keyEngineHash);
    if (engineHash != null) {
      engineHashNotifier.value = engineHash;
    }

    final selectedEnginePackage = prefs.getString(_keySelectedEnginePackage);
    if (selectedEnginePackage != null) {
      selectedEnginePackageNotifier.value = selectedEnginePackage;
    }

    final analysisDepth = prefs.getInt(_keyAnalysisDepth);
    if (analysisDepth != null) {
      analysisDepthNotifier.value = analysisDepth;
    }

    final keepAnalysisAlive = prefs.getBool(_keyKeepAnalysisAlive);
    if (keepAnalysisAlive != null) {
      keepAnalysisAliveNotifier.value = keepAnalysisAlive;
    }

    final engineArrows = prefs.getBool(_keyEngineArrows);
    if (engineArrows != null) {
      engineArrowsNotifier.value = engineArrows;
    }

    final gifPixelRatio = prefs.getDouble(_keyGifPixelRatio);
    if (gifPixelRatio != null) {
      gifPixelRatioNotifier.value = gifPixelRatio;
    }

    final gifFrameDuration = prefs.getInt(_keyGifFrameDuration);
    if (gifFrameDuration != null) {
      gifFrameDurationNotifier.value = gifFrameDuration;
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
      () =>
          prefs.setString(_keyBoardColorScheme, boardColorSchemeNotifier.value),
    );
    boardPieceSetNotifier.addListener(
      () => prefs.setString(_keyBoardPieceSet, boardPieceSetNotifier.value),
    );
    engineThreadsNotifier.addListener(
      () => prefs.setInt(_keyEngineThreads, engineThreadsNotifier.value),
    );
    engineHashNotifier.addListener(
      () => prefs.setInt(_keyEngineHash, engineHashNotifier.value),
    );
    selectedEnginePackageNotifier.addListener(() {
      final pkg = selectedEnginePackageNotifier.value;
      if (pkg != null) {
        prefs.setString(_keySelectedEnginePackage, pkg);
      } else {
        prefs.remove(_keySelectedEnginePackage);
      }
    });
    analysisDepthNotifier.addListener(
      () => prefs.setInt(_keyAnalysisDepth, analysisDepthNotifier.value),
    );
    keepAnalysisAliveNotifier.addListener(
      () =>
          prefs.setBool(_keyKeepAnalysisAlive, keepAnalysisAliveNotifier.value),
    );
    engineArrowsNotifier.addListener(
      () => prefs.setBool(_keyEngineArrows, engineArrowsNotifier.value),
    );
    gifPixelRatioNotifier.addListener(
      () => prefs.setDouble(_keyGifPixelRatio, gifPixelRatioNotifier.value),
    );
    gifFrameDurationNotifier.addListener(
      () => prefs.setInt(_keyGifFrameDuration, gifFrameDurationNotifier.value),
    );
  }
}
