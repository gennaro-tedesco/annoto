import 'dart:async';
import 'dart:math';

import 'package:annoto/app/ui_sizes.dart';
import 'package:annoto/features/board/board_screen.dart';
import 'package:annoto/models/move_pair.dart';
import 'package:annoto/models/scoresheet.dart';
import 'package:annoto/services/lichess_service.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

const double _collectionStackOffset = 4.0;
const int _collectionStackLayerCount = 3;
const double _collectionChipSpacing = 8.0;
const double _collectionChipGap = 6.0;
const double _collectionChipIconSize = 14.0;
const double _listItemSpacing = 12.0;
const double _titleIconSize = 22.0;
const double _titleIconSpacing = 6.0;
const _chessIcons = [
  LucideIcons.chess_bishop,
  LucideIcons.chess_king,
  LucideIcons.chess_knight,
  LucideIcons.chess_pawn,
  LucideIcons.chess_queen,
  LucideIcons.chess_rook,
];

class LichessScreen extends StatefulWidget {
  const LichessScreen({super.key});

  @override
  State<LichessScreen> createState() => LichessScreenState();
}

class LichessScreenState extends State<LichessScreen> {
  late Future<List<LichessStudy>> _studiesFuture;
  late final List<IconData> _titleIcons;

  @override
  void initState() {
    super.initState();
    _studiesFuture = lichessService.getStudies();
    _titleIcons = List<IconData>.from(_chessIcons)..shuffle(Random());
  }

  void refresh() => setState(() {
        _studiesFuture = lichessService.getStudies();
      });

  Future<void> _openStudy(
    BuildContext context,
    LichessStudy study,
    String? cachedPgn,
  ) async {
    try {
      final pgn = cachedPgn ?? await lichessService.exportStudyPgn(study.id);

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewPadding = MediaQuery.viewPaddingOf(context);
        final appBarHeight = kToolbarHeight + viewPadding.top;
        final tabBarHeight = AppControlSize.tabBar + viewPadding.bottom;
        final listHeight = constraints.maxHeight - appBarHeight - tabBarHeight;

        return Column(
          children: [
            AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < _titleIcons.length; i++) ...[
                Icon(
                  _titleIcons[i],
                  size: _titleIconSize,
                  color: theme.colorScheme.primary,
                ),
                if (i < _titleIcons.length - 1)
                  const SizedBox(width: _titleIconSpacing),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: refresh,
            ),
            const SizedBox(width: 4),
          ],
        ),
            SizedBox(
              height: listHeight,
              child: FutureBuilder<List<LichessStudy>>(
                future: _studiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    final isNotConnected = snapshot.error
                        .toString()
                        .contains('username missing');
                    if (isNotConnected) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: Icon(
                                  LucideIcons.chess_knight,
                                  size: 220,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              'Connect your Lichess account',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    }
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
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: _listItemSpacing),
                        child: _StudyCard(
                          study: study,
                          onTap: (cachedPgn) =>
                              _openStudy(context, study, cachedPgn),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudyCard extends StatefulWidget {
  const _StudyCard({required this.study, required this.onTap});

  final LichessStudy study;
  final void Function(String? cachedPgn) onTap;

  @override
  State<_StudyCard> createState() => _StudyCardState();
}

class _StudyCardState extends State<_StudyCard> {
  int _chapterCount = 0;
  String? _cachedPgn;

  @override
  void initState() {
    super.initState();
    _loadChapterCount();
  }

  Future<void> _loadChapterCount() async {
    try {
      final pgn = await lichessService.exportStudyPgn(widget.study.id);
      final games = splitPgnGames(pgn);
      if (mounted) {
        setState(() {
          _cachedPgn = pgn;
          _chapterCount = games.isEmpty ? 1 : games.length;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _chapterCount = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCollection = _chapterCount > 1;
    final collectionStackInset =
        _collectionStackOffset * _collectionStackLayerCount;
    final collectionLayerColor = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.55);
    final collectionChipColor = theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        right: isCollection ? collectionStackInset : 0,
        bottom: isCollection ? collectionStackInset : 0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isCollection)
            for (int layer = _collectionStackLayerCount; layer >= 1; layer--)
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(
                    _collectionStackOffset * layer,
                    _collectionStackOffset * layer,
                  ),
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: collectionLayerColor,
                  ),
                ),
              ),
          Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => widget.onTap(_cachedPgn),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.study.name,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (isCollection) ...[
                      const SizedBox(width: _collectionChipSpacing),
                      Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_chapterCount',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: collectionChipColor,
                              ),
                            ),
                            const SizedBox(width: _collectionChipGap),
                            Icon(
                              Icons.menu_book_outlined,
                              size: _collectionChipIconSize,
                              color: collectionChipColor,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: _collectionChipGap,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
