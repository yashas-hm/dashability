import 'dart:io';

import 'package:dashability/dashability.dart';
import 'package:dashability/src/cli/cli_select.dart';
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

const _menuOptions = [
  'Start MCP Server',
  'Install MCP',
  'List Devices',
  'Run App',
  'Attach to App',
];

/// Show the interactive menu and route the user's selection.
Future<void> showInteractiveMenu() async {
  stdout.write('\x1B[38;2;93;169;222m$_banner\x1B[0m');

  final selected = cliSelect(options: _menuOptions);

  if (selected == -1) {
    exit(0);
  }

  stdout.writeln('');

  switch (selected) {
    case 0:
      await _startMcpServer();
    case 1:
      await installMcp([]);
    case 2:
      await _listDevices();
    case 3:
      await _runApp();
    case 4:
      await _attachToApp();
  }
}

Future<void> _startMcpServer() async {
  await startServer(
    config: const DashabilityConfig(),
    flutterProcess: FlutterProcess(),
  );
}

Future<void> _listDevices() async {
  stdout.writeln('Listing Flutter devices...');
  final flutterProcess = FlutterProcess();
  try {
    final devices = await flutterProcess.listDevices();
    if (devices.isEmpty) {
      stdout.writeln('No devices found. Start an emulator or connect a device.');
      return;
    }
    stdout.writeln('');
    stdout.writeln('Available devices:');
    for (var i = 0; i < devices.length; i++) {
      final d = devices[i];
      final emulator = d.isEmulator ? ' (emulator)' : '';
      stdout.writeln('  ${d.id.padRight(24)} ${d.name} [${d.platform}]$emulator');
    }
  } on FlutterProcessException catch (e) {
    stderr.writeln('Failed to list devices: ${e.message}');
    exit(1);
  }
}

Future<void> _runApp() async {
  stdout.write('Flutter project directory: ');
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

  stdout.writeln('Listing Flutter devices...');
  final devices = await flutterProcess.listDevices();
  if (devices.isEmpty) {
    stdout.writeln('No devices found. Start an emulator or connect a device.');
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
  stdout.writeln('Running Flutter app on ${devices[index]}...');
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

  stdout.writeln('Discovering running Flutter apps...');
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
      final appOptions = result.apps!
          .map((a) => '${a.id} - ${a.name}')
          .toList();

      final index = cliSelect(
        options: appOptions,
        prompt: 'Multiple Flutter apps found. Select one:',
      );

      if (index == -1) {
        exit(0);
      }

      stdout.writeln('');
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

    stdout.writeln('No running Flutter apps found.');
    exit(1);
  } on FlutterProcessException catch (e) {
    stderr.writeln('Failed to attach: ${e.message}');
    exit(1);
  }
}
