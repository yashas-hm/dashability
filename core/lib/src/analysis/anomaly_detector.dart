import 'dart:async';
import 'dart:collection';

import 'package:dashability/src/analysis/event_types.dart';
import 'package:dashability/src/connector/config.dart';

/// Tier 1 rule-based anomaly detection.
///
/// Consumes raw [ObservationEvent]s from observers, applies rules,
/// and emits only anomalies worth reporting to the AI layer.
class AnomalyDetector {
  final _anomalyController = StreamController<ObservationEvent>.broadcast();
  StreamSubscription<ObservationEvent>? _subscription;

  /// Detected anomalies since last drain.
  final _pendingAnomalies = Queue<ObservationEvent>();
  static const _maxPending = 100;

  AnomalyDetector(this._config);

  /// Stream of detected anomalies.
  Stream<ObservationEvent> get anomalies => _anomalyController.stream;

  /// Start listening to an event source.
  void attach(Stream<ObservationEvent> source) {
    _subscription = source.listen(_evaluate);
  }

  /// Stop listening.
  Future<void> detach() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Drain all pending anomalies and clear the buffer.
  List<ObservationEvent> drainAnomalies() {
    final result = _pendingAnomalies.toList();
    _pendingAnomalies.clear();
    return result;
  }

  void _evaluate(ObservationEvent event) {
    switch (event) {
      case FrameDrop():
      // Always report frame drops — they've already been filtered by FrameObserver.
        _emit(event);

      case RebuildSpike():
      // Always report — already filtered by RebuildObserver threshold.
        _emit(event);

      case ErrorCaught():
      // All errors are anomalies.
        _emit(event);

      case LogEntry():
      // Only escalate error/severe level logs.
        if (event.level == 'error' || event.level == 'severe') {
          _emit(event);
        }

      case MetricsSnapshot():
      // Snapshots are informational, not anomalies.
        break;
    }
  }

  void _emit(ObservationEvent event) {
    _pendingAnomalies.addLast(event);
    while (_pendingAnomalies.length > _maxPending) {
      _pendingAnomalies.removeFirst();
    }
    _anomalyController.add(event);
  }
}
