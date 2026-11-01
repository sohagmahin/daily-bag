import 'package:flutter/services.dart';

enum HapticKind { none, selection, light, medium, heavy, success, warning }

/// One place that maps intent to the platform haptic engine.
abstract final class Haptics {
  static void play(HapticKind kind) {
    switch (kind) {
      case HapticKind.none:
        return;
      case HapticKind.selection:
        HapticFeedback.selectionClick();
      case HapticKind.light:
        HapticFeedback.lightImpact();
      case HapticKind.medium:
        HapticFeedback.mediumImpact();
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
      case HapticKind.success:
        HapticFeedback.successNotification();
      case HapticKind.warning:
        HapticFeedback.warningNotification();
    }
  }
}
