import 'dart:developer' as developer;

/// Optional in-app instrumentation for Dashability.
///
/// Provides convenience methods to emit custom events that Dashability
/// can observe via the VM Service logging stream. Uses only `dart:developer`,
/// zero external dependencies.
///
/// Usage:
/// ```dart
/// DashabilityReporter.interaction('user_drew_stroke');
/// DashabilityReporter.metric('canvas_points', 1523);
/// DashabilityReporter.screen('ImageEditor');
/// ```
class DashabilityReporter {
  DashabilityReporter._();

  /// Report a user interaction event.
  static void interaction(String action) {
    developer.postEvent('dashability.interaction', {
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Report a custom metric.
  static void metric(String name, num value) {
    developer.postEvent('dashability.metric', {
      'name': name,
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Report a screen/route change.
  static void screen(String name) {
    developer.postEvent('dashability.screen', {
      'screen': name,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Report a custom event with arbitrary data.
  static void event(String type, Map<String, Object?> data) {
    developer.postEvent('dashability.$type', {
      ...data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
