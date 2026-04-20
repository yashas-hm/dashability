# Dashability Extensions

Optional in-app instrumentation helpers for [Dashability](https://pub.dev/packages/dashability).

Report custom interactions, metrics, screen changes, and arbitrary events from inside your Flutter app.
Dashability picks them up automatically via the VM Service logging stream.

**Zero external dependencies** - uses only `dart:developer`.

## Install

```yaml
dev_dependencies:
  dashability_extensions: ^1.0.2
```

## Usage

```dart
import 'package:dashability_extensions/dashability_extensions.dart';

// Report a user interaction.
DashabilityReporter.interaction('button_pressed');

// Report a custom metric.
DashabilityReporter.metric('items_loaded', 42);

// Report a screen/route change.
DashabilityReporter.screen('HomeScreen');

// Report a custom event with arbitrary data.
DashabilityReporter.event('purchase', {
  'item': 'widget_pack',
  'price': 9.99,
});
```

## API

| Method | Description |
|--------|-------------|
| `DashabilityReporter.interaction(action)` | Report a user interaction event |
| `DashabilityReporter.metric(name, value)` | Report a custom numeric metric |
| `DashabilityReporter.screen(name)` | Report a screen/route change |
| `DashabilityReporter.event(type, data)` | Report a custom event with arbitrary data |

All events are emitted via `dart:developer.postEvent` with `dashability.*` event kinds and are
automatically picked up by the Dashability MCP server when connected to your app.

## Requirements

- This is a companion package for [dashability](https://pub.dev/packages/dashability), the main CLI and MCP server.
- Dashability works fully without this package. This is optional for richer custom event reporting.
- Add as a `dev_dependency` so it is stripped from release builds.

