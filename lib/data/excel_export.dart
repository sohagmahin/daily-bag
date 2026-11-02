import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app/format.dart';
import '../models/expense.dart';

/// "Export to Excel": every expense as a row of one sheet, oldest first,
/// with each day's Bazar thoughts beside its first item and a grand total.
abstract final class ExcelExport {
  static const _sheet = 'Expenses';

  /// `Daily-Bag-2026.xlsx`
  static String fileName(DateTime now) => 'Daily-Bag-${now.year}.xlsx';

  static List<int> workbook(List<DayNote> days, {required String currency}) {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, _sheet);
    final bold = CellStyle(bold: true);

    void row(List<CellValue?> cells, {bool strong = false}) {
      excel.appendRow(_sheet, cells);
      if (!strong) return;
      final sheet = excel[_sheet];
      for (var c = 0; c < cells.length; c++) {
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: c,
                    rowIndex: sheet.maxRows - 1,
                  ),
                )
                .cellStyle =
            bold;
      }
    }

    row([
      TextCellValue('Date'),
      TextCellValue('Day'),
      TextCellValue('Item'),
      TextCellValue('Amount ($currency)'),
      TextCellValue('Bazar thoughts'),
    ], strong: true);

    var total = 0.0;
    for (final day in days) {
      final date = DateCellValue(
        year: day.date.year,
        month: day.date.month,
        day: day.date.day,
      );
      final weekday = TextCellValue(weekdayName(day.date));
      final thoughts = day.hasThoughts ? TextCellValue(day.thoughts) : null;
      if (day.items.isEmpty) {
        row([date, weekday, null, null, thoughts]);
        continue;
      }
      for (var i = 0; i < day.items.length; i++) {
        final item = day.items[i];
        total += item.amount;
        row([
          date,
          weekday,
          TextCellValue(item.name),
          DoubleCellValue(item.amount),
          i == 0 ? thoughts : null,
        ]);
      }
    }
    row([
      TextCellValue('Total'),
      null,
      null,
      DoubleCellValue(total),
      null,
    ], strong: true);

    return excel.encode()!;
  }

  /// Writes the workbook to a temporary file, ready to share.
  static Future<File> write(
    List<DayNote> days, {
    required String currency,
    DateTime? now,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName(now ?? DateTime.now())));
    return file.writeAsBytes(workbook(days, currency: currency), flush: true);
  }
}
