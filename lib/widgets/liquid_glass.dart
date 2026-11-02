import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _transparent = Color(0x00000000);

Color _scaleAlpha(Color c, double factor) =>
    c.withValues(alpha: (c.a * factor).clamp(0.0, 1.0));

/// A CSS `box-shadow`, painted with the browser's convention
/// (Gaussian sigma = blur / 2) so values copy straight from the design.
@immutable
class CssShadow {
  const CssShadow({
    this.dx = 0,
    this.dy = 0,
    this.blur = 0,
    this.spread = 0,
    required this.color,
  }) : inset = false;

  const CssShadow.inset({
    this.dx = 0,
    this.dy = 0,
    this.blur = 0,
    this.spread = 0,
    required this.color,
  }) : inset = true;

  const CssShadow._(
    this.dx,
    this.dy,
    this.blur,
    this.spread,
    this.color,
    this.inset,
  );

  final double dx;
  final double dy;
  final double blur;
  final double spread;
  final Color color;
  final bool inset;

  CssShadow withAlphaFactor(double factor) =>
      CssShadow._(dx, dy, blur, spread, _scaleAlpha(color, factor), inset);

  static CssShadow lerp(CssShadow a, CssShadow b, double t) {
    final ct = t.clamp(0.0, 1.0);
    return CssShadow._(
      ui.lerpDouble(a.dx, b.dx, ct)!,
      ui.lerpDouble(a.dy, b.dy, ct)!,
      ui.lerpDouble(a.blur, b.blur, ct)!,
      ui.lerpDouble(a.spread, b.spread, ct)!,
      Color.lerp(a.color, b.color, ct)!,
      ct < 0.5 ? a.inset : b.inset,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CssShadow &&
      other.dx == dx &&
      other.dy == dy &&
      other.blur == blur &&
      other.spread == spread &&
      other.color == color &&
      other.inset == inset;

  @override
  int get hashCode => Object.hash(dx, dy, blur, spread, color, inset);
}

/// Everything that makes a surface look like glass: the tint, the backdrop
/// blur + saturation, the rim, and its shadows (inset highlight included).
@immutable
class GlassStyle {
  const GlassStyle({
    required this.radius,
    required this.color,
    this.blur = 0,
    this.saturation = 1,
    this.borderColor = _transparent,
    this.borderWidth = 1,
    this.shadows = const [],
  });

  final double radius;
  final Color color;

  /// CSS `backdrop-filter: blur()` radius. Zero means no backdrop filter.
  final double blur;

  /// CSS `saturate()` amount applied after the blur.
  final double saturation;
  final Color borderColor;
  final double borderWidth;
  final List<CssShadow> shadows;

  GlassStyle copyWith({
    double? radius,
    Color? color,
    List<CssShadow>? shadows,
  }) => GlassStyle(
    radius: radius ?? this.radius,
    color: color ?? this.color,
    blur: blur,
    saturation: saturation,
    borderColor: borderColor,
    borderWidth: borderWidth,
    shadows: shadows ?? this.shadows,
  );

  GlassStyle faded(double factor) => GlassStyle(
    radius: radius,
    color: _scaleAlpha(color, factor),
    blur: blur * factor,
    saturation: ui.lerpDouble(1, saturation, factor)!,
    borderColor: _scaleAlpha(borderColor, factor),
    borderWidth: borderWidth,
    shadows: [for (final s in shadows) s.withAlphaFactor(factor)],
  );

  /// Geometry follows [t] past 0..1 so springs can overshoot; paint is clamped.
  static GlassStyle lerp(GlassStyle a, GlassStyle b, double t) {
    final ct = t.clamp(0.0, 1.0);
    return GlassStyle(
      radius: ui.lerpDouble(a.radius, b.radius, t)!.clamp(0.0, double.infinity),
      color: Color.lerp(a.color, b.color, ct)!,
      blur: ui.lerpDouble(a.blur, b.blur, ct)!,
      saturation: ui.lerpDouble(a.saturation, b.saturation, ct)!,
      borderColor: Color.lerp(a.borderColor, b.borderColor, ct)!,
      borderWidth: ui.lerpDouble(a.borderWidth, b.borderWidth, ct)!,
      shadows: a.shadows.length == b.shadows.length
          ? [
              for (var i = 0; i < a.shadows.length; i++)
                CssShadow.lerp(a.shadows[i], b.shadows[i], ct),
            ]
          : (ct < 0.5 ? a.shadows : b.shadows),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassStyle &&
      other.radius == radius &&
      other.color == color &&
      other.blur == blur &&
      other.saturation == saturation &&
      other.borderColor == borderColor &&
      other.borderWidth == borderWidth &&
      listEquals(other.shadows, shadows);

  @override
  int get hashCode => Object.hash(
    radius,
    color,
    blur,
    saturation,
    borderColor,
    borderWidth,
    Object.hashAll(shadows),
  );
}

/// Fades every [LiquidBox] below it.
///
/// A backdrop filter inside an [Opacity] samples an empty layer instead of
/// the scene, so glass must never be faded with [Opacity] or
/// [FadeTransition]. Glass reads this instead and scales its own paint.
class GlassFade extends InheritedWidget {
  const GlassFade({super.key, required this.opacity, required super.child});

  final double opacity;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassFade>()?.opacity ?? 1;

  @override
  bool updateShouldNotify(GlassFade oldWidget) => oldWidget.opacity != opacity;
}

/// Applies the surrounding [GlassFade] to content that is not glass.
class FadeWithGlass extends StatelessWidget {
  const FadeWithGlass({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fade = GlassFade.of(context);
    return fade >= 1
        ? child
        : Opacity(opacity: fade.clamp(0.0, 1.0), child: child);
  }
}

/// A rounded surface painted from a [GlassStyle].
///
/// [width] and [height] are CSS content-box sizes, like the design: padding
/// and border are added on top.
class LiquidBox extends StatelessWidget {
  const LiquidBox({
    super.key,
    required this.style,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.child,
  });

  final GlassStyle style;
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final fade = GlassFade.of(context).clamp(0.0, 1.0);
    final s = fade < 1 ? style.faded(fade) : style;

    Widget content = SizedBox(width: width, height: height, child: child);
    if (fade < 1) {
      content = Opacity(
        opacity: fade,
        child: GlassFade(opacity: 1, child: content),
      );
    }

    Widget box = CustomPaint(
      painter: _SurfacePainter(s),
      child: Padding(
        padding: padding + EdgeInsets.all(style.borderWidth),
        child: content,
      ),
    );

    if (style.blur > 0) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(s.radius),
        child: BackdropFilter(
          enabled: s.blur > 0.05,
          filter: _glassFilter(s.blur, s.saturation),
          child: box,
        ),
      );
    }

    if (s.shadows.any((x) => !x.inset)) {
      box = CustomPaint(painter: _DropShadowPainter(s), child: box);
    }
    return box;
  }
}

ui.ImageFilter _glassFilter(double sigma, double saturation) {
  final blur = ui.ImageFilter.blur(
    sigmaX: sigma,
    sigmaY: sigma,
    tileMode: TileMode.mirror,
  );
  if ((saturation - 1).abs() < 0.001) return blur;
  return ui.ImageFilter.compose(
    outer: ui.ColorFilter.matrix(_saturationMatrix(saturation)),
    inner: blur,
  );
}

/// The CSS Filter Effects `saturate()` matrix.
List<double> _saturationMatrix(double s) => [
  0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
  0, 0, 0, 1, 0, //
];

Paint _shadowPaint(CssShadow s) {
  final paint = Paint()..color = s.color;
  if (s.blur > 0) {
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
  }
  return paint;
}

/// Tint, inset shadows and border, in CSS paint order.
class _SurfacePainter extends CustomPainter {
  _SurfacePainter(this.style);

  final GlassStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(style.radius),
    );
    final inner = outer.deflate(style.borderWidth);

    if (style.color.a > 0) {
      canvas.drawRRect(outer, Paint()..color = style.color);
    }

    for (final s in style.shadows) {
      if (!s.inset || s.color.a == 0) continue;
      final hole = inner.shift(Offset(s.dx, s.dy)).deflate(s.spread);
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(
          inner.outerRect.inflate(s.blur * 2 + s.dx.abs() + s.dy.abs() + 1),
        )
        ..addRRect(hole);
      canvas
        ..save()
        ..clipRRect(inner)
        ..drawPath(path, _shadowPaint(s))
        ..restore();
    }

    if (style.borderWidth > 0 && style.borderColor.a > 0) {
      canvas.drawDRRect(outer, inner, Paint()..color = style.borderColor);
    }
  }

  @override
  bool shouldRepaint(_SurfacePainter oldDelegate) => oldDelegate.style != style;
}

/// Outer shadows, clipped to outside the box like CSS, so they never
/// darken the translucent glass above them.
class _DropShadowPainter extends CustomPainter {
  _DropShadowPainter(this.style);

  final GlassStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(style.radius),
    );
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(outer.outerRect.inflate(240))
          ..addRRect(outer),
      );
    for (final s in style.shadows) {
      if (s.inset || s.color.a == 0) continue;
      canvas.drawRRect(
        outer.shift(Offset(s.dx, s.dy)).inflate(s.spread),
        _shadowPaint(s),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DropShadowPainter oldDelegate) =>
      oldDelegate.style != style;
}
