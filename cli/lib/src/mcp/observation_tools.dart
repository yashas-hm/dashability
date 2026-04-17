import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:dashability_core/dashability_core.dart';
import 'package:dashability_cli/src/mcp/server.dart';

/// Registers all observation MCP tools on the server.
void registerObservationTools(DashabilityServer server) {
  // get_current_metrics
  server.registerTool(
    Tool(
      name: 'get_current_metrics',
      description: 'Get current app performance metrics: FPS, jank frames, '
          'error count, and widget rebuild hotspots.',
      inputSchema: ObjectSchema(),
    ),
    (request) {
      final frameObserver = server.observerManager.getObserver<FrameObserver>();
      final logObserver = server.observerManager.getObserver<LogObserver>();
      final rebuildObserver =
          server.observerManager.getObserver<RebuildObserver>();

      final metrics = {
        'fps': frameObserver?.currentFps ?? 0.0,
        'error_count': logObserver?.errorCount ?? 0,
        'rebuild_hotspots': rebuildObserver?.rebuildCounts ?? {},
        'connected': server.connector.state.name,
      };

      return CallToolResult(
        content: [TextContent(text: jsonEncode(metrics))],
      );
    },
  );

  // get_recent_frames
  server.registerTool(
    Tool(
      name: 'get_recent_frames',
      description: 'Get recent frame timing data including build and render '
          'times in milliseconds.',
      inputSchema: ObjectSchema(
        properties: {
          'limit': Schema.int(
            description: 'Max number of frames to return (default 20)',
          ),
        },
      ),
    ),
    (request) {
      final frameObserver = server.observerManager.getObserver<FrameObserver>();
      final limit = (request.arguments?['limit'] as int?) ?? 20;
      final frames = frameObserver?.recentFrames ?? [];
      final limited = frames.length > limit
          ? frames.sublist(frames.length - limit)
          : frames;

      return CallToolResult(
        content: [
          TextContent(text: jsonEncode(limited.map((f) => f.toJson()).toList())),
        ],
      );
    },
  );

  // get_widget_hotspots
  server.registerTool(
    Tool(
      name: 'get_widget_hotspots',
      description: 'Get the top rebuilding widgets sorted by rebuild count.',
      inputSchema: ObjectSchema(),
    ),
    (request) {
      final rebuildObserver =
          server.observerManager.getObserver<RebuildObserver>();
      final hotspots = rebuildObserver?.hotspots ?? [];

      final result = [
        for (final entry in hotspots)
          {'widget': entry.key, 'rebuild_count': entry.value},
      ];

      return CallToolResult(
        content: [TextContent(text: jsonEncode(result))],
      );
    },
  );

  // get_logs
  server.registerTool(
    Tool(
      name: 'get_logs',
      description: 'Get recent log entries. Optionally filter by level.',
      inputSchema: ObjectSchema(
        properties: {
          'level': Schema.string(
            description:
                'Filter by log level: fine, config, info, warning, error, severe',
          ),
          'limit': Schema.int(
            description: 'Max number of log entries to return (default 50)',
          ),
        },
      ),
    ),
    (request) {
      final logObserver = server.observerManager.getObserver<LogObserver>();
      final level = request.arguments?['level'] as String?;
      final limit = (request.arguments?['limit'] as int?) ?? 50;

      var logs = logObserver?.recentLogs ?? [];
      if (level != null) {
        logs = logs.where((l) => l.level == level).toList();
      }
      final limited = logs.length > limit
          ? logs.sublist(logs.length - limit)
          : logs;

      return CallToolResult(
        content: [
          TextContent(
            text: jsonEncode(limited.map((l) => l.toJson()).toList()),
          ),
        ],
      );
    },
  );

  // get_anomalies
  server.registerTool(
    Tool(
      name: 'get_anomalies',
      description: 'Get detected anomalies since last call. Returns compressed '
          'context optimized for AI analysis. Clears the buffer after reading.',
      inputSchema: ObjectSchema(),
    ),
    (request) {
      final anomalies = server.anomalyDetector.drainAnomalies();
      final compressed = server.contextCompressor.compress(anomalies);

      return CallToolResult(
        content: [TextContent(text: jsonEncode(compressed))],
      );
    },
  );
}

