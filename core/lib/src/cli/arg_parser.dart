import 'dart:io';

import 'package:args/args.dart';

/// Build the CLI argument parser.
ArgParser buildArgParser() {
  return ArgParser()
    ..addOption(
      'uri',
      abbr: 'u',
      help: 'VM Service WebSocket URI (direct connect, skips discovery)',
    )
    ..addOption(
      'project-dir',
      abbr: 'p',
      help: 'Flutter project directory (runs flutter run)',
    )
    ..addOption(
      'device',
      abbr: 'd',
      help: 'Target device ID',
    )
    ..addOption(
      'flavor',
      help: 'Build flavor',
    )
    ..addFlag(
      'attach',
      abbr: 'a',
      help: 'Attach to an already-running Flutter app',
      defaultsTo: false,
    )
    ..addFlag(
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
}

/// Print CLI help text.
void printHelp(ArgParser parser) {
  stderr.writeln('Dashability - AI Observability Layer for Flutter Apps');
  stderr.writeln('');
  stderr.writeln('Usage: dashability [options]');
  stderr.writeln('');
  stderr.writeln('Commands:');
  stderr.writeln(
      '  install-mcp [host]     Install MCP server config for an AI host');
  stderr.writeln('');
  stderr.writeln('Modes:');
  stderr.writeln('  --uri <ws://...>       Direct connect to VM Service');
  stderr.writeln('  --project-dir <path>   Run flutter app from project dir');
  stderr.writeln('  --attach               Attach to running Flutter app');
  stderr.writeln(
      '  (no flags)             Interactive menu');
  stderr.writeln('');
  stderr.writeln(parser.usage);
}
