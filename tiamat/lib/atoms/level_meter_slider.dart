import 'package:flutter/material.dart';

/// A slider whose track doubles as a level meter.
///
/// [value] is the threshold position in [min, max] (controls the thumb).
/// [level] is the current input level, also in [min, max] (fills the track).
/// The fill is green when level >= value (gate open), gray when below.
class LevelMeterSlider extends StatelessWidget {
  const LevelMeterSlider({
    super.key,
    required this.value,
    required this.level,
    this.min = 0.0,
    this.max = 1.0,
    this.onChanged,
    this.onChangeEnd,
  });

  final double value;
  final double level;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  static const double _thumbRadius = 10.0;
  static const double _trackHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final normLevel = ((level - min) / (max - min)).clamp(0.0, 1.0);
    final normThreshold = ((value - min) / (max - min)).clamp(0.0, 1.0);

    return SizedBox(
      height: 48, // standard Slider touch-target height
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Track background + level fill, aligned to the slider's track rect.
          Padding(
            // The Slider thumb centre travels from thumbRadius to
            // width-thumbRadius, so the track is inset by thumbRadius on each
            // side. Match that padding so the fill aligns with the thumb.
            padding: const EdgeInsets.symmetric(horizontal: _thumbRadius),
            child: Center(
              child: SizedBox(
                height: _trackHeight,
                child: CustomPaint(
                  painter: _MeterPainter(
                    level: normLevel,
                    threshold: normThreshold,
                    scheme: scheme,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          // Slider with invisible track — only the thumb is rendered.
          Material(
            color: Colors.transparent,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                disabledActiveTrackColor: Colors.transparent,
                disabledInactiveTrackColor: Colors.transparent,
                thumbColor: scheme.onSurface,
                overlayColor: scheme.onSurface.withAlpha(30),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: _thumbRadius),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  const _MeterPainter({
    required this.level,
    required this.threshold,
    required this.scheme,
  });

  final double level;
  final double threshold;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(4);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(fullRect, radius),
      Paint()..color = scheme.surfaceContainerHighest.withAlpha(120),
    );

    // Level fill
    if (level > 0) {
      final levelWidth = (level * size.width).clamp(0.0, size.width);
      final fillColor = level >= threshold
          ? const Color(0xFF4CAF50)
          : scheme.onSurface.withAlpha(60);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, levelWidth, size.height),
          radius,
        ),
        Paint()..color = fillColor,
      );
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.level != level ||
      old.threshold != threshold ||
      old.scheme != scheme;
}
