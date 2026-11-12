import 'package:flutter/services.dart';

import '../services/app_settings.dart';

/// Every vibration in the app goes through here, so one setting turns them
/// all off and the strength per kind of event stays the same everywhere.
abstract final class Haptics {
  static bool get _on => AppSettings.instance.haptics;

  /// Switching tabs, toggles.
  static void select() {
    if (_on) HapticFeedback.selectionClick();
  }

  /// An action that changes something (start a ride, connect).
  static void commit() {
    if (_on) HapticFeedback.lightImpact();
  }

  /// Something finished (ride saved).
  static void success() {
    if (_on) HapticFeedback.mediumImpact();
  }
}
