import 'dart:convert';

import 'package:annoto/app/app_state.dart';
import 'package:annoto/app/ui_sizes.dart';
import 'package:annoto/features/game_detail/game_detail_screen.dart';
import 'package:annoto/features/review/review_screen.dart';
import 'package:annoto/features/settings/settings_screen.dart';
import 'package:annoto/models/scoresheet.dart';
import 'package:annoto/repositories/scoresheet_repository.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:annoto/widgets/gradient_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _Tab { home, files }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _createButtonWidth = 84.0;
  static const _createButtonHeight = 56.0;
  static const _createButtonBottom = 72.0;
  static const _tabStripHeight = 56.0;
  static const _fabOverlayHeight = _createButtonBottom + _createButtonHeight;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  _Tab _tab = _Tab.home;
  List<Scoresheet> _scoresheets = [];

  @override
  void initState() {
    super.initState();
    _loadScoresheets();
  }

  Future<void> _loadScoresheets() async {
    final scoresheets = await scoresheetRepository.getAll();
    if (!mounted) return;
    setState(() => _scoresheets = scoresheets);
  }

  void _selectTab(_Tab tab) {
    setState(() {
      _tab = tab;
    });
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
              title: const Text('Take photo'),
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
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final image = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null && mounted) await _processScoresheet(image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Upload from files'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                );
                final path = result?.files.single.path;
                if (path != null && mounted) {
                  await _processScoresheet(XFile(path));
                }
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
      final provider = AppStateScope.of(context).selectedProvider.providerKey;
      final response = await Supabase.instance.client.functions.invoke(
        'extract-pgn',
        body: {'image': b64, 'mimeType': mimeType, 'provider': provider},
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

    final appBarTitle = switch (_tab) {
      _Tab.home => 'annoto',
      _Tab.files => 'files',
    };

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.7,
        child: const Drawer(child: SettingsScreen()),
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('images/logo.png', height: 38),
            const SizedBox(width: 8),
            GradientText(
              appBarTitle,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _tab == _Tab.home
          ? _buildHomeTab2(context)
          : _buildFilesEmptyState(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: overlayWidth,
        height: _fabOverlayHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: overlayWidth,
                height: _tabStripHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildHomeTab(
                        context,
                        icon: Icons.home_outlined,
                        label: 'home',
                        selected: _tab == _Tab.home,
                        onTap: () => _selectTab(_Tab.home),
                      ),
                    ),
                    Expanded(
                      child: _buildHomeTab(
                        context,
                        icon: Icons.folder_outlined,
                        label: 'files',
                        selected: _tab == _Tab.files,
                        onTap: () => _selectTab(_Tab.files),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: _createButtonBottom,
              child: SizedBox(
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
            ),
          ],
        ),
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
          const SizedBox(height: _tabStripHeight),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _scoresheets.length,
      itemBuilder: (context, index) {
        final scoresheet = _scoresheets[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: ValueKey(scoresheet.id),
            direction: DismissDirection.endToStart,
            background: const SizedBox.shrink(),
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Icon(Icons.delete, color: theme.colorScheme.onError),
            ),
            confirmDismiss: (_) async {
              await scoresheetRepository.delete(scoresheet.id);
              setState(() => _scoresheets.removeAt(index));
              return false;
            },
            child: _buildScoresheetCard(context, scoresheet),
          ),
        );
      },
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
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).pushNamed(GameDetailScreen.routeName, arguments: scoresheet),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
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
              const Spacer(),
              const SizedBox(width: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _errorMessage(String code) => switch (code) {
    'quota_exceeded' =>
      'AI provider quota exceeded. Try again later or switch provider.',
    'provider_unavailable' =>
      'AI provider is currently unavailable. Try again later.',
    'model_not_found' => 'The selected AI model is unavailable.',
    'empty_model_output' => 'The AI returned no content. Try a clearer image.',
    'unauthorized' => 'Authentication required. Please sign in.',
    'payload_too_large' => 'Image is too large. Please use a smaller file.',
    _ => 'Extraction failed. Try again.',
  };

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

  String? _joinNonEmpty(List<String?> parts, String separator) {
    final values = parts
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isEmpty) return null;
    return values.join(separator);
  }

  Widget _buildFilesEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.35,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No files yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Uploaded scoresheets will appear here',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: _tabStripHeight),
      ],
    );
  }

  Widget _buildHomeTab(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    return Material(
      color: fillColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: selected
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                )
              : null,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: AppIconSize.inlineAction,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
