import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Lightweight Socket.IO wrapper. No UI changes needed; call connect() once.
class SocketService {
  final String url;
  final Map<String, dynamic> authPayload;
  IO.Socket? _socket;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  SocketService({
    required this.url,
    this.authPayload = const {},
  });

  IO.Socket? get socket => _socket;

  void connect() {
    // Avoid duplicate connections.
    if (_socket != null && _socket!.connected) return;

    final opts = IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableReconnection()
        .enableAutoConnect()
        .setAuth(authPayload)
        .build();

    _socket = IO.io(url, opts);

    _socket!
      ..onConnect((_) => _log('connected'))
      ..onConnectError((e) => _log('connect_error: $e'))
      ..onDisconnect((_) => _log('disconnected'))
      ..onReconnect((_) => _log('reconnected'))
      ..onError((e) => _log('error: $e'));

    _connSub ??=
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
  }

  void emit(String event, dynamic data) {
    final s = _socket;
    if (s == null || !s.connected) return;
    s.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _connSub?.cancel();
    _connSub = null;
  }

  void _log(String msg) {
    // Keep lightweight logging; replace with your logger if needed.
    // ignore: avoid_print
    print('[SocketService] $msg');
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    // Take the first result (Android/iOS emit single; Web may emit multiple).
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    if (result == ConnectivityResult.none) {
      _log('connectivity lost');
      _socket?.disconnect();
      return;
    }
    if (_socket != null && !_socket!.connected) {
      _log('connectivity back, attempting reconnect');
      _socket!.connect();
    }
  }
}
