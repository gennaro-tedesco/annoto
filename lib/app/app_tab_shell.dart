import 'package:annoto/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class AppTabShell extends StatefulWidget {
  const AppTabShell({super.key});

  @override
  State<AppTabShell> createState() => _AppTabShellState();
}

class _AppTabShellState extends State<AppTabShell> {
  static const _homeTabIndex = 0;
  static const _engineTabIndex = 1;
  static const _lichessTabIndex = 2;
  static const _tabHeight = 56.0;
  static const _homeLabel = 'home';
  static const _engineLabel = 'engine';
  static const _lichessLabel = 'lichess';

  int _selectedTabIndex = _homeTabIndex;

  late final List<Widget> _tabs = const [
    HomeScreen(),
    _PlaceholderTabScreen(title: _engineLabel),
    _PlaceholderTabScreen(title: _lichessLabel),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      body: IndexedStack(index: _selectedTabIndex, children: _tabs),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: _tabHeight,
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  context,
                  fillColor: fillColor,
                  icon: LucideIcons.house,
                  label: _homeLabel,
                  selected: _selectedTabIndex == _homeTabIndex,
                  onTap: () => _onDestinationSelected(_homeTabIndex),
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  context,
                  fillColor: fillColor,
                  icon: LucideIcons.cpu,
                  label: _engineLabel,
                  selected: _selectedTabIndex == _engineTabIndex,
                  onTap: () => _onDestinationSelected(_engineTabIndex),
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  context,
                  fillColor: fillColor,
                  icon: LucideIcons.sword,
                  label: _lichessLabel,
                  selected: _selectedTabIndex == _lichessTabIndex,
                  onTap: () => _onDestinationSelected(_lichessTabIndex),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required Color fillColor,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: fillColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: _tabHeight,
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
                  size: 18,
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

class _PlaceholderTabScreen extends StatelessWidget {
  const _PlaceholderTabScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(title, style: theme.textTheme.titleLarge),
      ),
    );
  }
}
