import 'dart:io';

import 'package:dashability/dashability.dart';
import 'package:dashability/src/cli/cli_select.dart';

/// Resolve the VM Service URI from CLI arguments.
///
/// Returns the resolved URI string, or null if agent-driven mode.
Future<String?> resolveConnection({
  required String? vmServiceUri,
  required bool attachMode,
  required String? projectDir,
  required String? device,
  required String? flavor,
  required bool profileMode,
  required FlutterProcess flutterProcess,
}) async {
  if (vmServiceUri != null) {
    return vmServiceUri;
  }

  if (attachMode) {
    return _resolveAttach(flutterProcess, device);
  }

  if (projectDir != null) {
    return _resolveRunApp(
      flutterProcess,
      projectDir: projectDir,
      device: device,
      flavor: flavor,
      profileMode: profileMode,
    );
  }

  return null;
}

Future<String> _resolveAttach(
  FlutterProcess flutterProcess,
  String? device,
) async {
  stderr.writeln('Attaching to running Flutter app...');
  try {
    final result = await flutterProcess.attach(device: device);
    if (result.isConnected) {
      return result.uri!;
    } else if (result.hasMultipleApps) {
      stderr.writeln('Multiple Flutter apps found:');
      for (final app in result.apps!) {
        stderr.writeln('  ${app.id} - ${app.name}');
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
}

Future<String> _resolveRunApp(
  FlutterProcess flutterProcess, {
  required String projectDir,
  required String? device,
  required String? flavor,
  required bool profileMode,
}) async {
  if (device != null) {
    stderr.writeln('Running Flutter app on device $device...');
    return flutterProcess.run(
      projectDir: projectDir,
      device: device,
      flavor: flavor,
      profile: profileMode,
    );
  }

  // List devices and prompt.
  stderr.writeln('Listing Flutter devices...');
  final devices = await flutterProcess.listDevices();
  if (devices.isEmpty) {
    stderr.writeln(
      'No devices found. Start an emulator or connect a device.',
    );
    exit(1);
  }

  final deviceOptions = devices.map((d) {
    final emulator = d.isEmulator ? ' (emulator)' : '';
    return '${d.name} [${d.platform}]$emulator';
  }).toList();

  final index = cliSelect(
    options: deviceOptions,
    prompt: 'Select device:',
  );

  if (index == -1) {
    exit(0);
  }

  stdout.writeln('');

  stderr.writeln('Running Flutter app on ${devices[index]}...');
  return flutterProcess.run(
    projectDir: projectDir,
    device: devices[index].id,
    flavor: flavor,
    profile: profileMode,
  );
}
