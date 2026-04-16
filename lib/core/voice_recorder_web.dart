import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

export 'voice_recorder_stub.dart';
import 'voice_recorder_stub.dart';

VoiceRecorder createVoiceRecorder() => _WebVoiceRecorder();

class _WebVoiceRecorder implements VoiceRecorder {
  static const int _targetSampleRate = 16000;

  html.MediaStream? _stream;
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = <html.Blob>[];
  void Function(html.Event)? _onDataAvailable;
  void Function(html.Event)? _onStop;
  void Function(html.Event)? _onError;
  Completer<RecordedAudio?>? _stopCompleter;

  @override
  bool get isSupported => html.window.navigator.mediaDevices != null;

  @override
  bool get isRecording => _recorder?.state == 'recording';

  @override
  Future<void> start() async {
    if (!isSupported || isRecording) return;

    _stream = await html.window.navigator.mediaDevices!.getUserMedia({
      'audio': true,
      'video': false,
    });

    _chunks.clear();
    _recorder = html.MediaRecorder(_stream!);

    log('Voice recording started with MIME type: ${_recorder!.mimeType}');

    _onDataAvailable = (event) {
      if (event is! html.BlobEvent) return;
      final blob = event.data;
      if (blob != null && blob.size > 0) {
        _chunks.add(blob);
      }
    };
    _recorder!.addEventListener('dataavailable', _onDataAvailable);

    _onError = (_) {
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        _stopCompleter!.complete(null);
      }
    };
    _recorder!.addEventListener('error', _onError);

    _onStop = (_) async {
      if (_stopCompleter == null || _stopCompleter!.isCompleted) {
        return;
      }
      final audio = await _toRecordedAudio();
      _stopCompleter!.complete(audio);
    };
    _recorder!.addEventListener('stop', _onStop);

    _recorder!.start();
  }

  @override
  Future<RecordedAudio?> stop() async {
    if (_recorder == null || !isRecording) {
      return null;
    }

    _stopCompleter = Completer<RecordedAudio?>();
    _recorder!.stop();

    final result = await _stopCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
    _stopCompleter = null;
    return result;
  }

  Future<RecordedAudio?> _toRecordedAudio() async {
    if (_chunks.isEmpty) {
      _stopTracks();
      return null;
    }

    final mimeType = _recorder?.mimeType ?? 'audio/webm';
    final blob = html.Blob(_chunks, mimeType);
    try {
      final compressedBytes = await _readBlobBytes(blob);
      final pcmBytes = await _decodeTo16kMonoPcm(compressedBytes);

      // ── NOTE: rawPcmBytes carries the decoded 16 kHz mono PCM.
      //    Callers must use recorded.rawPcmBytes, NOT recorded.pcmBytes.
      return RecordedAudio(
        base64Data: base64Encode(compressedBytes),
        mimeType: mimeType,
        sizeBytes: pcmBytes.length,
        rawPcmBytes: pcmBytes,
      );
    } finally {
      _stopTracks();
    }
  }

  Future<Uint8List> _readBlobBytes(html.Blob blob) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();

    late StreamSubscription loadSub;
    late StreamSubscription errorSub;

    loadSub = reader.onLoadEnd.listen((_) {
      loadSub.cancel();
      errorSub.cancel();

      final result = reader.result;
      if (result is String && result.contains(',')) {
        completer.complete(base64Decode(result.split(',').last));
      } else {
        completer.completeError(
          StateError('Recorded audio could not be read as a data URL.'),
        );
      }
    });

    errorSub = reader.onError.listen((_) {
      loadSub.cancel();
      errorSub.cancel();
      completer.completeError(StateError('Unable to read recorded audio.'));
    });

    reader.readAsDataUrl(blob);
    return completer.future;
  }

  Future<Uint8List> _decodeTo16kMonoPcm(Uint8List compressedBytes) async {
    final browserWindow = JSObject.fromInteropObject(html.window);
    final audioContextCtor =
        browserWindow.getProperty<JSFunction?>('AudioContext'.toJS) ??
            browserWindow.getProperty<JSFunction?>('webkitAudioContext'.toJS);
    if (audioContextCtor == null) {
      throw UnsupportedError('Web Audio API is unavailable in this browser.');
    }

    final audioContext = audioContextCtor.callAsConstructor<JSObject>();
    try {
      final decodedAudio = await audioContext
          .callMethod<JSPromise<JSObject>>(
            'decodeAudioData'.toJS,
            compressedBytes.buffer.toJS,
          )
          .toDart;

      final channelCount =
          decodedAudio.getProperty<JSNumber>('numberOfChannels'.toJS).toDartInt;
      final sourceLength =
          decodedAudio.getProperty<JSNumber>('length'.toJS).toDartInt;
      final sourceRate =
          decodedAudio.getProperty<JSNumber>('sampleRate'.toJS).toDartDouble;

      if (channelCount <= 0 || sourceLength <= 0 || sourceRate <= 0) {
        return Uint8List(0);
      }

      final mono = Float32List(sourceLength);
      for (var channel = 0; channel < channelCount; channel++) {
        final samples = decodedAudio
            .callMethod<JSFloat32Array>(
              'getChannelData'.toJS,
              channel.toJS,
            )
            .toDart;

        for (var i = 0; i < sourceLength; i++) {
          mono[i] += samples[i] / channelCount;
        }
      }

      return _resampleAndEncodePcm16(mono, sourceRate, _targetSampleRate);
    } finally {
      if (audioContext.has('close')) {
        audioContext.callMethod<JSAny?>('close'.toJS);
      }
    }
  }

  Uint8List _resampleAndEncodePcm16(
    Float32List samples,
    double sourceRate,
    int targetRate,
  ) {
    final targetLength = math.max(
      1,
      (samples.length * targetRate / sourceRate).round(),
    );
    final pcm = Uint8List(targetLength * 2);
    final data = ByteData.view(pcm.buffer);
    final ratio = sourceRate / targetRate;

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

  void _stopTracks() {
    for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
  }

  @override
  Future<void> dispose() async {
    if (_recorder != null && isRecording) {
      await stop();
    }
    if (_recorder != null) {
      if (_onDataAvailable != null) {
        _recorder!.removeEventListener('dataavailable', _onDataAvailable);
      }
      if (_onStop != null) {
        _recorder!.removeEventListener('stop', _onStop);
      }
      if (_onError != null) {
        _recorder!.removeEventListener('error', _onError);
      }
    }
    _onDataAvailable = null;
    _onStop = null;
    _onError = null;
    _recorder = null;
    _chunks.clear();
    _stopTracks();
  }
}
