import 'package:annoto/app/themes.dart';
import 'package:annoto/features/account/account_screen.dart';
import 'package:annoto/features/game_detail/game_detail_screen.dart';
import 'package:annoto/features/home/home_screen.dart';
import 'package:annoto/features/processing/processing_screen.dart';
import 'package:annoto/features/provider/provider_screen.dart';
import 'package:annoto/features/review/review_screen.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';

class AnnotoApp extends StatefulWidget {
  const AnnotoApp({super.key});

  @override
  State<AnnotoApp> createState() => _AnnotoAppState();
}

class _AnnotoAppState extends State<AnnotoApp> {
  final AppState _appState = AppState();

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _appState,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          themeNotifier,
          uiFontScaleNotifier,
          appFontNotifier,
        ]),
        builder: (context, child) {
          final theme = themeNotifier.value.themeData;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              systemNavigationBarColor: theme.scaffoldBackgroundColor,
              systemNavigationBarIconBrightness:
                  theme.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );

          return MaterialApp(
            title: 'annoto',
            scaffoldMessengerKey: NotificationService.messengerKey,
            theme: theme,
            darkTheme: appFontNotifier.value.apply(
              AppThemes.systemDark(fontScale: uiFontScaleNotifier.value),
            ),
            themeMode: themeNotifier.value == AppThemeOption.none
                ? ThemeMode.system
                : ThemeMode.light,
            routes: {
              HomeScreen.routeName: (_) => const HomeScreen(),
              AccountScreen.routeName: (_) => const AccountScreen(),
              ProviderScreen.routeName: (_) => const ProviderScreen(),
              ProcessingScreen.routeName: (_) => const ProcessingScreen(),
              ReviewScreen.routeName: (_) => const ReviewScreen(),
              GameDetailScreen.routeName: (_) => const GameDetailScreen(),
            },
            initialRoute: HomeScreen.routeName,
          );
        },
      ),
    );
  }
}
