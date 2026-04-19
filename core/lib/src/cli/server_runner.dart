import 'dart:io';

import 'package:args/args.dart';
import 'package:dashability/dashability.dart';
import 'package:dashability/src/cli/arg_parser.dart';
import 'package:dashability/src/cli/connection.dart';

/// Run Dashability with parsed CLI arguments.
Future<void> runWithArgs(List<String> arguments) async {
  final parser = buildArgParser();

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln('Usage: dashability [options]');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    printHelp(parser);
    exit(0);
  }

  final vmServiceUri = args['uri'] as String?;
  final projectDir = args['project-dir'] as String?;
  final device = args['device'] as String?;
  final flavor = args['flavor'] as String?;
  final attachMode = args['attach'] as bool;
  final profileMode = args['profile'] as bool;
  final appiumUrl = args['appium-url'] as String?;

  final config = profileMode
      ? const DashabilityConfig.profile()
      : const DashabilityConfig();

  final flutterProcess = FlutterProcess();

  AppiumActor? appiumActor;
  if (appiumUrl != null) {
    appiumActor = AppiumActor(appiumUrl: Uri.parse(appiumUrl));
    stderr.writeln('Appium action tools enabled ($appiumUrl).');
  }

  final resolvedUri = await resolveConnection(
    vmServiceUri: vmServiceUri,
    attachMode: attachMode,
    projectDir: projectDir,
    device: device,
    flavor: flavor,
    profileMode: profileMode,
    flutterProcess: flutterProcess,
  );

  await startServer(
    config: config,
    flutterProcess: flutterProcess,
    appiumActor: appiumActor,
    resolvedUri: resolvedUri,
  );
}

/// Start the MCP server, optionally connect to an app, and wait.
Future<void> startServer({
  required DashabilityConfig config,
  required FlutterProcess flutterProcess,
  AppiumActor? appiumActor,
  String? resolvedUri,
}) async {
  stderr.writeln('Starting MCP server on stdio...');
  final server = await DashabilityServer.start(
    config: config,
    flutterProcess: flutterProcess,
    appiumActor: appiumActor,
  );

  if (resolvedUri != null) {
    stderr.writeln('Connecting to VM Service at $resolvedUri...');
    try {
      await server.connectToApp(Uri.parse(resolvedUri));
      stderr.writeln(
        'Connected. Isolate: ${server.connector!.mainIsolateId}',
      );
      stderr.writeln('Observers started.');
    } catch (e) {
      stderr.writeln('Failed to connect: $e');
      stderr.writeln(
        'MCP server is running - agent can connect via lifecycle tools.',
      );
    }
  } else {
    stderr.writeln(
      'No connection target specified. '
      'Agent can use list_devices, run_app, or attach_to_app tools.',
    );
  }

  stderr.writeln('Dashability MCP server running. Waiting for client...');

  ProcessSignal.sigint.watch().listen((_) async {
    stderr.writeln('Shutting down...');
    await server.disconnectFromApp();
    await flutterProcess.dispose();
    await server.shutdown();
    exit(0);
  });
}
