import 'package:flutter/material.dart';

abstract final class AppIconSize {
  static const double toolbar = 22;
  static const double inlineAction = 18;
  static const double smallStatus = 16;
}

abstract final class AppControlSize {
  static const double toolbarButton = 48;
  static const double compact = 32;
}

abstract final class AppFieldSize {
  static const double inlineSearch = 36;
}

abstract final class AppConstraints {
  static const BoxConstraints compactIcon = BoxConstraints(
    minWidth: AppControlSize.compact,
    minHeight: AppControlSize.compact,
  );

  static const Size compactButton = Size(
    AppControlSize.compact,
    AppControlSize.compact,
  );
}
