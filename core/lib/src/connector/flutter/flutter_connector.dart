import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:dashability_core/src/connector/connector.dart';

/// Connects to a running Flutter app via the Dart VM Service WebSocket.
class FlutterConnector implements Connector {
  VmService? _service;
  String? _mainIsolateId;
  WebSocketChannel? _channel;

  ConnectorState _state = ConnectorState.disconnected;
  final _stateController = StreamController<ConnectorState>.broadcast();

  @override
  ConnectorState get state => _state;

  @override
  Stream<ConnectorState> get onStateChange => _stateController.stream;

  @override
  VmService get service {
    if (_service == null) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _service!;
  }

  @override
  String get mainIsolateId {
    if (_mainIsolateId == null) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _mainIsolateId!;
  }

  void _setState(ConnectorState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  @override
  Future<void> connect(Uri uri) async {
    if (_state == ConnectorState.connected) {
      await disconnect();
    }

    _setState(ConnectorState.connecting);

    try {
      // Ensure WebSocket scheme.
      final wsUri = uri.replace(
        scheme: uri.scheme == 'http' ? 'ws' : uri.scheme == 'https' ? 'wss' : uri.scheme,
      );

      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;

      _service = VmService(
        _channel!.stream.cast<String>(),
        (String message) => _channel!.sink.add(message),
      );

      // Resolve the main isolate.
      _mainIsolateId = await _resolveMainIsolate();

      _setState(ConnectorState.connected);

      // Listen for disconnect.
      _channel!.stream.handleError((_) async {
        await disconnect();
      });
    } catch (e) {
      _setState(ConnectorState.disconnected);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _setState(ConnectorState.disconnected);
    await _service?.dispose();
    _service = null;
    _mainIsolateId = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<Map<String, dynamic>> callServiceExtension(
    String method, {
    String? isolateId,
    Map<String, String>? args,
  }) async {
    final response = await service.callServiceExtension(
      method,
      isolateId: isolateId ?? mainIsolateId,
      args: args,
    );
    return response.json ?? {};
  }

  Future<String> _resolveMainIsolate() async {
    final vm = await _service!.getVM();
    final isolates = vm.isolates;
    if (isolates == null || isolates.isEmpty) {
      throw StateError('No isolates found in the connected VM.');
    }

    // Prefer the isolate named 'main' or the first one.
    for (final isolate in isolates) {
      if (isolate.name == 'main') {
        return isolate.id!;
      }
    }
    return isolates.first.id!;
  }
}
