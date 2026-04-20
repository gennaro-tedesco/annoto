import 'package:annoto/app/app_state.dart';
import 'package:annoto/features/account/account_screen.dart';
import 'package:annoto/features/provider/provider_screen.dart';
import 'package:flutter/material.dart';

import 'about_screen.dart';
import 'appearance_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _tileDensity = VisualDensity(vertical: -3.5);

  void _openSubpage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 300) {
              Navigator.of(context).pop();
            }
          },
          child: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final isSignedIn = appState.session.isAuthenticated;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    visualDensity: _tileDensity,
                    title: const Text('Appearance'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _openSubpage(context, const AppearanceSettingsScreen()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    visualDensity: _tileDensity,
                    title: const Text('Account'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openSubpage(context, const AccountScreen()),
                  ),
                  if (isSignedIn) ...[
                    const Divider(height: 1),
                    ListTile(
                      visualDensity: _tileDensity,
                      title: const Text('AI provider'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _openSubpage(context, const ProviderScreen()),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Card(
              child: ListTile(
                visualDensity: _tileDensity,
                title: const Text('About'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSubpage(context, const AboutScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
