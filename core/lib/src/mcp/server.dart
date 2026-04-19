import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:dashability/dashability.dart';
import 'package:stream_channel/stream_channel.dart';

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
      instructions:
      'Dashability AI Observability Layer for Flutter apps. '
          'Use lifecycle tools to connect to a Flutter app, then '
          'use observation tools to monitor performance, logs, and anomalies. '
          'Use action tools to interact with the app via Appium.',
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
