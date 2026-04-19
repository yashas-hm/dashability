import 'dart:async';

import 'package:dashability/src/analysis/event_types.dart';
import 'package:dashability/src/connector/connector.dart';

/// Abstract interface for all observers.
///
/// Each observer subscribes to specific signals from the connected app
/// and emits [ObservationEvent]s when noteworthy things happen.
abstract class Observer {
  /// Whether this observer is currently running.
  bool get isRunning;

  /// Stream of events produced by this observer.
  Stream<ObservationEvent> get events;

  /// Start observing. Requires an active [connector].
  Future<void> start(Connector connector);

  /// Stop observing and clean up resources.
  Future<void> stop();
}
