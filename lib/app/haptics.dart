import 'package:flutter/services.dart';

enum HapticKind { none, selection, light, medium, heavy, success, warning }

/// One place that maps intent to the platform haptic engine.
///
/// Each kind plays one step firmer than its name, so taps feel solid.
abstract final class Haptics {
  static void play(HapticKind kind) {
    switch (kind) {
      case HapticKind.none:
        return;
      case HapticKind.selection:
        HapticFeedback.lightImpact();
      case HapticKind.light:
        HapticFeedback.mediumImpact();
      case HapticKind.medium:
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
      case HapticKind.success:
        HapticFeedback.successNotification();
      case HapticKind.warning:
        HapticFeedback.warningNotification();
    }
  }
}
