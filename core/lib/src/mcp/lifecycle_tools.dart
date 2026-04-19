import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:dashability/dashability.dart';

/// Registers lifecycle MCP tools for managing Flutter app connections.
void registerLifecycleTools(DashabilityServer server) {
  // list_devices
  server.registerTool(
    Tool(
      name: 'list_devices',
      description:
      'List available Flutter devices (emulators, simulators, '
          'physical devices). Returns device IDs, names, and platforms. '
          'If no devices are found, prompt the user to start an emulator '
          'or connect a physical device.',
      inputSchema: ObjectSchema(),
    ),
        (request) async {
      try {
        final devices = await server.flutterProcess.listDevices();

        if (devices.isEmpty) {
          return CallToolResult(
            content: [
              TextContent(
                text: jsonEncode({
                  'devices': <dynamic>[],
                  'message':
                  'No Flutter devices found. Ask the user to start '
                      'an emulator, open a simulator, or connect a '
                      'physical device, then try again.',
                }),
              ),
            ],
          );
        }

        return CallToolResult(
          content: [
            TextContent(
              text: jsonEncode({
                'devices': devices.map((d) => d.toJson()).toList(),
                'message':
                'Found ${devices.length} device(s). '
                    'Ask the user which device to use, then call run_app '
                    'or attach_to_app with the chosen device ID.',
              }),
            ),
          ],
        );
      } on FlutterProcessException catch (e) {
        return CallToolResult(
          isError: true,
          content: [TextContent(text: 'Failed to list devices: ${e.message}')],
        );
      }
    },
  );

  // run_app
  server.registerTool(
    Tool(
      name: 'run_app',
      description:
      'Run a Flutter app and connect Dashability to it. '
          'Spawns `flutter run` in the given project directory, '
          'waits for the app to start, and automatically begins '
          'observing performance, logs, and anomalies.',
      inputSchema: ObjectSchema(
        properties: {
          'project_dir': Schema.string(
            description: 'Path to the Flutter project directory (required)',
          ),
          'device': Schema.string(
            description:
            'Device ID to run on (required, from list_devices)',
          ),
          'flavor': Schema.string(
            description: 'Build flavor (optional)',
          ),
          'profile': Schema.bool(
            description: 'Run in profile mode (default: false)',
          ),
        },
        required: ['project_dir', 'device'],
      ),
    ),
        (request) async {
      if (server.isConnected) {
        return CallToolResult(
          isError: true,
          content: [
            TextContent(
              text: 'Already connected to a Flutter app. '
                  'Call stop_app first to disconnect.',
            ),
          ],
        );
      }

      final projectDir = request.arguments!['project_dir'] as String;
      final device = request.arguments!['device'] as String;
      final flavor = request.arguments?['flavor'] as String?;
      final profile = request.arguments?['profile'] as bool? ?? false;

      try {
        final uri = await server.flutterProcess.run(
          projectDir: projectDir,
          device: device,
          flavor: flavor,
          profile: profile,
        );

        await server.connectToApp(Uri.parse(uri));

        return CallToolResult(
          content: [
            TextContent(
              text: jsonEncode({
                'status': 'connected',
                'uri': uri,
                'device': device,
                'project_dir': projectDir,
                'message': 'App is running and Dashability is observing. '
                    'Use observation tools to monitor the app.',
              }),
            ),
          ],
        );
      } on FlutterProcessException catch (e) {
        return CallToolResult(
          isError: true,
          content: [TextContent(text: 'Failed to run app: ${e.message}')],
        );
      } catch (e) {
        return CallToolResult(
          isError: true,
          content: [TextContent(text: 'Failed to connect: $e')],
        );
      }
    },
  );

  // attach_to_app
  server.registerTool(
    Tool(
      name: 'attach_to_app',
      description:
      'Attach to an already-running Flutter app. '
          'Discovers running Flutter apps and connects Dashability. '
          'If multiple apps are running, returns a list for the user '
          'to choose from — call again with the chosen app_id.',
      inputSchema: ObjectSchema(
        properties: {
          'device': Schema.string(
            description: 'Device ID to attach to (optional)',
          ),
          'app_id': Schema.string(
            description:
            'Specific app ID to attach to when multiple apps '
                'are running (optional, from a previous attach_to_app call)',
          ),
          'uri': Schema.string(
            description:
            'VM Service WebSocket URI to connect to directly '
                '(optional, skips discovery)',
          ),
        },
      ),
    ),
        (request) async {
      if (server.isConnected) {
        return CallToolResult(
          isError: true,
          content: [
            TextContent(
              text: 'Already connected to a Flutter app. '
                  'Call stop_app first to disconnect.',
            ),
          ],
        );
      }

      // Direct URI connection.
      final directUri = request.arguments?['uri'] as String?;
      if (directUri != null) {
        try {
          await server.connectToApp(Uri.parse(directUri));
          return CallToolResult(
            content: [
              TextContent(
                text: jsonEncode({
                  'status': 'connected',
                  'uri': directUri,
                  'message': 'Connected to app. '
                      'Use observation tools to monitor.',
                }),
              ),
            ],
          );
        } catch (e) {
          return CallToolResult(
            isError: true,
            content: [TextContent(text: 'Failed to connect: $e')],
          );
        }
      }

      // Discovery via flutter attach.
      final device = request.arguments?['device'] as String?;
      final appId = request.arguments?['app_id'] as String?;

      try {
        final result = await server.flutterProcess.attach(
          device: device,
          appId: appId,
        );

        if (result.isConnected) {
          await server.connectToApp(Uri.parse(result.uri!));
          return CallToolResult(
            content: [
              TextContent(
                text: jsonEncode({
                  'status': 'connected',
                  'uri': result.uri,
                  'message': 'Attached to running app. '
                      'Use observation tools to monitor.',
                }),
              ),
            ],
          );
        }

        if (result.hasMultipleApps) {
          return CallToolResult(
            content: [
              TextContent(
                text: jsonEncode({
                  'status': 'multiple_apps',
                  'apps': result.apps!.map((a) => a.toJson()).toList(),
                  'message':
                  'Multiple Flutter apps found. Ask the user which '
                      'app to connect to, then call attach_to_app again '
                      'with the chosen app_id.',
                }),
              ),
            ],
          );
        }

        return CallToolResult(
          isError: true,
          content: [
            TextContent(
              text: 'No running Flutter apps found. '
                  'Use run_app to start one, or start the app manually '
                  'and try again.',
            ),
          ],
        );
      } on FlutterProcessException catch (e) {
        if (e.apps != null && e.apps!.isNotEmpty) {
          return CallToolResult(
            content: [
              TextContent(
                text: jsonEncode({
                  'status': 'multiple_apps',
                  'apps': e.apps!.map((a) => a.toJson()).toList(),
                  'message':
                  'Multiple Flutter apps found. Ask the user which '
                      'app to connect to, then call attach_to_app again '
                      'with the chosen app_id.',
                }),
              ),
            ],
          );
        }
        return CallToolResult(
          isError: true,
          content: [TextContent(text: 'Failed to attach: ${e.message}')],
        );
      }
    },
  );

  // stop_app
  server.registerTool(
    Tool(
      name: 'stop_app',
      description:
      'Stop the running Flutter app and disconnect Dashability. '
          'Kills the flutter process (if started by run_app) and '
          'stops all observers.',
      inputSchema: ObjectSchema(),
    ),
        (request) async {
      try {
        await server.disconnectFromApp();
        await server.flutterProcess.stop();

        return CallToolResult(
          content: [
            TextContent(
              text: jsonEncode({
                'status': 'disconnected',
                'message': 'App stopped and Dashability disconnected.',
              }),
            ),
          ],
        );
      } catch (e) {
        return CallToolResult(
          isError: true,
          content: [TextContent(text: 'Failed to stop app: $e')],
        );
      }
    },
  );

  // get_connection_status
  server.registerTool(
    Tool(
      name: 'get_connection_status',
      description:
      'Get the current connection status of Dashability. '
          'Returns whether connected, the VM Service URI, '
          'and whether a flutter process is managed.',
      inputSchema: ObjectSchema(),
    ),
        (request) {
      return CallToolResult(
        content: [
          TextContent(
            text: jsonEncode({
              'connected': server.isConnected,
              'flutter_process_running': server.flutterProcess.isRunning,
              if (server.isConnected)
                'connector_state': server.connector!.state.name,
            }),
          ),
        ],
      );
    },
  );
}
