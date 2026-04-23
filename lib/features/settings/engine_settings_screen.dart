import 'package:annoto/app/themes.dart';
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

class EngineSettingsScreen extends StatelessWidget {
  const EngineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        engineThreadsNotifier,
        engineHashNotifier,
        engineNameNotifier,
      ]),
      builder: (context, child) {
        final theme = Theme.of(context);
        final engineName = engineNameNotifier.value;
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
            title: const Text('Engine settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (engineName != null) ...[
                Center(
                  child: Chip(
                    avatar: const Icon(Icons.memory, size: 16),
                    label: Text(engineName, style: theme.textTheme.bodySmall),
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
            ],
          ),
        );
      },
    );
  }
}
