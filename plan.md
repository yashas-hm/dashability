# Dashability MVP Implementation Plan

## Overview

A **monorepo** containing multiple packages that together form an AI Observability Layer for Flutter (and eventually other) apps. The system connects externally to a running app, monitors performance/errors in real-time, detects anomalies locally, and exposes structured observation + action tools via MCP.

## Key Architectural Decisions

1. **Standalone external tool** — never runs inside the target app process. Zero coupling.
2. **Monorepo with separate packages** — clean separation of concerns, each package publishable independently.
3. **Core is framework-agnostic** — connectors are pluggable, enabling multi-SDK support.

### Usage Flow

```
1. flutter run --profile              → app starts, prints VM Service URI
2. dashability --uri ws://...         → connects, starts MCP server on stdio
3. AI host (Claude, etc.) uses MCP    → full observation + action loop
```

## Monorepo Structure

```
dashability/
├── packages/
│   ├── dashability_core/             # Engine: connectors, observers, analysis, actions
│   │   ├── lib/
│   │   │   ├── dashability_core.dart
│   │   │   └── src/
│   │   │       ├── connector/
│   │   │       │   ├── connector.dart           # Abstract connector interface
│   │   │       │   └── flutter/
│   │   │       │       └── flutter_connector.dart  # VM Service implementation
│   │   │       ├── observers/
│   │   │       │   ├── observer.dart             # Abstract observer interface
│   │   │       │   ├── frame_observer.dart       # FPS, jank detection
│   │   │       │   ├── log_observer.dart         # Logs & errors
│   │   │       │   ├── rebuild_observer.dart     # Widget rebuild tracking
│   │   │       │   └── observer_manager.dart     # Lifecycle, stream aggregation
│   │   │       ├── analysis/
│   │   │       │   ├── anomaly_detector.dart     # Tier 1 rule-based detection
│   │   │       │   ├── context_compressor.dart   # Raw signals → structured events
│   │   │       │   └── event_types.dart          # Typed event models
│   │   │       └── actions/
│   │   │           └── appium_actor.dart         # Appium: tap, scroll, type
│   │   ├── test/
│   │   └── pubspec.yaml
│   │
│   ├── dashability_cli/              # CLI + MCP server — user-facing entry point
│   │   ├── bin/
│   │   │   └── dashability.dart      # CLI entry point
│   │   ├── lib/
│   │   │   └── src/
│   │   │       └── mcp/
│   │   │           ├── server.dart             # MCP server setup, tool registration
│   │   │           ├── observation_tools.dart   # get_current_metrics, get_logs, etc.
│   │   │           ├── action_tools.dart        # tap, scroll, type
│   │   │           └── validation_tools.dart    # assert_visible
│   │   ├── test/
│   │   └── pubspec.yaml              # depends on dashability_core
│   │
│   └── dashability_helper/           # Optional tiny Dart package for in-app instrumentation
│       ├── lib/
│       │   ├── dashability_helper.dart
│       │   └── src/
│       │       └── reporter.dart     # Convenience wrappers around developer.postEvent
│       ├── test/
│       └── pubspec.yaml              # Zero external dependencies, pure dart:developer
│
├── example/                          # Demo Flutter app with deliberate jank
│   ├── lib/
│   │   └── main.dart
│   └── pubspec.yaml                  # Standalone Flutter app, optionally uses dashability_helper
│
├── plan.md
├── idea.md
└── README.md
```

## Package Responsibilities

### `dashability_core`
The engine. Framework-agnostic analysis + pluggable connectors.

**Dependencies:**
```yaml
dependencies:
  vm_service: ^15.0.2
  appium_driver: ^0.7.1
  web_socket_channel: ^3.0.0
dev_dependencies:
  test: ^1.25.0
  lints: ^5.0.0
```

**No Flutter SDK. No MCP. Pure Dart.**

### `dashability_cli`
The user-facing tool. Wires core into an MCP server with a CLI interface.

**Dependencies:**
```yaml
dependencies:
  dashability_core:
    path: ../dashability_core
  dart_mcp: ^0.5.0
  args: ^2.5.0
dev_dependencies:
  test: ^1.25.0
  lints: ^5.0.0

executables:
  dashability: dashability
```

Installed via `dart pub global activate dashability_cli` or compiled to native binary.

### `dashability_helper`
Optional. Tiny package users can add as `dev_dependency` to their Flutter app for richer custom events.

**Dependencies:**
```yaml
dependencies: {}  # Zero — only uses dart:developer
```

Provides convenience like:
```dart
import 'package:dashability_helper/dashability_helper.dart';

DashabilityReporter.interaction('user_drew_stroke');
DashabilityReporter.metric('canvas_points', 1523);
```

This is strictly optional — dashability works fully without it.

## Implementation Steps

### Step 1: Monorepo Setup
- Create `packages/dashability_core/`, `packages/dashability_cli/`, `packages/dashability_helper/`
- Set up each `pubspec.yaml` with correct dependencies and path references
- Clean out current placeholder code (`Calculator` class, etc.)
- Move `example/` to root level as standalone Flutter app

### Step 2: Core — Connector Interface & Flutter Connector
- **Abstract `Connector`**: defines `connect(uri)`, `disconnect()`, exposes service instance and isolate info
- **`FlutterConnector`** (implements `Connector`):
  - Accepts VM Service URI (`ws://127.0.0.1:xxxxx/ws`)
  - Connects via `vm_service` over WebSocket
  - Resolves main isolate ID automatically
  - Handles disconnect/reconnection
- **`Config`**: tunable thresholds
  - `jankThresholdMs` (default: 16.67ms — 60fps budget)
  - `rebuildSpikeThreshold` (default: 50 rebuilds/sec)
  - `batchWindowMs` (default: 5000ms for smart batching)

### Step 3: Core — Observers
- **Abstract `Observer`**: defines `start()`, `stop()`, `Stream<ObservationEvent> get events`
- **`FrameObserver`**: subscribes to `onTimelineEvent`, tracks frame build/render times, computes rolling FPS, flags jank
- **`LogObserver`**: subscribes to `onLoggingEvent` + `onStdoutEvent` + `onStderrEvent`, categorizes by level
- **`RebuildObserver`**: polls `ext.flutter.inspector` extensions for widget rebuild counts, identifies hot widgets
- **`ObserverManager`**: starts/stops all observers, merges into single `Stream<ObservationEvent>`

### Step 4: Core — Analysis
- **Event types**: `FrameDrop`, `RebuildSpike`, `ErrorCaught`, `PerformanceDegradation` — typed models with `toJson()`
- **`AnomalyDetector`** (Tier 1 rule-based):
  - Frame drop: FPS below threshold for N consecutive frames
  - Rebuild spike: rebuild count exceeds threshold in window
  - Error: any uncaught exception or error-level log
- **`ContextCompressor`**: transforms raw data into token-efficient structured JSON
- Smart batching: aggregates events within `batchWindowMs` into single combined context

### Step 5: Core — Appium Actions
- **`AppiumActor`**:
  - Connects to Appium server (configurable URL, default `http://localhost:4723`)
  - `tap({String? text, String? id})`, `scroll({String direction})`, `type({String field, String value})`
  - `launchApp()`, `closeApp()`
  - Uses `AppiumFlutterFinder` for Flutter-specific element location
  - Gracefully optional — observation works without Appium

### Step 6: CLI — MCP Server
- **`DashabilityServer`** extends `dart_mcp` server with `ToolsSupport`
- Observation tools: `get_current_metrics`, `get_recent_frames`, `get_widget_hotspots`, `get_logs`, `get_anomalies`
- Action tools (when Appium available): `tap`, `scroll`, `type`
- Validation tools: `assert_visible`
- Stdio transport

### Step 7: CLI — Entry Point
- `bin/dashability.dart` with `args` parsing:
  - `--uri` (required) — VM Service WebSocket URI
  - `--appium-url` (optional) — enables action tools
  - `--profile` (flag) — preset thresholds for profile mode
- Wires: FlutterConnector → ObserverManager → AnomalyDetector → MCP Server

### Step 8: Helper Package
- `DashabilityReporter` class with static methods:
  - `interaction(String action)` — posts `ai.interaction` event
  - `metric(String name, num value)` — posts `ai.metric` event
  - `screen(String name)` — posts `ai.screen` event
- All implemented via `dart:developer.postEvent` — zero dependencies

### Step 9: Example App
- Standalone Flutter app at root `example/`
- Deliberately janky widgets for demo:
  - Heavy rebuild widget (setState every frame)
  - Janky scroll list
- Optional `dashability_helper` usage for custom events
- README: how to run, get VM Service URI, connect dashability

## Multi-SDK Extensibility

Adding a new framework connector (e.g. React Native via Chrome DevTools Protocol):

1. Create `packages/dashability_core/lib/src/connector/react_native/rn_connector.dart`
2. Implement the abstract `Connector` interface
3. Add framework-specific observers implementing the `Observer` interface
4. CLI auto-detects or accepts `--framework flutter|rn|swift` flag

The analysis, MCP, and action layers require **zero changes**.

## Verification

1. **Unit tests** (`dashability_core`): anomaly detection, context compression, event types, connector mocks
2. **Unit tests** (`dashability_cli`): MCP tool registration, argument parsing
3. **Integration test**: connect to example app's VM Service, call observation tools, verify output
4. **End-to-end**: MCP host → dashability CLI → running Flutter app → structured observations
5. **Compile test**: `dart compile exe packages/dashability_cli/bin/dashability.dart`
