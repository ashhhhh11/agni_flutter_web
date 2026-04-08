import 'dart:async';
import 'dart:html';

Future<dynamic> createWebSocket(String url, Map<String, dynamic> auth) async {
  final socket = WebSocket(url);

  await socket.onOpen.first; // wait until connected
  return socket;
}

StreamSubscription listenWebSocket(
  dynamic socket, {
  required Function(dynamic) onMessage,
  required Function() onDone,
  required Function(dynamic) onError,
}) {
  socket.onMessage.listen((event) {
    onMessage(event.data);
  });

  socket.onClose.listen((_) {
    onDone();
  });

  socket.onError.listen((error) {
    onError(error);
  });

  return const Stream.empty().listen((_) {});
}

void sendWebSocket(dynamic socket, String data) {
  socket.send(data);
}

void closeWebSocket(dynamic socket) {
  socket.close();
}
