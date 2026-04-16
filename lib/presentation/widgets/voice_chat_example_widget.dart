import 'package:flutter/material.dart';

import '../viewmodels/voice_chat_view_model.dart';

class VoiceChatExampleWidget extends StatelessWidget {
  final VoiceChatViewModel viewModel;

  const VoiceChatExampleWidget({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('State: ${viewModel.state.name}'),
            if (viewModel.liveTranscript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Transcript: ${viewModel.liveTranscript}'),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: viewModel.onTalkPressed,
              child: Text(viewModel.talkButtonLabel),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: viewModel.visibleConversation
                    .map(
                      (message) => ListTile(
                        title: Text(message.text),
                        subtitle: Text(message.source),
                        trailing: message.isPartial
                            ? const Text('live')
                            : null,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
