import 'dart:io';

import 'package:args/args.dart';
import 'package:dashability/dashability.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'uri',
      abbr: 'u',
      help: 'VM Service WebSocket URI (direct connect, skips discovery)',
    )..addOption(
      'project-dir',
      abbr: 'p',
      help: 'Flutter project directory (runs flutter run)',
    )..addOption(
      'device',
      abbr: 'd',
      help: 'Target device ID',
    )..addOption(
      'flavor',
      help: 'Build flavor',
    )
    ..addFlag(
      'attach',
      abbr: 'a',
      help: 'Attach to an already-running Flutter app',
      defaultsTo: false,
    )..addFlag(
      'profile',
      help: 'Use profile-mode thresholds (120fps budget)',
      defaultsTo: false,
    )
    ..addOption(
      'appium-url',
      help: 'Appium server URL (enables action tools)',
      defaultsTo: null,
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
    stderr.writeln('Usage: dashability [options]');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    stderr.writeln('Dashability — AI Observability Layer for Flutter Apps');
    stderr.writeln('');
    stderr.writeln('Usage: dashability [options]');
    stderr.writeln('');
    stderr.writeln('Modes:');
    stderr.writeln('  --uri <ws://...>       Direct connect to VM Service');
    stderr.writeln('  --project-dir <path>   Run flutter app from project dir');
    stderr.writeln('  --attach               Attach to running Flutter app');
    stderr.writeln(
        '  (no flags)             Start MCP server, agent connects via tools');
    stderr.writeln('');
    stderr.writeln(parser.usage);
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

  // Optional Appium.
  AppiumActor? appiumActor;
  if (appiumUrl != null) {
    appiumActor = AppiumActor(appiumUrl: Uri.parse(appiumUrl));
    stderr.writeln('Appium action tools enabled ($appiumUrl).');
  }

  // Determine connection mode.
  String? resolvedUri;

  if (vmServiceUri != null) {
    // Direct URI mode.
    resolvedUri = vmServiceUri;
  } else if (attachMode) {
    // Attach to running app.
    stderr.writeln('Attaching to running Flutter app...');
    try {
      final result = await flutterProcess.attach(device: device);
      if (result.isConnected) {
        resolvedUri = result.uri;
      } else if (result.hasMultipleApps) {
        stderr.writeln('Multiple Flutter apps found:');
        for (final app in result.apps!) {
          stderr.writeln('  ${app.id} — ${app.name}');
        }
        stderr.writeln(
          'Use --uri to connect directly, or start the MCP server '
              'without flags and let the agent choose.',
        );
        exit(1);
      } else {
        stderr.writeln('No running Flutter apps found.');
        exit(1);
      }
    } on FlutterProcessException catch (e) {
      stderr.writeln('Failed to attach: ${e.message}');
      exit(1);
    }
  } else if (projectDir != null) {
    // Run app from project dir.
    if (device == null) {
      // List devices and prompt.
      stderr.writeln('Listing Flutter devices...');
      final devices = await flutterProcess.listDevices();
      if (devices.isEmpty) {
        stderr.writeln(
          'No devices found. Start an emulator or connect a device.',
        );
        exit(1);
      }
      stderr.writeln('Available devices:');
      for (var i = 0; i < devices.length; i++) {
        stderr.writeln('  [$i] ${devices[i]}');
      }
      stderr.write('Select device (0-${devices.length - 1}): ');
      final input = stdin.readLineSync();
      final index = int.tryParse(input ?? '');
      if (index == null || index < 0 || index >= devices.length) {
        stderr.writeln('Invalid selection.');
        exit(1);
      }

      stderr.writeln('Running Flutter app on ${devices[index]}...');
      resolvedUri = await flutterProcess.run(
        projectDir: projectDir,
        device: devices[index].id,
        flavor: flavor,
        profile: profileMode,
      );
    } else {
      stderr.writeln('Running Flutter app on device $device...');
      resolvedUri = await flutterProcess.run(
        projectDir: projectDir,
        device: device,
        flavor: flavor,
        profile: profileMode,
      );
    }
  }

  // Start MCP server.
  stderr.writeln('Starting MCP server on stdio...');
  final server = await DashabilityServer.start(
    config: config,
    flutterProcess: flutterProcess,
    appiumActor: appiumActor,
  );

  // If we resolved a URI from CLI flags, connect now.
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
        'MCP server is running — agent can connect via lifecycle tools.',
      );
    }
  } else {
    stderr.writeln(
      'No connection target specified. '
          'Agent can use list_devices, run_app, or attach_to_app tools.',
    );
  }

  stderr.writeln('Dashability MCP server running. Waiting for client...');

  // Handle shutdown.
  ProcessSignal.sigint.watch().listen((_) async {
    stderr.writeln('Shutting down...');
    await server.disconnectFromApp();
    await flutterProcess.dispose();
    await server.shutdown();
    exit(0);
  });
}
