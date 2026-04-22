import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/socket_service.dart';
import '../../data/services/audio_playback_service.dart';
import '../../data/services/audio_record_service.dart';
import '../../data/services/silence_detector.dart';
import '../../data/services/voice_socket_service.dart';

enum VoiceChatState { idle, listening, processing, playing, error }

class ChatMessage {
  final String id;
  final String source;
  final String text;
  final bool isPartial;

  ChatMessage({
    required this.id,
    required this.source,
    required this.text,
    this.isPartial = false,
  });

  ChatMessage copyWith({
    String? text,
    bool? isPartial,
  }) {
    return ChatMessage(
      id: id,
      source: source,
      text: text ?? this.text,
      isPartial: isPartial ?? this.isPartial,
    );
  }
}

class VoiceChatController extends ChangeNotifier {
  static const bool _preferAssistantTextToSpeech = true;

  final AudioRecordService _recordService;
  final AudioPlaybackService _playbackService;
  final VoiceSocketService _socketService;
  final SilenceDetector _silenceDetector;
  final AudioRecordConfig _recordConfig;
  final Duration _processingTimeout;

  final List<ChatMessage> _messages = <ChatMessage>[];
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  VoiceChatState _state = VoiceChatState.idle;
  Timer? _processingTimeoutTimer;
  String? _currentUserTurnId;
  String? _currentAiTurnId;
  String _latestTranscriptText = '';
  String _latestAssistantText = '';
  String? _lastError;
  DateTime? _listeningStartedAt;
  bool _assistantAudioReceivedForTurn = false;
  bool _isStoppingOrSending = false;
  bool _disposed = false;

  VoiceChatController({
    required SocketService socketService,
    AudioRecordService? recordService,
    AudioPlaybackService? playbackService,
    SilenceDetector? silenceDetector,
    AudioRecordConfig recordConfig = const AudioRecordConfig(),
    Duration processingTimeout = const Duration(seconds: 20),
  })  : _recordService = recordService ?? AudioRecordService(),
        _playbackService = playbackService ?? AudioPlaybackService(),
        _silenceDetector = silenceDetector ??
            SilenceDetector(
              threshold: 0.015,
              silenceDuration: const Duration(milliseconds: 1800),
              minActiveListening: const Duration(milliseconds: 1200),
            ),
        _recordConfig = recordConfig,
        _processingTimeout = processingTimeout,
        _socketService = VoiceSocketService(socketService) {
    _bindStreams();
    _silenceDetector.onSilenceDetected = null;
  }

  VoiceChatState get state => _state;
  bool get isListening => _state == VoiceChatState.listening;
  bool get isProcessing => _state == VoiceChatState.processing;
  bool get isPlaying => _state == VoiceChatState.playing;
  bool get canStartListening =>
      _state == VoiceChatState.idle ||
      _state == VoiceChatState.playing ||
      _state == VoiceChatState.error;
  bool get isMicSupported => _recordService.isSupported;
  String get liveTranscript => _latestTranscriptText;
  String? get lastError => _lastError;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void _bindStreams() {
    _subscriptions
        .add(_recordService.volumeStream.listen(_silenceDetector.updateVolume));
    _subscriptions.add(_recordService.audioStream.listen(_onRecordedChunk));
    _subscriptions.add(
        _socketService.partialTranscripts.listen(_handlePartialTranscript));
    _subscriptions
        .add(_socketService.finalTranscripts.listen(_handleFinalTranscript));
    _subscriptions
        .add(_socketService.assistantTextStream.listen(_handleAssistantText));
    _subscriptions
        .add(_socketService.completionEvents.listen(_handleAssistantDone));
    _subscriptions
        .add(_socketService.statusEvents.listen(_handleStatusMessage));
    _subscriptions.add(_socketService.errorEvents.listen(_handleSocketError));
    _subscriptions
        .add(_socketService.audioChunks.listen(_handleBackendAudioChunk));
    _subscriptions
        .add(_playbackService.statusStream.listen(_handlePlaybackStatus));
  }

  Future<void> toggleListening() async {
    if (isListening) {
      await stopListeningAndSend();
      return;
    }

    if (isProcessing) {
      _clearProcessingTimeout();
      _isStoppingOrSending = false;
      _socketService.sendInterrupt();
      await _playbackService.interrupt();
      _setState(VoiceChatState.idle);
    }

    if (canStartListening) {
      await startListening();
    }
  }

  Future<void> startListening() async {
    if (!isMicSupported) {
      _setError('Microphone recording is not supported in this browser.');
      return;
    }

    _lastError = null;
    _clearProcessingTimeout();
    _socketService.sendInterrupt();
    await _playbackService.interrupt();

    final connected = await _socketService.ensureConnected();
    if (!connected) {
      _setError('Unable to connect to the voice server.');
      return;
    }

    try {
      _currentUserTurnId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
      _currentAiTurnId = null;
      _latestTranscriptText = '';
      _latestAssistantText = '';
      _assistantAudioReceivedForTurn = false;
      _isStoppingOrSending = false;
      _listeningStartedAt = DateTime.now();
      _silenceDetector.reset();

      _socketService.sendTurnStarted();
      await _recordService.start(config: _recordConfig);

      _addOrUpdateMessage(
        ChatMessage(
          id: _currentUserTurnId!,
          source: 'user',
          text: 'Listening...',
          isPartial: true,
        ),
      );
      _setState(VoiceChatState.listening);
    } catch (_) {
      _setError('Microphone permission denied or recording could not start.');
    }
  }

  Future<void> stopListeningAndSend() async {
    if (!isListening || _isStoppingOrSending) return;
    _isStoppingOrSending = true;

    try {
      await _recordService.stop();
    } catch (_) {
      _setError('Recording stopped unexpectedly.');
      return;
    }

    _setState(VoiceChatState.processing);
    _startProcessingTimeout();

    _socketService.sendEndOfInput(
      transcriptHint: _latestTranscriptText,
      speechDuration: _listeningStartedAt == null
          ? null
          : DateTime.now().difference(_listeningStartedAt!),
    );
    _socketService.requestAssistantResponse(
      transcriptHint: _latestTranscriptText,
    );
  }

  void _onRecordedChunk(AudioChunk chunk) {
    if (!isListening || !_socketService.isConnected) return;
    _socketService.sendAudioChunk(chunk);
  }

  // void _onSilenceDetected() {
  //   if (isListening) {
  //     unawaited(stopListeningAndSend());
  //   }
  // }

  void _handlePartialTranscript(String text) {
    _latestTranscriptText = text;
    if (_currentUserTurnId == null) return;
    _addOrUpdateMessage(
      ChatMessage(
        id: _currentUserTurnId!,
        source: 'user',
        text: text,
        isPartial: true,
      ),
    );
  }

  void _handleFinalTranscript(String text) {
    _latestTranscriptText = text;
    if (_currentUserTurnId == null) return;
    _addOrUpdateMessage(
      ChatMessage(
        id: _currentUserTurnId!,
        source: 'user',
        text: text,
        isPartial: false,
      ),
    );
  }

  void _handleAssistantText(String text) {
    _clearProcessingTimeout();
    _latestAssistantText = '$_latestAssistantText$text';
    if (_currentAiTurnId == null) {
      _currentAiTurnId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
      _addOrUpdateMessage(
        ChatMessage(
          id: _currentAiTurnId!,
          source: 'assistant',
          text: text,
          isPartial: true,
        ),
      );
    } else {
      final existing = _messages.firstWhere(
        (message) => message.id == _currentAiTurnId,
        orElse: () => ChatMessage(
          id: _currentAiTurnId!,
          source: 'assistant',
          text: '',
          isPartial: true,
        ),
      );
      _addOrUpdateMessage(
        existing.copyWith(
          text: '${existing.text}$text',
          isPartial: true,
        ),
      );
    }

    if (_state == VoiceChatState.processing) {
      _setState(VoiceChatState.playing);
    }
  }

  void _handleAssistantDone(Map<String, dynamic> _) {
    _clearProcessingTimeout();
    final shouldSpeakFullResponse = _latestAssistantText.trim().isNotEmpty &&
        (_preferAssistantTextToSpeech ||
            !_assistantAudioReceivedForTurn ||
            !_playbackService.isPlaying);
    if (_currentAiTurnId != null) {
      final index =
          _messages.indexWhere((message) => message.id == _currentAiTurnId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(isPartial: false);
      }
      _currentAiTurnId = null;
    }

    if (shouldSpeakFullResponse) {
      unawaited(_playbackService.speakText(_latestAssistantText));
      return;
    }

    if (!_playbackService.isPlaying) {
      _setState(VoiceChatState.idle);
    } else {
      notifyListeners();
    }
  }

  Future<void> _handleBackendAudioChunk(Uint8List chunk) async {
    if (chunk.isEmpty) return;

    if (isListening) {
      await _playbackService.interrupt();
      return;
    }

    _assistantAudioReceivedForTurn = true;
    if (_preferAssistantTextToSpeech) {
      return;
    }

    if (_state == VoiceChatState.processing) {
      _setState(VoiceChatState.playing);
    }

    await _playbackService.enqueueChunk(chunk);
  }

  void _handleStatusMessage(Map<String, dynamic> message) {
    final status = message['status']?.toString().toLowerCase();
    if (status == null || status.isEmpty) return;

    if (status == 'processing' || status == 'thinking') {
      if (_state == VoiceChatState.listening || _state == VoiceChatState.idle) {
        _setState(VoiceChatState.processing);
      }
      return;
    }

    if (status == 'done' || status == 'completed' || status == 'idle') {
      _clearProcessingTimeout();
      if (!_playbackService.isPlaying) {
        _setState(VoiceChatState.idle);
      }
    }
  }

  void _handleSocketError(Map<String, dynamic> message) {
    _setError('Server Error: ${message["text"] ?? "Unknown error"}');
  }

  void _handlePlaybackStatus(AudioPlaybackStatus status) {
    if (_disposed) return;

    switch (status) {
      case AudioPlaybackStatus.playing:
        if (_state == VoiceChatState.processing ||
            _state == VoiceChatState.idle) {
          _setState(VoiceChatState.playing);
        }
        break;
      case AudioPlaybackStatus.idle:
        if (_state == VoiceChatState.playing && _currentAiTurnId == null) {
          _setState(VoiceChatState.idle);
        }
        break;
      case AudioPlaybackStatus.error:
        _setError('Audio playback failed.');
        break;
      case AudioPlaybackStatus.interrupted:
      case AudioPlaybackStatus.priming:
        notifyListeners();
        break;
    }
  }

  void _addOrUpdateMessage(ChatMessage message) {
    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index == -1) {
      _messages.add(message);
    } else {
      _messages[index] = message;
    }
    notifyListeners();
  }

  void _startProcessingTimeout() {
    _processingTimeoutTimer?.cancel();
    _processingTimeoutTimer = Timer(_processingTimeout, () {
      if (_state != VoiceChatState.processing) return;
      _addOrUpdateMessage(
        ChatMessage(
          id: 'timeout_${DateTime.now().millisecondsSinceEpoch}',
          source: 'system',
          text:
              'No response came back from the voice server. Please try again.',
        ),
      );
      _setState(VoiceChatState.idle);
    });
  }

  void _clearProcessingTimeout() {
    _processingTimeoutTimer?.cancel();
    _processingTimeoutTimer = null;
  }

  void _setError(String message) {
    _lastError = message;
    _clearProcessingTimeout();
    unawaited(_playbackService.interrupt());
    _addOrUpdateMessage(
      ChatMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        source: 'system',
        text: message,
      ),
    );
    _setState(VoiceChatState.error);
  }

  void _setState(VoiceChatState nextState) {
    if (_state == nextState) {
      notifyListeners();
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clearProcessingTimeout();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _silenceDetector.dispose();
    _recordService.dispose();
    unawaited(_playbackService.dispose());
    _socketService.dispose();
    super.dispose();
  }
}
