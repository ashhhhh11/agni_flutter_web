import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_record_service.dart';

AudioRecordService createAudioRecordService() => _WebAudioRecordService();

class _WebAudioRecordService implements AudioRecordService {
  html.MediaStream? _stream;
  dynamic _audioContext;
  dynamic _source;
  dynamic _processor;
  dynamic _silenceGain;

  final _audioController = StreamController<AudioChunk>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _recordingStateController = StreamController<bool>.broadcast();

  final BytesBuilder _buffer = BytesBuilder(copy: false);

  bool _isRecording = false;
  AudioRecordConfig _activeConfig = const AudioRecordConfig();
  int _bytesPerChunk = 0;

  @override
  bool get isSupported => html.window.navigator.mediaDevices != null;

  @override
  bool get isRecording => _isRecording;

  @override
  AudioRecordConfig get activeConfig => _activeConfig;

  @override
  Stream<AudioChunk> get audioStream => _audioController.stream;

  @override
  Stream<double> get volumeStream => _volumeController.stream;

  @override
  Stream<bool> get recordingStateStream => _recordingStateController.stream;

  @override
  Future<void> start(
      {AudioRecordConfig config = const AudioRecordConfig()}) async {
    if (!isSupported || _isRecording) return;

    _activeConfig = config;
    _bytesPerChunk = math.max(
      3200,
      (config.targetSampleRate *
              config.channels *
              2 *
              config.chunkDuration.inMilliseconds /
              1000)
          .round(),
    );

    try {
      _stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': {
          'echoCancellation': config.echoCancellation,
          'noiseSuppression': config.noiseSuppression,
          'autoGainControl': config.autoGainControl,
          'channelCount': config.channels,
        },
        'video': false,
      });

      final ctor = js_util.getProperty(html.window, 'AudioContext') ??
          js_util.getProperty(html.window, 'webkitAudioContext');
      _audioContext = js_util.callConstructor(ctor, []);

      final state = js_util.getProperty(_audioContext, 'state');
      if (state == 'suspended') {
        await js_util.promiseToFuture(
          js_util.callMethod(_audioContext, 'resume', []),
        );
      }

      _source = js_util.callMethod(
        _audioContext,
        'createMediaStreamSource',
        [_stream],
      );
      _processor = js_util.callMethod(
        _audioContext,
        'createScriptProcessor',
        [4096, config.channels, 1],
      );
      _silenceGain = js_util.callMethod(_audioContext, 'createGain', []);
      final gainParam = js_util.getProperty(_silenceGain, 'gain');
      js_util.setProperty(gainParam, 'value', 0);

      _isRecording = true;
      _recordingStateController.add(true);

      js_util.setProperty(
        _processor,
        'onaudioprocess',
        js_util.allowInterop((dynamic event) {
          if (!_isRecording) return;
          final inputBuffer = js_util.getProperty(event, 'inputBuffer');
          if (inputBuffer == null) return;

          final channelData = js_util
              .callMethod(inputBuffer, 'getChannelData', [0]) as Float32List;
          if (channelData.isEmpty) return;

          var sumSquares = 0.0;
          for (final sample in channelData) {
            sumSquares += sample * sample;
          }
          _volumeController.add(math.sqrt(sumSquares / channelData.length));

          final sampleRate =
              (js_util.getProperty(inputBuffer, 'sampleRate') as num)
                  .toDouble();
          final pcm16 = _resampleAndEncodePcm16(
            channelData,
            sampleRate,
            config.targetSampleRate,
          );
          _buffer.add(pcm16);
          _emitReadyChunks();
        }),
      );

      js_util.callMethod(_source, 'connect', [_processor]);
      js_util.callMethod(_processor, 'connect', [_silenceGain]);
      final destination = js_util.getProperty(_audioContext, 'destination');
      js_util.callMethod(_silenceGain, 'connect', [destination]);
    } catch (error) {
      _isRecording = false;
      _recordingStateController.add(false);
      await _teardown();
      throw Exception('Failed to start recording: $error');
    }
  }

  void _emitReadyChunks() {
    final bufferedBytes = _buffer.takeBytes();
    if (bufferedBytes.isEmpty) return;

    var offset = 0;
    while (bufferedBytes.length - offset >= _bytesPerChunk) {
      final chunk = Uint8List.sublistView(
        bufferedBytes,
        offset,
        offset + _bytesPerChunk,
      );
      _audioController.add(_buildChunk(chunk));
      offset += _bytesPerChunk;
    }

    if (offset < bufferedBytes.length) {
      _buffer.add(
        Uint8List.sublistView(bufferedBytes, offset, bufferedBytes.length),
      );
    }
  }

  AudioChunk _buildChunk(Uint8List pcmBytes, {bool isFinal = false}) {
    final payload = _activeConfig.encoding == AudioEncoding.wav
        ? _wrapPcmAsWav(pcmBytes)
        : Uint8List.fromList(pcmBytes);
    final durationMs = ((pcmBytes.length / 2) /
            (_activeConfig.targetSampleRate * _activeConfig.channels) *
            1000)
        .round();

    return AudioChunk(
      bytes: payload,
      sampleRate: _activeConfig.targetSampleRate,
      channels: _activeConfig.channels,
      encoding: _activeConfig.encoding,
      duration: Duration(milliseconds: durationMs),
      isFinal: isFinal,
    );
  }

  Uint8List _resampleAndEncodePcm16(
    Float32List samples,
    double sourceRate,
    int targetRate,
  ) {
    if (sourceRate == targetRate) {
      final pcm = Uint8List(samples.length * 2);
      final data = ByteData.view(pcm.buffer);
      for (var i = 0; i < samples.length; i++) {
        final clamped = samples[i].clamp(-1.0, 1.0);
        final intSample =
            clamped < 0 ? (clamped * 32768).round() : (clamped * 32767).round();
        data.setInt16(i * 2, intSample, Endian.little);
      }
      return pcm;
    }

    final ratio = sourceRate / targetRate;
    final targetLength = math.max(1, (samples.length / ratio).round());
    final pcm = Uint8List(targetLength * 2);
    final data = ByteData.view(pcm.buffer);

    for (var i = 0; i < targetLength; i++) {
      final sourceIndex = i * ratio;
      final leftIndex = sourceIndex.floor().clamp(0, samples.length - 1);
      final rightIndex = (leftIndex + 1).clamp(0, samples.length - 1);
      final fraction = sourceIndex - leftIndex;
      final sample = samples[leftIndex] +
          (samples[rightIndex] - samples[leftIndex]) * fraction;
      final clamped = sample.clamp(-1.0, 1.0);
      final intSample =
          clamped < 0 ? (clamped * 32768).round() : (clamped * 32767).round();
      data.setInt16(i * 2, intSample, Endian.little);
    }
    return pcm;
  }

  Uint8List _wrapPcmAsWav(Uint8List pcmBytes) {
    final bytesPerSecond =
        _activeConfig.targetSampleRate * _activeConfig.channels * 2;
    final wav = Uint8List(44 + pcmBytes.length);
    final data = ByteData.view(wav.buffer);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, 36 + pcmBytes.length, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, _activeConfig.channels, Endian.little);
    data.setUint32(24, _activeConfig.targetSampleRate, Endian.little);
    data.setUint32(28, bytesPerSecond, Endian.little);
    data.setUint16(32, _activeConfig.channels * 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, pcmBytes.length, Endian.little);
    wav.setRange(44, wav.length, pcmBytes);
    return wav;
  }

  @override
  Future<void> stop() async {
    if (!_isRecording &&
        _stream == null &&
        _audioContext == null &&
        _processor == null) {
      return;
    }

    _isRecording = false;
    _recordingStateController.add(false);

    final bufferedBytes = _buffer.takeBytes();
    if (bufferedBytes.isNotEmpty) {
      _audioController.add(_buildChunk(bufferedBytes, isFinal: true));
    }

    await _teardown();
  }

  Future<void> _teardown() async {
    if (_processor != null) {
      js_util.callMethod(_processor, 'disconnect', []);
    }
    if (_source != null) {
      js_util.callMethod(_source, 'disconnect', []);
    }
    if (_silenceGain != null) {
      js_util.callMethod(_silenceGain, 'disconnect', []);
    }
    if (_audioContext != null) {
      final state = js_util.getProperty(_audioContext, 'state');
      if (state != 'closed') {
        await js_util
            .promiseToFuture(
              js_util.callMethod(_audioContext, 'close', []),
            )
            .catchError((_) {});
      }
    }

    _stream?.getTracks().forEach((track) => track.stop());
    _processor = null;
    _source = null;
    _silenceGain = null;
    _audioContext = null;
    _stream = null;
  }

  @override
  void dispose() {
    unawaited(
      stop().whenComplete(() async {
        await _audioController.close();
        await _volumeController.close();
        await _recordingStateController.close();
      }),
    );
  }
}
