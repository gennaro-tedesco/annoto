import 'package:annoto/app/themes.dart';
import 'package:annoto/services/chess_engine.dart';
import 'package:flutter/material.dart';

class _HashTrackShape extends RoundedRectSliderTrackShape {
  const _HashTrackShape();

  static const _tickValues = [16.0, 32.0, 64.0, 128.0, 256.0];
  static const _min = 16.0;
  static const _max = 256.0;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
    );

    for (final value in _tickValues) {
      final t = (value - _min) / (_max - _min);
      final x = trackRect.left + t * trackRect.width;
      final center = Offset(x, trackRect.center.dy);
      final xOffset = center.dx - thumbCenter.dx;
      final (Color? begin, Color? end) = switch (textDirection) {
        TextDirection.ltr when xOffset > 0 => (
          sliderTheme.disabledInactiveTickMarkColor,
          sliderTheme.inactiveTickMarkColor,
        ),
        TextDirection.rtl when xOffset < 0 => (
          sliderTheme.disabledInactiveTickMarkColor,
          sliderTheme.inactiveTickMarkColor,
        ),
        TextDirection.ltr || TextDirection.rtl => (
          sliderTheme.disabledActiveTickMarkColor,
          sliderTheme.activeTickMarkColor,
        ),
      };
      final paint = Paint()
        ..color = ColorTween(begin: begin, end: end).evaluate(enableAnimation)!;
      final radius = sliderTheme.trackHeight! / 4;
      context.canvas.drawCircle(center, radius, paint);
    }
  }
}

class EngineSettingsScreen extends StatefulWidget {
  const EngineSettingsScreen({super.key});

  @override
  State<EngineSettingsScreen> createState() => _EngineSettingsScreenState();
}

class _EngineSettingsScreenState extends State<EngineSettingsScreen> {
  final _oex = OexChessEngine();
  List<ExternalChessEngine>? _engines;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadEngines();
  }

  Future<void> _loadEngines() async {
    setState(() => _loading = true);
    try {
      final engines = await _oex.listEngines();
      if (!mounted) return;
      final selected = selectedEnginePackageNotifier.value;
      if (selected != null && !engines.any((e) => e.packageName == selected)) {
        selectedEnginePackageNotifier.value = null;
      }
      setState(() {
        _engines = engines;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _engines = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        engineThreadsNotifier,
        engineHashNotifier,
        selectedEnginePackageNotifier,
        analysisDepthNotifier,
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
            title: const Text('Chess engine'),
            actions: [],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildEngineSelector(theme),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Threads', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${engineThreadsNotifier.value}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Slider(
                        min: 1,
                        max: 8,
                        divisions: 7,
                        value: engineThreadsNotifier.value.toDouble(),
                        label: '${engineThreadsNotifier.value}',
                        onChanged: (value) {
                          engineThreadsNotifier.value = value.round();
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
                      Text('Hash', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${engineHashNotifier.value}MB',
                        style: theme.textTheme.bodySmall,
                      ),
                      SliderTheme(
                        data: SliderTheme.of(
                          context,
                        ).copyWith(trackShape: const _HashTrackShape()),
                        child: Slider(
                          min: 16,
                          max: 256,
                          value: engineHashNotifier.value.toDouble(),
                          label: '${engineHashNotifier.value}MB',
                          onChanged: (value) {
                            const options = [16, 32, 64, 128, 256];
                            engineHashNotifier.value = options.reduce(
                              (a, b) =>
                                  (value - a).abs() < (value - b).abs() ? a : b,
                            );
                          },
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
                      Text(
                        'Analysis depth',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${analysisDepthNotifier.value}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Slider(
                        min: 8,
                        max: 30,
                        divisions: 22,
                        value: analysisDepthNotifier.value.toDouble(),
                        label: '${analysisDepthNotifier.value}',
                        onChanged: (value) {
                          analysisDepthNotifier.value = value.round();
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

  Widget _buildEngineSelector(ThemeData theme) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final engines = _engines;
    if (engines == null || engines.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Engine', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                engines == null
                    ? 'No external chess engine selected'
                    : 'No compatible external chess engines found',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final selectedPackage = selectedEnginePackageNotifier.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Engine', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...engines.map((engine) {
              final selected = engine.packageName == selectedPackage;
              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? theme.colorScheme.primary : null,
                ),
                title: Text(engine.name, style: theme.textTheme.bodyMedium),
                subtitle: Text(
                  engine.packageName,
                  style: theme.textTheme.bodySmall,
                ),
                onTap: () =>
                    selectedEnginePackageNotifier.value = engine.packageName,
              );
            }),
          ],
        ),
      ),
    );
  }
}
