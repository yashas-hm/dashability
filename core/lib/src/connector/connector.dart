import 'dart:async';

import 'package:vm_service/vm_service.dart';

/// Connection state of a connector.
enum ConnectorState { disconnected, connecting, connected }

/// Abstract interface for framework-specific connectors.
///
/// Each supported framework (Flutter, React Native, etc.) implements this
/// interface to provide access to its debugging/profiling services.
abstract class Connector {
  /// Current connection state.
  ConnectorState get state;

  /// Stream of state changes.
  Stream<ConnectorState> get onStateChange;

  /// The underlying VM Service instance (Flutter-specific, but exposed
  /// generically so observers can use it).
  VmService get service;

  /// The main isolate ID of the connected app.
  String get mainIsolateId;

  /// Connect to a running app at the given [uri].
  Future<void> connect(Uri uri);

  /// Disconnect from the app.
  Future<void> disconnect();

  /// Call a service extension on the connected app.
  Future<Map<String, dynamic>> callServiceExtension(
    String method, {
    String? isolateId,
    Map<String, String>? args,
  });
}
