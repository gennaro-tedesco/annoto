import 'package:annoto/app/themes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        themeNotifier,
        uiFontScaleNotifier,
        appFontNotifier,
      ]),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            leading: IconButton.filled(
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor:
                    theme.inputDecorationTheme.fillColor ??
                    theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurface,
              ),
              tooltip: 'Back',
              icon: const Icon(Icons.chevron_left, size: 22),
            ),
            title: const Text('Appearance'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      RadioGroup<AppThemeOption>(
                        groupValue: themeNotifier.value,
                        onChanged: (value) {
                          if (value != null) {
                            themeNotifier.value = value;
                          }
                        },
                        child: Column(
                          children: AppThemeOption.values
                              .map(
                                (option) => RadioListTile<AppThemeOption>(
                                  value: option,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(option.label),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Font Size', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '${(uiFontScaleNotifier.value * 100).round()}%',
                        style: theme.textTheme.bodySmall,
                      ),
                      Slider(
                        min: 0.85,
                        max: 1.80,
                        divisions: 19,
                        value: uiFontScaleNotifier.value,
                        onChanged: (value) {
                          uiFontScaleNotifier.value = value;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Font', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AppFontOption>(
                        initialValue: appFontNotifier.value,
                        decoration: const InputDecoration(),
                        items: AppFontOption.values
                            .map(
                              (option) => DropdownMenuItem<AppFontOption>(
                                value: option,
                                child: Text(
                                  option.label,
                                  style: _fontPreviewStyle(option),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            appFontNotifier.value = value;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

TextStyle? _fontPreviewStyle(AppFontOption option) => switch (option) {
  AppFontOption.system => null,
  AppFontOption.lexend => GoogleFonts.lexend(),
  AppFontOption.ubuntu => GoogleFonts.ubuntu(),
  AppFontOption.josefinSans => GoogleFonts.josefinSans(),
  AppFontOption.nunito => GoogleFonts.nunito(),
};
