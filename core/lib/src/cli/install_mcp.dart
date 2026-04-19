import 'dart:convert';
import 'dart:io';

import 'package:dashability/src/cli/cli_select.dart';

/// Supported AI host for MCP server configuration.
class McpHost {
  final String key;
  final String name;
  final String Function() configPath;
  final void Function(String path) writeConfig;

  const McpHost._({
    required this.key,
    required this.name,
    required this.configPath,
    required this.writeConfig,
  });
}

/// All supported MCP hosts.
final List<McpHost> mcpHosts = [
  McpHost._(
    key: 'claude-desktop',
    name: 'Claude Desktop',
    configPath: () => _platformPath(
      macOS: '${Platform.environment['HOME']}/Library/Application Support/Claude/claude_desktop_config.json',
      linux: '${Platform.environment['HOME']}/.config/Claude/claude_desktop_config.json',
      windows: '${Platform.environment['APPDATA']}\\Claude\\claude_desktop_config.json',
    ),
    writeConfig: (path) => _writeJsonMcpServers(path),
  ),
  McpHost._(
    key: 'claude-code',
    name: 'Claude Code',
    configPath: () => '${Directory.current.path}/.mcp.json',
    writeConfig: (path) => _writeJsonMcpServers(path),
  ),
  McpHost._(
    key: 'cursor',
    name: 'Cursor',
    configPath: () => _platformPath(
      macOS: '${Platform.environment['HOME']}/.cursor/mcp.json',
      linux: '${Platform.environment['HOME']}/.cursor/mcp.json',
      windows: '${Platform.environment['USERPROFILE']}\\.cursor\\mcp.json',
    ),
    writeConfig: (path) => _writeJsonMcpServers(path),
  ),
  McpHost._(
    key: 'windsurf',
    name: 'Windsurf',
    configPath: () => _platformPath(
      macOS: '${Platform.environment['HOME']}/.codeium/windsurf/mcp_config.json',
      linux: '${Platform.environment['HOME']}/.codeium/windsurf/mcp_config.json',
      windows: '${Platform.environment['USERPROFILE']}\\.codeium\\windsurf\\mcp_config.json',
    ),
    writeConfig: (path) => _writeJsonMcpServers(path),
  ),
  McpHost._(
    key: 'codex',
    name: 'Codex',
    configPath: () => _platformPath(
      macOS: '${Platform.environment['HOME']}/.codex/config.toml',
      linux: '${Platform.environment['HOME']}/.codex/config.toml',
      windows: '${Platform.environment['USERPROFILE']}\\.codex\\config.toml',
    ),
    writeConfig: (path) => _writeCodexToml(path),
  ),
  McpHost._(
    key: 'gemini',
    name: 'Gemini CLI',
    configPath: () => '${Directory.current.path}/.gemini/settings.json',
    writeConfig: (path) => _writeJsonMcpServers(path),
  ),
  McpHost._(
    key: 'opencode',
    name: 'OpenCode',
    configPath: () => _platformPath(
      macOS: '${Platform.environment['HOME']}/.config/opencode/opencode.json',
      linux: '${Platform.environment['HOME']}/.config/opencode/opencode.json',
      windows: '${Platform.environment['USERPROFILE']}\\.config\\opencode\\opencode.json',
    ),
    writeConfig: (path) => _writeOpenCodeConfig(path),
  ),
];

/// Run the install-mcp subcommand.
Future<void> installMcp(List<String> args) async {
  if (args.contains('--list') || args.contains('-l')) {
    _printHosts();
    return;
  }

  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  McpHost host;

  if (args.isNotEmpty && !args.first.startsWith('-')) {
    // Specific host provided.
    final key = args.first;
    final found = mcpHosts.where((h) => h.key == key).toList();
    if (found.isEmpty) {
      stderr.writeln('Unknown host: $key');
      stderr.writeln('');
      _printHosts();
      exit(1);
    }
    host = found.first;
  } else {
    // Interactive: prompt user to pick.
    final hostNames = mcpHosts.map((h) => h.name).toList();
    final index = cliSelect(
      options: hostNames,
      prompt: 'Select an AI host to configure:',
    );
    if (index == -1) {
      exit(0);
    }
    stdout.writeln('');
    host = mcpHosts[index];
  }

  final path = host.configPath();
  host.writeConfig(path);
  stdout.writeln('Installed dashability MCP server config for ${host.name}');
  stdout.writeln('  -> $path');
}

void _printUsage() {
  stdout.writeln('Usage: dashability install-mcp [host] [options]');
  stdout.writeln('');
  stdout.writeln('Install Dashability MCP server configuration for an AI host.');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  --list, -l   List supported hosts');
  stdout.writeln('  --help, -h   Show this help');
  stdout.writeln('');
  stdout.writeln('Examples:');
  stdout.writeln('  dashability install-mcp              # interactive');
  stdout.writeln('  dashability install-mcp claude-code   # specific host');
  stdout.writeln('  dashability install-mcp --list        # list hosts');
  stdout.writeln('');
  _printHosts();
}

void _printHosts() {
  stdout.writeln('Supported hosts:');
  for (final host in mcpHosts) {
    stdout.writeln('  ${host.key.padRight(16)} ${host.name}');
  }
}

/// Write dashability entry into a JSON file with `mcpServers` key.
void _writeJsonMcpServers(String path) {
  final file = File(path);
  Map<String, dynamic> config = {};

  if (file.existsSync()) {
    try {
      config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      // File exists but isn't valid JSON — start fresh.
    }
  }

  final mcpServers =
      (config['mcpServers'] as Map<String, dynamic>?) ?? <String, dynamic>{};

  if (mcpServers.containsKey('dashability')) {
    stderr.writeln('Note: dashability already configured, overwriting.');
  }

  mcpServers['dashability'] = {
    'type': 'stdio',
    'command': 'dashability',
    'args': <String>[],
  };

  config['mcpServers'] = mcpServers;

  file.parent.createSync(recursive: true);
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(config)}\n');
}

/// Write dashability entry into OpenCode's config format.
void _writeOpenCodeConfig(String path) {
  final file = File(path);
  Map<String, dynamic> config = {};

  if (file.existsSync()) {
    try {
      config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      // Start fresh.
    }
  }

  final mcp = (config['mcp'] as Map<String, dynamic>?) ?? <String, dynamic>{};

  if (mcp.containsKey('dashability')) {
    stderr.writeln('Note: dashability already configured, overwriting.');
  }

  mcp['dashability'] = {
    'type': 'local',
    'command': ['dashability'],
    'enabled': true,
  };

  config['mcp'] = mcp;

  file.parent.createSync(recursive: true);
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(config)}\n');
}

/// Write dashability entry into Codex's TOML config.
void _writeCodexToml(String path) {
  final file = File(path);
  var content = '';

  if (file.existsSync()) {
    content = file.readAsStringSync();
  }

  if (content.contains('[mcp_servers.dashability]')) {
    stderr.writeln('Note: dashability already configured in TOML, skipping.');
    stderr.writeln('To update, edit $path manually.');
    return;
  }

  final entry = '''

[mcp_servers.dashability]
command = "dashability"
args = []
''';

  file.parent.createSync(recursive: true);
  file.writeAsStringSync('$content$entry');
}

/// Resolve platform-specific path.
String _platformPath({
  required String macOS,
  required String linux,
  required String windows,
}) {
  if (Platform.isMacOS) return macOS;
  if (Platform.isLinux) return linux;
  if (Platform.isWindows) return windows;
  return linux; // fallback
}
