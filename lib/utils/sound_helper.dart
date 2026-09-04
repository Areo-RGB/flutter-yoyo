import 'package:audioplayers/audioplayers.dart';

class SoundHelper {
  final AudioPlayer _mainTrackPlayer = AudioPlayer();
  bool _isSoundEnabled = true;
  String _currentAsset = 'audio/audio.mp3';
  int _audioStartOffsetMs = 0;

  Future<void> init({String asset = 'audio/audio.mp3'}) async {
    try {
      _currentAsset = asset;
      await _mainTrackPlayer.setReleaseMode(ReleaseMode.stop);
      await _mainTrackPlayer.setSource(AssetSource(_currentAsset));
    } catch (e) {
      // Handle audio errors silently
    }
  }

  void startAudioTrack({String? assetPath, int startOffsetMs = 0}) {
    if (!_isSoundEnabled) return;
    unawaited(() async {
      try {
        final targetAsset = assetPath ?? _currentAsset;
        _currentAsset = targetAsset;
        _audioStartOffsetMs = startOffsetMs;

        await _mainTrackPlayer.setSource(AssetSource(targetAsset));
        await _mainTrackPlayer.seek(Duration(milliseconds: startOffsetMs));
        await _mainTrackPlayer.resume();
      } catch (e) {
        try {
          await _mainTrackPlayer.play(AssetSource(assetPath ?? _currentAsset));
          if (startOffsetMs > 0) {
            await _mainTrackPlayer.seek(Duration(milliseconds: startOffsetMs));
          }
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
        await _mainTrackPlayer.seek(Duration(milliseconds: _audioStartOffsetMs));
      } catch (_) {}
    }());
  }

  void resetAudioTrack() {
    stopAudioTrack();
  }

  void seekAudioTrackTo(int elapsedMs) {
    unawaited(_mainTrackPlayer.seek(Duration(milliseconds: _audioStartOffsetMs + elapsedMs)));
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
