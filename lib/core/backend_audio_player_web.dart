import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

export 'backend_audio_player_stub.dart';
import 'backend_audio_player_stub.dart';

BackendAudioPlayer createBackendAudioPlayer() => _WebBackendAudioPlayer();

class _WebBackendAudioPlayer implements BackendAudioPlayer {
  html.AudioElement? _audio;
  String? _objectUrl;
  bool _primed = false;
  int _playbackSeq = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> prime() async {
    if (_primed) return;
    final unlock = html.AudioElement()
      ..src =
          'data:audio/mpeg;base64,//uQxAAAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAACAAACcQCA'
      ..muted = true
      ..autoplay = false;
    try {
      await unlock.play();
      unlock.pause();
      _primed = true;
    } catch (_) {
      // Keep unprimed; we'll still try normal playback later.
    }
  }

  @override
  Future<void> playBytes({
    required Uint8List bytes,
    String mimeType = 'audio/mpeg',
  }) async {
    if (bytes.isEmpty) return;
    final playable = _toPlayableAudio(bytes, mimeType);
    final estimatedMs = _estimateDurationMs(playable.bytes, playable.mimeType);
    _log(
      'playBytes request bytes=${bytes.length} '
      'resolvedMime=${playable.mimeType} estimatedMs=$estimatedMs',
    );
    await _playBlob(bytes: playable.bytes, mimeType: playable.mimeType);
  }

  @override
  Future<void> playBase64({
    required String base64Audio,
    String mimeType = 'audio/mpeg',
  }) async {
    if (base64Audio.trim().isEmpty) return;

    final normalized = base64Audio.trim();
    final src = normalized.startsWith('data:')
        ? normalized
        : 'data:$mimeType;base64,$normalized';

    _audio?.pause();
    _revokeObjectUrl();
    final audio = html.AudioElement()
      ..src = src
      ..preload = 'auto'
      ..autoplay = true;
    _audio = audio;
    final playbackId = ++_playbackSeq;
    _log(
      'playBase64[$playbackId] start mime=$mimeType '
      'srcPrefix=${src.substring(0, src.length > 24 ? 24 : src.length)}',
    );

    try {
      await audio.play();
      _log('playBase64[$playbackId] play() started');
      await _waitForPlaybackToFinish(audio);
      _log('playBase64[$playbackId] playback finished');
    } catch (e) {
      _log('playBase64[$playbackId] playback failed: $e');
    }
  }

  @override
  Future<void> speakText(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    final synth = html.window.speechSynthesis;
    if (synth == null) return;
    try {
      synth.cancel();
      final utterance = html.SpeechSynthesisUtterance(value)
        ..rate = 1.0
        ..pitch = 1.0
        ..volume = 1.0;
      _log('speakText length=${value.length}');
      synth.speak(utterance);
    } catch (e) {
      _log('speech synthesis failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _audio?.pause();
    _audio = null;
    _revokeObjectUrl();
  }

  Future<void> _playBlob({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    _audio?.pause();
    _revokeObjectUrl();
    final playbackId = ++_playbackSeq;
    final estimatedMs = _estimateDurationMs(bytes, mimeType);

    final blob = html.Blob(<Object>[bytes], mimeType);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    _objectUrl = objectUrl;
    _log(
      'playBlob[$playbackId] created objectUrl mime=$mimeType bytes=${bytes.length} '
      'estimatedMs=$estimatedMs',
    );

    final audio = html.AudioElement()
      ..src = objectUrl
      ..preload = 'auto'
      ..autoplay = true;
    _audio = audio;
    audio.onCanPlay.listen((_) {
      _log('playBlob[$playbackId] canPlay currentTime=${audio.currentTime}');
    });
    audio.onError.listen((_) {
      _log('playBlob[$playbackId] audio element error for $mimeType');
    });

    try {
      await audio.play();
      _log('playBlob[$playbackId] play() started');
      await _waitForPlaybackToFinish(audio);
      _log('playBlob[$playbackId] playback finished');
    } catch (e) {
      _log('playBlob[$playbackId] playback failed: $e');
    }
  }

  Future<void> _waitForPlaybackToFinish(html.AudioElement audio) {
    final completer = Completer<void>();
    late final StreamSubscription endedSub;
    late final StreamSubscription errorSub;
    late final StreamSubscription pauseSub;

    void complete() {
      if (completer.isCompleted) return;
      endedSub.cancel();
      errorSub.cancel();
      pauseSub.cancel();
      completer.complete();
    }

    endedSub = audio.onEnded.listen((_) => complete());
    errorSub = audio.onError.listen((_) => complete());
    pauseSub = audio.onPause.listen((_) => complete());
    return completer.future;
  }

  void _revokeObjectUrl() {
    final url = _objectUrl;
    if (url == null) return;
    html.Url.revokeObjectUrl(url);
    _log('objectUrl revoked');
    _objectUrl = null;
  }

  _PlayableAudio _toPlayableAudio(Uint8List bytes, String fallbackMimeType) {
    if (_looksLikeWave(bytes)) {
      return _PlayableAudio(bytes, 'audio/wav');
    }
    if (_looksLikeOgg(bytes)) {
      return _PlayableAudio(bytes, 'audio/ogg');
    }
    if (_looksLikeMpeg(bytes)) {
      return _PlayableAudio(bytes, 'audio/mpeg');
    }
    if (fallbackMimeType != 'audio/mpeg') {
      return _PlayableAudio(bytes, fallbackMimeType);
    }

    // Raw PCM needs a container before the browser AudioElement can play it.
    return _PlayableAudio(_wrapPcm16MonoAsWav(bytes), 'audio/wav');
  }

  bool _looksLikeWave(Uint8List bytes) {
    return bytes.length > 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
  }

  bool _looksLikeOgg(Uint8List bytes) {
    return bytes.length > 4 &&
        bytes[0] == 0x4f &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53;
  }

  bool _looksLikeMpeg(Uint8List bytes) {
    final hasId3 = bytes.length > 3 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33;
    final hasFrameSync =
        bytes.length > 2 && bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0;
    return hasId3 || hasFrameSync;
  }

  Uint8List _wrapPcm16MonoAsWav(Uint8List pcmBytes) {
    const sampleRate = 16000;
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final wav = Uint8List(44 + pcmBytes.length);
    final data = ByteData.view(wav.buffer);

    _writeAscii(wav, 0, 'RIFF');
    data.setUint32(4, 36 + pcmBytes.length, Endian.little);
    _writeAscii(wav, 8, 'WAVE');
    _writeAscii(wav, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, blockAlign, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    _writeAscii(wav, 36, 'data');
    data.setUint32(40, pcmBytes.length, Endian.little);
    wav.setRange(44, wav.length, pcmBytes);
    return wav;
  }

  void _writeAscii(Uint8List bytes, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes[offset + i] = value.codeUnitAt(i);
    }
  }

  int _estimateDurationMs(Uint8List bytes, String mimeType) {
    if (bytes.isEmpty) return 0;
    if (mimeType == 'audio/wav') {
      final bytesPerSecond = 16000 * 2;
      return (bytes.length * 1000) ~/ bytesPerSecond;
    }
    return -1;
  }

  void _log(String msg) => debugPrint('[BackendAudioPlayer] $msg');
}

class _PlayableAudio {
  final Uint8List bytes;
  final String mimeType;

  const _PlayableAudio(this.bytes, this.mimeType);
}
