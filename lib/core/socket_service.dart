import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';

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

  // Pending queues — binary and text are kept separate because the server
  // expects raw PCM bytes (not JSON-wrapped) for audio frames.
  final List<Object> _pendingPayloads = []; // String (JSON) | Uint8List (PCM)

  // Broadcast stream for JSON messages only. Binary audio frames from the
  // server (TTS chunks) are delivered via the separate [audioChunks] stream.
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioController   = StreamController<Uint8List>.broadcast();

  Stream<Map<String, dynamic>> get messages    => _messageController.stream;
  Stream<Uint8List>            get audioChunks => _audioController.stream;

  // Per-event subscriptions registered via on().
  final Map<String, StreamSubscription> _eventSubs = {};

  SocketService({
    required this.url,
    this.authPayload = const {},
  });

  bool _isSocketOpen() => _socket != null && isWebSocketOpen(_socket);

  Future<void> connect() async {
    if (_isConnecting || _socket != null) return;
    _isConnecting = true;

    // Wire connectivity listener before the async gap to avoid race.
    _connSub ??=
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);

    try {
      _log('connecting to $url');
      _socket = await createWebSocket(url, authPayload);

      _socketSub = listenWebSocket(
        _socket,
        onMessage: (data) {
          // ── Binary frame: raw TTS audio from the server ──────────────────
          if (data is List<int> || data is Uint8List) {
            final bytes = data is Uint8List ? data : Uint8List.fromList(data as List<int>);
            if (bytes.isNotEmpty) {
              _audioController.add(bytes);
              _log('audio chunk received, bytes=${bytes.length}');
            }
            return;
          }

          // ── Text frame: JSON control message ─────────────────────────────
          final text = data is String ? data : jsonEncode(data);

          Map<String, dynamic> decoded;
          try {
            decoded = jsonDecode(text) as Map<String, dynamic>;
          } catch (_) {
            _log('non-json message ignored: $text');
            return;
          }

          // Handle server_ping internally — matches JS: ws.send({type:'pong'})
          if (decoded['type'] == 'server_ping') {
            _sendJson({'type': 'pong'});
            _log('sent pong');
            return;
          }

          _log('message: $text');
          _messageController.add(decoded);
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

      // JS client sends a ping immediately on open — mirror that behaviour.
      _sendJson({'type': 'ping'});

      _flushPending();
    } catch (e) {
      _log('connect_error: $e');
      _cleanup();
      _reconnect();
    } finally {
      _isConnecting = false;
    }
  }

  // ── Sending ────────────────────────────────────────────────────────────────

  /// Send a JSON control message — matches js: ws.send(JSON.stringify({...}))
  /// e.g. sendJson({'type': 'set_voice', 'voice': 'en-US-AriaNeural'})
  ///      sendJson({'type': 'interrupt'})
  ///      sendJson({'type': 'reset'})
  bool sendJson(Map<String, dynamic> payload) {
    return _sendOrQueue(payload);
  }

  /// Send raw PCM audio bytes — matches js: ws.send(pcm.buffer)
  /// Pass Int16 PCM at 16 kHz, mono, exactly as the JS client does.
  bool sendAudio(Uint8List pcmBytes) {
    return _sendOrQueue(pcmBytes);
  }

  /// Compatibility shim — landing_page.dart calls emitRaw(payload).
  /// Forwards to sendJson() with no wrapping; exact payload is sent as-is.
  bool emitRaw(Map<String, dynamic> payload) => sendJson(payload);

  // ── Event subscription ─────────────────────────────────────────────────────

  /// Listen for a specific message type from the server.
  /// e.g. on('status',      (msg) => setState(msg['text']))
  ///      on('transcript',  (msg) => showTranscript(msg['text']))
  ///      on('ai_stream',   (msg) => appendAI(msg['text']))
  ///      on('ai_done',     (msg) => handleDone(msg))
  ///      on('session_start',(msg) => applySession(msg))
  void on(String type, void Function(Map<String, dynamic>) handler) {
    _eventSubs[type]?.cancel();
    _eventSubs[type] = messages.listen((msg) {
      if (msg['type'] == type) handler(msg);
    });
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  void dispose() {
    _connSub?.cancel();
    _connSub = null;
    for (final sub in _eventSubs.values) sub.cancel();
    _eventSubs.clear();
    _cleanup();
    _messageController.close();
    _audioController.close();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _sendJson(Map<String, dynamic> payload) {
    _sendOrQueue(payload);
  }

  bool _sendOrQueue(Object payload) {
    // payload is either Map<String,dynamic> (JSON) or Uint8List (binary PCM).
    if (!_isSocketOpen()) {
      _pendingPayloads.add(payload);
      final label = payload is Uint8List ? 'audio(${payload.length}B)' : (payload as Map)['type'];
      _log('queued while disconnected: $label');
      return false;
    }

    try {
      if (payload is Uint8List) {
        sendBinaryWebSocket(_socket, payload);
        _log('sent audio, bytes=${payload.length}');
      } else {
        final encoded = jsonEncode(payload);
        sendWebSocket(_socket, encoded);
        _log('sent: $encoded');
      }
      return true;
    } catch (e) {
      _log('send failed, re-queuing: $e');
      _pendingPayloads.add(payload);
      return false;
    }
  }

  void _flushPending() {
    if (!_isSocketOpen() || _pendingPayloads.isEmpty) return;
    final toSend = List<Object>.from(_pendingPayloads);
    _pendingPayloads.clear();
    for (final payload in toSend) {
      try {
        if (payload is Uint8List) {
          sendBinaryWebSocket(_socket, payload);
        } else {
          sendWebSocket(_socket, jsonEncode(payload));
        }
      } catch (e) {
        _log('flush failed, re-queuing: $e');
        _pendingPayloads.add(payload);
      }
    }
    _log('flushed ${toSend.length} queued message(s)');
  }

  void _cleanup() {
    _socketSub?.cancel();
    _socketSub = null;
    final socketToClose = _socket;
    _socket = null;
    if (socketToClose != null) closeWebSocket(socketToClose);
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 2), () {
      if (_socket == null) {
        _log('attempting reconnect...');
        connect();
      }
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    if (result == ConnectivityResult.none) {
      _log('connectivity lost');
      _cleanup();
      return;
    }
    if (_socket == null) {
      _log('connectivity back, reconnecting...');
      connect();
    }
  }

  void _log(String msg) => print('[WebSocketService] $msg');
}