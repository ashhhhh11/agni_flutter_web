import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';

export 'backend_audio_player_stub.dart';
import 'backend_audio_player_stub.dart';

BackendAudioPlayer createBackendAudioPlayer() => _WebBackendAudioPlayer();

class _WebBackendAudioPlayer implements BackendAudioPlayer {
  html.AudioElement? _audio;
  bool _primed = false;

  @override
  bool get isSupported => true;

  @override
  Future<void> prime() async {
    if (_primed) return;
    final unlock = html.AudioElement()
      ..src = 'data:audio/mpeg;base64,//uQxAAAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAACAAACcQCA'
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
    await playBase64(
      base64Audio: base64Encode(bytes),
      mimeType: mimeType,
    );
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
    final audio = html.AudioElement()
      ..src = src
      ..preload = 'auto'
      ..autoplay = true;
    _audio = audio;

    try {
      await audio.play();
    } catch (e) {
      print('[BackendAudioPlayer] playback failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _audio?.pause();
    _audio = null;
  }
}
