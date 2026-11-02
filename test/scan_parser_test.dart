import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_expense/data/text_reader.dart';
import 'package:little_expense/state/scan_parser.dart';

/// Lines stacked down the page, one per entry; a `|` splits an entry
/// into a left and right observation on the same row, as Vision reports
/// a name and a far-right price.
List<TextLine> page(List<String> entries, {double confidence = 0.9}) => [
  for (var i = 0; i < entries.length; i++)
    for (final (j, part) in entries[i].split('|').indexed)
      TextLine(
        part,
        Rect.fromLTWH(j == 0 ? 0.1 : 0.7, 0.05 + i * 0.06, 0.2, 0.04),
        confidence: confidence,
      ),
];

void main() {
  group('ScanParser', () {
    test('reads the design receipt, skipping header and totals', () {
      final result = ScanParser.parse(
        page([
          'RAHIM GENERAL STORE',
          'Mirpur 10 · 02/03/2026',
          'Rice 5kg|450.00',
          'Onion 1kg|120.00',
          'Eggs 12pc|15O.00',
          'Soybean oil 1L|190.00',
          'TOTAL|910.00',
          'Thank you · Come again',
        ]),
        ScanMode.receipt,
      );
      expect(result.store, 'RAHIM GENERAL STORE');
      expect(result.items.map((i) => i.name), [
        'Rice 5kg',
        'Onion 1kg',
        'Eggs 12pc',
        'Soybean oil 1L',
      ]);
      expect(result.items.map((i) => i.price), [450, 120, 150, 190]);
      // "15O.00" had a letter O read for a zero.
      expect(result.items.map((i) => i.unsure), [false, false, true, false]);
    });

    test('reads a written list, flagging repaired and missing prices', () {
      final result = ScanParser.parse(
        page(['Bazar list', 'Alu 1kg  60', 'Peyaj 120', 'Dim 12ta', 'Kacha morich  2o']),
        ScanMode.list,
      );
      expect(result.store, isNull);
      expect(result.items.map((i) => i.name), [
        'Alu 1kg',
        'Peyaj',
        'Dim 12ta',
        'Kacha morich',
      ]);
      expect(result.items.map((i) => i.price), [60, 120, null, 20]);
      expect(result.items.map((i) => i.unsure), [false, false, true, true]);
    });

    test('drops the quantity between an item and its line total', () {
      final result = ScanParser.parse(
        page(['Shop', 'Milk 2 x 90.00|180.00', 'Bread|Tk 60']),
        ScanMode.receipt,
      );
      expect(result.items.map((i) => (i.name, i.price)), [
        ('Milk', 180),
        ('Bread', 60),
      ]);
    });

    test('low recogniser confidence asks for a check', () {
      final result = ScanParser.parse(
        page(['Tea|40'], confidence: 0.3),
        ScanMode.list,
      );
      expect(result.items.single.unsure, isTrue);
    });

    test('a row box covers both its name and its price', () {
      final item = ScanParser.parse(
        page(['Shop', 'Tea|40']),
        ScanMode.receipt,
      ).items.single;
      expect(item.box.left, closeTo(0.1, 1e-9));
      expect(item.box.right, closeTo(0.9, 1e-9));
    });
  });
}
