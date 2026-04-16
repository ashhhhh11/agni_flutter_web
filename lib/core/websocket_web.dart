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
      return;
    }
    if (data is html.Blob) {
      unawaited(
        _readBlobBytes(data).then(onMessage).catchError(onError),
      );
      return;
    }
    if (data is String) {
      onMessage(data);
      return;
    }

    print(
      '[websocket_web] unexpected message type: ${data.runtimeType}',
    );
    onMessage(data);
  });
}

Future<Uint8List> _readBlobBytes(html.Blob blob) {
  final reader = html.FileReader();
  final completer = Completer<Uint8List>();

  late final StreamSubscription loadEndSub;
  late final StreamSubscription errorSub;

  void cleanup() {
    loadEndSub.cancel();
    errorSub.cancel();
  }

  loadEndSub = reader.onLoadEnd.listen((_) {
    cleanup();
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
      return;
    }
    if (result is Uint8List) {
      completer.complete(result);
      return;
    }
    completer.completeError(
      StateError('WebSocket Blob read returned ${result.runtimeType}.'),
    );
  });

  errorSub = reader.onError.listen((_) {
    cleanup();
    completer.completeError(
      StateError('Failed to read WebSocket binary blob.'),
    );
  });

  reader.readAsArrayBuffer(blob);
  return completer.future;
}

/// Send a JSON text frame.
void sendWebSocket(dynamic socket, String data) {
  (socket as html.WebSocket).send(data);
}

/// Send raw binary frame (PCM audio to server).
void sendBinaryWebSocket(dynamic socket, Uint8List bytes) {
  final ws = socket as html.WebSocket;
  final payload = bytes.offsetInBytes == 0 &&
          bytes.lengthInBytes == bytes.buffer.lengthInBytes
      ? bytes
      : Uint8List.sublistView(bytes);

  ws.send(html.Blob(<Object>[payload]));
}

void closeWebSocket(dynamic socket) {
  if (socket != null) (socket as html.WebSocket).close();
}

bool isWebSocketOpen(dynamic socket) {
  return socket != null &&
      (socket as html.WebSocket).readyState == html.WebSocket.OPEN;
}
