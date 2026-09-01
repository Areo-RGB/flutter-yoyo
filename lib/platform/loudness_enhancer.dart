import 'package:flutter/services.dart';

class LoudnessEnhancerService {
  static const MethodChannel _channel = MethodChannel('com.aistudio.yoyoir1/loudness_enhancer');

  static Future<void> setGain(double boost, {int? audioSessionId}) async {
    try {
      // Convert multiplier to millibels gain
      final int gainMb = ((boost - 1.0) * 1000).toInt().clamp(0, 2000);
      
      final Map<String, dynamic> arguments = {
        'gainMb': gainMb,
      };
      if (audioSessionId != null) {
        arguments['audioSessionId'] = audioSessionId;
      }
      
      await _channel.invokeMethod('setGain', arguments);
    } catch (e) {
      // Safely catch platform errors silently cross-platform
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (e) {
      // Safely catch platform errors silently
    }
  }

  static Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
    } catch (e) {
      // Safely catch platform errors silently
    }
  }
}
