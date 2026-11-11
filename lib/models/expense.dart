import 'package:flutter/foundation.dart';

@immutable
class Expense {
  const Expense({required this.name, required this.amount});

  final String name;
  final double amount;
}

/// One day's "Bazar Diary": the items bought that date and the shopper's
/// free-form "Bazar thoughts".
@immutable
class DayNote {
  DayNote(this.date, List<Expense> items, {this.thoughts = ''})
    : items = List.unmodifiable(items);

  final DateTime date;
  final List<Expense> items;
  final String thoughts;

  double get total => items.fold(0, (sum, e) => sum + e.amount);
  bool get hasThoughts => thoughts.trim().isNotEmpty;

  /// Nothing worth keeping: the day can be dropped.
  bool get isEmpty => items.isEmpty && !hasThoughts;
}

@immutable
class MonthSummary {
  MonthSummary(this.month, List<DayNote> days) : days = List.unmodifiable(days);

  final DateTime month;
  final List<DayNote> days;

  double get total => days.fold(0, (sum, d) => sum + d.total);
  int get itemCount => days.fold(0, (sum, d) => sum + d.items.length);
}

enum GroupMode { day, month }

/// One line on the Bazar Note shopping list. [price] stays null until the
/// shopper types one.
@immutable
class BazarItem {
  const BazarItem({
    required this.id,
    required this.name,
    this.price,
    this.checked = false,
  });

  final int id;
  final String name;
  final double? price;

  /// Ticked as bought.
  final bool checked;

  BazarItem copyWith({double? Function()? price, bool? checked}) => BazarItem(
    id: id,
    name: name,
    price: price == null ? this.price : price(),
    checked: checked ?? this.checked,
  );
}
