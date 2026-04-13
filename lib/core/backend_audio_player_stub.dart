import 'dart:typed_data';

abstract class BackendAudioPlayer {
  bool get isSupported;

  Future<void> prime();

  Future<void> playBytes({
    required Uint8List bytes,
    String mimeType = 'audio/mpeg',
  });

  Future<void> playBase64({
    required String base64Audio,
    String mimeType = 'audio/mpeg',
  });

  Future<void> dispose();
}

BackendAudioPlayer createBackendAudioPlayer() => _UnsupportedBackendAudioPlayer();

class _UnsupportedBackendAudioPlayer implements BackendAudioPlayer {
  @override
  bool get isSupported => false;

  @override
  Future<void> prime() async {}

  @override
  Future<void> playBytes({
    required Uint8List bytes,
    String mimeType = 'audio/mpeg',
  }) async {}

  @override
  Future<void> playBase64({
    required String base64Audio,
    String mimeType = 'audio/mpeg',
  }) async {}

  @override
  Future<void> dispose() async {}
}
