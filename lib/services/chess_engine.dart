import 'package:flutter/services.dart';

class ExternalChessEngine {
  final String name;
  final String packageName;

  const ExternalChessEngine({required this.name, required this.packageName});

  factory ExternalChessEngine.fromMap(Map<dynamic, dynamic> map) {
    return ExternalChessEngine(
      name: map['name'] as String,
      packageName: map['packageName'] as String,
    );
  }

  Map<String, String> toMap() => {'name': name, 'packageName': packageName};
}

abstract class ChessEngine {
  Future<List<ExternalChessEngine>> listEngines();
  Future<void> start(String packageName);
  Future<void> send(String command);
  Future<List<String>> drainOutput();
  Stream<String> get output;
  Future<void> stop();
}

class OexChessEngine implements ChessEngine {
  static const _method = MethodChannel('app/oex_engine');
  static const _events = EventChannel('app/oex_engine_output');

  @override
  Stream<String> get output => _events.receiveBroadcastStream().cast<String>();

  @override
  Future<List<ExternalChessEngine>> listEngines() async {
    final result = await _method.invokeMethod<List<dynamic>>('listEngines');
    return (result ?? [])
        .map(
          (item) => ExternalChessEngine.fromMap(item as Map<dynamic, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> start(String packageName) =>
      _method.invokeMethod('start', {'packageName': packageName});

  @override
  Future<void> send(String command) =>
      _method.invokeMethod('send', {'command': command});

  @override
  Future<List<String>> drainOutput() async {
    final result = await _method.invokeMethod<List<dynamic>>('drainOutput');
    return (result ?? []).cast<String>();
  }

  @override
  Future<void> stop() => _method.invokeMethod('stop');
}
