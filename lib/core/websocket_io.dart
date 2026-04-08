import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<dynamic> createWebSocket(String url, Map<String, dynamic> auth) async {
  return await WebSocket.connect(
    url,
    headers: auth.isNotEmpty ? {"Authorization": jsonEncode(auth)} : null,
  );
}

StreamSubscription listenWebSocket(
  dynamic socket, {
  required Function(dynamic) onMessage,
  required Function() onDone,
  required Function(dynamic) onError,
}) {
  return socket.listen(onMessage, onDone: onDone, onError: onError);
}

void sendWebSocket(dynamic socket, String data) {
  socket.add(data);
}

void closeWebSocket(dynamic socket) {
  socket?.close();
}
