import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../app/format.dart';
import '../app/strings.dart';
import '../data/expense_database.dart';
import '../models/expense.dart';

/// App-wide state: every day's Bazar Diary, how they are grouped, and
/// which day or month is open.
///
/// Reads are served from memory; when a [database] is attached, every
/// change is also written to it, in order, in the background.
class ExpenseStore extends ChangeNotifier {
  ExpenseStore({
    List<DayNote> days = const [],
    DateTime? selectedDay,
    GroupMode mode = GroupMode.day,
    ExpenseDatabase? database,
  }) : _mode = mode,
       _database = database {
    for (final d in days) {
      final date = dateOnly(d.date);
      _days[date] = DayNote(date, d.items, thoughts: d.thoughts);
    }
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
    days: [
      DayNote(DateTime(2026, 2, 12), const [
        Expense(name: 'Rice', amount: 600),
        Expense(name: 'Soybean oil', amount: 420),
        Expense(name: 'Eggs', amount: 280),
        Expense(name: 'Onion', amount: 240),
      ]),
      DayNote(DateTime(2026, 2, 13), const [
        Expense(name: 'Chicken', amount: 650),
        Expense(name: 'Milk', amount: 260),
        Expense(name: 'Bread', amount: 150),
      ]),
      DayNote(
        DateTime(2026, 2, 20),
        const [
          Expense(name: 'Potato', amount: 200),
          Expense(name: 'Beef', amount: 820),
          Expense(name: 'Jira', amount: 200),
        ],
        thoughts:
            'Beef was fresh today, so I took a bit extra for the weekend. '
            'Ran out of jira at home — picked up a small pack. '
            'Next time, bring my own bag.',
      ),
      DayNote(DateTime(2026, 2, 26), const [
        Expense(name: 'Fish', amount: 520),
        Expense(name: 'Tomato', amount: 180),
      ]),
      DayNote(DateTime(2026, 3, 2), const [
        Expense(name: 'Rice', amount: 450),
        Expense(name: 'Lentils', amount: 160),
        Expense(name: 'Vegetables', amount: 340),
      ]),
    ],
  );

  /// Most bars the chart keeps; older ones are left to the day list.
  static const chartLength = 30;

  final ExpenseDatabase? _database;
  final _days = SplayTreeMap<DateTime, DayNote>();
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
    return _mode == GroupMode.day ? monthTitle(month) : digits(month.year);
  }

  List<DayNote> get days => _days.values.toList();

  /// Everything ever spent: the chart header's "Total".
  double get grandTotal => _days.values.fold(0, (sum, d) => sum + d.total);

  List<DayNote> get daysInFocusedMonth {
    final month = focusedMonth;
    if (month == null) return const [];
    return [
      for (final d in _days.values)
        if (isSameMonth(d.date, month)) d,
    ];
  }

  List<MonthSummary> get months {
    final grouped = SplayTreeMap<DateTime, List<DayNote>>();
    for (final day in _days.values) {
      grouped.putIfAbsent(monthOf(day.date), () => []).add(day);
    }
    return [for (final e in grouped.entries) MonthSummary(e.key, e.value)];
  }

  DayNote? dayFor(DateTime date) => _days[dateOnly(date)];

  /// The last [chartLength] days (or months) with spending, oldest first.
  List<ChartBar> get chartBars {
    if (_mode == GroupMode.month) {
      final all = months.where((m) => m.total > 0).toList();
      final focused = focusedMonth;
      return [
        for (final m in all.skip(_tailStart(all.length)))
          ChartBar(
            key: m.month,
            label: shortMonthName(m.month),
            semanticLabel: '${monthTitle(m.month)}, ${formatMoney(m.total)}',
            value: m.total,
            selected: focused != null && isSameMonth(m.month, focused),
          ),
      ];
    }
    // A day kept only for its thoughts has nothing to chart.
    final all = _days.values.where((d) => d.total > 0).toList();
    return [
      for (final d in all.skip(_tailStart(all.length)))
        ChartBar(
          key: d.date,
          label: digits(twoDigits(d.date.day)),
          semanticLabel: '${shortDay(d.date)}, ${formatMoney(d.total)}',
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

  /// Moves the day list to the previous/next month that has entries.
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

  /// Saves a Bazar Diary entry and opens its day.
  ///
  /// [original] is the day being edited, if any; it is replaced. Whatever
  /// already sits on [date] (when moving or adding) is kept, with the new
  /// items after it. A day left with nothing in it is removed.
  void saveDay({
    DateTime? original,
    required DateTime date,
    required List<Expense> items,
    String thoughts = '',
  }) {
    final to = dateOnly(date);
    final from = original == null ? null : dateOnly(original);
    if (from != null) _days.remove(from);

    final existing = _days[to];
    final merged = DayNote(
      to,
      [...?existing?.items, ...items],
      thoughts: [
        if (existing?.hasThoughts ?? false) existing!.thoughts.trim(),
        if (thoughts.trim().isNotEmpty) thoughts.trim(),
      ].join('\n\n'),
    );
    if (merged.isEmpty) {
      _days.remove(to);
    } else {
      _days[to] = merged;
    }

    if (_days.containsKey(to)) {
      _selectedDay = to;
    } else if (_selectedDay == from || _selectedDay == to) {
      _selectedDay = _days.isEmpty ? null : _days.lastKey();
    }
    if (_selectedDay != null) _selectedMonth = monthOf(_selectedDay!);
    notifyListeners();
    _saveDays({?from, to});
  }

  /// Replaces one day's thoughts in place; empty text deletes them.
  void setThoughts(DateTime date, String thoughts) {
    final day = _days[dateOnly(date)];
    if (day == null) return;
    final updated = DayNote(day.date, day.items, thoughts: thoughts.trim());
    if (updated.isEmpty) {
      _days.remove(day.date);
      if (_selectedDay == day.date) {
        _selectedDay = _days.isEmpty ? null : _days.lastKey();
      }
    } else {
      _days[day.date] = updated;
    }
    notifyListeners();
    _saveDays({day.date});
  }

  /// Completes once every change made so far has been written.
  Future<void> flush() => _writes;

  void _saveDays(Set<DateTime> days) {
    // Notes are immutable, so this is a snapshot of right now.
    final snapshot = {for (final d in days) d: _days[d]};
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
            library: 'daily_bag',
            context: ErrorDescription('while saving the Bazar Diary'),
          ),
        );
      }
    });
  }
}
