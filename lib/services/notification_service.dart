import 'package:flutter/material.dart';

enum NotificationType { info, error }

class NotificationService {
  NotificationService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showInfo(
    String message,
  ) => _show(message, NotificationType.info);

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showError(
    String message,
  ) => _show(message, NotificationType.error);

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _show(
    String message,
    NotificationType type,
  ) {
    final messenger = messengerKey.currentState;
    final context = messengerKey.currentContext;
    if (messenger == null || context == null) {
      return null;
    }

    final theme = Theme.of(context);
    final colors = switch (type) {
      NotificationType.info => (
        background: theme.colorScheme.tertiary.withAlpha(64),
        foreground: theme.colorScheme.onSurface,
      ),
      NotificationType.error => (
        background: theme.colorScheme.errorContainer,
        foreground: theme.colorScheme.onErrorContainer,
      ),
    };

    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.background,
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.foreground),
        ),
        duration: const Duration(milliseconds: 1500),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
