import 'dart:async';
import 'package:dashability_core/src/analysis/event_types.dart';
import 'package:dashability_core/src/connector/config.dart';
import 'package:dashability_core/src/connector/connector.dart';
import 'observer.dart';

/// Monitors widget rebuild counts via Flutter inspector service extensions.
///
/// Polls the widget inspector periodically to track rebuild counts
/// and emits [RebuildSpike] events when a widget exceeds the threshold.
class RebuildObserver implements Observer {
  final DashabilityConfig _config;
  final _eventController = StreamController<ObservationEvent>.broadcast();
  Timer? _pollTimer;
  Connector? _connector;
  bool _running = false;

  /// Current rebuild counts per widget name.
  final _rebuildCounts = <String, int>{};

  /// Previous rebuild counts for computing deltas.
  final _previousCounts = <String, int>{};

  /// Poll interval for checking rebuilds.
  static const _pollInterval = Duration(seconds: 2);

  RebuildObserver(this._config);

  @override
  bool get isRunning => _running;

  @override
  Stream<ObservationEvent> get events => _eventController.stream;

  /// Current rebuild counts (read-only).
  Map<String, int> get rebuildCounts => Map.unmodifiable(_rebuildCounts);

  /// Top rebuilding widgets, sorted by count descending.
  List<MapEntry<String, int>> get hotspots {
    final sorted = _rebuildCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).toList();
  }

  @override
  Future<void> start(Connector connector) async {
    if (_running) return;
    _running = true;
    _connector = connector;

    // Try to enable widget rebuild tracking.
    try {
      await connector.callServiceExtension(
        'ext.flutter.inspector.trackRebuildDirtyWidgets',
        args: {'enabled': 'true'},
      );
    } catch (_) {
      // Extension may not be available — continue without rebuild tracking.
    }

    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  Future<void> stop() async {
    _running = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _connector = null;
  }

  Future<void> _poll() async {
    if (!_running || _connector == null) return;

    try {
      final result = await _connector!.callServiceExtension(
        'ext.flutter.inspector.getRebuildDirtyWidgets',
      );

      final widgets = result['widgets'] as List<dynamic>?;
      if (widgets == null) return;

      _previousCounts.clear();
      _previousCounts.addAll(_rebuildCounts);
      _rebuildCounts.clear();

      for (final w in widgets) {
        if (w is Map<String, dynamic>) {
          final name = w['name'] as String? ?? 'Unknown';
          final count = w['count'] as int? ?? 0;
          _rebuildCounts[name] = count;

          // Check for spike: delta exceeds threshold.
          final previousCount = _previousCounts[name] ?? 0;
          final delta = count - previousCount;
          final rate = delta / _pollInterval.inSeconds;

          if (rate > _config.rebuildSpikeThreshold) {
            _eventController.add(RebuildSpike(
              widget: name,
              rebuildCount: delta,
              window: _pollInterval,
              severity: rate > _config.rebuildSpikeThreshold * 2
                  ? EventSeverity.critical
                  : EventSeverity.warning,
            ));
          }
        }
      }
    } catch (_) {
      // Silently continue if polling fails (app may be busy).
    }
  }
}
