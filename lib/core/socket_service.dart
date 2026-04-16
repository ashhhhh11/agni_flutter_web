import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'websocket_stub.dart'
    if (dart.library.html) 'websocket_web.dart'
    if (dart.library.io) 'websocket_io.dart';

class SocketService {
  static const int _maxReconnectAttempts = 5;

  final String url;
  final Map<String, dynamic> authPayload;

  dynamic _socket;
  StreamSubscription? _socketSub;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _keepAliveTimer;

  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  Completer<void>? _connectCompleter;
  int _rxAudioChunkCount = 0;
  int _rxAudioBytesTotal = 0;
  int _txAudioChunkCount = 0;
  int _txAudioBytesTotal = 0;
  int _rxJsonCount = 0;
  int _txJsonCount = 0;
  static const Duration _keepAliveInterval = Duration(seconds: 12);

  // Pending queues — binary and text are kept separate because the server
  // expects raw PCM bytes (not JSON-wrapped) for audio frames.
  final List<Object> _pendingPayloads = []; // String (JSON) | Uint8List (PCM)

  // Broadcast stream for JSON messages only. Binary audio frames from the
  // server (TTS chunks) are delivered via the separate [audioChunks] stream.
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<Uint8List> get audioChunks => _audioController.stream;

  // Per-event subscriptions registered via on().
  final Map<String, StreamSubscription> _eventSubs = {};

  // ── Public connection state ────────────────────────────────────────────────

  /// True when the underlying WebSocket is open and ready to send/receive.
  bool get isConnected => _isSocketOpen();

  /// True while a connection attempt is in progress (before open or failure).
  bool get isConnecting => _isConnecting;

  /// True when the socket has given up reconnecting after [_maxReconnectAttempts].
  bool get isReconnectExhausted => _reconnectAttempts >= _maxReconnectAttempts;

  /// Current reconnect attempt count (0 when connected cleanly).
  int get reconnectAttempts => _reconnectAttempts;

  SocketService({
    required String url,
    this.authPayload = const {},
  }) : url = _normalizeWebSocketUrl(url);

  static String _normalizeWebSocketUrl(String rawUrl) {
    final trimmed = rawUrl.trim();

    if (trimmed.startsWith('ws://https://')) {
      return 'wss://${trimmed.substring('ws://https://'.length)}';
    }
    if (trimmed.startsWith('ws://http://')) {
      return 'ws://${trimmed.substring('ws://http://'.length)}';
    }
    if (trimmed.startsWith('https://')) {
      return 'wss://${trimmed.substring('https://'.length)}';
    }
    if (trimmed.startsWith('http://')) {
      return 'ws://${trimmed.substring('http://'.length)}';
    }

    return trimmed;
  }

  bool _isSocketOpen() => _socket != null && isWebSocketOpen(_socket);

  Future<void> connect() async {
    if (_socket != null && _isSocketOpen()) return;
    if (_isConnecting) {
      await _connectCompleter?.future;
      return;
    }
    _isConnecting = true;
    _connectCompleter = Completer<void>();

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
            final bytes = data is Uint8List
                ? data
                : Uint8List.fromList(data as List<int>);
            if (bytes.isNotEmpty) {
              _rxAudioChunkCount += 1;
              _rxAudioBytesTotal += bytes.length;
              _audioController.add(bytes);
              _log(
                'audio chunk received '
                '#$_rxAudioChunkCount bytes=${bytes.length} '
                'total=$_rxAudioBytesTotal',
              );
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
          _rxJsonCount += 1;

          // Handle server_ping internally — matches JS: ws.send({type:'pong'})
          if (decoded['type'] == 'server_ping') {
            _sendJson({'type': 'pong'});
            _log('sent pong');
            return;
          }

          final msgType = decoded['type']?.toString() ?? 'unknown';
          final latency = decoded['latency'];
          _log(
            'message[$_rxJsonCount] type=$msgType '
            'keys=${decoded.keys.join(",")} '
            'latency=${latency is Map ? jsonEncode(latency) : "n/a"}',
          );
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
      _reconnectAttempts = 0;
      _connectCompleter?.complete();
      _startKeepAlive();

      // JS client sends a ping immediately on open — mirror that behaviour.
      _sendJson({'type': 'ping'});

      _flushPending();
    } catch (e) {
      _log('connect_error: $e');
      _cleanup();
      if (!(_connectCompleter?.isCompleted ?? true)) {
        _connectCompleter?.completeError(e);
      }
      _reconnect();
    } finally {
      _isConnecting = false;
      _connectCompleter = null;
    }
  }

  Future<bool> waitUntilConnected({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (isConnected) return true;
    await connect();
    if (isConnected) return true;

    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (isConnected) {
        return true;
      }
    }
    return isConnected;
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
    for (final sub in _eventSubs.values) {
      sub.cancel();
    }
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
      final label = payload is Uint8List
          ? 'audio(${payload.length}B)'
          : (payload as Map)['type'];
      _log(
        'queued while disconnected: $label '
        '(pending=${_pendingPayloads.length})',
      );
      return false;
    }

    try {
      if (payload is Uint8List) {
        sendBinaryWebSocket(_socket, payload);
        _txAudioChunkCount += 1;
        _txAudioBytesTotal += payload.length;
        _log(
          'sent audio chunk '
          '#$_txAudioChunkCount bytes=${payload.length} '
          'total=$_txAudioBytesTotal',
        );
      } else {
        final encoded = jsonEncode(payload);
        sendWebSocket(_socket, encoded);
        _txJsonCount += 1;
        final type = payload is Map ? payload['type'] : null;
        _log(
          'sent json[$_txJsonCount] type=${type ?? "unknown"} '
          'payload=${_preview(encoded)}',
        );
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
          _txAudioChunkCount += 1;
          _txAudioBytesTotal += payload.length;
          _log(
            'flushed audio chunk '
            '#$_txAudioChunkCount bytes=${payload.length} '
            'total=$_txAudioBytesTotal',
          );
        } else {
          final encoded = jsonEncode(payload);
          sendWebSocket(_socket, encoded);
          _txJsonCount += 1;
          final type = payload is Map ? payload['type'] : null;
          _log(
            'flushed json[$_txJsonCount] type=${type ?? "unknown"} '
            'payload=${_preview(encoded)}',
          );
        }
      } catch (e) {
        _log('flush failed, re-queuing: $e');
        _pendingPayloads.add(payload);
      }
    }
    _log('flushed ${toSend.length} queued message(s)');
  }

  void _cleanup() {
    _stopKeepAlive();
    _socketSub?.cancel();
    _socketSub = null;
    final socketToClose = _socket;
    _socket = null;
    if (socketToClose != null) closeWebSocket(socketToClose);
  }

  void _reconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log(
        'stopped reconnecting after $_maxReconnectAttempts failed attempt(s); '
        'check backend websocket URL/path: $url',
      );
      return;
    }

    _reconnectAttempts += 1;
    final delaySeconds = 2 * _reconnectAttempts;
    _log(
      'scheduling reconnect in ${delaySeconds}s '
      '(${_reconnectAttempts}/$_maxReconnectAttempts)',
    );
    Future.delayed(Duration(seconds: delaySeconds), () {
      if (_socket == null) {
        _log('attempting reconnect '
            '($_reconnectAttempts/$_maxReconnectAttempts)...');
        connect();
      }
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _log('connectivity event: $result');
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

  void _log(String msg) => debugPrint('[WebSocketService] $msg');

  void _startKeepAlive() {
    _stopKeepAlive();
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (_) {
      if (!_isSocketOpen()) return;
      _sendJson({'type': 'ping'});
      _log('keepalive ping sent');
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  String _preview(String value, {int limit = 220}) {
    final normalized = value.replaceAll('\n', ' ');
    if (normalized.length <= limit) return normalized;
    return '${normalized.substring(0, limit)}...';
  }
}