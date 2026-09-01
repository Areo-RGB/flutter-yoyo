package com.aistudio.yoyoir1.track

import android.media.audiofx.LoudnessEnhancer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.aistudio.yoyoir1/loudness_enhancer"
    private var loudnessEnhancer: LoudnessEnhancer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setGain" -> {
                    val gainMb = call.argument<Int>("gainMb") ?: 0
                    val audioSessionId = call.argument<Int>("audioSessionId")

                    try {
                        if (loudnessEnhancer == null && audioSessionId != null && audioSessionId != 0) {
                            loudnessEnhancer = LoudnessEnhancer(audioSessionId)
                        }
                        
                        loudnessEnhancer?.setTargetGain(gainMb)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        loudnessEnhancer?.enabled = enabled
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "release" -> {
                    try {
                        loudnessEnhancer?.release()
                        loudnessEnhancer = null
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        try {
            loudnessEnhancer?.release()
            loudnessEnhancer = null
        } catch (e: Exception) {
            // Ignore
        }
        super.onDestroy()
    }
}
