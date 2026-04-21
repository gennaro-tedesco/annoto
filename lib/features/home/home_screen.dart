import 'dart:convert';

import 'package:annoto/app/ai_models.dart';
import 'package:annoto/app/app_state.dart';
import 'package:share_plus/share_plus.dart';
import 'package:annoto/app/ui_sizes.dart';
import 'package:annoto/features/board/board_screen.dart';
import 'package:annoto/features/game_detail/game_detail_screen.dart';
import 'package:annoto/features/review/review_screen.dart';
import 'package:annoto/features/settings/settings_screen.dart';
import 'package:annoto/models/scoresheet.dart';
import 'package:annoto/repositories/scoresheet_repository.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:annoto/services/pgn_validator.dart';
import 'package:annoto/widgets/gradient_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _bottomControlHeight = 56.0;
  static const _createButtonWidth = 84.0;
  static const _createButtonHeight = _bottomControlHeight;
  static const _createButtonBottom = 0.0;
  static const _fabOverlayHeight = _createButtonBottom + _createButtonHeight;
  static const _bottomOverlaySideInset = 16.0;
  static const _bottomOverlayBottomInset = 16.0;
  static const _contentBottomClearance =
      _bottomOverlayBottomInset + _fabOverlayHeight;
  static const _homeListBottomClearance =
      _contentBottomClearance + _listItemSpacing;
  static const _filterButtonWidth = 84.0;
  static const _filterButtonHeight = _bottomControlHeight;
  static const _filterPanelMaxWidth = 340.0;
  static const _filterSpacing = 12.0;
  static const _filterMenuHeight = 280.0;
  static const _listSideInset = 16.0;
  static const _listTopInset = 12.0;
  static const _listItemSpacing = 12.0;
  static const _cardInternalPadding = 16.0;
  static const _swipeRevealPadding = 20.0;
  static const _invalidIndicatorSize = 10.0;
  static const _invalidIndicatorInset = 8.0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Scoresheet> _scoresheets = [];
  bool _filtersOpen = false;
  late final AnimationController _filterSpinController;
  String? _selectedTournament;
  String? _selectedRound;
  String? _selectedWhitePlayer;
  String? _selectedBlackPlayer;

  @override
  void initState() {
    super.initState();
    _filterSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadScoresheets();
  }

  @override
  void dispose() {
    _filterSpinController.dispose();
    super.dispose();
  }

  Future<void> _loadScoresheets() async {
    final scoresheets = await scoresheetRepository.getAll();
    if (!mounted) return;
    setState(() {
      _scoresheets = scoresheets;
      _clearMissingFilters(_buildFilterData());
    });
  }

  void _toggleFilters() {
    if (_filtersOpen) {
      _filterSpinController.reverse(from: 1.0);
    } else {
      _filterSpinController.forward(from: 0.0);
    }
    setState(() => _filtersOpen = !_filtersOpen);
  }

  void _closeFilters() {
    if (!_filtersOpen) return;
    _filterSpinController.reverse(from: 1.0);
    setState(() => _filtersOpen = false);
  }

  void _openSettings() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _openAddSheetMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final image = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                );
                if (image != null && mounted) await _processScoresheet(image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Upload from gallery'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final image = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null && mounted) await _processScoresheet(image);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processScoresheet(XFile image) async {
    final bytes = await image.readAsBytes();
    final b64 = base64Encode(bytes);
    final mimeType = image.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? errorMessage;
    String? pgn;

    try {
      final selectedProvider = AppStateScope.of(context).selectedProvider;
      final provider = selectedProvider.providerKey;
      final model = providerModels[selectedProvider]!.first;
      final response = await Supabase.instance.client.functions.invoke(
        'extract-pgn',
        body: {
          'image': b64,
          'mimeType': mimeType,
          'provider': provider,
          'model': model,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        errorMessage = _errorMessage(data['error'] as String);
      } else {
        pgn = data['pgn'] as String? ?? '';
      }
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map<String, dynamic>
          ? details['error']?.toString()
          : null;
      errorMessage = _errorMessage(code ?? 'extraction_failed');
    } catch (e) {
      errorMessage = 'Failed to extract scoresheet.';
    } finally {
      if (mounted) Navigator.of(context).pop();
    }

    if (!mounted) return;
    if (errorMessage != null) {
      NotificationService.showError(errorMessage);
      return;
    }
    await Navigator.of(
      context,
    ).pushNamed(ReviewScreen.routeName, arguments: pgn);
    await _loadScoresheets();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final overlayWidth = MediaQuery.sizeOf(context).width - 32;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.7,
        child: const Drawer(child: SettingsScreen()),
      ),
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset('images/logo.png', height: 50),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              Expanded(child: _buildHomeTab2(context)),
              SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom +
                    _homeListBottomClearance,
              ),
            ],
          ),
          Positioned(
            left: _bottomOverlaySideInset,
            right: _bottomOverlaySideInset,
            bottom:
                MediaQuery.of(context).padding.bottom +
                _bottomOverlayBottomInset,
            height: _fabOverlayHeight,
            child: _buildBottomOverlay(context, overlayWidth, fillColor),
          ),
          if (_filtersOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeFilters,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: theme.colorScheme.scrim.withValues(alpha: 0.45),
                ),
              ),
            ),
          Positioned(
            left: _bottomOverlaySideInset,
            bottom:
                MediaQuery.of(context).padding.bottom +
                _bottomOverlayBottomInset +
                _fabOverlayHeight +
                16,
            child: ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: overlayWidth
                      .clamp(_filterButtonWidth, _filterPanelMaxWidth)
                      .toDouble(),
                  child: _filtersOpen
                      ? _buildFilterPanel(context, _buildFilterData())
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomOverlay(
    BuildContext context,
    double overlayWidth,
    Color fillColor,
  ) {
    final theme = Theme.of(context);
    return SizedBox(
      width: overlayWidth,
      height: _fabOverlayHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: _filterButtonWidth,
            height: _filterButtonHeight,
            child: RotationTransition(
              turns: _filterSpinController,
              child: IconButton(
                onPressed: _toggleFilters,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.expand(),
                iconSize: _createButtonHeight * 0.5,
                color: _hasActiveFilters
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                icon: const Icon(LucideIcons.sliders_horizontal),
              ),
            ),
          ),
          SizedBox(
            width: _createButtonWidth,
            height: _createButtonHeight,
            child: FloatingActionButton(
              heroTag: 'new_scoresheet',
              onPressed: _openAddSheetMenu,
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
                        Icons.image_search_outlined,
                        size: 28,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab2(BuildContext context) {
    final theme = Theme.of(context);
    if (_scoresheets.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No scoresheets yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Tap + to add one', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      );
    }
    final filterData = _buildFilterData();
    final filteredScoresheets = _scoresheets
        .where(
          (scoresheet) => _matchesFilters(filterData.tagsById[scoresheet.id]!),
        )
        .toList();
    return filteredScoresheets.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_alt_off_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No matching games',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adjust or clear filters to see more cards',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : ListView.builder(
            padding: EdgeInsets.fromLTRB(
              _listSideInset,
              _listTopInset,
              _listSideInset,
              _homeListBottomClearance,
            ),
            itemCount: filteredScoresheets.length,
            itemBuilder: (context, index) {
              final scoresheet = filteredScoresheets[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: _listItemSpacing),
                child: Dismissible(
                  key: ValueKey(scoresheet.id),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _swipeRevealPadding,
                    ),
                    child: Icon(
                      Icons.share,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  secondaryBackground: Container(
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
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      final path = await scoresheetRepository.getFilePath(
                        scoresheet.id,
                      );
                      await Share.shareXFiles([
                        XFile(path, mimeType: 'application/x-chess-pgn'),
                      ]);
                    } else {
                      await scoresheetRepository.delete(scoresheet.id);
                      setState(() {
                        _scoresheets.removeWhere(
                          (item) => item.id == scoresheet.id,
                        );
                        _clearMissingFilters(_buildFilterData());
                      });
                    }
                    return false;
                  },
                  child: _buildScoresheetCard(context, scoresheet),
                ),
              );
            },
          );
  }

  Widget _buildFilterPanel(BuildContext context, _FilterData filterData) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filters', style: theme.textTheme.bodyMedium),
                const Spacer(),
                TextButton(
                  onPressed: _hasActiveFilters ? _clearFilters : null,
                  style: TextButton.styleFrom(
                    textStyle: theme.textTheme.bodySmall,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = 1;
                final totalSpacing = _filterSpacing * (columns - 1);
                final fieldWidth =
                    (constraints.maxWidth - totalSpacing) / columns;
                return Wrap(
                  spacing: _filterSpacing,
                  runSpacing: _filterSpacing,
                  children: [
                    _buildFilterDropdown(
                      context,
                      width: fieldWidth,
                      fillColor: fillColor,
                      label: 'Tournament',
                      value: _selectedTournament,
                      options: filterData.tournaments,
                      onSelected: (value) {
                        setState(() => _selectedTournament = value);
                      },
                    ),
                    _buildFilterDropdown(
                      context,
                      width: fieldWidth,
                      fillColor: fillColor,
                      label: 'Round',
                      value: _selectedRound,
                      options: filterData.rounds,
                      onSelected: (value) {
                        setState(() => _selectedRound = value);
                      },
                    ),
                    _buildFilterDropdown(
                      context,
                      width: fieldWidth,
                      fillColor: fillColor,
                      label: 'White',
                      value: _selectedWhitePlayer,
                      options: filterData.whitePlayers,
                      onSelected: (value) {
                        setState(() => _selectedWhitePlayer = value);
                      },
                    ),
                    _buildFilterDropdown(
                      context,
                      width: fieldWidth,
                      fillColor: fillColor,
                      label: 'Black',
                      value: _selectedBlackPlayer,
                      options: filterData.blackPlayers,
                      onSelected: (value) {
                        setState(() => _selectedBlackPlayer = value);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context, {
    required double width,
    required Color fillColor,
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onSelected,
  }) {
    return _FilterDropdown(
      label: label,
      value: value,
      options: options,
      width: width,
      fillColor: fillColor,
      menuHeight: _filterMenuHeight,
      onSelected: onSelected,
    );
  }

  Widget _buildScoresheetCard(BuildContext context, Scoresheet scoresheet) {
    final theme = Theme.of(context);
    final tags = _parsePgnTags(scoresheet.pgn);
    final players = _joinNonEmpty([
      _joinNonEmpty([tags['White'], tags['Black']], ' - '),
      tags['Result'],
    ], '\t\t\t');
    final eventRound = _joinNonEmpty([
      tags['Event'],
      tags['Round'],
    ], ' - Game ');
    final invalid = _hasInvalidMoves(scoresheet.pgn);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () {
              if (!invalid) {
                Navigator.of(
                  context,
                ).pushNamed(BoardScreen.routeName, arguments: scoresheet);
              }
            },
            onLongPress: () async {
              final updated = await Navigator.of(
                context,
              ).pushNamed(GameDetailScreen.routeName, arguments: scoresheet);
              if (updated == true && mounted) {
                await _loadScoresheets();
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(_cardInternalPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (players != null)
                          Text(players, style: theme.textTheme.bodyMedium),
                        if (players != null && eventRound != null)
                          const SizedBox(height: 4),
                        if (eventRound != null)
                          Text(eventRound, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (invalid)
          Positioned(
            top: _invalidIndicatorInset,
            right: _invalidIndicatorInset,
            child: Container(
              width: _invalidIndicatorSize,
              height: _invalidIndicatorSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  String _errorMessage(String code) => switch (code) {
    'quota_exceeded' =>
      'AI provider quota exceeded. Try again later or switch provider.',
    'provider_unavailable' =>
      'AI provider is currently unavailable. Try again later.',
    'unknown_provider' =>
      'Unknown AI provider selected. Please check your settings.',
    'model_not_found' => 'The selected AI model is unavailable.',
    'empty_model_output' => 'The AI returned no content. Try a clearer image.',
    'unauthorized' => 'Authentication required. Please sign in.',
    'payload_too_large' => 'Image is too large. Please use a smaller file.',
    _ => 'Extraction failed. Try again.',
  };

  bool _hasInvalidMoves(String pgn) {
    final movesMatch = RegExp(r'\n\n(.+)', dotAll: true).firstMatch(pgn);
    final movesText = movesMatch?.group(1)?.trim() ?? '';
    if (movesText.isEmpty) return false;
    final sans = <String>[];
    for (final m in RegExp(
      r'(\d+)\.\s*(\S+)(?:\s+(\S+))?',
    ).allMatches(movesText)) {
      sans.add(m.group(2) ?? '');
      final black = m.group(3);
      if (black != null) sans.add(black);
    }
    while (sans.isNotEmpty && sans.last.isEmpty) sans.removeLast();
    if (sans.isEmpty) return false;
    return validateMoves(sans).any((v) => !v);
  }

  Map<String, String> _parsePgnTags(String pgn) {
    final tags = <String, String>{};
    final exp = RegExp(r'^\[(\w+)\s+"(.*)"\]$', multiLine: true);
    for (final match in exp.allMatches(pgn)) {
      final value = match.group(2)?.trim();
      if (value == null || value.isEmpty || value == '?') continue;
      tags[match.group(1)!] = value;
    }
    return tags;
  }

  _FilterData _buildFilterData() {
    final tagsById = <String, Map<String, String>>{};
    final tournaments = <String>{};
    final rounds = <String>{};
    final whitePlayers = <String>{};
    final blackPlayers = <String>{};
    for (final scoresheet in _scoresheets) {
      final tags = _parsePgnTags(scoresheet.pgn);
      tagsById[scoresheet.id] = tags;
      _addFilterValue(tournaments, tags['Event']);
      _addFilterValue(rounds, tags['Round']);
      _addFilterValue(whitePlayers, tags['White']);
      _addFilterValue(blackPlayers, tags['Black']);
    }
    return _FilterData(
      tagsById: tagsById,
      tournaments: tournaments.toList()..sort(),
      rounds: rounds.toList()..sort(),
      whitePlayers: whitePlayers.toList()..sort(),
      blackPlayers: blackPlayers.toList()..sort(),
    );
  }

  void _addFilterValue(Set<String> values, String? value) {
    if (value == null || value.isEmpty) return;
    values.add(value);
  }

  bool _matchesFilters(Map<String, String> tags) {
    final checks = <bool>[];
    _addFilterMatch(checks, tags['Event'], _selectedTournament);
    _addFilterMatch(checks, tags['Round'], _selectedRound);
    _addFilterMatch(checks, tags['White'], _selectedWhitePlayer);
    _addFilterMatch(checks, tags['Black'], _selectedBlackPlayer);
    if (checks.isEmpty) return true;
    return checks.every((matches) => matches);
  }

  void _addFilterMatch(List<bool> checks, String? actual, String? selected) {
    if (selected == null) return;
    checks.add(actual == selected);
  }

  void _clearFilters() {
    setState(() {
      _selectedTournament = null;
      _selectedRound = null;
      _selectedWhitePlayer = null;
      _selectedBlackPlayer = null;
    });
  }

  bool get _hasActiveFilters =>
      _selectedTournament != null ||
      _selectedRound != null ||
      _selectedWhitePlayer != null ||
      _selectedBlackPlayer != null;

  void _clearMissingFilters(_FilterData filterData) {
    if (!filterData.tournaments.contains(_selectedTournament)) {
      _selectedTournament = null;
    }
    if (!filterData.rounds.contains(_selectedRound)) {
      _selectedRound = null;
    }
    if (!filterData.whitePlayers.contains(_selectedWhitePlayer)) {
      _selectedWhitePlayer = null;
    }
    if (!filterData.blackPlayers.contains(_selectedBlackPlayer)) {
      _selectedBlackPlayer = null;
    }
  }

  String? _joinNonEmpty(List<String?> parts, String separator) {
    final values = parts
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isEmpty) return null;
    return values.join(separator);
  }
}

class _FilterData {
  const _FilterData({
    required this.tagsById,
    required this.tournaments,
    required this.rounds,
    required this.whitePlayers,
    required this.blackPlayers,
  });

  final Map<String, Map<String, String>> tagsById;
  final List<String> tournaments;
  final List<String> rounds;
  final List<String> whitePlayers;
  final List<String> blackPlayers;
}

class _FilterDropdown extends StatefulWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.width,
    required this.fillColor,
    required this.menuHeight,
    required this.onSelected,
  });

  final String label;
  final String? value;
  final List<String> options;
  final double width;
  final Color fillColor;
  final double menuHeight;
  final ValueChanged<String?> onSelected;

  @override
  State<_FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<_FilterDropdown> {
  final _controller = MenuController();
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodySmall = theme.textTheme.bodySmall;
    final hasValue = widget.value != null;

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: Offset.zero,
      onOpen: () => setState(() => _isOpen = true),
      onClose: () => setState(() => _isOpen = false),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: WidgetStatePropertyAll(Size(widget.width, 0)),
        maximumSize: WidgetStatePropertyAll(
          Size(widget.width, widget.menuHeight),
        ),
      ),
      menuChildren: [
        if (hasValue)
          MenuItemButton(
            onPressed: () {
              widget.onSelected(null);
              _controller.close();
            },
            style: MenuItemButton.styleFrom(textStyle: bodySmall),
            child: Text(
              'Any',
              style: bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ...widget.options.map(
          (option) => MenuItemButton(
            onPressed: () {
              widget.onSelected(option);
              _controller.close();
            },
            style: MenuItemButton.styleFrom(
              textStyle: bodySmall,
              backgroundColor: option == widget.value
                  ? theme.colorScheme.primaryContainer
                  : null,
            ),
            child: Text(option, style: bodySmall),
          ),
        ),
      ],
      builder: (context, controller, _) => GestureDetector(
        onTap: () => _isOpen ? controller.close() : controller.open(),
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.fillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? widget.value! : widget.label,
                  style: hasValue
                      ? bodySmall
                      : bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              Icon(
                _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
