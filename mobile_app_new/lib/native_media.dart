import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Bridge to the native (Kotlin) MethodChannel for saving an image to the
/// phone's gallery and sharing it (WhatsApp, etc.). Reuses the existing
/// 'ai_locker/image_picker' channel — no third-party plugins required.
class NativeMedia {
  static const _channel = MethodChannel('ai_locker/image_picker');

  /// Saves image bytes into the phone gallery (Pictures/AI Smart Locker).
  /// Returns true on success.
  static Future<bool> saveToGallery(Uint8List bytes, String name) async {
    try {
      final ok = await _channel.invokeMethod<bool>('saveImageToGallery', {
        'bytes': bytes,
        'name': name,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system share sheet (WhatsApp, Gmail, etc.) for the image.
  static Future<void> shareImage(Uint8List bytes, String name,
      {String text = ''}) async {
    try {
      await _channel.invokeMethod('shareImage', {
        'bytes': bytes,
        'name': name,
        'text': text,
      });
    } catch (_) {}
  }
}
