import 'package:flutter/services.dart';

/// POS Terminal Physical & Sound Feedback Helper
class FeedbackHelper {
  FeedbackHelper._();

  static const MethodChannel _channel = MethodChannel('com.onimta.mobile_pos/feedback');

  /// Trigger audible cash-register scanner beep and hardware vibration
  static Future<void> playScanFeedback() async {
    try {
      await _channel.invokeMethod('beepAndVibrate');
    } catch (_) {
      try {
        HapticFeedback.vibrate();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Trigger hardware vibration only
  static Future<void> vibrate() async {
    try {
      await _channel.invokeMethod('vibrate');
    } catch (_) {
      try {
        HapticFeedback.vibrate();
      } catch (_) {}
    }
  }
}
