import 'dart:io';

import 'package:args/args.dart';
import 'package:dashability_core/dashability_core.dart';
import 'package:dashability_cli/src/mcp/server.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'uri',
      abbr: 'u',
      help: 'VM Service WebSocket URI (e.g. ws://127.0.0.1:12345/ws)',
      mandatory: true,
    )
    ..addOption(
      'appium-url',
      help: 'Appium server URL (enables action tools)',
      defaultsTo: null,
    )
    ..addFlag(
      'profile',
      help: 'Use profile-mode thresholds (120fps budget)',
      defaultsTo: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show usage information',
      negatable: false,
    );

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln('Usage: dashability --uri <vm-service-uri>');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    stderr.writeln('Dashability — AI Observability Layer for Flutter Apps');
    stderr.writeln('');
    stderr.writeln('Usage: dashability --uri <vm-service-uri> [options]');
    stderr.writeln('');
    stderr.writeln(parser.usage);
    exit(0);
  }

  final vmServiceUri = args['uri'] as String;
  final appiumUrl = args['appium-url'] as String?;
  final profileMode = args['profile'] as bool;

  final config = profileMode
      ? const DashabilityConfig.profile()
      : const DashabilityConfig();

  // Connect to the Flutter app.
  stderr.writeln('Connecting to VM Service at $vmServiceUri...');
  final connector = FlutterConnector();
  try {
    await connector.connect(Uri.parse(vmServiceUri));
  } catch (e) {
    stderr.writeln('Failed to connect: $e');
    exit(1);
  }
  stderr.writeln('Connected. Isolate: ${connector.mainIsolateId}');

  // Set up observers.
  final observers = ObserverManager([
    FrameObserver(config),
    LogObserver(),
    RebuildObserver(config),
  ]);
  await observers.startAll(connector);
  stderr.writeln('Observers started.');

  // Set up analysis.
  final anomalyDetector = AnomalyDetector(config);
  anomalyDetector.attach(observers.events);
  final contextCompressor = ContextCompressor();

  // Optional Appium.
  AppiumActor? appiumActor;
  if (appiumUrl != null) {
    appiumActor = AppiumActor(appiumUrl: Uri.parse(appiumUrl));
    stderr.writeln('Appium action tools enabled ($appiumUrl).');
  }

  // Start MCP server on stdio.
  stderr.writeln('Starting MCP server on stdio...');
  final server = await DashabilityServer.start(
    connector: connector,
    observerManager: observers,
    anomalyDetector: anomalyDetector,
    contextCompressor: contextCompressor,
    appiumActor: appiumActor,
  );

  stderr.writeln('Dashability MCP server running. Waiting for client...');

  // Handle shutdown.
  ProcessSignal.sigint.watch().listen((_) async {
    stderr.writeln('Shutting down...');
    await anomalyDetector.detach();
    await observers.stopAll();
    await connector.disconnect();
    await server.shutdown();
    exit(0);
  });
}
