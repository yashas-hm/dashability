import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:dashability/dashability.dart';
import 'package:stream_channel/stream_channel.dart';

/// The Dashability MCP server.
///
/// Exposes observation, action, and validation tools over stdio transport.
final class DashabilityServer extends MCPServer with ToolsSupport {
  final FlutterConnector connector;
  final ObserverManager observerManager;
  final AnomalyDetector anomalyDetector;
  final ContextCompressor contextCompressor;
  final AppiumActor? appiumActor;

  DashabilityServer._(
    StreamChannel<String> channel, {
    required Implementation implementation,
    String? instructions,
    required this.connector,
    required this.observerManager,
    required this.anomalyDetector,
    required this.contextCompressor,
    this.appiumActor,
  }) : super.fromStreamChannel(
         channel,
         implementation: implementation,
         instructions: instructions,
       );

  /// Create and start a Dashability MCP server on stdio.
  static Future<DashabilityServer> start({
    required FlutterConnector connector,
    required ObserverManager observerManager,
    required AnomalyDetector anomalyDetector,
    required ContextCompressor contextCompressor,
    AppiumActor? appiumActor,
  }) async {
    final channel = stdioChannel(input: stdin, output: stdout);

    final server = DashabilityServer._(
      channel,
      implementation: Implementation(name: 'dashability', version: '0.1.0'),
      instructions:
          'Dashability AI Observability Layer for Flutter apps. '
          'Use observation tools to monitor app performance, logs, and anomalies. '
          'Use action tools to interact with the app via Appium.',
      connector: connector,
      observerManager: observerManager,
      anomalyDetector: anomalyDetector,
      contextCompressor: contextCompressor,
      appiumActor: appiumActor,
    );

    return server;
  }

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);

    registerObservationTools(this);

    if (appiumActor != null) {
      registerActionTools(this, appiumActor!);
      registerValidationTools(this, appiumActor!);
    }

    return result;
  }
}
