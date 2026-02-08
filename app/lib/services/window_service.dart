import 'package:flutter/services.dart';

/// Platform channel wrapper for native window management.
class WindowService {
  static const _channel = MethodChannel('com.logger/window');

  /// Set the window's always-on-top state via the native GTK API.
  static Future<void> setAlwaysOnTop(bool value) async {
    await _channel.invokeMethod('setAlwaysOnTop', value);
  }
}
