import 'package:flutter/services.dart';

/// One line of text found in a photo.
class TextLine {
  const TextLine(this.text, this.box, {this.confidence = 1});

  final String text;

  /// Where it sits, as fractions of the upright photo (top-left origin).
  final Rect box;

  /// 0..1, as the recogniser reports it.
  final double confidence;
}

/// Reads the text in a photo on the device: Apple's Vision framework on
/// iOS, ML Kit on Android (see AppDelegate.swift and MainActivity.kt).
abstract final class TextReader {
  static const _channel = MethodChannel('daily_bag/text_reader');

  static Future<List<TextLine>> read(String path) async {
    final raw = await _channel.invokeListMethod<Map>('read', {'path': path});
    return [
      for (final m in raw ?? const <Map>[])
        TextLine(
          m['text'] as String,
          Rect.fromLTWH(
            (m['x'] as num).toDouble(),
            (m['y'] as num).toDouble(),
            (m['w'] as num).toDouble(),
            (m['h'] as num).toDouble(),
          ),
          confidence: (m['confidence'] as num).toDouble(),
        ),
    ];
  }
}
