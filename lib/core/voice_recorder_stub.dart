import 'dart:convert';
import 'dart:typed_data';

class RecordedAudio {
  final String base64Data;
  final String mimeType;
  final int sizeBytes;
  final Uint8List? rawPcmBytes;

  const RecordedAudio({
    required this.base64Data,
    required this.mimeType,
    required this.sizeBytes,
    this.rawPcmBytes,
  });

  // Compatibility getter for flows expecting raw bytes.
  Uint8List get pcmBytes =>
      rawPcmBytes ?? Uint8List.fromList(base64Decode(base64Data));
}

abstract class VoiceRecorder {
  bool get isSupported;
  bool get isRecording;

  Future<void> start();
  Future<RecordedAudio?> stop();
  Future<void> dispose();
}

VoiceRecorder createVoiceRecorder() => _UnsupportedVoiceRecorder();

class _UnsupportedVoiceRecorder implements VoiceRecorder {
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
