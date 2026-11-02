import 'dart:io';
import 'dart:ui';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:little_expense/data/excel_export.dart';
import 'package:little_expense/state/expense_store.dart';
import 'package:little_expense/widgets/line_icon.dart';

void main() {
  test('the workbook lists every item, with thoughts and a total', () {
    final days = ExpenseStore.demo().days;
    final bytes = ExcelExport.workbook(days, currency: 'BDT');
    final sheet = Excel.decodeBytes(bytes).tables['Expenses']!;
    final rows = [
      for (final row in sheet.rows) [for (final c in row) c?.value],
    ];

    expect(rows.first.map((v) => '$v'), [
      'Date',
      'Day',
      'Item',
      'Amount (BDT)',
      'Bazar thoughts',
    ]);
    // 15 items in the demo, plus the header and total rows.
    expect(rows, hasLength(17));
    expect('${rows[1][2]}', 'Rice');
    expect('${rows[1][1]}', 'Thursday');
    final beefDay = rows.indexWhere((r) => '${r[2]}' == 'Potato');
    expect('${rows[beefDay][4]}', startsWith('Beef was fresh today'));
    expect('${rows[beefDay + 1][4]}', 'null');
    expect('${rows.last[0]}', 'Total');
    expect(num.parse('${rows.last[3]}'), 5470);
  });

  test('writing reports steady progress up to 100%', () async {
    final dir = await Directory.systemTemp.createTemp('daily_bag_export');
    addTearDown(() => dir.delete(recursive: true));
    final seen = <double>[];
    final file = await ExcelExport.write(
      ExpenseStore.demo().days,
      currency: 'BDT',
      now: DateTime(2026, 11, 3),
      into: dir,
      onProgress: seen.add,
    );

    expect(file.path, endsWith('Daily-Bag-2026.xlsx'));
    expect(await file.length(), greaterThan(0));
    expect(seen.first, 0);
    expect(seen.last, 1);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
    }
    // A step per day, plus encoding and saving.
    expect(seen.length, ExpenseStore.demo().days.length + 3);
  });

  test('the export is named for the year', () {
    expect(ExcelExport.fileName(DateTime(2026, 11, 2)), 'Daily-Bag-2026.xlsx');
  });

  test('SVG path data draws the same box as the direct path', () {
    final path = Path();
    svgPath(path, 'M4 9h16v6H4z');
    expect(path.getBounds(), const Rect.fromLTRB(4, 9, 20, 15));

    final arc = Path();
    svgPath(arc, 'M9 8V6.5a3 3 0 0 1 6 0V8');
    final bounds = arc.getBounds();
    expect(bounds.left, closeTo(9, 0.01));
    expect(bounds.right, closeTo(15, 0.01));
    // The arc bulges up to the top of its 3-unit radius.
    expect(bounds.top, closeTo(3.5, 0.05));
  });
}
