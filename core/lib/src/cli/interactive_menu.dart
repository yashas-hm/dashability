import 'dart:io';

import 'package:dashability/dashability.dart';
import 'package:dashability/src/cli/install_mcp.dart';
import 'package:dashability/src/cli/server_runner.dart';

const _banner = r'''
╭━━━╮╱╱╱╱╱╭╮╱╱╱╱╭╮╱╱╭╮╱╭╮
╰╮╭╮┃╱╱╱╱╱┃┃╱╱╱╱┃┃╱╱┃┃╭╯╰╮
╱┃┃┃┣━━┳━━┫╰━┳━━┫╰━┳┫┃┣╮╭╋╮╱╭╮
╱┃┃┃┃╭╮┃━━┫╭╮┃╭╮┃╭╮┣┫┃┣┫┃┃┃╱┃┃
╭╯╰╯┃╭╮┣━━┃┃┃┃╭╮┃╰╯┃┃╰┫┃╰┫╰━╯┃
╰━━━┻╯╰┻━━┻╯╰┻╯╰┻━━┻┻━┻┻━┻━╮╭╯
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╭━╯┃
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╰━━╯
''';

/// Show the interactive menu and route the user's selection.
Future<void> showInteractiveMenu() async {
  stderr.write('\x1B[38;2;93;169;222m$_banner\x1B[0m');
  stderr.writeln('1. Start MCP Server');
  stderr.writeln('2. Install MCP');
  stderr.writeln('3. List Devices');
  stderr.writeln('4. Run App');
  stderr.writeln('5. Attach to App');
  stderr.writeln('');
  stderr.write('Select an option (1-5): ');

  final input = stdin.readLineSync();
  switch (input?.trim()) {
    case '1':
      await _startMcpServer();
    case '2':
      await installMcp([]);
    case '3':
      await _listDevices();
    case '4':
      await _runApp();
    case '5':
      await _attachToApp();
    default:
      stderr.writeln('Invalid selection.');
      exit(1);
  }
}

Future<void> _startMcpServer() async {
  await startServer(
    config: const DashabilityConfig(),
    flutterProcess: FlutterProcess(),
  );
}

Future<void> _listDevices() async {
  stderr.writeln('Listing Flutter devices...');
  final flutterProcess = FlutterProcess();
  try {
    final devices = await flutterProcess.listDevices();
    if (devices.isEmpty) {
      stderr.writeln('No devices found. Start an emulator or connect a device.');
      return;
    }
    stderr.writeln('');
    stderr.writeln('Available devices:');
    for (var i = 0; i < devices.length; i++) {
      final d = devices[i];
      final emulator = d.isEmulator ? ' (emulator)' : '';
      stderr.writeln('  ${d.id.padRight(24)} ${d.name} [${d.platform}]$emulator');
    }
  } on FlutterProcessException catch (e) {
    stderr.writeln('Failed to list devices: ${e.message}');
    exit(1);
  }
}

Future<void> _runApp() async {
  stderr.write('Flutter project directory: ');
  final projectDir = stdin.readLineSync()?.trim();
  if (projectDir == null || projectDir.isEmpty) {
    stderr.writeln('No project directory provided.');
    exit(1);
  }

  final dir = Directory(projectDir);
  if (!dir.existsSync()) {
    stderr.writeln('Directory does not exist: $projectDir');
    exit(1);
  }

  final flutterProcess = FlutterProcess();

  stderr.writeln('Listing Flutter devices...');
  final devices = await flutterProcess.listDevices();
  if (devices.isEmpty) {
    stderr.writeln('No devices found. Start an emulator or connect a device.');
    exit(1);
  }

  stderr.writeln('Available devices:');
  for (var i = 0; i < devices.length; i++) {
    stderr.writeln('  [$i] ${devices[i]}');
  }
  stderr.write('Select device (0-${devices.length - 1}): ');
  final deviceInput = stdin.readLineSync();
  final index = int.tryParse(deviceInput ?? '');
  if (index == null || index < 0 || index >= devices.length) {
    stderr.writeln('Invalid selection.');
    exit(1);
  }

  stderr.writeln('Running Flutter app on ${devices[index]}...');
  final uri = await flutterProcess.run(
    projectDir: projectDir,
    device: devices[index].id,
  );

  await startServer(
    config: const DashabilityConfig(),
    flutterProcess: flutterProcess,
    resolvedUri: uri,
  );
}

Future<void> _attachToApp() async {
  final flutterProcess = FlutterProcess();

  stderr.writeln('Discovering running Flutter apps...');
  try {
    final result = await flutterProcess.attach();
    if (result.isConnected) {
      await startServer(
        config: const DashabilityConfig(),
        flutterProcess: flutterProcess,
        resolvedUri: result.uri,
      );
      return;
    }

    if (result.hasMultipleApps) {
      stderr.writeln('Multiple Flutter apps found:');
      for (var i = 0; i < result.apps!.length; i++) {
        final app = result.apps![i];
        stderr.writeln('  [$i] ${app.id} - ${app.name}');
      }
      stderr.write('Select app (0-${result.apps!.length - 1}): ');
      final input = stdin.readLineSync();
      final index = int.tryParse(input ?? '');
      if (index == null || index < 0 || index >= result.apps!.length) {
        stderr.writeln('Invalid selection.');
        exit(1);
      }

      final chosen = result.apps![index];
      final retryResult = await flutterProcess.attach(appId: chosen.id);
      if (retryResult.isConnected) {
        await startServer(
          config: const DashabilityConfig(),
          flutterProcess: flutterProcess,
          resolvedUri: retryResult.uri,
        );
        return;
      }

      stderr.writeln('Failed to attach to ${chosen.id}.');
      exit(1);
    }

    stderr.writeln('No running Flutter apps found.');
    exit(1);
  } on FlutterProcessException catch (e) {
    stderr.writeln('Failed to attach: ${e.message}');
    exit(1);
  }
}
