import 'package:annoto/features/board/board_screen.dart';
import 'package:annoto/models/move_pair.dart';
import 'package:annoto/models/scoresheet.dart';
import 'package:annoto/repositories/scoresheet_repository.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:annoto/services/pgn_validator.dart';
import 'package:flutter/material.dart';

class LichessScreen extends StatelessWidget {
  const LichessScreen({super.key});

  Future<List<Scoresheet>> _loadScoresheets() async {
    final scoresheets = await scoresheetRepository.getAll();

    return scoresheets
        .where((scoresheet) => scoresheet.filename.startsWith('lichess_'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('lichess')),
      body: FutureBuilder<List<Scoresheet>>(
        future: _loadScoresheets(),
        builder: (context, snapshot) {
          final scoresheets = snapshot.data ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (scoresheets.isEmpty) {
            return Center(
              child: Text(
                'No Lichess studies imported',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scoresheets.length,
            itemBuilder: (context, index) {
              final scoresheet = scoresheets[index];
              final games = splitPgnGames(scoresheet.pgn);

              return Card(
                child: ListTile(
                  title: Text(scoresheet.filename),
                  subtitle: Text('${games.length} games'),
                  onTap: () {
                    if (hasInvalidPgnMoves(scoresheet.pgn)) {
                      NotificationService.showError('Invalid PGN');
                      return;
                    }

                    Navigator.of(
                      context,
                    ).pushNamed(BoardScreen.routeName, arguments: scoresheet);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
