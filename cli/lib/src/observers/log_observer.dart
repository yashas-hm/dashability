import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dashability/src/analysis/event_types.dart';
import 'package:dashability/src/connector/connector.dart';
import 'package:vm_service/vm_service.dart' as vm;

import 'observer.dart';

/// Monitors log output and errors from the connected app.
///
/// Subscribes to logging, stdout, and stderr VM Service streams.
/// Emits [LogEntry] for normal logs and [ErrorCaught] for errors.
class LogObserver implements Observer {
  final _eventController = StreamController<ObservationEvent>.broadcast();
  final List<StreamSubscription<vm.Event>> _subscriptions = [];
  bool _running = false;

  /// Recent log entries (bounded buffer).
  final _recentLogs = Queue<LogEntry>();
  static const _maxLogs = 200;

  @override
  bool get isRunning => _running;

  @override
  Stream<ObservationEvent> get events => _eventController.stream;

  /// Recent log entries (read-only view).
  List<LogEntry> get recentLogs => List.unmodifiable(_recentLogs);

  /// Total error count since start.
  int errorCount = 0;

  @override
  Future<void> start(Connector connector) async {
    if (_running) return;
    _running = true;
    errorCount = 0;

    await connector.service.streamListen(vm.EventStreams.kLogging);
    await connector.service.streamListen(vm.EventStreams.kStdout);
    await connector.service.streamListen(vm.EventStreams.kStderr);

    _subscriptions.add(
      connector.service.onLoggingEvent.listen(_handleLoggingEvent),
    );
    _subscriptions.add(
      connector.service.onStdoutEvent.listen(
        (e) => _handleOutputEvent(e, 'stdout'),
      ),
    );
    _subscriptions.add(
      connector.service.onStderrEvent.listen(
        (e) => _handleOutputEvent(e, 'stderr'),
      ),
    );
  }

  @override
  Future<void> stop() async {
    _running = false;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  void _handleLoggingEvent(vm.Event event) {
    final logRecord = event.logRecord;
    if (logRecord == null) return;

    final message = logRecord.message?.valueAsString ?? '';
    final level = _levelFromValue(logRecord.level as vm.InstanceRef?);
    final loggerName = logRecord.loggerName?.valueAsString;

    final isError = level == 'error' || level == 'severe';

    if (isError) {
      errorCount++;
      final errorEvent = ErrorCaught(
        message: message,
        stackTrace: logRecord.stackTrace?.valueAsString,
        source: 'logging:${loggerName ?? "unknown"}',
      );
      _eventController.add(errorEvent);
    }

    final entry = LogEntry(
      message: message,
      level: level,
      loggerName: loggerName,
      severity: isError ? EventSeverity.critical : EventSeverity.info,
    );
    _addLog(entry);
    _eventController.add(entry);
  }

  void _handleOutputEvent(vm.Event event, String source) {
    final bytes = event.bytes;
    if (bytes == null) return;

    final message = utf8.decode(base64Decode(bytes)).trim();
    if (message.isEmpty) return;

    final isError = source == 'stderr';
    if (isError) errorCount++;

    final entry = LogEntry(
      message: message,
      level: isError ? 'error' : 'info',
      loggerName: source,
      severity: isError ? EventSeverity.warning : EventSeverity.info,
    );
    _addLog(entry);
    _eventController.add(entry);
  }

  void _addLog(LogEntry entry) {
    _recentLogs.addLast(entry);
    while (_recentLogs.length > _maxLogs) {
      _recentLogs.removeFirst();
    }
  }

  String _levelFromValue(vm.InstanceRef? levelRef) {
    final value = levelRef?.valueAsString;
    if (value == null) return 'info';

    final intValue = int.tryParse(value);
    if (intValue == null) return value.toLowerCase();

    // Dart logging levels: FINEST=300, FINER=400, FINE=500,
    // CONFIG=700, INFO=800, WARNING=900, SEVERE=1000, SHOUT=1200
    if (intValue >= 1000) return 'severe';
    if (intValue >= 900) return 'warning';
    if (intValue >= 800) return 'info';
    if (intValue >= 700) return 'config';
    return 'fine';
  }
}
