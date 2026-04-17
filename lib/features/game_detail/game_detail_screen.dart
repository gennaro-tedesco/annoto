import 'package:annoto/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';

class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key});

  static const routeName = '/game';

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Saved game',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saved PGN'),
          SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                '[Event "?"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
