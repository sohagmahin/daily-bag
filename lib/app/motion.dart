import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// A damped-spring [Curve] described the way SwiftUI describes springs:
/// [response] is the period of the undamped spring in seconds and
/// [dampingFraction] is the damping ratio (1 = no overshoot).
///
/// The curve is evaluated in real time, so it must be driven for [duration].
class SpringCurve extends Curve {
  const SpringCurve({
    required this.response,
    required this.dampingFraction,
    required this.duration,
  });

  final double response;
  final double dampingFraction;
  final Duration duration;

  @override
  double transformInternal(double t) {
    final time = t * duration.inMicroseconds / Duration.microsecondsPerSecond;
    final omega = 2 * math.pi / response;
    final zeta = dampingFraction;
    if (zeta >= 1) {
      return 1 - (1 + omega * time) * math.exp(-omega * time);
    }
    final damped = omega * math.sqrt(1 - zeta * zeta);
    final decay = math.exp(-zeta * omega * time);
    return 1 -
        decay *
            (math.cos(damped * time) +
                (zeta * omega / damped) * math.sin(damped * time));
  }
}

/// Motion tokens for the Liquid Glass system.
abstract final class Motion {
  /// Small state changes: toggles, text, selection colour.
  static const snappy = SpringCurve(
    response: 0.35,
    dampingFraction: 0.8,
    duration: Duration(milliseconds: 500),
  );

  /// Layout changes: expanding cards, sheets.
  static const smooth = SpringCurve(
    response: 0.5,
    dampingFraction: 0.86,
    duration: Duration(milliseconds: 650),
  );

  /// Glass morphs and sliding indicators — a visible, liquid overshoot.
  static const bouncy = SpringCurve(
    response: 0.45,
    dampingFraction: 0.68,
    duration: Duration(milliseconds: 800),
  );

  /// The spending map folding open or shut: the list glides to the
  /// nearest rest point on the design's ease-out.
  static const fold = Cubic(0.22, 1, 0.36, 1);
  static const foldDuration = Duration(milliseconds: 450);

  /// CSS `cubic-bezier(0.34, 1.56, 0.64, 1)`: a quick pop past the target.
  static const pop = Cubic(0.34, 1.56, 0.64, 1);

  /// The day island opening (`cubic-bezier(0.34, 1.35, 0.64, 1)`), and its
  /// lift and contents settling (`cubic-bezier(0.34, 1.4, 0.64, 1)`).
  static const islandGrow = Cubic(0.34, 1.35, 0.64, 1);
  static const islandPop = Cubic(0.34, 1.4, 0.64, 1);

  /// Used when an overlay collapses back into the control that opened it.
  static const dismiss = Curves.easeInCubic;
  static const dismissDuration = Duration(milliseconds: 320);

  /// Physical springs for touch feedback, which carry finger velocity.
  static const pressDown = SpringDescription(
    mass: 1,
    stiffness: 900,
    damping: 50,
  );
  static const pressRelease = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 26,
  );
}
