Future<dynamic> createWebSocket(String url, Map<String, dynamic> auth) {
  throw UnsupportedError('WebSocket not supported');
}

dynamic listenWebSocket(
  dynamic socket, {
  required Function(dynamic) onMessage,
  required Function() onDone,
  required Function(dynamic) onError,
}) {}

void sendWebSocket(dynamic socket, String data) {}

void closeWebSocket(dynamic socket) {}
