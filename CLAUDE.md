# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Dashability is an **AI Observability Layer for Flutter apps** — a standalone external tool (not a package you add to your app) that connects to a running Flutter app via VM Service WebSocket, monitors performance/errors in real-time, detects anomalies locally, and exposes structured observation + action tools via MCP (Model Context Protocol).

**It is not** a testing framework or just an MCP server. It is an AI runtime layer that understands and reacts to a Flutter app while it is running.

## Build & Development Commands

This is a Dart monorepo with three packages. Each has its own `pubspec.yaml`.

```bash
# Resolve dependencies (run in each package dir)
cd core && dart pub get
cd cli && dart pub get
cd helper && dart pub get

# Run tests
cd core && dart test
cd cli && dart test
cd helper && dart test

# Run a single test file
cd core && dart test test/some_test.dart

# Lint
cd core && dart analyze
cd cli && dart analyze
cd helper && dart analyze

# Compile CLI to native binary
dart compile exe cli/bin/dashability.dart

# Run CLI directly
dart run cli/bin/dashability.dart --uri ws://127.0.0.1:XXXXX/ws
```

## Architecture

### Monorepo Layout (flat, not nested under packages/)

- **`core/`** (`dashability_core`) — The engine. Pure Dart, no Flutter SDK, no MCP. Contains:
  - **Connectors** — Abstract `Connector` interface + `FlutterConnector` (VM Service over WebSocket). New framework support (React Native, SwiftUI) means adding a new connector here.
  - **Observers** — Abstract `Observer` interface + implementations (`FrameObserver`, `LogObserver`, `RebuildObserver`). Each subscribes to VM Service streams and emits `ObservationEvent`s. `ObserverManager` aggregates all observer streams.
  - **Analysis** — `AnomalyDetector` (rule-based tier 1), `ContextCompressor` (raw signals → token-efficient JSON), typed event models (`FrameDrop`, `RebuildSpike`, `ErrorCaught`, etc.).
  - **Actions** — `AppiumActor` for app interaction (tap, scroll, type) via `appium_driver`. Gracefully optional.

- **`cli/`** (`dashability_cli`) — User-facing entry point. Depends on `dashability_core` via `path: ../core`. Contains:
  - **MCP Server** — Uses `dart_mcp` with `ToolsSupport` mixin, stdio transport. Registers observation tools (`get_current_metrics`, `get_logs`, `get_anomalies`), action tools (`tap`, `scroll`, `type`), and validation tools (`assert_visible`).
  - **CLI** — `bin/dashability.dart` with `args` parsing. Wires FlutterConnector → ObserverManager → AnomalyDetector → MCP Server.

- **`helper/`** (`dashability_helper`) — Optional tiny package (zero external deps, uses only `dart:developer`). Users can add as `dev_dependency` for custom event reporting via `developer.postEvent`. Dashability works fully without it.

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

- **Tokens scale with problems, not with time** — AI is only called on anomalies, not on every frame. Events are compressed and batched.
- **Multi-tier intelligence** — Tier 1 (rules) filters locally, Tier 2 (heuristics) maps patterns, Tier 3 (AI) does root cause analysis. Only Tier 3 costs tokens.
- **Pluggable connectors** — Adding a new framework means implementing `Connector` + framework-specific `Observer`s. Analysis, MCP, and action layers require zero changes.

## Code Rules

- **Always use package imports, never relative imports.** Use `import 'package:dashability_core/...'` not `import '../src/...'`. This applies across all packages in the monorepo.

## Git & Commits

- **Never commit directly.** After completing a logical unit of work, pause and suggest a commit message to the user. The user will commit manually.
- **One-liner commit messages only.** No multi-line descriptions or bullet points.
- Use prefixes: `feat:`, `add:`, `fix:`, `update:`

## Key Dependencies

| Package | Used In | Purpose |
|---------|---------|---------|
| `vm_service` | core | Typed Dart VM Service client |
| `web_socket_channel` | core | WebSocket transport |
| `appium_driver` | core | App interaction (tap/scroll/type) |
| `dart_mcp` | cli | MCP server SDK |
| `args` | cli | CLI argument parsing |
