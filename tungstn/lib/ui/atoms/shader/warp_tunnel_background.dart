import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class WarpTunnelBackground extends StatefulWidget {
  const WarpTunnelBackground({super.key, this.child});
  final Widget? child;

  @override
  State<WarpTunnelBackground> createState() => _WarpTunnelBackgroundState();
}

class _WarpTunnelBackgroundState extends State<WarpTunnelBackground>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF03030A);

  static bool _loadingShader = false;
  static FragmentShader? _shader;

  late final Ticker _ticker;
  final _repaint = ValueNotifier<double>(0);
  double _time = 0;
  Duration? _last;

  // Poor-performance auto-disable
  Duration? _prevFrame;
  int _slowFrames = 0;
  bool _animate = true;

  @override
  void initState() {
    super.initState();
    if (_shader == null && !_loadingShader) _loadShader();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _loadShader() async {
    _loadingShader = true;
    try {
      final program =
          await FragmentProgram.fromAsset('assets/shader/warp_tunnel.frag');
      _shader = program.fragmentShader();
      if (mounted) setState(() {});
    } catch (_) {
      // Shader unsupported on this renderer — ColoredBox fallback stays.
    } finally {
      _loadingShader = false;
    }
  }

  void _onTick(Duration elapsed) {
    if (!_animate) return;

    if (_prevFrame != null) {
      final diff = elapsed - _prevFrame!;
      if (diff.inMilliseconds > 33) {
        _slowFrames++;
        if (_slowFrames > 10) {
          _animate = false;
          _ticker.stop();
          return;
        }
      } else {
        _slowFrames = 0;
      }
    }
    _prevFrame = elapsed;

    if (_last != null) {
      _time += (elapsed - _last!).inMicroseconds / 1e6;
    }
    _last = elapsed;
    _repaint.value = _time;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null) {
      return ColoredBox(
          color: _bg, child: widget.child ?? const SizedBox.expand());
    }
    return CustomPaint(
      painter: _WarpTunnelPainter(_shader!, _repaint),
      child: widget.child ?? const SizedBox.expand(),
    );
  }
}

class _WarpTunnelPainter extends CustomPainter {
  final FragmentShader shader;
  final ValueNotifier<double> repaintNotifier;

  _WarpTunnelPainter(this.shader, this.repaintNotifier)
      : super(repaint: repaintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, repaintNotifier.value * 0.4);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_WarpTunnelPainter old) => old.shader != shader;
}
