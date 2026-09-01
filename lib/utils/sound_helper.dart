import 'package:audioplayers/audioplayers.dart';

class SoundHelper {
  final AudioPlayer _mainTrackPlayer = AudioPlayer();
  bool _isSoundEnabled = true;
  bool _isPrewarmed = false;

  Future<void> init() async {
    try {
      await _mainTrackPlayer.setReleaseMode(ReleaseMode.stop);
      await _mainTrackPlayer.setSource(AssetSource('audio/audio.mp3'));
      _isPrewarmed = true;
    } catch (e) {
      // Handle audio errors silently
    }
  }

  void startAudioTrack() {
    if (!_isSoundEnabled) return;
    unawaited(() async {
      try {
        if (!_isPrewarmed) {
          await _mainTrackPlayer.setSource(AssetSource('audio/audio.mp3'));
          _isPrewarmed = true;
        }
        await _mainTrackPlayer.seek(Duration.zero);
        await _mainTrackPlayer.resume();
      } catch (e) {
        // Fallback if resume fails
        try {
          await _mainTrackPlayer.play(AssetSource('audio/audio.mp3'));
        } catch (_) {}
      }
    }());
  }

  void pauseAudioTrack() {
    unawaited(_mainTrackPlayer.pause());
  }

  void resumeAudioTrack() {
    if (!_isSoundEnabled) return;
    unawaited(_mainTrackPlayer.resume());
  }

  void stopAudioTrack() {
    unawaited(() async {
      try {
        await _mainTrackPlayer.pause();
        await _mainTrackPlayer.seek(Duration.zero);
      } catch (_) {}
    }());
  }

  void resetAudioTrack() {
    stopAudioTrack();
  }

  void seekAudioTrackTo(int positionMs) {
    unawaited(_mainTrackPlayer.seek(Duration(milliseconds: positionMs)));
  }

  void setSoundEnabledState(bool enabled) {
    _isSoundEnabled = enabled;
    if (!enabled) {
      pauseAudioTrack();
    } else {
      resumeAudioTrack();
    }
  }

  void playStartBeep() {}
  void playWarningBeep() {}
  void playEliminationBeep() {}
  void playCountdownBeep() {}

  void setVolumeBoost(double boost, bool enabled) {}

  void dispose() {
    unawaited(_mainTrackPlayer.dispose());
  }

  void unawaited(Future<void>? future) {
    future?.catchError((_) {});
  }
}
