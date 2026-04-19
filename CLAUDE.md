# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Dashability is an **AI Observability Layer for Flutter apps** — a standalone external tool (not a package you add to
your app) that connects to a running Flutter app via VM Service WebSocket, monitors performance/errors in real-time,
detects anomalies locally, and exposes structured observation + action tools via MCP (Model Context Protocol).

**It is not** a testing framework or just an MCP server. It is an AI runtime layer that understands and reacts to a
Flutter app while it is running.

## Build & Development Commands

This is a Dart monorepo with two packages. Each has its own `pubspec.yaml`.

```bash
# Resolve dependencies (run in each package dir)
cd core && dart pub get
cd extensions && dart pub get

# Run tests
cd core && dart test
cd extensions && dart test

# Run a single test file
cd core && dart test test/some_test.dart

# Lint
cd core && dart analyze
cd extensions && dart analyze

# Compile CLI to native binary
dart compile exe core/bin/dashability.dart

# Run CLI directly
dart run core/bin/dashability.dart
dart run core/bin/dashability.dart --project-dir ./example --profile
dart run core/bin/dashability.dart --attach
dart run core/bin/dashability.dart --uri ws://127.0.0.1:XXXXX/ws
```

## Architecture

### Monorepo Layout (flat, not nested under packages/)

- **`core/`** (`dashability`) — The main package. Contains the engine, MCP server, and CLI entry point:
    - **Connectors** — Abstract `Connector` interface + `FlutterConnector` (VM Service over WebSocket).
    - **Observers** — Abstract `Observer` interface + implementations (`FrameObserver`, `LogObserver`,
      `RebuildObserver`). Each subscribes to VM Service streams and emits `ObservationEvent`s. `ObserverManager`
      aggregates all observer streams.
    - **Analysis** — `AnomalyDetector` (rule-based tier 1), `ContextCompressor` (raw signals → token-efficient JSON),
      typed event models (`FrameDrop`, `RebuildSpike`, `ErrorCaught`, etc.).
    - **Actions** — `AppiumActor` for app interaction (tap, scroll, type) via `appium_driver`. Gracefully optional.
    - **Flutter Process** — `FlutterProcess` for managing `flutter run`, `flutter attach`, `flutter devices`.
    - **MCP Server** — Uses `dart_mcp` with `ToolsSupport` mixin, stdio transport. Registers lifecycle tools
      (`list_devices`, `run_app`, `attach_to_app`, `stop_app`), observation tools (`get_current_metrics`, `get_logs`,
      `get_anomalies`), action tools (`tap`, `scroll`, `type`), and validation tools (`assert_visible`).
    - **CLI** — `bin/dashability.dart` with `args` parsing. Supports agent-driven mode (no flags), `--project-dir`,
      `--attach`, `--uri` direct connect, and more.

- **`extensions/`** (`dashability_extensions`) — Optional tiny package (zero external deps, uses only `dart:developer`). Users
  can add as `dev_dependency` for custom event reporting via `developer.postEvent`. Dashability works fully without it.

- **`example/`** — Standalone Flutter demo app with deliberately janky widgets.

### Data Flow

```
Flutter App (running) → VM Service WebSocket → FlutterConnector
  → Observers (frame/log/rebuild) → ObservationEvents
  → AnomalyDetector (rule-based filtering) → ContextCompressor (token-efficient JSON)
  → MCP Server (stdio) → AI Host (Claude, etc.)
  → Optional: Appium actions back to the app
```

### Key Design Principles

- **Tokens scale with problems, not with time** — AI is only called on anomalies, not on every frame. Events are
  compressed and batched.
- **Multi-tier intelligence** — Tier 1 (rules) filters locally, Tier 2 (heuristics) maps patterns, Tier 3 (AI) does root
  cause analysis. Only Tier 3 costs tokens.
- **Pluggable connectors** — Adding a new framework means implementing `Connector` + framework-specific `Observer`s.
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
| `appium_driver`      | App interaction (tap/scroll/type) |
| `dart_mcp`           | MCP server SDK                    |
| `args`               | CLI argument parsing              |
