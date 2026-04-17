/// Dashability Core — AI Observability engine for Flutter apps.
///
/// Provides connectors, observers, analysis, and action capabilities
/// for monitoring running apps externally.
library dashability_core;

// Connector
export 'src/connector/connector.dart';
export 'src/connector/config.dart';
export 'src/connector/flutter/flutter_connector.dart';

// Observers
export 'src/observers/observer.dart';
export 'src/observers/frame_observer.dart';
export 'src/observers/log_observer.dart';
export 'src/observers/rebuild_observer.dart';
export 'src/observers/observer_manager.dart';

// Analysis
export 'src/analysis/event_types.dart';
export 'src/analysis/anomaly_detector.dart';
export 'src/analysis/context_compressor.dart';

// Actions
export 'src/actions/appium_actor.dart';
