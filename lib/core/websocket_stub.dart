import 'dart:async';
import 'dart:typed_data';

dynamic createWebSocket(String url, Map<String, dynamic> authPayload) =>
    throw UnsupportedError('No WebSocket implementation for this platform.');

StreamSubscription listenWebSocket(dynamic socket,
        {required void Function(dynamic) onMessage,
        required void Function() onDone,
        required void Function(dynamic) onError}) =>
    throw UnsupportedError('No WebSocket implementation for this platform.');

void sendWebSocket(dynamic socket, String data) =>
    throw UnsupportedError('No WebSocket implementation for this platform.');

void sendBinaryWebSocket(dynamic socket, Uint8List bytes) =>
    throw UnsupportedError('No WebSocket implementation for this platform.');

void closeWebSocket(dynamic socket) =>
    throw UnsupportedError('No WebSocket implementation for this platform.');

bool isWebSocketOpen(dynamic socket) =>
    throw UnsupportedError('No WebSocket implementation for this platform.');
