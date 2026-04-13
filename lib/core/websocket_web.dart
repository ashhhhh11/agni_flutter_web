// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Waits until the socket is fully OPEN before returning.
Future<html.WebSocket> createWebSocket(
    String url, Map<String, dynamic> authPayload) async {
  final completer = Completer<html.WebSocket>();
  final socket = html.WebSocket(url);
  socket.binaryType = 'arraybuffer';

  late StreamSubscription openSub;
  late StreamSubscription errorSub;

  openSub = socket.onOpen.listen((_) {
    openSub.cancel();
    errorSub.cancel();
    if (!completer.isCompleted) completer.complete(socket);
  });

  errorSub = socket.onError.listen((event) {
    openSub.cancel();
    errorSub.cancel();
    if (!completer.isCompleted)
      completer.completeError(Exception('WebSocket failed to connect to $url'));
  });

  return completer.future;
}

StreamSubscription<dynamic> listenWebSocket(
  dynamic socket, {
  required void Function(dynamic) onMessage,
  required void Function() onDone,
  required void Function(dynamic) onError,
}) {
  final ws = socket as html.WebSocket;
  ws.onClose.listen((_) => onDone());
  ws.onError.listen((e) => onError(e));

  return ws.onMessage.listen((event) {
    final data = event.data;
    // Use ByteBuffer from dart:typed_data — html.ByteBuffer is invalid in DDC.
    if (data is ByteBuffer) {
      onMessage(Uint8List.view(data));
    } else {
      onMessage(data); // String
    }
  });
}

/// Send a JSON text frame.
void sendWebSocket(dynamic socket, String data) {
  (socket as html.WebSocket).send(data);
}

/// Send raw binary frame (PCM audio to server).
void sendBinaryWebSocket(dynamic socket, Uint8List bytes) {
  (socket as html.WebSocket).send(bytes.buffer);
}

void closeWebSocket(dynamic socket) {
  if (socket != null) (socket as html.WebSocket).close();
}

bool isWebSocketOpen(dynamic socket) {
  return socket != null &&
      (socket as html.WebSocket).readyState == html.WebSocket.OPEN;
}