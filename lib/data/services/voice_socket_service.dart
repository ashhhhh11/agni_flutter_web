import 'dart:async';
import 'dart:typed_data';

import '../../core/socket_service.dart';
import 'audio_record_service.dart';

class VoiceSocketService {
  final SocketService _socket;

  VoiceSocketService(this._socket);

  bool get isConnected => _socket.isConnected;
  bool get isConnecting => _socket.isConnecting;
  bool get isReconnectExhausted => _socket.isReconnectExhausted;

  Stream<Map<String, dynamic>> get messages => _socket.messages;
  Stream<Uint8List> get audioChunks => _socket.audioChunks;

  Stream<Map<String, dynamic>> messagesOfType(String type) =>
      messages.where((message) => message['type'] == type);

  Stream<String> get partialTranscripts => messages
      .where((message) {
        final type = message['type']?.toString();
        return type == 'partial' ||
            type == 'transcript_partial' ||
            type == 'partial_transcript';
      })
      .map((message) => message['text']?.toString() ?? '')
      .where((text) => text.isNotEmpty);

  Stream<String> get finalTranscripts => messages
      .where((message) {
        final type = message['type']?.toString();
        return type == 'transcript' ||
            type == 'final_transcript' ||
            type == 'user_transcript';
      })
      .map((message) => message['text']?.toString() ?? '')
      .where((text) => text.isNotEmpty);

  Stream<String> get assistantTextStream => messages
      .where((message) {
        final type = message['type']?.toString();
        return type == 'ai_stream' ||
            type == 'assistant_text' ||
            type == 'response_text_delta';
      })
      .map((message) => message['text']?.toString() ?? '')
      .where((text) => text.isNotEmpty);

  Stream<Map<String, dynamic>> get completionEvents => messages.where(
        (message) {
          final type = message['type']?.toString();
          return type == 'ai_done' ||
              type == 'response_done' ||
              type == 'assistant_done';
        },
      );

  Stream<Map<String, dynamic>> get statusEvents => messages.where(
        (message) => message['type'] == 'status',
      );

  Stream<Map<String, dynamic>> get errorEvents => messages.where(
        (message) => message['type'] == 'error',
      );

  Future<void> connect() => _socket.connect();

  Future<bool> ensureConnected({
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _socket.waitUntilConnected(timeout: timeout);

  bool sendAudioChunk(AudioChunk chunk) => _socket.sendAudio(chunk.bytes);

  bool sendAudioFrame(Uint8List audioFrame) => _socket.sendAudio(audioFrame);

  bool sendControlMessage(String type, [Map<String, dynamic>? extra]) {
    final payload = <String, dynamic>{'type': type};
    if (extra != null) {
      payload.addAll(extra);
    }
    return _socket.sendJson(payload);
  }

  void sendInterrupt() {
    sendControlMessage('interrupt');
  }

  void sendTurnStarted() {
    sendControlMessage('speech_start');
  }

  void sendEndOfInput({
    String? transcriptHint,
    Duration? speechDuration,
  }) {
    final base = <String, dynamic>{
      if (transcriptHint != null && transcriptHint.trim().isNotEmpty)
        'text': transcriptHint.trim(),
      if (speechDuration != null) 'duration_ms': speechDuration.inMilliseconds,
    };

    sendControlMessage('speech_end', base);
    sendControlMessage('done', base);
    sendControlMessage('end_of_stream', base);
  }

  void requestAssistantResponse({String? transcriptHint}) {
    final cleanedHint = transcriptHint?.trim();
    final payload = <String, dynamic>{
      if (cleanedHint != null && cleanedHint.isNotEmpty) 'text': cleanedHint,
    };

    if (payload.isNotEmpty) {
      sendControlMessage('transcript', payload);
    }
    sendControlMessage('generate_response', payload);
  }

  void on(String type, void Function(Map<String, dynamic>) handler) {
    _socket.on(type, handler);
  }

  void dispose() {
    // Socket lifecycle stays with the shared app-level SocketService.
  }
}
