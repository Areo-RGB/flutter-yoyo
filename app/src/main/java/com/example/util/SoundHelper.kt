package com.example.util

import android.content.Context
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.ToneGenerator
import android.media.audiofx.LoudnessEnhancer
import android.util.Log
import com.example.R

class SoundHelper(private val context: Context? = null) {
    private var toneGenerator: ToneGenerator? = null
    private var mediaPlayer: MediaPlayer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    var isSoundEnabled: Boolean = true
    var isAudioTrackLoaded: Boolean = false
        private set
    var volumeBoost: Float = 1f
        private set
    var isBoostEnabled: Boolean = false
        private set

    init {
        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 85)
        } catch (_: Exception) {
            toneGenerator = null
        }

        context?.let { ctx ->
            initMediaPlayer(ctx)
        }
    }

    private fun initMediaPlayer(ctx: Context) {
        try {
            mediaPlayer?.release()
            loudnessEnhancer?.release()
            loudnessEnhancer = null
            mediaPlayer = MediaPlayer.create(ctx, R.raw.yoyo_ir1_audio)
            mediaPlayer?.let { mp ->
                if (mp.duration > 0) {
                    isAudioTrackLoaded = true
                }
                applyVolumeBoost()
            }
        } catch (e: Exception) {
            Log.e("SoundHelper", "Could not initialize audio track", e)
            mediaPlayer = null
            isAudioTrackLoaded = false
        }
    }

    fun setVolumeBoost(boost: Float, enabled: Boolean) {
        volumeBoost = boost.coerceIn(1f, 3f)
        isBoostEnabled = enabled
        applyVolumeBoost()
    }

    private fun applyVolumeBoost() {
        val mp = mediaPlayer ?: return
        try {
            if (!isBoostEnabled || volumeBoost <= 1f) {
                loudnessEnhancer?.release()
                loudnessEnhancer = null
                mp.setVolume(1f, 1f)
                return
            }
            // Use MediaPlayer volume for 1x-2x, LoudnessEnhancer for extra gain
            val vol = volumeBoost.coerceIn(1f, 2f)
            mp.setVolume(
                vol.coerceAtMost(1f) * if (volumeBoost > 1f) 1f else 1f,
                vol.coerceAtMost(1f) * if (volumeBoost > 1f) 1f else 1f
            )
            // For boost > 1, apply LoudnessEnhancer (gain in mB, ~ +10dB per 1x extra)
            val audioSessionId = mp.audioSessionId
            if (audioSessionId != AudioManager.ERROR && volumeBoost > 1f) {
                if (loudnessEnhancer == null) {
                    loudnessEnhancer = LoudnessEnhancer(audioSessionId)
                }
                val gainMb = ((volumeBoost - 1f) * 1000).toInt().coerceIn(0, 2000)
                loudnessEnhancer?.setTargetGain(gainMb)
                loudnessEnhancer?.enabled = true
                // Ensure full output volume
                mp.setVolume(1f, 1f)
            }
        } catch (e: Exception) {
            Log.e("SoundHelper", "Failed to apply volume boost", e)
        }
    }

    fun startAudioTrack() {
        if (!isSoundEnabled) return
        try {
            if (mediaPlayer == null && context != null) {
                initMediaPlayer(context)
            }
            mediaPlayer?.let { mp ->
                if (!mp.isPlaying) {
                    mp.seekTo(0)
                    mp.start()
                }
            }
        } catch (e: Exception) {
            Log.e("SoundHelper", "Failed to start audio track", e)
        }
    }

    fun pauseAudioTrack() {
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.pause()
            }
        } catch (_: Exception) {
        }
    }

    fun resumeAudioTrack() {
        if (!isSoundEnabled) return
        try {
            mediaPlayer?.let { mp ->
                if (!mp.isPlaying) {
                    mp.start()
                }
            }
        } catch (_: Exception) {
        }
    }

    fun stopAudioTrack() {
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.pause()
                mediaPlayer?.seekTo(0)
            }
        } catch (_: Exception) {
        }
    }

    fun resetAudioTrack() {
        try {
            mediaPlayer?.pause()
            mediaPlayer?.seekTo(0)
        } catch (_: Exception) {
        }
    }

    fun seekAudioTrackTo(positionMs: Long) {
        try {
            mediaPlayer?.seekTo(positionMs.toInt().coerceAtLeast(0))
        } catch (_: Exception) {
        }
    }

    fun setSoundEnabledState(enabled: Boolean) {
        isSoundEnabled = enabled
        if (!enabled) {
            pauseAudioTrack()
        }
    }

    fun playStartBeep() {
        if (!isSoundEnabled) return
        try {
            toneGenerator?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 200)
        } catch (_: Exception) {
        }
    }

    fun playWarningBeep() {
        if (!isSoundEnabled) return
        try {
            toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP2, 150)
        } catch (_: Exception) {
        }
    }

    fun playEliminationBeep() {
        if (!isSoundEnabled) return
        try {
            toneGenerator?.startTone(ToneGenerator.TONE_CDMA_LOW_PBX_L, 300)
        } catch (_: Exception) {
        }
    }

    fun playCountdownBeep() {
        if (!isSoundEnabled) return
        try {
            toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 80)
        } catch (_: Exception) {
        }
    }

    fun release() {
        try {
            loudnessEnhancer?.release()
            loudnessEnhancer = null
        } catch (_: Exception) {
        }
        try {
            toneGenerator?.release()
            toneGenerator = null
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {
        }
    }
}
