import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dashability/src/flutter/flutter_device.dart';

/// Result of attempting to attach to a running Flutter app.
class AttachResult {
  /// VM Service URI if a single app was found and connected.
  final String? uri;

  /// List of running app instances if multiple were found.
  final List<AppInstance>? apps;

  /// Human-readable status message.
  final String message;

  const AttachResult({this.uri, this.apps, required this.message});

  bool get isConnected => uri != null;

  bool get hasMultipleApps => apps != null && apps!.length > 1;

  Map<String, dynamic> toJson() =>
      {
        'status': isConnected
            ? 'connected'
            : hasMultipleApps
            ? 'multiple_apps'
            : 'no_apps',
        if (uri != null) 'uri': uri,
        if (apps != null)
          'apps': apps!.map((a) => a.toJson()).toList(),
        'message': message,
      };
}

/// A running Flutter app instance discovered during attach.
class AppInstance {
  final String id;
  final String name;
  final String? uri;

  const AppInstance({required this.id, required this.name, this.uri});

  Map<String, dynamic> toJson() =>
      {
        'id': id,
        'name': name,
        if (uri != null) 'uri': uri,
      };
}

/// Manages Flutter CLI processes (run, attach, devices).
class FlutterProcess {
  Process? _process;
  final _outputController = StreamController<String>.broadcast();

  /// Whether a flutter process is currently running.
  bool get isRunning => _process != null;

  /// Stream of output lines from the flutter process.
  Stream<String> get output => _outputController.stream;

  /// List available Flutter devices.
  ///
  /// Runs `flutter devices --machine` and parses the JSON output.
  Future<List<FlutterDevice>> listDevices() async {
    final result = await Process.run('flutter', ['devices', '--machine']);

    if (result.exitCode != 0) {
      throw FlutterProcessException(
        'flutter devices failed: ${result.stderr}',
      );
    }

    final stdout = result.stdout as String;

    // Find the JSON array in output (skip any non-JSON lines).
    final jsonStart = stdout.indexOf('[');
    if (jsonStart == -1) return [];

    final jsonStr = stdout.substring(jsonStart);
    final List<dynamic> devices = jsonDecode(jsonStr) as List<dynamic>;

    return devices
        .whereType<Map<String, dynamic>>()
        .map(FlutterDevice.fromJson)
        .toList();
  }

  /// Run a Flutter app.
  ///
  /// Spawns `flutter run` in [projectDir] and parses the VM Service URI
  /// from the process output. Returns the URI once the app is running.
  Future<String> run({
    required String projectDir,
    String? device,
    String? flavor,
    bool profile = false,
    List<String> extraArgs = const [],
  }) async {
    if (_process != null) {
      throw FlutterProcessException(
        'A Flutter process is already running. Call stop() first.',
      );
    }

    final args = <String>[
      'run',
      if (device != null) ...['--device-id', device],
      if (flavor != null) ...['--flavor', flavor],
      if (profile) '--profile',
      ...extraArgs,
    ];

    return _startAndParseUri(args, projectDir);
  }

  /// Attach to a running Flutter app.
  ///
  /// Runs `flutter attach` which discovers running Flutter apps.
  /// If [appId] is provided, attaches to that specific app.
  /// If multiple apps are running and no [appId] given, returns an
  /// [AttachResult] with the list of apps for the user to choose.
  Future<AttachResult> attach({String? device, String? appId}) async {
    if (_process != null) {
      throw FlutterProcessException(
        'A Flutter process is already running. Call stop() first.',
      );
    }

    final args = <String>[
      'attach',
      if (device != null) ...['--device-id', device],
      if (appId != null) ...['--app-id', appId],
    ];

    try {
      final uri = await _startAndParseUri(args, null);
      return AttachResult(uri: uri, message: 'Connected to app.');
    } on FlutterProcessException catch (e) {
      // Check if the error indicates multiple apps.
      if (e.message.contains('Multiple') ||
          e.message.contains('multiple')) {
        // Try to parse app instances from output.
        // flutter attach lists them when multiple are found.
        await stop();
        return AttachResult(
          message: e.message,
          apps: e.apps,
        );
      }
      await stop();
      rethrow;
    }
  }

  /// Stop the running Flutter process.
  Future<void> stop() async {
    final process = _process;
    if (process == null) return;

    // Send 'q' to gracefully quit flutter run/attach.
    process.stdin.writeln('q');

    // Give it a moment to shut down, then force kill.
    final exited = await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        process.kill(ProcessSignal.sigterm);
        return -1;
      },
    );

    if (exited == -1) {
      process.kill(ProcessSignal.sigkill);
    }

    _process = null;
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await stop();
    await _outputController.close();
  }

  /// Start a flutter process and parse the VM Service URI from output.
  Future<String> _startAndParseUri(List<String> args,
      String? workingDirectory,) async {
    final process = await Process.start(
      'flutter',
      args,
      workingDirectory: workingDirectory,
    );
    _process = process;

    final uriCompleter = Completer<String>();
    final appInstances = <AppInstance>[];

    // Listen to both stdout and stderr.
    _listenToStream(process.stdout, uriCompleter, appInstances);
    _listenToStream(process.stderr, uriCompleter, appInstances);

    // Handle process exit before URI is found.
    process.exitCode.then((code) {
      if (!uriCompleter.isCompleted) {
        if (appInstances.isNotEmpty) {
          uriCompleter.completeError(FlutterProcessException(
            'Multiple Flutter apps found. Choose one to attach to.',
            apps: appInstances,
          ));
        } else {
          uriCompleter.completeError(FlutterProcessException(
            'Flutter process exited with code $code before '
                'VM Service URI was found.',
          ));
        }
        _process = null;
      }
    });

    return uriCompleter.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        stop();
        throw FlutterProcessException(
          'Timed out waiting for VM Service URI.',
        );
      },
    );
  }

  void _listenToStream(Stream<List<int>> stream,
      Completer<String> uriCompleter,
      List<AppInstance> appInstances,) {
    stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _outputController.add(line);

      if (uriCompleter.isCompleted) return;

      // Parse VM Service URI.
      final uri = _parseVmServiceUri(line);
      if (uri != null) {
        uriCompleter.complete(uri);
        return;
      }

      // Parse app instances from attach output.
      final app = _parseAppInstance(line);
      if (app != null) {
        appInstances.add(app);
      }
    });
  }

  /// Extract VM Service URI from a log line.
  static String? _parseVmServiceUri(String line) {
    // Matches patterns like:
    //   The Dart VM service is listening on ws://127.0.0.1:12345/xxxxx=/ws
    //   Observatory listening on ws://...
    //   A Dart VM Service on ... is available at: ws://...
    final patterns = [
      RegExp(r'listening on (ws://\S+)'),
      RegExp(r'available at: (ws://\S+)'),
      RegExp(r'(ws://127\.0\.0\.1:\d+/\S*)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) return match.group(1);
    }

    return null;
  }

  /// Try to parse an app instance line from flutter attach output.
  static AppInstance? _parseAppInstance(String line) {
    // Flutter attach lists apps like:
    //   • com.example.app (on Device Name)
    final match = RegExp(r'[•\-]\s+(\S+)\s+\(on (.+)\)').firstMatch(line);
    if (match != null) {
      return AppInstance(
        id: match.group(1)!,
        name: match.group(2)!,
      );
    }
    return null;
  }
}

/// Exception thrown by [FlutterProcess] operations.
class FlutterProcessException implements Exception {
  final String message;
  final List<AppInstance>? apps;

  const FlutterProcessException(this.message, {this.apps});

  @override
  String toString() => 'FlutterProcessException: $message';
}
