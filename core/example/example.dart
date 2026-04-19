/// Example: Starting Dashability as an MCP server.
///
/// This shows how to programmatically start the Dashability MCP server.
/// For CLI usage, run:
///
/// ```bash
/// # Agent-driven (recommended)
/// dart run core/bin/dashability.dart
///
/// # Run a Flutter app and observe
/// dart run core/bin/dashability.dart --project-dir ./my_app -d emulator-5554
///
/// # Attach to a running app
/// dart run core/bin/dashability.dart --attach
///
/// # Direct connect
/// dart run core/bin/dashability.dart --uri ws://127.0.0.1:12345/ws
/// ```
library;

import 'package:dashability/dashability.dart';

Future<void> main() async {
  // 1. List available Flutter devices.
  final flutterProcess = FlutterProcess();
  final devices = await flutterProcess.listDevices();
  print('Found ${devices.length} device(s):');
  for (final device in devices) {
    print('  ${device.name} (${device.id}) [${device.platform}]');
  }

  // 2. Start the MCP server (agent-driven mode).
  //    The AI agent will use lifecycle tools (list_devices, run_app,
  //    attach_to_app) to connect to a Flutter app.
  final server = await DashabilityServer.start(
    config: const DashabilityConfig(),
    flutterProcess: flutterProcess,
  );

  // 3. Or connect programmatically to a known VM Service URI.
  await server.connectToApp(
    Uri.parse('ws://127.0.0.1:12345/xxxxx=/ws'),
  );

  print('Connected: ${server.isConnected}');

  // 4. Access observers directly if needed.
  final frameObserver =
      server.observerManager?.getObserver<FrameObserver>();
  print('Current FPS: ${frameObserver?.currentFps}');

  // 5. Clean up.
  await server.disconnectFromApp();
  await flutterProcess.dispose();
  await server.shutdown();
}
