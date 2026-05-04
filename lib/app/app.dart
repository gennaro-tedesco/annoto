import 'dart:async';

import 'package:annoto/app/themes.dart';
import 'package:annoto/app/app_tab_shell.dart';
import 'package:annoto/features/account/account_screen.dart';
import 'package:annoto/features/board/board_screen.dart';
import 'package:annoto/features/game_detail/game_detail_screen.dart';
import 'package:annoto/features/provider/provider_screen.dart';
import 'package:annoto/features/review/review_screen.dart';
import 'package:annoto/services/chess_engine_service.dart';
import 'package:annoto/services/engine_service_scope.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';

class AnnotoApp extends StatefulWidget {
  const AnnotoApp({super.key});

  @override
  State<AnnotoApp> createState() => _AnnotoAppState();
}

class _AnnotoAppState extends State<AnnotoApp> {
  final AppState _appState = AppState(Supabase.instance.client);
  final _engineService = ChessEngineService();

  @override
  void initState() {
    super.initState();
    selectedEnginePackageNotifier.addListener(_onEnginePackageChanged);
    _warmUpEngine();
  }

  void _warmUpEngine() {
    if (selectedEnginePackageNotifier.value != null) {
      unawaited(_engineService.init().catchError((_) {}));
    }
  }

  void _onEnginePackageChanged() {
    unawaited(_engineService.dispose().then((_) => _warmUpEngine()));
  }

  @override
  void dispose() {
    selectedEnginePackageNotifier.removeListener(_onEnginePackageChanged);
    unawaited(_engineService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _appState,
      child: EngineServiceScope(
        service: _engineService,
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
              home: const AppTabShell(),
              theme: theme,
              darkTheme: appFontNotifier.value.apply(
                AppThemes.systemDark(fontScale: uiFontScaleNotifier.value),
              ),
              themeMode: themeNotifier.value == AppThemeOption.none
                  ? ThemeMode.system
                  : ThemeMode.light,
              routes: {
                AccountScreen.routeName: (_) => const AccountScreen(),
                ProviderScreen.routeName: (_) => const ProviderScreen(),
                ReviewScreen.routeName: (_) => const ReviewScreen(),
                GameDetailScreen.routeName: (_) => const GameDetailScreen(),
                BoardScreen.routeName: (_) => const BoardScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}
