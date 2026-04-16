import 'dart:async';
import 'dart:typed_data';

import 'audio_record_service_stub.dart'
    if (dart.library.html) 'audio_record_service_web.dart';

enum AudioEncoding { pcm16, wav }

class AudioRecordConfig {
  final int targetSampleRate;
  final int channels;
  final Duration chunkDuration;
  final AudioEncoding encoding;
  final bool echoCancellation;
  final bool noiseSuppression;
  final bool autoGainControl;

  const AudioRecordConfig({
    this.targetSampleRate = 16000,
    this.channels = 1,
    this.chunkDuration = const Duration(milliseconds: 250),
    this.encoding = AudioEncoding.pcm16,
    this.echoCancellation = true,
    this.noiseSuppression = true,
    this.autoGainControl = true,
  });
}

class AudioChunk {
  final Uint8List bytes;
  final int sampleRate;
  final int channels;
  final AudioEncoding encoding;
  final Duration duration;
  final bool isFinal;

  const AudioChunk({
    required this.bytes,
    required this.sampleRate,
    required this.channels,
    required this.encoding,
    required this.duration,
    this.isFinal = false,
  });
}

abstract class AudioRecordService {
  factory AudioRecordService() => createAudioRecordService();

  bool get isSupported;
  bool get isRecording;
  AudioRecordConfig get activeConfig;

  Stream<AudioChunk> get audioStream;
  Stream<double> get volumeStream;
  Stream<bool> get recordingStateStream;

  Future<void> start({AudioRecordConfig config = const AudioRecordConfig()});
  Future<void> stop();
  void dispose();
}
