import 'package:annoto/features/board/board_screen.dart';
import 'package:annoto/services/chess_engine_service.dart';
import 'package:flutter/material.dart';

class EngineScreen extends StatelessWidget {
  const EngineScreen({super.key, required this.engineService});

  final ChessEngineService engineService;

  @override
  Widget build(BuildContext context) {
    return BoardScreen.engine(engineService: engineService);
  }
}
