import 'dart:typed_data';

import 'audio_playback_service_stub.dart'
    if (dart.library.html) 'audio_playback_service_web.dart';

enum AudioPlaybackStatus { idle, priming, playing, interrupted, error }

abstract class AudioPlaybackService {
  factory AudioPlaybackService() => createAudioPlaybackService();

  bool get isPlaying;
  Stream<AudioPlaybackStatus> get statusStream;

  Future<void> prime();
  Future<void> enqueueChunk(Uint8List chunk);
  Future<void> speakText(String text);
  Future<void> interrupt();
  Future<void> dispose();
}
