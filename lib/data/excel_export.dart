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
    final out = _Workbook();
    _build(days, currency, out).forEach((_) {});
    return out.bytes!;
  }

  /// Builds the sheet a day at a time, yielding how far along it is (0–1,
  /// encoding included) so a caller can report progress and stay responsive.
  static Iterable<double> _build(
    List<DayNote> days,
    String currency,
    _Workbook out,
  ) sync* {
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
    for (var d = 0; d < days.length; d++) {
      final day = days[d];
      yield _rowsShare * d / days.length;
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
    yield _rowsShare;

    out.bytes = excel.encode()!;
    yield 1;
  }

  /// Rows take most of the work; encoding the zip takes the rest.
  static const _rowsShare = 0.8;

  /// Writes the workbook to a temporary file, ready to share.
  ///
  /// [onProgress] hears 0–1 as the sheet is built, encoded and saved. The
  /// work pauses for a frame every few milliseconds so the UI can animate.
  static Future<File> write(
    List<DayNote> days, {
    required String currency,
    DateTime? now,
    void Function(double progress)? onProgress,
    Directory? into,
  }) async {
    final out = _Workbook();
    final slice = Stopwatch()..start();
    for (final step in _build(days, currency, out)) {
      // Saving the file is the last 5%.
      onProgress?.call(step * 0.95);
      if (slice.elapsedMilliseconds > 8) {
        await Future<void>.delayed(Duration.zero);
        slice.reset();
      }
    }
    final dir = into ?? await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName(now ?? DateTime.now())));
    await file.writeAsBytes(out.bytes!, flush: true);
    onProgress?.call(1);
    return file;
  }
}

class _Workbook {
  List<int>? bytes;
}
