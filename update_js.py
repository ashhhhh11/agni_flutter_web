import os

path_rec = r"c:\Users\Ashritha TD\Desktop\technodysis_web\agni_flutter_web\lib\data\services\audio_record_service_web.dart"
path_play = r"c:\Users\Ashritha TD\Desktop\technodysis_web\agni_flutter_web\lib\data\services\audio_playback_service_web.dart"

rec_code = """import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'dart:math' as math;

import 'audio_record_service.dart';

AudioRecordService createAudioRecordService() => _WebAudioRecordService();

class _WebAudioRecordService implements AudioRecordService {
  html.MediaStream? _stream;
  dynamic _audioContext;
  dynamic _source;
  dynamic _processor;

  final _audioController = StreamController<Uint8List>.broadcast();
  final _volumeController = StreamController<double>.broadcast();

  bool _isRecording = false;

  @override
  bool get isSupported => html.window.navigator.mediaDevices != null;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<Uint8List> get audioStream => _audioController.stream;

  @override
  Stream<double> get volumeStream => _volumeController.stream;

  @override
  Future<void> start() async {
    if (!isSupported || _isRecording) return;
    try {
      _stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
        'video': false,
      });

      final ctor = js_util.getProperty(html.window, 'AudioContext') ?? js_util.getProperty(html.window, 'webkitAudioContext');
      _audioContext = js_util.callConstructor(ctor, []);
      
      _source = js_util.callMethod(_audioContext, 'createMediaStreamSource', [_stream]);

      _processor = js_util.callMethod(_audioContext, 'createScriptProcessor', [4096, 1, 1]);

      js_util.setProperty(_processor, 'onaudioprocess', js_util.allowInterop((dynamic event) {
        if (!_isRecording) return;
        final inputBuffer = js_util.getProperty(event, 'inputBuffer');
        if (inputBuffer == null) return;
        
        final channelData = js_util.callMethod(inputBuffer, 'getChannelData', [0]);
        final Float32List float32Data = channelData as Float32List;

        double sumSquares = 0.0;
        for (int i = 0; i < float32Data.length; i++) {
          final sample = float32Data[i];
          sumSquares += sample * sample;
        }
        final rms = math.sqrt(sumSquares / float32Data.length);
        _volumeController.add(rms);

        final sampleRate = js_util.getProperty(inputBuffer, 'sampleRate') as num;
        final pcm16 = _resampleAndEncodePcm16(float32Data, sampleRate.toDouble(), 16000);
        _audioController.add(pcm16);
      }));

      js_util.callMethod(_source, 'connect', [_processor]);
      final dest = js_util.getProperty(_audioContext, 'destination');
      js_util.callMethod(_processor, 'connect', [dest]);

      _isRecording = true;
    } catch (e) {
      _isRecording = false;
      throw Exception("Failed to start recording: $e");
    }
  }

  Uint8List _resampleAndEncodePcm16(Float32List samples, double sourceRate, int targetRate) {
    if (sourceRate == targetRate) {
        final pcm = Uint8List(samples.length * 2);
        final data = ByteData.view(pcm.buffer);
        for(int i = 0; i < samples.length; i++) {
            int intSample = (samples[i].clamp(-1.0, 1.0) * 32767).round();
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
      final sample = samples[leftIndex] + (samples[rightIndex] - samples[leftIndex]) * fraction;
      
      final clamped = sample.clamp(-1.0, 1.0);
      final intSample = clamped < 0 ? (clamped * 32768).round() : (clamped * 32767).round();
      data.setInt16(i * 2, intSample, Endian.little);
    }
    return pcm;
  }

  @override
  Future<void> stop() async {
    _isRecording = false;
    if (_processor != null) js_util.callMethod(_processor, 'disconnect', []);
    if (_source != null) js_util.callMethod(_source, 'disconnect', []);
    if (_audioContext != null) {
        final state = js_util.getProperty(_audioContext, 'state');
        if (state != 'closed') {
            js_util.callMethod(_audioContext, 'close', []);
        }
    }
    
    _stream?.getTracks().forEach((track) => track.stop());
    
    _processor = null;
    _source = null;
    _audioContext = null;
    _stream = null;
  }

  @override
  void dispose() {
    stop();
    _audioController.close();
    _volumeController.close();
  }
}
"""

play_code = """import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'audio_playback_service.dart';

AudioPlaybackService createAudioPlaybackService() => _WebAudioPlaybackService();

class _WebAudioPlaybackService implements AudioPlaybackService {
  dynamic _audioContext;
  
  final List<Uint8List> _queue = [];
  bool _isPlaying = false;
  double _nextStartTime = 0;
  
  final List<dynamic> _currentSources = [];

  @override
  void prime() {
    if (_audioContext == null) {
        final ctor = js_util.getProperty(html.window, 'AudioContext') ?? js_util.getProperty(html.window, 'webkitAudioContext');
        _audioContext = js_util.callConstructor(ctor, []);
    }
    final state = js_util.getProperty(_audioContext, 'state');
    if (state == 'suspended') {
      js_util.callMethod(_audioContext, 'resume', []);
    }
  }

  @override
  void enqueueChunk(Uint8List chunk) {
    if (_audioContext == null) prime();
    _queue.add(chunk);
    if (!_isPlaying) _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isPlaying) return;
    _isPlaying = true;

    final state = js_util.getProperty(_audioContext, 'state');
    if (state == 'suspended') {
      await js_util.promiseToFuture(js_util.callMethod(_audioContext, 'resume', []));
    }

    final cTime = js_util.getProperty(_audioContext, 'currentTime') as num;
    _nextStartTime = cTime.toDouble() + 0.05;

    while (_queue.isNotEmpty) {
      final chunk = _queue.removeAt(0);
      try {
        final decodedBuffer = await _decodeChunk(chunk);
        if (decodedBuffer != null) {
          _scheduleBuffer(decodedBuffer);
        }
      } catch (e) {
      }
    }

    final finalTime = js_util.getProperty(_audioContext, 'currentTime') as num;
    final delay = _nextStartTime - finalTime.toDouble();
    if (delay > 0) {
      await Future.delayed(Duration(milliseconds: (delay * 1000).toInt() + 50));
    }
    
    _isPlaying = false;

    if (_queue.isNotEmpty) {
      _processQueue();
    }
  }

  void _scheduleBuffer(dynamic buffer) {
    final source = js_util.callMethod(_audioContext, 'createBufferSource', []);
    js_util.setProperty(source, 'buffer', buffer);
    final dest = js_util.getProperty(_audioContext, 'destination');
    js_util.callMethod(source, 'connect', [dest]);
    
    final cTime = js_util.getProperty(_audioContext, 'currentTime') as num;
    final currentTime = cTime.toDouble();
    if (_nextStartTime < currentTime) {
      _nextStartTime = currentTime + 0.02; 
    }
    
    js_util.callMethod(source, 'start', [_nextStartTime]);
    final dur = js_util.getProperty(buffer, 'duration') as num;
    _nextStartTime += dur.toDouble();
    
    _currentSources.add(source);
    js_util.setProperty(source, 'onended', js_util.allowInterop((dynamic _) {
      _currentSources.remove(source);
    }));
  }

  Future<dynamic> _decodeChunk(Uint8List chunk) async {
    if (chunk.isEmpty) return null;
    
    if (_looksLikeWave(chunk) || _LooksLikeMpeg(chunk) || _looksLikeOgg(chunk)) {
      final completer = Completer<dynamic>();
      try {
         final promise = js_util.callMethod(_audioContext, 'decodeAudioData', [chunk.buffer]);
         js_util.promiseToFuture(promise).then((buffer) {
           completer.complete(buffer);
         }).catchError((e) {
           completer.complete(null);
         });
      } catch (e) {
         completer.complete(null);
      }
      return completer.future;
    } else {
      return _pcmToBuffer(chunk);
    }
  }

  dynamic _pcmToBuffer(Uint8List pcm16) {
    final floatArray = Float32List(pcm16.length ~/ 2);
    final dataView = ByteData.view(pcm16.buffer, pcm16.offsetInBytes, pcm16.length);
    for (int i = 0; i < floatArray.length; i++) {
        floatArray[i] = dataView.getInt16(i * 2, Endian.little) / 32768.0;
    }
    final buffer = js_util.callMethod(_audioContext, 'createBuffer', [1, floatArray.length, 16000]);
    final channelData = js_util.callMethod(buffer, 'getChannelData', [0]) as Float32List;
    channelData.setAll(0, floatArray);
    return buffer;
  }

  bool _looksLikeWave(Uint8List bytes) {
    return bytes.length > 12 && bytes[0] == 0x52 && bytes[1] == 0x49; 
  }

  bool _LooksLikeMpeg(Uint8List bytes) {
    final hasId3 = bytes.length > 3 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33;
    final hasFrameSync = bytes.length > 2 && bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0;
    return hasId3 || hasFrameSync;
  }

  bool _looksLikeOgg(Uint8List bytes) {
    return bytes.length > 4 && bytes[0] == 0x4f && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53;
  }

  @override
  void interrupt() {
    _queue.clear();
    for (var source in _currentSources) {
      try {
        js_util.callMethod(source, 'stop', []);
        js_util.callMethod(source, 'disconnect', []);
      } catch (_) {}
    }
    _currentSources.clear();
    _isPlaying = false;
    _nextStartTime = 0;
  }

  @override
  void dispose() {
    interrupt();
    if (_audioContext != null) {
      final state = js_util.getProperty(_audioContext, 'state');
      if (state != 'closed') {
         js_util.callMethod(_audioContext, 'close', []);
      }
    }
  }
}
"""

with open(path_rec, "w", encoding='utf-8') as f: f.write(rec_code)
with open(path_play, "w", encoding='utf-8') as f: f.write(play_code)

print("Done writing web files with JSUtil")
