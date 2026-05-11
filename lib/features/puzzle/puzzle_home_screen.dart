import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:annoto/app/ui_sizes.dart';
import 'package:annoto/models/puzzle_collection.dart';
import 'package:annoto/repositories/puzzle_collection_repository.dart';
import 'package:annoto/features/puzzle/puzzle_screen.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class PuzzleHomeScreen extends StatefulWidget {
  const PuzzleHomeScreen({super.key});

  @override
  State<PuzzleHomeScreen> createState() => _PuzzleHomeScreenState();
}

class _PuzzleHomeScreenState extends State<PuzzleHomeScreen> {
  static const _listSideInset = 16.0;
  static const _listTopInset = 12.0;
  static const _listItemSpacing = 12.0;
  static const _cardInternalPadding = 16.0;
  static const _swipeRevealPadding = 20.0;
  static const _collectionChipIconSize = 16.0;
  static const _collectionChipGap = 6.0;
  static const _collectionChipSpacing = 12.0;
  static const _backgroundIconSize = 220.0;
  static const _backgroundIconOpacity = 0.08;
  static const _titleIconSize = 22.0;
  static const _titleIconSpacing = 6.0;
  static const _chessIcons = [
    LucideIcons.chess_bishop,
    LucideIcons.chess_king,
    LucideIcons.chess_knight,
    LucideIcons.chess_pawn,
    LucideIcons.chess_queen,
    LucideIcons.chess_rook,
  ];
  static const _fabBottomInset = 16.0;
  static const _fabSideInset = 16.0;
  static const _fabHeight = 56.0;
  static const _fabWidth = 84.0;
  static const _homeListBottomClearance =
      _fabBottomInset + _fabHeight + _listItemSpacing;

  List<PuzzleCollection> _collections = [];
  late final List<IconData> _titleChessIcons;

  @override
  void initState() {
    super.initState();
    _titleChessIcons = List<IconData>.from(_chessIcons)..shuffle(Random());
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final collections = await puzzleCollectionRepository.getAll();
    if (!mounted) return;
    setState(() => _collections = collections);
  }

  Future<void> _importCollection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pgn'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    String content;
    try {
      if (file.path != null) {
        final bytes = await File(file.path!).readAsBytes();
        content = utf8.decode(bytes, allowMalformed: true);
      } else if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else {
        if (mounted) NotificationService.showError('Failed to read file.');
        return;
      }
    } catch (_) {
      if (mounted) NotificationService.showError('Failed to read file.');
      return;
    }

    final name = file.name.toLowerCase().endsWith('.pgn')
        ? file.name.substring(0, file.name.length - 4)
        : file.name;

    try {
      await puzzleCollectionRepository.save(name, content);
    } on FormatException catch (e) {
      if (mounted) NotificationService.showError(e.message);
      return;
    } catch (_) {
      if (mounted) NotificationService.showError('Failed to save collection.');
      return;
    }

    if (mounted) await _loadCollections();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _titleChessIcons.length; i++) ...[
              Icon(
                _titleChessIcons[i],
                size: _titleIconSize,
                color: theme.colorScheme.primary,
              ),
              if (i < _titleChessIcons.length - 1)
                const SizedBox(width: _titleIconSpacing),
            ],
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Icon(
                  LucideIcons.puzzle,
                  size: _backgroundIconSize,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: _backgroundIconOpacity,
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(child: _buildList(context)),
              SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom +
                    _homeListBottomClearance,
              ),
            ],
          ),
          Positioned(
            right: _fabSideInset,
            bottom: MediaQuery.of(context).padding.bottom + _fabBottomInset,
            child: SizedBox(
              width: _fabWidth,
              height: _fabHeight,
              child: FloatingActionButton(
                heroTag: 'new_puzzle_collection',
                onPressed: _importCollection,
                backgroundColor: fillColor,
                foregroundColor: theme.colorScheme.onSurface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: AppIconSize.inlineAction),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 35,
                      height: 35,
                      child: OverflowBox(
                        maxWidth: 88,
                        maxHeight: 88,
                        child: Icon(
                          LucideIcons.puzzle,
                          size: 28,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    if (_collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.puzzle,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'No puzzle collections yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text('Tap + to add one', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        _listSideInset,
        _listTopInset,
        _listSideInset,
        _homeListBottomClearance,
      ),
      itemCount: _collections.length,
      itemBuilder: (context, index) {
        final collection = _collections[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: _listItemSpacing),
          child: Dismissible(
            key: ValueKey(collection.id),
            direction: DismissDirection.endToStart,
            background: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(
                horizontal: _swipeRevealPadding,
              ),
              child: Icon(Icons.delete, color: theme.colorScheme.onError),
            ),
            confirmDismiss: (_) async {
              await puzzleCollectionRepository.delete(collection.id);
              _collections.removeWhere((c) => c.id == collection.id);
              setState(() {});
              return false;
            },
            child: _buildCollectionCard(context, collection),
          ),
        );
      },
    );
  }

  Widget _buildCollectionCard(
    BuildContext context,
    PuzzleCollection collection,
  ) {
    final theme = Theme.of(context);
    final chipColor = theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () async {
          await Navigator.of(
            context,
          ).pushNamed(PuzzleScreen.routeName, arguments: collection);
          if (mounted) await _loadCollections();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(_cardInternalPadding),
          child: Row(
            children: [
              Expanded(
                child: Text(collection.name, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(width: _collectionChipSpacing),
              Chip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${collection.puzzles.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: chipColor,
                      ),
                    ),
                    const SizedBox(width: _collectionChipGap),
                    Icon(
                      LucideIcons.puzzle,
                      size: _collectionChipIconSize,
                      color: chipColor,
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
          ),
        ),
      ),
    );
  }
}
