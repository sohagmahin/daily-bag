import 'package:flutter/widgets.dart';

import '../app/format.dart';
import '../app/strings.dart';
import '../models/expense.dart';
import 'expense_store.dart';

/// One editable line in the "Little note" sheet.
class DraftRow {
  DraftRow({String name = '', String amount = '', this.fresh = false})
    : name = TextEditingController(text: name),
      amount = TextEditingController(text: amount);

  final Key key = UniqueKey();
  final TextEditingController name;
  final TextEditingController amount;
  final FocusNode nameFocus = FocusNode();
  final FocusNode amountFocus = FocusNode();

  /// Added by the user rather than loaded, so it animates in.
  final bool fresh;

  double get value => double.tryParse(amount.text.trim()) ?? 0;

  void dispose() {
    name.dispose();
    amount.dispose();
    nameFocus.dispose();
    amountFocus.dispose();
  }
}

/// State of the Bazar Diary sheet, scoped to the sheet's route.
class ExpenseDraft extends ChangeNotifier {
  /// [existing] is the day being edited; null when starting a new one.
  ExpenseDraft({required DateTime date, this.existing})
    : _date = dateOnly(existing?.date ?? date),
      thoughts = TextEditingController(text: existing?.thoughts ?? '') {
    for (final item in existing?.items ?? const <Expense>[]) {
      _attach(DraftRow(name: item.name, amount: editableAmount(item.amount)));
    }
    _attach(DraftRow());
  }

  final DayNote? existing;

  /// The "Bazar thoughts" free text.
  final TextEditingController thoughts;
  final FocusNode thoughtsFocus = FocusNode();
  final List<DraftRow> _rows = [];
  DateTime _date;
  int _version = 0;
  bool _disposed = false;

  DateTime get date => _date;

  /// Bumps whenever rows are added or removed (not when they are typed in).
  int get version => _version;
  List<DraftRow> get rows => List.unmodifiable(_rows);
  double get total => _rows.fold(0, (sum, r) => sum + r.value);

  String get totalLabel => isSameDay(_date, DateTime.now())
      ? tr.totalForToday
      : tr.totalFor(shortDay(_date));

  void _attach(DraftRow row) {
    row.amount.addListener(notifyListeners);
    _rows.add(row);
  }

  void setDate(DateTime date) {
    final day = dateOnly(date);
    if (day == _date) return;
    _date = day;
    notifyListeners();
  }

  DraftRow addRow() {
    final row = DraftRow(fresh: true);
    _attach(row);
    _version++;
    notifyListeners();
    return row;
  }

  void removeRow(DraftRow row) {
    if (!_rows.remove(row)) return;
    row.amount.removeListener(notifyListeners);
    // The row's fields are still mounted this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
    if (_rows.isEmpty) _attach(DraftRow(fresh: true));
    _version++;
    notifyListeners();
  }

  List<Expense> get items => [
    for (final r in _rows)
      if (r.value > 0)
        Expense(
          name: r.name.text.trim().isEmpty ? tr.untitled : r.name.text.trim(),
          amount: r.value,
        ),
  ];

  /// Writes the draft to [store]; returns the saved day, or null if nothing
  /// was kept.
  DateTime? commit(ExpenseStore store) {
    if (existing == null && items.isEmpty && thoughts.text.trim().isEmpty) {
      return null;
    }
    store.saveDay(
      original: existing?.date,
      date: _date,
      items: items,
      thoughts: thoughts.text,
    );
    return store.dayFor(_date) == null ? null : _date;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final r in _rows) {
      r.dispose();
    }
    thoughts.dispose();
    thoughtsFocus.dispose();
    super.dispose();
  }
}
