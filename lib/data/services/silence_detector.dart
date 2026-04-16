import 'dart:async';

class SilenceDetector {
  final double threshold;
  final Duration silenceDuration;
  final Duration minActiveListening;

  final _silenceStateController = StreamController<bool>.broadcast();

  DateTime? _lastVoiceActivityAt;
  DateTime? _startedAt;
  bool _hasTriggered = false;

  void Function()? onSilenceDetected;

  SilenceDetector({
    this.threshold = 0.015,
    this.silenceDuration = const Duration(milliseconds: 2000),
    this.minActiveListening = const Duration(milliseconds: 800),
    this.onSilenceDetected,
  });

  Stream<bool> get silenceStateStream => _silenceStateController.stream;

  void reset() {
    _startedAt = DateTime.now();
    _lastVoiceActivityAt = _startedAt;
    _hasTriggered = false;
    _silenceStateController.add(false);
  }

  void updateVolume(double rms) {
    if (_startedAt == null || _hasTriggered) return;

    final now = DateTime.now();
    if (rms > threshold) {
      _lastVoiceActivityAt = now;
      _silenceStateController.add(false);
      return;
    }

    final lastActivity = _lastVoiceActivityAt ?? _startedAt!;
    final hasExceededSilence = now.difference(lastActivity) >= silenceDuration;
    final hasWaitedLongEnough =
        now.difference(_startedAt!) >= minActiveListening;

    _silenceStateController.add(hasExceededSilence);

    if (hasExceededSilence && hasWaitedLongEnough) {
      _hasTriggered = true;
      onSilenceDetected?.call();
    }
  }

  void dispose() {
    unawaited(_silenceStateController.close());
  }
}
