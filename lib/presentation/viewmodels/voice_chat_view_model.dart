import 'package:flutter/foundation.dart';

import '../../core/socket_service.dart';
import '../controllers/voice_chat_controller.dart';

class VoiceChatViewModel extends ChangeNotifier {
  final VoiceChatController _controller;
  bool _isBusy = false;

  VoiceChatViewModel({
    required SocketService socketService,
    VoiceChatController? controller,
  }) : _controller =
            controller ?? VoiceChatController(socketService: socketService) {
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    notifyListeners();
  }

  VoiceChatState get state => _controller.state;
  bool get isListening => _controller.isListening;
  bool get isProcessing => _controller.isProcessing;
  bool get isPlaying => _controller.isPlaying;
  bool get isMicSupported => _controller.isMicSupported;
  String? get errorText => _controller.lastError;
  String get liveTranscript => _controller.liveTranscript;
  List<ChatMessage> get messages => _controller.messages;
  bool get isBusy => _isBusy;

  List<ChatMessage> get visibleConversation => messages
      .where((item) => item.source == 'user' || item.source == 'assistant')
      .toList();

  String get talkButtonLabel {
    if (_isBusy) return 'Please wait...';
    switch (state) {
      case VoiceChatState.listening:
        return '■ Tap to stop';
      case VoiceChatState.processing:
        return '● Processing...';
      case VoiceChatState.playing:
        return '● Speaking...';
      case VoiceChatState.error:
        return '● Try again';
      case VoiceChatState.idle:
        return '● Tap to talk';
    }
  }

  /// Returns true if the button should accept taps:
  /// - Always tappable when idle/error (to start)
  /// - Tappable when listening (to stop)
  /// - NOT tappable when processing or playing
  bool get isButtonEnabled {
    if (_isBusy) return false;
    switch (state) {
      case VoiceChatState.idle:
      case VoiceChatState.error:
      case VoiceChatState.listening:
        return true;
      case VoiceChatState.processing:
      case VoiceChatState.playing:
        return false;
    }
  }

  Future<void> onTalkPressed() async {
    // Guard: don't double-trigger
    if (_isBusy) return;

    // Only allow tap when idle/error (start) or listening (stop)
    if (state == VoiceChatState.processing || state == VoiceChatState.playing) {
      return;
    }

    _isBusy = true;
    notifyListeners();

    try {
      await _controller.toggleListening();
    } catch (e) {
      debugPrint('VoiceChatViewModel.onTalkPressed error: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }
}
