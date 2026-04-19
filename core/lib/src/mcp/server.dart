import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:dashability/dashability.dart';
import 'package:stream_channel/stream_channel.dart';

const _serverInstructions = '''
You have access to Dashability, a runtime observability layer for Flutter apps. Dashability connects to a running Flutter app via the Dart VM Service and gives you real-time performance data, logs, widget rebuild counts, and anomaly detection.

IMPORTANT: Dashability is a RUNTIME observability layer. You must actually run the Flutter app and observe it while it is running. Do not just read source code and do static analysis. The value of Dashability is that it tells you what is actually happening at runtime - frame drops, rebuild spikes, errors, and performance metrics from the live app.

TOOLS:

Lifecycle (manage the app):
- get_connection_status: Check if connected to a Flutter app. Always call this first.
- list_devices: List available Flutter devices (emulators, simulators, physical). Ask the user which device to use.
- run_app: Launch a Flutter app from a project directory on a device. Automatically connects observers.
- attach_to_app: Connect to an already-running Flutter app. If multiple apps are running, returns a list to choose from.
- stop_app: Stop the app and disconnect all observers.

Observation (monitor the running app):
- get_current_metrics: Current FPS, error count, and widget rebuild hotspots.
- get_recent_frames: Frame timing history (build and render ms per frame).
- get_logs: Recent log entries from the app, filterable by level.
- get_anomalies: Detected anomalies (frame drops, rebuild spikes, errors) since last call. Clears after reading.
- get_widget_tree: Live widget tree of the running app.
- get_widget_hotspots: Top rebuilding widgets sorted by rebuild count.

WORKFLOW:

1. Call get_connection_status. If already connected, skip to step 4.
2. Call list_devices. Present the devices to the user and ask which one to use.
3. Call run_app with the project directory and chosen device ID. Wait for connection confirmation.
4. Call get_current_metrics, get_logs, and get_anomalies to observe the app.
5. If you find performance issues or errors, fix the code, then call stop_app and run_app again to verify.
6. Repeat step 4-5 until the app runs clean: stable FPS, no anomalies, no errors.
7. Call stop_app when finished.

All observation tools require an active connection. If not connected, they return an error telling you to call run_app or attach_to_app first.
''';

/// The Dashability MCP server.
///
/// Supports two modes:
/// - **Pre-connected:** Pass a [FlutterConnector] at creation time.
/// - **Agent-driven:** Start without a connector; the agent uses lifecycle
///   tools (`run_app`, `attach_to_app`) to connect later.
final class DashabilityServer extends MCPServer with ToolsSupport {
  final FlutterProcess flutterProcess;
  final DashabilityConfig config;
  final AppiumActor? appiumActor;

  FlutterConnector? _connector;
  ObserverManager? _observerManager;
  AnomalyDetector? _anomalyDetector;
  final ContextCompressor _contextCompressor = ContextCompressor();

  /// Whether the server is connected to a Flutter app.
  bool get isConnected =>
      _connector != null &&
          _connector!.state == ConnectorState.connected;

  /// The active connector, or `null` if not connected.
  FlutterConnector? get connector => _connector;

  /// The active observer manager, or `null` if not connected.
  ObserverManager? get observerManager => _observerManager;

  /// The active anomaly detector, or `null` if not connected.
  AnomalyDetector? get anomalyDetector => _anomalyDetector;

  /// The context compressor (always available).
  ContextCompressor get contextCompressor => _contextCompressor;

  DashabilityServer._(StreamChannel<String> channel, {
    required Implementation implementation,
    String? instructions,
    required this.flutterProcess,
    required this.config,
    this.appiumActor,
    FlutterConnector? connector,
    ObserverManager? observerManager,
    AnomalyDetector? anomalyDetector,
  })
      : _connector = connector,
        _observerManager = observerManager,
        _anomalyDetector = anomalyDetector,
        super.fromStreamChannel(
        channel,
        implementation: implementation,
        instructions: instructions,
      );

  /// Create and start a Dashability MCP server on stdio.
  ///
  /// If [connector] is provided, the server starts in connected mode.
  /// Otherwise, the agent must use lifecycle tools to connect.
  static Future<DashabilityServer> start({
    required DashabilityConfig config,
    FlutterProcess? flutterProcess,
    FlutterConnector? connector,
    ObserverManager? observerManager,
    AnomalyDetector? anomalyDetector,
    AppiumActor? appiumActor,
  }) async {
    final channel = stdioChannel(input: stdin, output: stdout);

    final server = DashabilityServer._(
      channel,
      implementation: Implementation(name: 'dashability', version: '0.1.0'),
      instructions: _serverInstructions,
      flutterProcess: flutterProcess ?? FlutterProcess(),
      config: config,
      appiumActor: appiumActor,
      connector: connector,
      observerManager: observerManager,
      anomalyDetector: anomalyDetector,
    );

    return server;
  }

  /// Connect to a Flutter app at the given VM Service [uri].
  ///
  /// Creates the connector, starts observers, and attaches the anomaly
  /// detector. Call this from lifecycle tools or CLI setup.
  Future<void> connectToApp(Uri uri) async {
    if (isConnected) {
      await disconnectFromApp();
    }

    final connector = FlutterConnector();
    await connector.connect(uri);

    final observers = ObserverManager([
      FrameObserver(config),
      LogObserver(),
      RebuildObserver(config),
    ]);
    await observers.startAll(connector);

    final detector = AnomalyDetector(config);
    detector.attach(observers.events);

    _connector = connector;
    _observerManager = observers;
    _anomalyDetector = detector;
  }

  /// Disconnect from the current Flutter app.
  ///
  /// Stops observers, detaches the anomaly detector, and disconnects
  /// the connector.
  Future<void> disconnectFromApp() async {
    await _anomalyDetector?.detach();
    await _observerManager?.stopAll();
    await _connector?.disconnect();

    _anomalyDetector = null;
    _observerManager = null;
    _connector = null;
  }

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);

    // Lifecycle tools are always available.
    registerLifecycleTools(this);

    // Observation tools are always registered but return errors when
    // not connected.
    registerObservationTools(this);

    if (appiumActor != null) {
      registerActionTools(this, appiumActor!);
      registerValidationTools(this, appiumActor!);
    }

    return result;
  }
}
