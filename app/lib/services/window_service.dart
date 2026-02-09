import 'package:flutter/services.dart';

/// Platform channel wrapper for native window management.
class WindowService {
  static const _channel = MethodChannel('com.logger/window');

  /// Set the window's always-on-top state via the native GTK API.
  static Future<void> setAlwaysOnTop(bool value) async {
    await _channel.invokeMethod('setAlwaysOnTop', value);
  }

  /// Minimize (iconify) the window.
  static Future<void> minimize() async {
    await _channel.invokeMethod('minimize');
  }

  /// Toggle maximize / unmaximize.
  static Future<void> maximize() async {
    await _channel.invokeMethod('maximize');
  }

  /// Close the window (fire-and-forget to avoid response lag).
  static void close() {
    _channel.invokeMethod('close');
  }

  /// Query whether the window is currently maximized.
  static Future<bool> isMaximized() async {
    return await _channel.invokeMethod<bool>('isMaximized') ?? false;
  }

  /// Show or hide the native window decoration (title bar).
  static Future<void> setDecorated(bool value) async {
    await _channel.invokeMethod('setDecorated', value);
  }

  /// Initiate a window drag via the native GTK API.
  static Future<void> startDrag() async {
    await _channel.invokeMethod('startDrag');
  }
}
