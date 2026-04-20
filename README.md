
<div align="center">
<img src="https://raw.githubusercontent.com/yashas-hm/dashability/refs/heads/main/assets/dashability_avatar.png" width="50%">

### Runtime Observability Layer for Flutter Apps
</div>

A standalone external tool that connects to a running Flutter app, monitors
performance and errors in real-time, detects anomalies, and exposes structured observation + action tools via
MCP (Model Context Protocol).

[Dashability](https://pub.dev/packages/dashability) is **not** a testing framework and **not** just an MCP server. It is a runtime observability layer that understands and
reacts to a Flutter app while it is running.

## How It Works

```
Flutter App (running) → VM Service WebSocket → Dashability
  → Observers (frame timing, logs, widget rebuilds)
  → Anomaly Detection (rule-based filtering)
  → Context Compression (token-efficient JSON)
  → MCP Server (stdio) → AI Host (Claude, etc.)
  → Optional: Appium actions back to the app
```

Dashability attaches **externally** to your Flutter app, no code changes needed. It connects to the Dart VM Service
that Flutter exposes in debug/profile mode, observes runtime signals, and serves them to an AI agent via MCP tools.

---

## Quick Start

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) >= 3.11.1
- Flutter SDK (for running/attaching to apps)
- (Optional) [Appium](https://appium.io/) server for autonomous app interaction

### 1. Install

```bash
dart pub global activate dashability
```

### 2. Configure Your AI Host

```bash
# Interactive - pick from supported hosts
dashability install-mcp

# Or specify directly
dashability install-mcp claude-code
dashability install-mcp cursor
dashability install-mcp claude-desktop

# See all supported hosts
dashability install-mcp --list
```

Supported hosts: Claude Desktop, Claude Code, Cursor, Windsurf, Codex, Gemini CLI, OpenCode.

### 3. Start Dashability

Running `dashability` with no arguments shows an interactive menu:

```
Dashability - Runtime Observability Layer for Flutter Apps

1. Start MCP Server
2. Install MCP
3. List Devices
4. Run App
5. Attach to App

Select an option (1-5):
```

You can also pass flags directly:

```bash
# Run a Flutter app and connect automatically
dashability --project-dir ./my_app -d emulator-5554

# Attach to an already-running Flutter app
dashability --attach

# Direct connect with a known VM Service URI
dashability --uri ws://127.0.0.1:12345/xxxxx=/ws
```

### Agent Workflow

Dashability is designed for an autonomous observe-fix-verify loop. The AI agent drives the entire workflow:

1. **Connect** - call `get_connection_status`, then `list_devices` to find devices, ask the user which to use, call `run_app` to launch the app (or `attach_to_app` for an already-running app)
2. **Observe** - call `get_current_metrics`, `get_logs`, `get_anomalies`, `get_widget_hotspots` to see real runtime performance data
3. **Fix** - modify the code based on real observations (frame drops, rebuild spikes, errors)
4. **Verify** - call `stop_app`, then `run_app` again to relaunch, observe again to confirm the fix
5. **Repeat** - loop steps 2-4 until the app runs clean
6. **Done** - call `stop_app` when finished

The MCP server delivers these instructions to any connected agent automatically. No special prompting needed.

---

## MCP Tools

### Lifecycle

| Tool | Description |
|------|-------------|
| `list_devices` | List available Flutter devices (emulators, simulators, physical) |
| `run_app` | Run a Flutter app in a project directory on a chosen device |
| `attach_to_app` | Attach to an already-running Flutter app (or connect via URI) |
| `stop_app` | Stop the Flutter app and disconnect observers |
| `get_connection_status` | Check if Dashability is connected |

### Observation

| Tool | Description |
|------|-------------|
| `get_current_metrics` | Current FPS, error count, rebuild hotspots |
| `get_recent_frames` | Frame timing data (build/render ms) |
| `get_widget_tree` | Full widget tree (summary, user widgets only, configurable depth) |
| `get_widget_hotspots` | Top rebuilding widgets by count |
| `get_logs` | Recent log entries, filterable by level |
| `get_anomalies` | Detected anomalies since last call (compressed context) |

### Actions (requires Appium)

| Tool | Description |
|------|-------------|
| `tap` | Tap element by text or accessibility ID |
| `scroll` | Scroll in a direction |
| `type_text` | Type into an input field |

### Validation (requires Appium)

| Tool | Description |
|------|-------------|
| `assert_visible` | Check if element is visible on screen |

---

## Project Structure

```
dashability/
├── core/       dashability           - Engine, MCP server, and CLI entry point
├── extensions/ dashability_extensions - Optional in-app instrumentation (zero deps)
└── example/    Demo Flutter app      - Deliberately janky widgets for testing
```

### [Dashability](https://pub.dev/packages/dashability)

The main package. Contains the engine (connectors, observers, analysis, actions), Flutter process management,
MCP server, and CLI entry point.

- **Connectors** - Abstract `Connector` interface + `FlutterConnector` (VM Service over WebSocket)
- **Observers** - `FrameObserver`, `LogObserver`, `RebuildObserver` + `ObserverManager`
- **Analysis** - `AnomalyDetector` (rule-based), `ContextCompressor` (token-efficient JSON), typed event models
- **Actions** - `AppiumActor` for tap/scroll/type via Appium
- **Flutter Process** - `FlutterProcess` for managing `flutter run`, `flutter attach`, `flutter devices`
- **MCP Server** - `dart_mcp` with `ToolsSupport` mixin, stdio transport

```bash
dashability [options]
```

| Flag | Description |
|------|-------------|
| `--uri`, `-u` | VM Service WebSocket URI (direct connect) |
| `--project-dir`, `-p` | Flutter project directory (runs `flutter run`) |
| `--device`, `-d` | Target device ID |
| `--flavor` | Build flavor |
| `--attach`, `-a` | Attach to an already-running Flutter app |
| `--profile` | Use profile-mode thresholds (120fps budget) |
| `--appium-url` | Appium server URL, enables action/validation tools |

### [Dashability Extension](https://pub.dev/packages/dashability_extensions)

Optional tiny package users can add as `dev_dependency` for richer custom event reporting. Zero external dependencies -
uses only `dart:developer`.

```dart
import 'package:dashability_extensions/dashability_extensions.dart';

DashabilityReporter.interaction('user_drew_stroke');
DashabilityReporter.metric('canvas_points', 1523);
DashabilityReporter.screen('ImageEditor');
```

Dashability works fully without this package.

---

## Running the Example App

```bash
# Option 1: Let Dashability handle everything
dashability --project-dir ./example --profile

# Option 2: Run manually and attach
cd example && flutter run --profile
# In another terminal:
dashability --attach

# Option 3: Start MCP server, agent does the rest
dashability
# Select "1. Start MCP Server" from the menu
```

The example app includes:

- **Janky Counter** - rebuilds every frame with expensive computation
- **Heavy List** - unoptimized scroll list with 10,000 items
- **Error Thrower** - triggers a deliberate exception

---

## Development

```bash
# Run tests
cd core && dart test

# Lint
cd core && dart analyze
cd extensions && dart analyze

# Compile to native binary (for development)
dart compile exe core/bin/dashability.dart
```

---

## Contributing

We welcome contributions from the community! To contribute:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Submit a pull request with a detailed description of changes.

Please adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) when interacting with the project.

---

## Security

If you discover any security vulnerabilities, please report them
via [yashashm.dev@gmail.com](mailto:yashashm.dev@gmail.com). We take security issues seriously and appreciate your
efforts to responsibly disclose them. Read more at [SECURITY](SECURITY.md)

---

## Code of Conduct

This project is governed by a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold a welcoming
and inclusive environment.

---

## License

Dashability is licensed under the [License](LICENSE).
