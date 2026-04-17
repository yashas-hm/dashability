import 'package:dashability_core/src/analysis/event_types.dart';

/// Compresses raw observation events into token-efficient structured JSON
/// suitable for AI consumption.
///
/// Implements smart batching: multiple events in a time window are merged
/// into a single combined context payload.
class ContextCompressor {
  /// Compress a list of events into a single structured payload.
  ///
  /// This is the main entry point — call with batched events from
  /// [AnomalyDetector.drainAnomalies].
  Map<String, dynamic> compress(List<ObservationEvent> events) {
    if (events.isEmpty) {
      return {'status': 'ok', 'events': []};
    }

    final compressed = <String, dynamic>{
      'event_count': events.length,
      'time_range': _timeRange(events),
    };

    // Group by type for compact representation.
    final frameDrops = events.whereType<FrameDrop>().toList();
    final rebuildSpikes = events.whereType<RebuildSpike>().toList();
    final errors = events.whereType<ErrorCaught>().toList();
    final errorLogs = events
        .whereType<LogEntry>()
        .where((l) => l.level == 'error' || l.level == 'severe')
        .toList();

    if (frameDrops.isNotEmpty) {
      compressed['performance'] = _compressFrameDrops(frameDrops);
    }

    if (rebuildSpikes.isNotEmpty) {
      compressed['rebuild_hotspots'] = _compressRebuildSpikes(rebuildSpikes);
    }

    if (errors.isNotEmpty || errorLogs.isNotEmpty) {
      compressed['errors'] = _compressErrors(errors, errorLogs);
    }

    return compressed;
  }

  /// Compress a single event for immediate reporting.
  Map<String, dynamic> compressSingle(ObservationEvent event) {
    return compress([event]);
  }

  Map<String, String> _timeRange(List<ObservationEvent> events) {
    final sorted = events.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return {
      'from': sorted.first.timestamp.toIso8601String(),
      'to': sorted.last.timestamp.toIso8601String(),
    };
  }

  Map<String, dynamic> _compressFrameDrops(List<FrameDrop> drops) {
    final worstFps = drops.map((d) => d.fpsAvg).reduce((a, b) => a < b ? a : b);
    final totalJank = drops.map((d) => d.jankFrames).reduce((a, b) => a + b);
    final allWidgets = drops.expand((d) => d.topWidgets).toSet().toList();

    return {
      'worst_fps': worstFps,
      'total_jank_frames': totalJank,
      'occurrences': drops.length,
      'top_widgets': allWidgets.take(5).toList(),
    };
  }

  Map<String, dynamic> _compressRebuildSpikes(List<RebuildSpike> spikes) {
    // Merge by widget name, keep highest count.
    final byWidget = <String, int>{};
    for (final spike in spikes) {
      final existing = byWidget[spike.widget] ?? 0;
      if (spike.rebuildCount > existing) {
        byWidget[spike.widget] = spike.rebuildCount;
      }
    }

    final sorted = byWidget.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'widgets': {for (final entry in sorted.take(5)) entry.key: entry.value},
    };
  }

  Map<String, dynamic> _compressErrors(
    List<ErrorCaught> errors,
    List<LogEntry> errorLogs,
  ) {
    final messages = <String>[
      ...errors.map((e) => e.message),
      ...errorLogs.map((l) => l.message),
    ];

    // Deduplicate similar messages.
    final unique = messages.toSet().toList();

    return {
      'count': messages.length,
      'unique_messages': unique.take(5).toList(),
    };
  }
}
