import 'dart:async';
import 'dart:collection';

import 'package:dashability_core/src/analysis/event_types.dart';
import 'package:dashability_core/src/connector/config.dart';
import 'package:dashability_core/src/connector/connector.dart';
import 'package:vm_service/vm_service.dart' as vm;

import 'observer.dart';

/// Monitors frame timing via VM Service timeline events.
///
/// Tracks build and render phase durations, computes rolling FPS,
/// and emits [FrameDrop] events when jank is detected.
class FrameObserver implements Observer {
  final DashabilityConfig _config;
  final _eventController = StreamController<ObservationEvent>.broadcast();
  StreamSubscription<vm.Event>? _subscription;
  bool _running = false;

  /// Rolling window of recent frame timings.
  final _frames = Queue<FrameTiming>();

  /// Current build phase start timestamp (microseconds).
  int? _buildStart;

  FrameObserver(this._config);

  @override
  bool get isRunning => _running;

  @override
  Stream<ObservationEvent> get events => _eventController.stream;

  /// Recent frame timings (read-only view).
  List<FrameTiming> get recentFrames => List.unmodifiable(_frames);

  /// Current rolling FPS based on recent frames.
  double get currentFps {
    if (_frames.length < 2) return 60.0;
    final oldest = _frames.first.timestamp;
    final newest = _frames.last.timestamp;
    final durationMs = newest.difference(oldest).inMilliseconds;
    if (durationMs <= 0) return 60.0;
    return (_frames.length - 1) / (durationMs / 1000.0);
  }

  @override
  Future<void> start(Connector connector) async {
    if (_running) return;
    _running = true;

    // Enable the timeline stream for frame events.
    await connector.service.setVMTimelineFlags(['GC', 'Dart', 'Embedder']);
    await connector.service.streamListen(vm.EventStreams.kTimeline);

    _subscription = connector.service.onTimelineEvent.listen(_handleEvent);
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _subscription?.cancel();
    _subscription = null;
  }

  void _handleEvent(vm.Event event) {
    final timelineEvents = event.timelineEvents;
    if (timelineEvents == null) return;

    for (final te in timelineEvents) {
      final name = te.json?['name'] as String?;
      final ph = te.json?['ph'] as String?;
      final ts = te.json?['ts'] as int?;

      if (name == null || ph == null || ts == null) continue;

      if (name == 'Frame' || name == 'VsyncProcessCallback') {
        if (ph == 'B') {
          _buildStart = ts;
        } else if (ph == 'E' && _buildStart != null) {
          final totalUs = ts - _buildStart!;
          final totalMs = totalUs / 1000.0;
          // Approximate build as 60% of total, render as 40%.
          final buildMs = totalMs * 0.6;
          final renderMs = totalMs * 0.4;

          final timing = FrameTiming(buildMs: buildMs, renderMs: renderMs);
          _addFrame(timing);
          _buildStart = null;
        }
      }
    }
  }

  void _addFrame(FrameTiming timing) {
    _frames.addLast(timing);
    while (_frames.length > _config.frameWindowSize) {
      _frames.removeFirst();
    }

    _checkForJank();
  }

  void _checkForJank() {
    if (_frames.length < _config.minJankFramesToAlert) return;

    final jankCount = _frames
        .where((f) => f.isJank(_config.jankThresholdMs))
        .length;

    if (jankCount >= _config.minJankFramesToAlert) {
      final fps = currentFps;
      if (fps < 55) {
        // Only alert if FPS is meaningfully degraded.
        _eventController.add(
          FrameDrop(
            fpsAvg: fps,
            jankFrames: jankCount,
            totalFrames: _frames.length,
            window: Duration(milliseconds: _config.batchWindowMs),
            severity: fps < 30 ? EventSeverity.critical : EventSeverity.warning,
          ),
        );
      }
    }
  }
}
