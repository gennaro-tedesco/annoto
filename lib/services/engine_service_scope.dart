import 'package:annoto/services/chess_engine_service.dart';
import 'package:flutter/widgets.dart';

class EngineServiceScope extends InheritedWidget {
  const EngineServiceScope({
    super.key,
    required this.service,
    required super.child,
  });

  final ChessEngineService service;

  static ChessEngineService? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EngineServiceScope>()?.service;

  @override
  bool updateShouldNotify(EngineServiceScope old) => false;
}
