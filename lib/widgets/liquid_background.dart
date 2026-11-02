import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../app/tokens.dart';

/// The soft colour fields behind the glass. Each one drifts slowly so
/// the glass above it always has something alive to refract; frame zero is
/// exactly the design.
class LiquidBackground extends StatefulWidget {
  const LiquidBackground({super.key}) : _blobs = _homeBlobs, _settings = false;

  /// The Bazar Note's mint, blue and apricot fields.
  const LiquidBackground.bazarNote({super.key})
    : _blobs = _bazarBlobs,
      _settings = false;

  /// Settings: blue, lilac and mint over its own (darker, in dark) canvas.
  const LiquidBackground.settings({super.key})
    : _blobs = _settingsBlobs,
      _settings = true;

  final List<_Blob> _blobs;
  final bool _settings;

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BlobPainter(
          _drift,
          widget._blobs,
          context.palette,
          settings: widget._settings,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Blob {
  const _Blob({
    required this.diameter,
    required this.color,
    required this.blur,
    required this.opacity,
    required this.phase,
    this.left,
    this.top,
    this.right,
    this.bottom,
  });

  final double diameter;
  final Color color;
  final double blur;
  final double opacity;
  final double phase;
  final double? left, top, right, bottom;

  Offset centerIn(Size size) {
    final r = diameter / 2;
    final x = left != null ? left! + r : size.width - right! - r;
    final y = top != null ? top! + r : size.height - bottom! - r;
    return Offset(x, y);
  }
}

const _homeBlobs = [
  _Blob(
    diameter: 320,
    color: Color(0xFF8EC5FF),
    blur: 70,
    opacity: 0.9,
    phase: 0.0,
    left: -110,
    top: -60,
  ),
  _Blob(
    diameter: 280,
    color: Color(0xFFC7B3FF),
    blur: 70,
    opacity: 0.85,
    phase: 1.7,
    right: -120,
    top: 230,
  ),
  _Blob(
    diameter: 300,
    color: Color(0xFF9BE7D2),
    blur: 80,
    opacity: 0.8,
    phase: 3.1,
    left: -80,
    top: 520,
  ),
  _Blob(
    diameter: 240,
    color: Color(0xFFFFC9A8),
    blur: 70,
    opacity: 0.85,
    phase: 4.4,
    right: -60,
    bottom: -80,
  ),
];

const _bazarBlobs = [
  _Blob(
    diameter: 320,
    color: Color(0xFF9BE7D2),
    blur: 70,
    opacity: 0.85,
    phase: 0.0,
    right: -110,
    top: -60,
  ),
  _Blob(
    diameter: 280,
    color: Color(0xFF8EC5FF),
    blur: 70,
    opacity: 0.85,
    phase: 1.7,
    left: -120,
    top: 260,
  ),
  _Blob(
    diameter: 300,
    color: Color(0xFFFFD59E),
    blur: 80,
    opacity: 0.8,
    phase: 3.1,
    right: -80,
    top: 560,
  ),
];

const _settingsBlobs = [
  _Blob(
    diameter: 320,
    color: Color(0xFF8EC5FF),
    blur: 70,
    opacity: 0.85,
    phase: 0.0,
    left: -110,
    top: -60,
  ),
  _Blob(
    diameter: 280,
    color: Color(0xFFC7B3FF),
    blur: 70,
    opacity: 0.85,
    phase: 1.7,
    right: -120,
    top: 300,
  ),
  _Blob(
    diameter: 260,
    color: Color(0xFF9BE7D2),
    blur: 80,
    opacity: 0.85,
    phase: 3.1,
    left: -60,
    bottom: -60,
  ),
];

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.drift, this.blobs, this.palette, {required this.settings})
    : super(repaint: drift);

  final Animation<double> drift;
  final List<_Blob> blobs;
  final Palette palette;
  final bool settings;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = settings ? palette.settingsBackground : palette.background,
    );
    final a = drift.value * 2 * math.pi;
    for (final blob in blobs) {
      // Offsets are relative to the start so the first frame is the design.
      final dx = (math.sin(a + blob.phase) - math.sin(blob.phase)) * 16;
      final dy = (math.cos(a * 2 + blob.phase) - math.cos(blob.phase)) * 10;
      canvas.drawCircle(
        blob.centerIn(size) + Offset(dx, dy),
        blob.diameter / 2,
        Paint()
          ..color = blob.color.withValues(
            alpha: palette.blobOpacity ?? blob.opacity,
          )
          // CSS filter blur(r) is a Gaussian with sigma = r.
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blob.blur),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) =>
      oldDelegate.blobs != blobs ||
      oldDelegate.palette != palette ||
      oldDelegate.settings != settings;
}
