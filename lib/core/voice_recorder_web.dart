import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;


export 'voice_recorder_stub.dart';
import 'voice_recorder_stub.dart';

VoiceRecorder createVoiceRecorder() => _WebVoiceRecorder();

class _WebVoiceRecorder implements VoiceRecorder {
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

    _onDataAvailable = (event) {
      final blob = js_util.getProperty<Object?>(event, 'data');
      if (blob is! html.Blob) return;
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
    final reader = html.FileReader();
    final completer = Completer<RecordedAudio?>();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is! String || !result.contains(',')) {
        completer.complete(null);
        return;
      }
      final base64Data = result.split(',').last;
      completer.complete(
        RecordedAudio(
          base64Data: base64Data,
          mimeType: mimeType,
          sizeBytes: blob.size,
        ),
      );
    });

    reader.readAsDataUrl(blob);
    final recorded = await completer.future;
    _stopTracks();
    return recorded;
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
