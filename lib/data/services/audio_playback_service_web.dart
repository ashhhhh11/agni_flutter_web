import 'dart:async';
import 'dart:collection';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'audio_playback_service.dart';

AudioPlaybackService createAudioPlaybackService() => _WebAudioPlaybackService();

class _WebAudioPlaybackService implements AudioPlaybackService {
  dynamic _audioContext;

  final Queue<Uint8List> _queue = Queue<Uint8List>();
  final List<dynamic> _activeSources = <dynamic>[];
  final _statusController =
      StreamController<AudioPlaybackStatus>.broadcast();

  bool _isPlaying = false;
  bool _isDisposed = false;
  bool _drainScheduled = false;
  bool _isSpeakingText = false;
  double _nextStartTime = 0;
  html.SpeechSynthesisUtterance? _activeUtterance;

  @override
  bool get isPlaying =>
      _isPlaying ||
      _isSpeakingText ||
      _activeSources.isNotEmpty ||
      _queue.isNotEmpty;

  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusController.stream;

  @override
  Future<void> prime() async {
    if (_isDisposed) return;

    _statusController.add(AudioPlaybackStatus.priming);
    _audioContext ??= js_util.callConstructor(
      js_util.getProperty(html.window, 'AudioContext') ??
          js_util.getProperty(html.window, 'webkitAudioContext'),
      [],
    );

    final state = js_util.getProperty(_audioContext, 'state');
    if (state == 'suspended') {
      await js_util.promiseToFuture(
        js_util.callMethod(_audioContext, 'resume', []),
      );
    }

    if (!isPlaying) {
      _statusController.add(AudioPlaybackStatus.idle);
    }
  }

  @override
  Future<void> enqueueChunk(Uint8List chunk) async {
    if (_isDisposed || chunk.isEmpty) return;

    await prime();
    _queue.add(Uint8List.fromList(chunk));
    _scheduleDrain();
  }

  @override
  Future<void> speakText(String text) async {
    if (_isDisposed) return;

    final value = text.trim();
    if (value.isEmpty) return;

    await prime();
    await interrupt();

    final synth = html.window.speechSynthesis;
    if (synth == null) {
      _statusController.add(AudioPlaybackStatus.error);
      return;
    }

    final utterance = html.SpeechSynthesisUtterance(value)
      ..rate = 1.0
      ..pitch = 1.0
      ..volume = 1.0;

    final completer = Completer<void>();
    _activeUtterance = utterance;
    _isSpeakingText = true;
    _statusController.add(AudioPlaybackStatus.playing);

    void finish([bool withError = false]) {
      if (completer.isCompleted) return;
      _activeUtterance = null;
      _isSpeakingText = false;
      if (withError && !_isDisposed) {
        _statusController.add(AudioPlaybackStatus.error);
      }
      if (!_isDisposed) {
        _statusController.add(AudioPlaybackStatus.idle);
      }
      completer.complete();
    }

    utterance.onEnd.listen((_) => finish());
    utterance.onError.listen((_) => finish(true));

    try {
      synth.cancel();
      synth.speak(utterance);
      await completer.future;
    } catch (_) {
      finish(true);
    }
  }

  void _scheduleDrain() {
    if (_drainScheduled || _isDisposed) return;
    _drainScheduled = true;
    unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    if (_isDisposed) return;

    _drainScheduled = false;
    if (_isPlaying) return;

    _isPlaying = true;
    _statusController.add(AudioPlaybackStatus.playing);

    try {
      while (_queue.isNotEmpty && !_isDisposed) {
        final chunk = _queue.removeFirst();
        final decoded = await _decodeChunk(chunk);
        if (decoded == null) {
          continue;
        }
        _scheduleDecodedBuffer(decoded);
      }

      await _waitForActivePlaybackToFinish();

      if (_queue.isNotEmpty && !_isDisposed) {
        _scheduleDrain();
      }
    } catch (_) {
      _statusController.add(AudioPlaybackStatus.error);
    } finally {
      _isPlaying = false;
      if (_queue.isEmpty && _activeSources.isEmpty && !_isDisposed) {
        _nextStartTime = 0;
        _statusController.add(AudioPlaybackStatus.idle);
      }
    }
  }

  Future<void> _waitForActivePlaybackToFinish() async {
    while (_activeSources.isNotEmpty && !_isDisposed) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  void _scheduleDecodedBuffer(dynamic buffer) {
    final source = js_util.callMethod(_audioContext, 'createBufferSource', []);
    js_util.setProperty(source, 'buffer', buffer);
    final destination = js_util.getProperty(_audioContext, 'destination');
    js_util.callMethod(source, 'connect', [destination]);

    final currentTime =
        (js_util.getProperty(_audioContext, 'currentTime') as num).toDouble();
    if (_nextStartTime < currentTime + 0.02) {
      _nextStartTime = currentTime + 0.02;
    }

    js_util.callMethod(source, 'start', [_nextStartTime]);
    _nextStartTime += (js_util.getProperty(buffer, 'duration') as num).toDouble();

    _activeSources.add(source);
    js_util.setProperty(
      source,
      'onended',
      js_util.allowInterop((dynamic _) {
        try {
          js_util.callMethod(source, 'disconnect', []);
        } catch (_) {}
        _activeSources.remove(source);
        if (_activeSources.isEmpty && _queue.isEmpty && !_isDisposed) {
          _statusController.add(AudioPlaybackStatus.idle);
        }
      }),
    );
  }

  Future<dynamic> _decodeChunk(Uint8List chunk) async {
    if (chunk.isEmpty) return null;
    if (_looksLikeContainerAudio(chunk)) {
      try {
        return await js_util.promiseToFuture(
          js_util.callMethod(_audioContext, 'decodeAudioData', [chunk.buffer]),
        );
      } catch (_) {
        return null;
      }
    }

    return _pcmToBuffer(chunk);
  }

  dynamic _pcmToBuffer(Uint8List pcm16) {
    final sampleCount = pcm16.length ~/ 2;
    final floatArray = Float32List(sampleCount);
    final dataView =
        ByteData.view(pcm16.buffer, pcm16.offsetInBytes, pcm16.length);
    for (var i = 0; i < sampleCount; i++) {
      floatArray[i] = dataView.getInt16(i * 2, Endian.little) / 32768.0;
    }

    final buffer = js_util.callMethod(
      _audioContext,
      'createBuffer',
      [1, floatArray.length, 16000],
    );
    final channelData = js_util.callMethod(buffer, 'getChannelData', [0]) as Float32List;
    channelData.setAll(0, floatArray);
    return buffer;
  }

  bool _looksLikeContainerAudio(Uint8List bytes) {
    return _looksLikeWave(bytes) || _looksLikeMpeg(bytes) || _looksLikeOgg(bytes);
  }

  bool _looksLikeWave(Uint8List bytes) {
    return bytes.length > 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41;
  }

  bool _looksLikeMpeg(Uint8List bytes) {
    final hasId3 =
        bytes.length > 3 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33;
    final hasFrameSync =
        bytes.length > 2 && bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0;
    return hasId3 || hasFrameSync;
  }

  bool _looksLikeOgg(Uint8List bytes) {
    return bytes.length > 4 &&
        bytes[0] == 0x4f &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53;
  }

  @override
  Future<void> interrupt() async {
    _queue.clear();
    for (final source in List<dynamic>.from(_activeSources)) {
      try {
        js_util.callMethod(source, 'stop', []);
        js_util.callMethod(source, 'disconnect', []);
      } catch (_) {}
    }
    _activeSources.clear();
    if (_activeUtterance != null) {
      try {
        html.window.speechSynthesis?.cancel();
      } catch (_) {}
      _activeUtterance = null;
    }
    _isSpeakingText = false;
    _isPlaying = false;
    _nextStartTime = 0;
    if (!_isDisposed) {
      _statusController.add(AudioPlaybackStatus.interrupted);
      _statusController.add(AudioPlaybackStatus.idle);
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    await interrupt();
    if (_audioContext != null) {
      final state = js_util.getProperty(_audioContext, 'state');
      if (state != 'closed') {
        await js_util.promiseToFuture(
          js_util.callMethod(_audioContext, 'close', []),
        ).catchError((_) {});
      }
      _audioContext = null;
    }
    await _statusController.close();
  }
}
