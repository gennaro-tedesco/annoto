import 'dart:io';

import 'package:flutter/services.dart';

class AnalysisForegroundService {
  static const _channel = MethodChannel('app/foreground_service');

  static Future<void> start() {
    if (!Platform.isAndroid) return Future.value();
    return _channel.invokeMethod('start');
  }

  static Future<void> stop() {
    if (!Platform.isAndroid) return Future.value();
    return _channel.invokeMethod('stop');
  }
}
