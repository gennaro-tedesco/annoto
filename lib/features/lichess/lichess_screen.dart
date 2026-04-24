import 'package:annoto/features/board/board_screen.dart';
import 'package:annoto/models/scoresheet.dart';
import 'package:annoto/services/lichess_service.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:flutter/material.dart';

class LichessScreen extends StatelessWidget {
  const LichessScreen({super.key});

  Future<void> _openStudy(BuildContext context, LichessStudy study) async {
    try {
      final pgn = await lichessService.exportStudyPgn(study.id);

      if (!context.mounted) return;

      Navigator.of(context).pushNamed(
        BoardScreen.routeName,
        arguments: Scoresheet(
          id: 'lichess_${study.id}',
          filename: '${study.name}.pgn',
          createdAt: DateTime.now(),
          pgn: pgn,
        ),
      );
    } catch (e) {
      NotificationService.showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('lichess')),
      body: FutureBuilder<List<LichessStudy>>(
        future: lichessService.getStudies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          final studies = snapshot.data ?? [];

          if (studies.isEmpty) {
            return Center(
              child: Text(
                'No Lichess studies found',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: studies.length,
            itemBuilder: (context, index) {
              final study = studies[index];

              return Card(
                child: ListTile(
                  title: Text(study.name),
                  subtitle: Text(study.visibility ?? 'study'),
                  onTap: () => _openStudy(context, study),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
