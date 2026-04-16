import os

file_path = r"c:\Users\Ashritha TD\Desktop\technodysis_web\agni_flutter_web\lib\presentation\pages\landing_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    line_num = i + 1
    
    # 1. Imports
    if 9 <= line_num <= 18:
        if line_num == 9:
            new_lines.append("import '../../core/agni_colors.dart';\n")
            new_lines.append("import '../../core/socket_service.dart';\n")
            new_lines.append("import '../../domain/entities/agni_content.dart';\n")
            new_lines.append("import '../controllers/voice_chat_controller.dart';\n")
            new_lines.append("import '../widgets/earth_globe_painter.dart';\n")
        continue

    # 2. State variables
    if 105 <= line_num <= 132:
        if line_num == 105:
            new_lines.append("  late final VoiceChatController _chatController;\n")
            new_lines.append("  final List<dynamic> _conversation = [];\n") # preserve just in case but it's unused
        continue

    # 3. initState
    if 195 <= line_num <= 204:
        if line_num == 195:
            new_lines.append("    _chatController = VoiceChatController(socketService: widget.socketService);\n")
            new_lines.append("    _chatController.addListener(() {\n")
            new_lines.append("      if (mounted) setState(() {});\n")
            new_lines.append("    });\n\n")
            new_lines.append("    _scrollController.addListener(_checkReveal);\n")
        continue

    # 4. _addConversation ... _replacePendingUserTranscript
    if 241 <= line_num <= 774:
        if line_num == 241:
            new_lines.append("  Future<void> _onTapToTalk() async {\n")
            new_lines.append("    await _chatController.toggleListening();\n")
            new_lines.append("  }\n")
        continue

    # 5. dispose
    if 777 <= line_num <= 791:
        if line_num == 777:
            new_lines.append("  void dispose() {\n")
            new_lines.append("    _chatController.dispose();\n")
            new_lines.append("    _globeController.dispose();\n")
            new_lines.append("    _waveController.dispose();\n")
            new_lines.append("    _marqueeController.dispose();\n")
            new_lines.append("    _langController.dispose();\n")
            new_lines.append("    _floatController.dispose();\n")
            new_lines.append("    _scrollController.dispose();\n")
            new_lines.append("    _langTimer?.cancel();\n")
            new_lines.append("    super.dispose();\n")
            new_lines.append("  }\n")
        continue

    # 6. _buildPhoneMockup text
    if 1276 <= line_num <= 1281:
        if line_num == 1276:
            new_lines.append("                          _chatController.state == VoiceChatState.processing\n")
            new_lines.append("                              ? '● Processing...'\n")
            new_lines.append("                              : _chatController.state == VoiceChatState.listening\n")
            new_lines.append("                                  ? '■ Tap to stop'\n")
            new_lines.append("                                  : '● Tap to talk',\n")
        continue

    # 7. _buildConversationPanel
    if 1415 <= line_num <= 1420:
        if line_num == 1415:
            new_lines.append("    final visibleConversation = _chatController.messages.toList();\n")
            new_lines.append("\n")
        continue

    if line_num == 1479:
        new_lines.append("                        item.text,\n")
        continue

    new_lines.append(line)

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("Updated landing_page.dart successfully.")
