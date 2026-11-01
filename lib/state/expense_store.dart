import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../app/format.dart';
import '../data/expense_database.dart';
import '../models/expense.dart';

/// App-wide expense state: every day's note, how they are grouped, and
/// which day or month is open.
///
/// Reads are served from memory; when a [database] is attached, every
/// change is also written to it, in order, in the background.
class ExpenseStore extends ChangeNotifier {
  ExpenseStore({
    Map<DateTime, List<Expense>> days = const {},
    DateTime? selectedDay,
    GroupMode mode = GroupMode.day,
    ExpenseDatabase? database,
  }) : _mode = mode,
       _database = database {
    days.forEach((date, items) => _days[dateOnly(date)] = List.of(items));
    _selectedDay = selectedDay != null
        ? dateOnly(selectedDay)
        : (_days.isEmpty ? null : _days.lastKey());
  }

  /// Restores what was saved on this device. Opens on the latest day.
  static Future<ExpenseStore> load(ExpenseDatabase database) async =>
      ExpenseStore(
        days: await database.loadDays(),
        mode: await database.loadMode(),
        database: database,
      );

  /// The data shown on the design canvas, in memory only (tests use it).
  factory ExpenseStore.demo() => ExpenseStore(
    selectedDay: DateTime(2026, 2, 20),
    days: {
      DateTime(2026, 2, 12): const [
        Expense(name: 'Rice', amount: 600),
        Expense(name: 'Soybean oil', amount: 420),
        Expense(name: 'Eggs', amount: 280),
        Expense(name: 'Onion', amount: 240),
      ],
      DateTime(2026, 2, 13): const [
        Expense(name: 'Chicken', amount: 650),
        Expense(name: 'Milk', amount: 260),
        Expense(name: 'Bread', amount: 150),
      ],
      DateTime(2026, 2, 20): const [
        Expense(name: 'Potato', amount: 200),
        Expense(name: 'Beef', amount: 820),
        Expense(name: 'Jira', amount: 200),
      ],
      DateTime(2026, 2, 26): const [
        Expense(name: 'Fish', amount: 520),
        Expense(name: 'Tomato', amount: 180),
      ],
      DateTime(2026, 3, 2): const [
        Expense(name: 'Rice', amount: 450),
        Expense(name: 'Lentils', amount: 160),
        Expense(name: 'Vegetables', amount: 340),
      ],
    },
  );

  static const chartLength = 5;

  final ExpenseDatabase? _database;
  final _days = SplayTreeMap<DateTime, List<Expense>>();
  GroupMode _mode;
  DateTime? _selectedDay;
  DateTime? _selectedMonth;
  Future<void> _writes = Future.value();

  GroupMode get mode => _mode;
  DateTime? get selectedDay => _selectedDay;

  /// The month whose days are listed, or that is open in month view.
  DateTime? get focusedMonth => switch (_mode) {
    GroupMode.day => _selectedDay == null ? null : monthOf(_selectedDay!),
    GroupMode.month =>
      _selectedMonth ?? (_selectedDay == null ? null : monthOf(_selectedDay!)),
  };

  String get eyebrow {
    final month = focusedMonth;
    if (month == null) return monthTitle(DateTime.now());
    return _mode == GroupMode.day ? monthTitle(month) : '${month.year}';
  }

  List<DayNote> get days => [
    for (final e in _days.entries) DayNote(e.key, e.value),
  ];

  List<DayNote> get daysInFocusedMonth {
    final month = focusedMonth;
    if (month == null) return const [];
    return [
      for (final e in _days.entries)
        if (isSameMonth(e.key, month)) DayNote(e.key, e.value),
    ];
  }

  List<MonthSummary> get months {
    final grouped = SplayTreeMap<DateTime, List<DayNote>>();
    for (final day in days) {
      grouped.putIfAbsent(monthOf(day.date), () => []).add(day);
    }
    return [for (final e in grouped.entries) MonthSummary(e.key, e.value)];
  }

  DayNote? dayFor(DateTime date) {
    final items = _days[dateOnly(date)];
    return items == null ? null : DayNote(dateOnly(date), items);
  }

  /// The last five days (or months) with spending, oldest first.
  List<ChartBar> get chartBars {
    if (_mode == GroupMode.month) {
      final all = months;
      final focused = focusedMonth;
      return [
        for (final m in all.skip(_tailStart(all.length)))
          ChartBar(
            key: m.month,
            label: shortMonthName(m.month),
            semanticLabel: '${monthTitle(m.month)}, ${formatTaka(m.total)}',
            value: m.total,
            selected: focused != null && isSameMonth(m.month, focused),
          ),
      ];
    }
    final all = days;
    return [
      for (final d in all.skip(_tailStart(all.length)))
        ChartBar(
          key: d.date,
          label: twoDigits(d.date.day),
          semanticLabel: '${shortDay(d.date)}, ${formatTaka(d.total)}',
          value: d.total,
          selected: _selectedDay != null && isSameDay(d.date, _selectedDay!),
        ),
    ];
  }

  int _tailStart(int length) => length > chartLength ? length - chartLength : 0;

  void setMode(GroupMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    if (mode == GroupMode.month && _selectedDay != null) {
      _selectedMonth = monthOf(_selectedDay!);
    }
    notifyListeners();
    _persist((db) => db.saveMode(mode));
  }

  void selectDay(DateTime date) {
    final day = dateOnly(date);
    if (_selectedDay == day && _mode == GroupMode.day) return;
    _selectedDay = day;
    _selectedMonth = monthOf(day);
    _mode = GroupMode.day;
    notifyListeners();
  }

  void selectMonth(DateTime month) {
    final m = monthOf(month);
    if (_selectedMonth == m) return;
    _selectedMonth = m;
    notifyListeners();
  }

  /// Moves the day list to the previous/next month that has spending.
  /// Returns false when there is nowhere to go.
  bool shiftMonth(int delta) {
    final current = focusedMonth;
    if (current == null) return false;
    final all = months.map((m) => m.month).toList();
    final index = all.indexWhere((m) => isSameMonth(m, current));
    final next = index + delta;
    if (index < 0 || next < 0 || next >= all.length) return false;
    final target = all[next];
    _selectedDay = _days.keys.lastWhere((d) => isSameMonth(d, target));
    _selectedMonth = target;
    notifyListeners();
    return true;
  }

  void addItems(DateTime date, List<Expense> items) {
    if (items.isEmpty) return;
    final day = dateOnly(date);
    _days.putIfAbsent(day, () => []).addAll(items);
    _selectedDay = day;
    _selectedMonth = monthOf(day);
    notifyListeners();
    _saveDays({day});
  }

  /// Saves an edited note. It may have moved to another [date]; an empty
  /// list deletes it.
  void replaceDay(DateTime original, DateTime date, List<Expense> items) {
    final from = dateOnly(original);
    final to = dateOnly(date);
    _days.remove(from);
    if (items.isNotEmpty) {
      _days.putIfAbsent(to, () => []).addAll(items);
      _selectedDay = to;
    } else if (_selectedDay == from) {
      _selectedDay = _days.isEmpty ? null : _days.lastKey();
    }
    if (_selectedDay != null) _selectedMonth = monthOf(_selectedDay!);
    notifyListeners();
    _saveDays({from, to});
  }

  /// Completes once every change made so far has been written.
  Future<void> flush() => _writes;

  void _saveDays(Set<DateTime> days) {
    // Snapshot now; memory may change again before the write runs.
    final snapshot = {
      for (final d in days) d: List<Expense>.of(_days[d] ?? const []),
    };
    _persist((db) => db.writeDays(snapshot));
  }

  /// Queues [write] behind earlier writes so they land in order.
  void _persist(Future<void> Function(ExpenseDatabase db) write) {
    final db = _database;
    if (db == null) return;
    _writes = _writes.then((_) async {
      try {
        await write(db);
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'little_expense',
            context: ErrorDescription('while saving expenses'),
          ),
        );
      }
    });
  }
}
