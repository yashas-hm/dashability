# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Dashability is an **AI Observability Layer for Flutter apps** - a standalone external tool (not a package you add to
your app) that connects to a running Flutter app via VM Service WebSocket, monitors performance/errors in real-time,
detects anomalies locally, and exposes structured observation + action tools via MCP (Model Context Protocol).

**It is not** a testing framework or just an MCP server. It is an AI runtime layer that understands and reacts to a
Flutter app while it is running.

## IMPORTANT: You Have Dashability MCP Tools

Dashability MCP tools are registered in this session via `.mcp.json`. **Use them directly** like any other MCP tool.
Do NOT run `dashability` as a CLI subprocess, pipe JSON-RPC, or read stderr. Do NOT just read source code and
do static analysis - Dashability is a **runtime observer**, not a linter.

**Available MCP tools:**

- **Lifecycle**: `list_devices`, `run_app`, `attach_to_app`, `stop_app`, `get_connection_status`
- **Observation**: `get_current_metrics`, `get_recent_frames`, `get_widget_tree`, `get_widget_hotspots`, `get_logs`, `get_anomalies`
- **Actions** (requires Appium): `tap`, `scroll`, `type_text`
- **Validation** (requires Appium): `assert_visible`

If the tools are not available, run `dart pub global activate --source path ./core` and restart the session.

## Autonomous Development Loop

When writing or improving Flutter code, use Dashability as your runtime feedback loop:

1. **Write/modify** the Flutter code
2. **Launch** the app: call `list_devices` -> ask user which device -> call `run_app`
3. **Observe** the running app: call `get_current_metrics`, `get_logs`, `get_anomalies`, `get_widget_hotspots`
4. **Fix** issues based on real runtime observations (frame drops, rebuild spikes, errors)
5. **Restart**: call `stop_app`, then `run_app` again to verify the fix
6. **Repeat** until the app runs clean - no anomalies, stable FPS, no errors

This is the core purpose of Dashability: you observe real performance data from the running app,
not just static code analysis. Always run the app and observe before declaring issues fixed.

## Build & Development Commands

This is a Dart monorepo with two packages. Each has its own `pubspec.yaml`.

```bash
# Resolve dependencies
./scripts/pub_get_all.sh

# Run tests
cd core && dart test
cd extensions && dart test

# Lint
cd core && dart analyze
cd extensions && dart analyze

# Run CLI interactively
dashability

# Run with flags
dashability --project-dir ./example --profile
dashability --attach
dashability --uri ws://127.0.0.1:XXXXX/ws

# Install MCP config
dashability install-mcp claude-code
dashability install-mcp --list

# Publish
./scripts/publish_dashability.sh
./scripts/publish_extensions.sh
```

## Architecture

### Monorepo Layout (flat, not nested under packages/)

- **`core/`** (`dashability`) - The main package. Contains the engine, MCP server, and CLI entry point:
    - **Connectors** - Abstract `Connector` interface + `FlutterConnector` (VM Service over WebSocket).
    - **Observers** - Abstract `Observer` interface + implementations (`FrameObserver`, `LogObserver`,
      `RebuildObserver`). Each subscribes to VM Service streams and emits `ObservationEvent`s. `ObserverManager`
      aggregates all observer streams.
    - **Analysis** - `AnomalyDetector` (rule-based tier 1), `ContextCompressor` (raw signals -> token-efficient JSON),
      typed event models (`FrameDrop`, `RebuildSpike`, `ErrorCaught`, etc.).
    - **Actions** - `AppiumActor` for app interaction (tap, scroll, type) via `appium_driver`. Gracefully optional.
    - **Flutter Process** - `FlutterProcess` for managing `flutter run`, `flutter attach`, `flutter devices`.
    - **MCP Server** - Uses `dart_mcp` with `ToolsSupport` mixin, stdio transport. Registers lifecycle tools
      (`list_devices`, `run_app`, `attach_to_app`, `stop_app`), observation tools (`get_current_metrics`, `get_logs`,
      `get_anomalies`), action tools (`tap`, `scroll`, `type`), and validation tools (`assert_visible`).
    - **CLI** - `bin/dashability.dart` routes to modular CLI files in `lib/src/cli/`:
        - `interactive_menu.dart` - Main menu + interactive lifecycle flows
        - `arg_parser.dart` - ArgParser setup + help text
        - `connection.dart` - Resolve connection URI from flags
        - `server_runner.dart` - Start MCP server, connect, shutdown
        - `install_mcp.dart` - Install MCP config for AI hosts

- **`extensions/`** (`dashability_extensions`) - Optional tiny package (zero external deps, uses only `dart:developer`). Users
  can add as `dev_dependency` for custom event reporting via `developer.postEvent`. Dashability works fully without it.

- **`example/`** - Standalone Flutter demo app with deliberately janky widgets.

- **`scripts/`** - Publishing and utility scripts.

### Data Flow

```
Flutter App (running) -> VM Service WebSocket -> FlutterConnector
  -> Observers (frame/log/rebuild) -> ObservationEvents
  -> AnomalyDetector (rule-based filtering) -> ContextCompressor (token-efficient JSON)
  -> MCP Server (stdio) -> AI Host (Claude, etc.)
  -> Optional: Appium actions back to the app
```

### Key Design Principles

- **Tokens scale with problems, not with time** - AI is only called on anomalies, not on every frame. Events are
  compressed and batched.
- **Multi-tier intelligence** - Tier 1 (rules) filters locally, Tier 2 (heuristics) maps patterns, Tier 3 (AI) does root
  cause analysis. Only Tier 3 costs tokens.
- **Pluggable connectors** - Adding a new framework means implementing `Connector` + framework-specific `Observer`s.
  Analysis, MCP, and action layers require zero changes.

## Code Rules

- **Always use package imports, never relative imports.** Use `import 'package:dashability/...'` not
  `import '../src/...'`. This applies across all packages in the monorepo.

## Git & Commits

- **Never commit directly.** After completing a logical unit of work, pause and suggest a commit message to the user.
  The user will commit manually.
- **One-liner commit messages only.** No multi-line descriptions or bullet points.
- Use prefixes: `feat:`, `add:`, `fix:`, `update:`

## Key Dependencies

| Package              | Purpose                           |
|----------------------|-----------------------------------|
| `vm_service`         | Typed Dart VM Service client      |
| `web_socket_channel` | WebSocket transport               |
| `stream_channel`     | Stream channel abstraction        |
| `appium_driver`      | App interaction (tap/scroll/type) |
| `dart_mcp`           | MCP server SDK                    |
| `args`               | CLI argument parsing              |
