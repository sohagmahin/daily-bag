import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../app/haptics.dart';
import '../app/motion.dart';

/// Touch feedback in the Liquid Glass manner: the control sinks under the
/// finger, leans a little toward it, lights up where it was touched, and
/// springs back with the release velocity. Fires a haptic on tap, and a
/// firmer one when a long press lands.
class LiquidPressable extends StatefulWidget {
  const LiquidPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.haptic = HapticKind.light,
    this.longPressHaptic = HapticKind.medium,
    this.pressedScale = 0.96,
    this.borderRadius,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Fires after the platform long-press delay (500ms), like the design.
  final VoidCallback? onLongPress;
  final HapticKind haptic;
  final HapticKind longPressHaptic;
  final double pressedScale;

  /// When set, a soft light follows the finger inside this radius.
  final double? borderRadius;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<LiquidPressable> createState() => _LiquidPressableState();
}

class _LiquidPressableState extends State<LiquidPressable>
    with TickerProviderStateMixin {
  static const _maxLean = 5.0;

  late final _press = AnimationController.unbounded(vsync: this);
  late final _lean = AnimationController.unbounded(vsync: this);
  final _leanOffset = ValueNotifier(Offset.zero);
  Offset _origin = Offset.zero;
  Offset _touch = Offset.zero;
  bool _down = false;

  @override
  void dispose() {
    _press.dispose();
    _lean.dispose();
    _leanOffset.dispose();
    super.dispose();
  }

  void _spring(
    AnimationController c,
    double target,
    SpringDescription spring, {
    double? velocity,
  }) {
    c.animateWith(
      SpringSimulation(spring, c.value, target, velocity ?? c.velocity),
    );
  }

  void _handleDown(TapDownDetails d) {
    _down = true;
    _origin = d.globalPosition;
    _touch = d.localPosition;
    _leanOffset.value = Offset.zero;
    _lean.value = 1;
    _spring(_press, 1, Motion.pressDown);
  }

  void _handleMove(PointerMoveEvent e) {
    if (!_down) return;
    final delta = (e.position - _origin) * 0.08;
    final distance = delta.distance;
    _leanOffset.value = distance > _maxLean
        ? delta / distance * _maxLean
        : delta;
  }

  void _release({bool tapped = false}) {
    _down = false;
    // A quick tap may lift before the press registers; give it a pulse.
    if (tapped && _press.value < 0.5) {
      _spring(_press, 0, Motion.pressRelease, velocity: 9);
    } else {
      _spring(_press, 0, Motion.pressRelease);
    }
    _spring(_lean, 0, Motion.pressRelease);
  }

  void _handleTap() {
    Haptics.play(widget.haptic);
    widget.onTap?.call();
  }

  void _handleLongPress() {
    // The tap was cancelled when the long press won, so we are springing
    // back already.
    Haptics.play(widget.longPressHaptic);
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) return widget.child;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: Listener(
        onPointerMove: _handleMove,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _handleDown,
          onTapUp: (_) => _release(tapped: true),
          onTapCancel: _release,
          onTap: widget.onTap == null ? null : _handleTap,
          onLongPress: widget.onLongPress == null ? null : _handleLongPress,
          child: AnimatedBuilder(
            animation: Listenable.merge([_press, _lean, _leanOffset]),
            child: widget.child,
            builder: (context, child) {
              final p = _press.value;
              Widget result = Transform.scale(
                scale: 1 - (1 - widget.pressedScale) * p,
                child: child,
              );
              if (widget.borderRadius != null && p > 0.01) {
                result = CustomPaint(
                  foregroundPainter: _TouchGlowPainter(
                    center: _touch,
                    radius: widget.borderRadius!,
                    strength: p.clamp(0.0, 1.0),
                  ),
                  child: result,
                );
              }
              return Transform.translate(
                offset: _leanOffset.value * _lean.value,
                child: result,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TouchGlowPainter extends CustomPainter {
  _TouchGlowPainter({
    required this.center,
    required this.radius,
    required this.strength,
  });

  final Offset center;
  final double radius;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final reach = size.longestSide * 0.9;
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)))
      ..drawCircle(
        center,
        reach,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 255, 255, 0.32 * strength),
              const Color.fromRGBO(255, 255, 255, 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: reach)),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_TouchGlowPainter old) =>
      old.center != center || old.strength != strength || old.radius != radius;
}
