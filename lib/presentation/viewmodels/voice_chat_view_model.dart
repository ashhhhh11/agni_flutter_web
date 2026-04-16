import 'package:flutter/foundation.dart';

import '../../core/socket_service.dart';
import '../controllers/voice_chat_controller.dart';

class VoiceChatViewModel extends ChangeNotifier {
  final VoiceChatController _controller;

  VoiceChatViewModel({
    required SocketService socketService,
    VoiceChatController? controller,
  }) : _controller = controller ?? VoiceChatController(socketService: socketService) {
    _controller.addListener(notifyListeners);
  }

  VoiceChatState get state => _controller.state;
  bool get isListening => _controller.isListening;
  bool get isProcessing => _controller.isProcessing;
  bool get isPlaying => _controller.isPlaying;
  bool get isMicSupported => _controller.isMicSupported;
  String? get errorText => _controller.lastError;
  String get liveTranscript => _controller.liveTranscript;
  List<ChatMessage> get messages => _controller.messages;

  List<ChatMessage> get visibleConversation => messages
      .where((item) => item.source == 'user' || item.source == 'assistant')
      .toList();

  String get talkButtonLabel {
    switch (state) {
      case VoiceChatState.listening:
        return 'Stop recording';
      case VoiceChatState.processing:
        return 'Processing...';
      case VoiceChatState.playing:
        return 'Speak again';
      case VoiceChatState.error:
        return 'Try again';
      case VoiceChatState.idle:
        return 'Tap to talk';
    }
  }

  Future<void> onTalkPressed() => _controller.toggleListening();

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    _controller.dispose();
    super.dispose();
  }
}
