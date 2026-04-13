export 'voice_recorder_stub.dart';

import 'voice_recorder_stub.dart';

VoiceRecorder createVoiceRecorder() => _IoVoiceRecorder();

class _IoVoiceRecorder implements VoiceRecorder {
  @override
  bool get isSupported => false;

  @override
  bool get isRecording => false;

  @override
  Future<void> start() async {}

  @override
  Future<RecordedAudio?> stop() async => null;

  @override
  Future<void> dispose() async {}
}
