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

class LichessScreenState extends State<LichessScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<LichessStudy>> _studiesFuture;
  late final List<IconData> _titleIcons;
  final TextEditingController _searchController = TextEditingController();
  bool _searchActive = false;
  late final AnimationController _searchAnimController;
  late final CurvedAnimation _searchCurvedAnimation;

  @override
  void initState() {
    super.initState();
    _studiesFuture = lichessService.getStudies();
    _titleIcons = List<IconData>.from(_chessIcons)..shuffle(Random());
    _searchAnimController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _searchCurvedAnimation = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchCurvedAnimation.dispose();
    _searchAnimController.dispose();
    super.dispose();
  }

  void refresh() => setState(() {
    _studiesFuture = lichessService.getStudies();
  });

  void _activateSearch() {
    setState(() => _searchActive = true);
    _searchAnimController.forward();
  }

  void _dismissSearch() {
    _searchController.clear();
    _searchAnimController.reverse().then((_) {
      if (mounted) setState(() => _searchActive = false);
    });
  }

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
          gameCount: splitPgnGamesRaw(pgn).length,
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
        final toolbarHeight = theme.appBarTheme.toolbarHeight ?? kToolbarHeight;
        final appBarHeight = toolbarHeight + viewPadding.top;
        final tabBarHeight = AppControlSize.tabBar + viewPadding.bottom;
        final listHeight = constraints.maxHeight - appBarHeight - tabBarHeight;

        return Scaffold(
          body: Column(
            children: [
              Material(
                color: theme.appBarTheme.backgroundColor,
                child: SizedBox(
                  height: appBarHeight,
                  child: Padding(
                    padding: EdgeInsets.only(top: viewPadding.top),
                    child: SizedBox(
                      height: toolbarHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_searchActive)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 48),
                                child: ClipRect(
                                  child: AnimatedBuilder(
                                    animation: _searchCurvedAnimation,
                                    builder: (context, child) => Align(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _searchCurvedAnimation.value,
                                      heightFactor: 1.0,
                                      child: child,
                                    ),
                                    child: FractionallySizedBox(
                                      widthFactor: 0.5,
                                      child: TextField(
                                        controller: _searchController,
                                        autofocus: true,
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          hintText: 'Search study',
                                          prefixIcon: const Icon(Icons.search),
                                          suffixIcon:
                                              _searchController.text.isEmpty
                                              ? null
                                              : IconButton(
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() {});
                                                  },
                                                  icon: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (
                                  int i = 0;
                                  i < _titleIcons.length;
                                  i++
                                ) ...[
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
                          IconTheme.merge(
                            data:
                                theme.appBarTheme.actionsIconTheme ??
                                const IconThemeData(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _searchActive
                                    ? IconButton(
                                        icon: const Icon(Icons.close),
                                        tooltip: 'Dismiss search',
                                        onPressed: _dismissSearch,
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.search),
                                        tooltip: 'Search',
                                        onPressed: _activateSearch,
                                      ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.refresh),
                                      tooltip: 'Refresh',
                                      onPressed: refresh,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                      final isNotConnected = snapshot.error.toString().contains(
                        'username missing',
                      );
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

                    final query = _searchController.text.trim().toLowerCase();
                    final studies = (snapshot.data ?? [])
                        .where(
                          (s) =>
                              query.isEmpty ||
                              s.name.toLowerCase().contains(query),
                        )
                        .toList();

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
                          padding: const EdgeInsets.only(
                            bottom: _listItemSpacing,
                          ),
                          child: _StudyCard(
                            key: ValueKey(study.id),
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
          ),
        );
      },
    );
  }
}

class _StudyCard extends StatefulWidget {
  const _StudyCard({super.key, required this.study, required this.onTap});

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
      final count = splitPgnGamesRaw(pgn).length;
      if (mounted) {
        setState(() {
          _cachedPgn = pgn;
          _chapterCount = count == 0 ? 1 : count;
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
