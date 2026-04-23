import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showError(
    String message,
  ) {
    final messenger = messengerKey.currentState;
    final context = messengerKey.currentContext;
    if (messenger == null || context == null) return null;

    final theme = Theme.of(context);
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.error,
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onError,
          ),
        ),
        duration: const Duration(milliseconds: 1500),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
