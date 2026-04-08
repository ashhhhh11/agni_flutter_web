import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Conditional imports
import 'websocket_stub.dart'
    if (dart.library.html) 'websocket_web.dart'
    if (dart.library.io) 'websocket_io.dart';

class SocketService {
  final String url;
  final Map<String, dynamic> authPayload;

  dynamic _socket;
  StreamSubscription? _socketSub;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  bool _isConnecting = false;

  final _messageController = StreamController<dynamic>.broadcast();

  Stream<dynamic> get messages => _messageController.stream;

  SocketService({
    required this.url,
    this.authPayload = const {},
  });

  Future<void> connect() async {
    if (_isConnecting || _socket != null) return;

    _isConnecting = true;

    try {
      _log('connecting to $url');

      _socket = await createWebSocket(url, authPayload);

      _socketSub = listenWebSocket(
        _socket,
        onMessage: (data) {
          _log('message: $data');
          _messageController.add(data);
        },
        onDone: () {
          _log('disconnected');
          _cleanup();
          _reconnect();
        },
        onError: (e) {
          _log('error: $e');
          _cleanup();
          _reconnect();
        },
      );

      _log('connected');
    } catch (e) {
      _log('connect_error: $e');
      _cleanup();
      _reconnect();
    }

    _isConnecting = false;

    _connSub ??=
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
  }

  void emit(String event, dynamic data) {
    if (_socket == null) return;

    final payload = jsonEncode({
      "event": event,
      "data": data,
    });

    sendWebSocket(_socket, payload);
  }

  void on(String event, Function(dynamic) handler) {
    messages.listen((msg) {
      try {
        final decoded = jsonDecode(msg);
        if (decoded["event"] == event) {
          handler(decoded["data"]);
        }
      } catch (_) {}
    });
  }

  void dispose() {
    closeWebSocket(_socket);
    _cleanup();
    _connSub?.cancel();
  }

  void _cleanup() {
    _socketSub?.cancel();
    _socketSub = null;
    _socket = null;
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_socket == null) {
        _log('attempting reconnect...');
        connect();
      }
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final result =
        results.isNotEmpty ? results.first : ConnectivityResult.none;

    if (result == ConnectivityResult.none) {
      _log('connectivity lost');
      closeWebSocket(_socket);
      _cleanup();
    } else {
      if (_socket == null) {
        _log('connectivity back, reconnecting...');
        connect();
      }
    }
  }

  void _log(String msg) {
    print('[WebSocketService] $msg');
  }
}