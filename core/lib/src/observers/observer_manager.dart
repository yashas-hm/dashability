import 'dart:async';

import 'package:dashability_core/src/analysis/event_types.dart';
import 'package:dashability_core/src/connector/connector.dart';
import 'package:dashability_core/src/observers/observer.dart';

/// Manages the lifecycle of all observers and aggregates their event streams.
class ObserverManager {
  final List<Observer> _observers;
  final _eventController = StreamController<ObservationEvent>.broadcast();
  final List<StreamSubscription<ObservationEvent>> _subscriptions = [];

  ObserverManager(this._observers);

  /// Merged stream of all observer events.
  Stream<ObservationEvent> get events => _eventController.stream;

  /// Whether all observers are running.
  bool get isRunning => _observers.every((o) => o.isRunning);

  /// Start all observers with the given [connector].
  Future<void> startAll(Connector connector) async {
    for (final observer in _observers) {
      await observer.start(connector);
      _subscriptions.add(
        observer.events.listen(_eventController.add),
      );
    }
  }

  /// Stop all observers.
  Future<void> stopAll() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    for (final observer in _observers) {
      await observer.stop();
    }
  }

  /// Get an observer by type.
  T? getObserver<T extends Observer>() {
    for (final observer in _observers) {
      if (observer is T) return observer;
    }
    return null;
  }
}
