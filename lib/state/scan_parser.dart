import 'dart:math' as math;
import 'dart:ui';

import '../data/text_reader.dart';

/// What the camera is pointed at: a shop's printed receipt, or a list
/// written by hand (prices may be missing).
enum ScanMode { receipt, list }

/// An item read from the photo, before the user checks it.
class ScannedItem {
  const ScannedItem({
    required this.name,
    required this.price,
    required this.box,
    this.unsure = false,
  });

  final String name;

  /// Null when no price was written next to it.
  final double? price;

  /// The photo region it was read from (fractions, top-left origin).
  final Rect box;

  /// The recogniser was not confident, or the price was missing or had to
  /// be repaired (`15O.00`): the review sheet asks to check it.
  final bool unsure;
}

class ScanResult {
  const ScanResult({required this.items, this.store});

  final List<ScannedItem> items;

  /// The receipt's heading, usually the shop's name.
  final String? store;
}

/// Turns recognised lines into bag items.
///
/// Lines that sit side by side (a name on the left, its price on the
/// right) are joined into one row first, then each row's trailing number
/// is read as its price.
abstract final class ScanParser {
  static const _lowConfidence = 0.5;

  /// A number at the end of a row, allowing for letters OCR confuses with
  /// digits (O, o, l, I) and a currency mark before or after it.
  static final _price = RegExp(
    r'(?:(?:tk|taka|bdt|rs)\.?|৳)?\s*([0-9OoIl][0-9OoIl,]*(?:\.[0-9Oo]{1,2})?)\s*(?:/-|=|tk|taka|৳)?\s*$',
    caseSensitive: false,
  );
  static final _letters = RegExp(r'[A-Za-zঀ-৿]');
  static final _digit = RegExp(r'[0-9]');

  /// Receipt rows that are bookkeeping, not things bought.
  static final _notAnItem = RegExp(
    r'\b(sub\s*-?total|total|grand|net|vat|tax|cash|change|discount|paid|'
    r'due|balance|amount|invoice|bill|receipt|date|time|tel|phone|mobile|'
    r'thank|visit|again|card|bkash|nagad|rounding|qty|price|item|served)\b',
    caseSensitive: false,
  );
  static final _date = RegExp(r'\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}');
  static final _listHeading = RegExp(
    r'^(bazar|bajar|shopping|grocery|market)?\s*(list|note)s?$',
    caseSensitive: false,
  );
  /// `2 x 225.00` left between a receipt item and its line total.
  static final _quantity = RegExp(
    r'\s+\d+(?:\.\d+)?\s*[x@*]\s*\d+(?:[.,]\d+)?$',
    caseSensitive: false,
  );
  static final _trailingJunk = RegExp(r'[\s.:=_\-–—x*@]+$');
  static final _leadingJunk = RegExp(r'^[\s.:=_\-–—*•·]+|^\d{1,2}[.)]\s+');

  static ScanResult parse(List<TextLine> lines, ScanMode mode) {
    final rows = _rows(lines);
    String? store;
    final items = <ScannedItem>[];

    for (final row in rows) {
      final text = row.text.trim();
      if (!_letters.hasMatch(text)) continue;

      final match = _price.firstMatch(text);
      final rawPrice = match?.group(1);
      double? price;
      var repaired = false;
      var name = text;
      if (match != null && rawPrice != null && _digit.hasMatch(rawPrice)) {
        final fixed = rawPrice
            .replaceAll(RegExp('[Oo]'), '0')
            .replaceAll(RegExp('[Il]'), '1')
            .replaceAll(',', '');
        final value = double.tryParse(fixed);
        // Long digit runs are barcodes and phone numbers, not prices.
        if (value != null && fixed.split('.').first.length <= 6) {
          price = value;
          repaired = fixed != rawPrice.replaceAll(',', '');
          name = text.substring(0, match.start);
        }
      }
      name = _clean(name);

      if (mode == ScanMode.receipt) {
        if (_notAnItem.hasMatch(text) || _date.hasMatch(text)) continue;
        if (price == null || price == 0) {
          // The first priceless line on a receipt is its heading.
          if (store == null && items.isEmpty) store = name;
          continue;
        }
      } else {
        if (items.isEmpty && price == null && _listHeading.hasMatch(name)) {
          continue;
        }
      }
      if (!_letters.hasMatch(name)) continue;

      items.add(
        ScannedItem(
          name: name,
          price: price,
          box: row.box,
          unsure: price == null || repaired || row.confidence < _lowConfidence,
        ),
      );
    }
    return ScanResult(items: items, store: store);
  }

  static String _clean(String name) {
    final trimmed = name
        .replaceAll(_quantity, '')
        .replaceAll(_trailingJunk, '')
        .replaceAll(_leadingJunk, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Groups lines whose vertical centres share a band into rows, each read
  /// left to right.
  static List<_Row> _rows(List<TextLine> lines) {
    final sorted = [...lines]
      ..removeWhere((l) => l.text.trim().isEmpty)
      ..sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));
    final rows = <List<TextLine>>[];
    for (final line in sorted) {
      final last = rows.isEmpty ? null : rows.last;
      if (last != null) {
        final band = last.map((l) => l.box.height).reduce(math.max);
        final centre = last.first.box.center.dy;
        if ((line.box.center.dy - centre).abs() < band * 0.5) {
          last.add(line);
          continue;
        }
      }
      rows.add([line]);
    }
    return [
      for (final row in rows)
        _Row(
          (row..sort((a, b) => a.box.left.compareTo(b.box.left)))
              .map((l) => l.text.trim())
              .join('  '),
          row.map((l) => l.box).reduce((a, b) => a.expandToInclude(b)),
          row.map((l) => l.confidence).reduce(math.min),
        ),
    ];
  }
}

class _Row {
  const _Row(this.text, this.box, this.confidence);

  final String text;
  final Rect box;
  final double confidence;
}
