import 'package:flutter/material.dart';

/// Wraps [Image] so animated GIFs and WebP freeze on the current frame
/// when [TickerMode] is disabled (e.g. when the app loses focus).
/// Static images are unaffected.
class PausableAnimatedImage extends StatefulWidget {
  const PausableAnimatedImage({
    super.key,
    required this.image,
    this.fit,
    this.filterQuality = FilterQuality.low,
    this.width,
    this.height,
  });

  final ImageProvider image;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final double? width;
  final double? height;

  @override
  State<PausableAnimatedImage> createState() => _PausableAnimatedImageState();
}

class _PausableAnimatedImageState extends State<PausableAnimatedImage> {
  Widget? _frozenFrame;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: widget.image,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      width: widget.width,
      height: widget.height,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (TickerMode.of(context)) {
          _frozenFrame = child;
          return child;
        }
        return _frozenFrame ?? child;
      },
    );
  }
}
