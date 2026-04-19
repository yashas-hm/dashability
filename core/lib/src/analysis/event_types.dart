/// Severity level for observation events.
enum EventSeverity { info, warning, critical }

/// Base class for all observation events emitted by observers and the
/// anomaly detector.
sealed class ObservationEvent {
  final DateTime timestamp;
  final EventSeverity severity;

  ObservationEvent({DateTime? timestamp, required this.severity})
    : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson();
}

/// A single frame timing measurement.
class FrameTiming {
  final double buildMs;
  final double renderMs;
  final DateTime timestamp;

  FrameTiming({
    required this.buildMs,
    required this.renderMs,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get totalMs => buildMs + renderMs;

  bool isJank(double thresholdMs) => totalMs > thresholdMs;

  Map<String, dynamic> toJson() => {
    'build_ms': buildMs,
    'render_ms': renderMs,
    'total_ms': totalMs,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Emitted when FPS drops below threshold for sustained period.
class FrameDrop extends ObservationEvent {
  final double fpsAvg;
  final int jankFrames;
  final int totalFrames;
  final Duration window;
  final List<String> topWidgets;

  FrameDrop({
    required this.fpsAvg,
    required this.jankFrames,
    required this.totalFrames,
    required this.window,
    this.topWidgets = const [],
    super.severity = EventSeverity.warning,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'frame_drop',
    'severity': severity.name,
    'fps_avg': fpsAvg,
    'jank_frames': jankFrames,
    'total_frames': totalFrames,
    'window_ms': window.inMilliseconds,
    'top_widgets': topWidgets,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Emitted when widget rebuild count exceeds threshold.
class RebuildSpike extends ObservationEvent {
  final String widget;
  final int rebuildCount;
  final Duration window;

  RebuildSpike({
    required this.widget,
    required this.rebuildCount,
    required this.window,
    super.severity = EventSeverity.warning,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'rebuild_spike',
    'severity': severity.name,
    'widget': widget,
    'rebuild_count': rebuildCount,
    'window_ms': window.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Emitted when an error or exception is caught.
class ErrorCaught extends ObservationEvent {
  final String message;
  final String? stackTrace;
  final String source;

  ErrorCaught({
    required this.message,
    this.stackTrace,
    required this.source,
    super.severity = EventSeverity.critical,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'error_caught',
    'severity': severity.name,
    'message': message,
    'stack_trace': stackTrace,
    'source': source,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Emitted for log entries.
class LogEntry extends ObservationEvent {
  final String message;
  final String level;
  final String? loggerName;

  LogEntry({
    required this.message,
    required this.level,
    this.loggerName,
    super.severity = EventSeverity.info,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'log_entry',
    'severity': severity.name,
    'message': message,
    'level': level,
    'logger_name': loggerName,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Emitted as a periodic metrics snapshot.
class MetricsSnapshot extends ObservationEvent {
  final double currentFps;
  final int jankFramesInWindow;
  final int totalFramesInWindow;
  final int errorCount;
  final Map<String, int> rebuildCounts;

  MetricsSnapshot({
    required this.currentFps,
    required this.jankFramesInWindow,
    required this.totalFramesInWindow,
    required this.errorCount,
    required this.rebuildCounts,
    super.severity = EventSeverity.info,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'metrics_snapshot',
    'fps': currentFps,
    'jank_frames': jankFramesInWindow,
    'total_frames': totalFramesInWindow,
    'error_count': errorCount,
    'rebuild_hotspots': rebuildCounts,
    'timestamp': timestamp.toIso8601String(),
  };
}
