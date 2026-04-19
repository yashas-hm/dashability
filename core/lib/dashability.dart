/// Dashability — AI Observability Layer for Flutter Apps.
library dashability;

// Actions
export 'src/actions/appium_actor.dart';

// Analysis
export 'src/analysis/anomaly_detector.dart';
export 'src/analysis/context_compressor.dart';
export 'src/analysis/event_types.dart';

// Connector
export 'src/connector/config.dart';
export 'src/connector/connector.dart';
export 'src/connector/flutter/flutter_connector.dart';

// Flutter process management
export 'src/flutter/flutter_device.dart';
export 'src/flutter/flutter_process.dart';

// MCP
export 'src/mcp/action_tools.dart';
export 'src/mcp/lifecycle_tools.dart';
export 'src/mcp/observation_tools.dart';
export 'src/mcp/server.dart';
export 'src/mcp/validation_tools.dart';

// Observers
export 'src/observers/frame_observer.dart';
export 'src/observers/log_observer.dart';
export 'src/observers/observer.dart';
export 'src/observers/observer_manager.dart';
export 'src/observers/rebuild_observer.dart';
