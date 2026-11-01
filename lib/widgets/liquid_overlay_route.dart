import 'package:flutter/widgets.dart';

import '../app/motion.dart';
import 'liquid_glass.dart';

/// A see-through route whose page animates itself from the route's
/// spring-curved animation (popovers morph, sheets slide).
class LiquidOverlayRoute<T> extends PageRoute<T> {
  LiquidOverlayRoute({required this.builder, this.curve = Motion.bouncy});

  final Widget Function(BuildContext context, Animation<double> animation)
  builder;
  final SpringCurve curve;

  late final CurvedAnimation _curved = CurvedAnimation(
    parent: animation!,
    curve: curve,
    reverseCurve: Motion.dismiss,
  );

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => curve.duration;

  @override
  Duration get reverseTransitionDuration => Motion.dismissDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context, _curved);

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }
}

/// A full-screen dimmer that can also frost what is beneath it.
class GlassScrim extends StatelessWidget {
  const GlassScrim({
    super.key,
    required this.progress,
    required this.color,
    this.blur = 0,
    this.onTap,
    this.semanticLabel,
  });

  final double progress;
  final Color color;
  final double blur;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final style = GlassStyle(
      radius: 0,
      color: color.withValues(alpha: color.a * t),
      blur: blur * t,
      borderWidth: 0,
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: blur > 0 && t > 0
            ? LiquidBox(style: style, child: const SizedBox.expand())
            : ColoredBox(color: style.color, child: const SizedBox.expand()),
      ),
    );
  }
}
