import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

Future<WebSocket> createWebSocket(
    String url, Map<String, dynamic> authPayload) async {
  return WebSocket.connect(url);
}

StreamSubscription<dynamic> listenWebSocket(
  dynamic socket, {
  required void Function(dynamic) onMessage,
  required void Function() onDone,
  required void Function(dynamic) onError,
}) {
  return (socket as WebSocket).listen(
    (data) {
      // Deliver raw — either String or List<int> (binary TTS audio).
      if (data is List<int>) {
        onMessage(Uint8List.fromList(data));
      } else {
        onMessage(data);
      }
    },
    onDone: onDone,
    onError: onError,
    cancelOnError: true,
  );
}

/// Send a JSON text frame.
void sendWebSocket(dynamic socket, String data) {
  (socket as WebSocket).add(data);
}

/// Send raw binary frame (PCM audio to server).
void sendBinaryWebSocket(dynamic socket, Uint8List bytes) {
  (socket as WebSocket).add(bytes);
}

void closeWebSocket(dynamic socket) {
  if (socket != null) (socket as WebSocket).close();
}

bool isWebSocketOpen(dynamic socket) {
  return socket != null &&
      (socket as WebSocket).readyState == WebSocket.open;
}