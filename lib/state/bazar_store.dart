import 'package:flutter/foundation.dart';

import '../data/expense_database.dart';
import '../models/expense.dart';
import 'expense_store.dart';

/// What "Move to Daily Bag" just added, for the confirmation card.
@immutable
class BazarMove {
  const BazarMove({
    required this.date,
    required this.count,
    required this.total,
  });

  final DateTime date;
  final int count;
  final double total;
}

/// The "Bazar Note" shopping list: items to buy, ticked off with a price
/// as they are bought, then moved into the Daily Bag in one go.
///
/// Like [ExpenseStore], reads come from memory and every change is written
/// to the [database] in order, in the background.
class BazarStore extends ChangeNotifier {
  BazarStore({List<BazarItem> items = const [], ExpenseDatabase? database})
    : _items = List.of(items),
      _database = database,
      _nextId = items.fold(0, (max, x) => x.id > max ? x.id : max) + 1;

  static Future<BazarStore> load(ExpenseDatabase database) async =>
      BazarStore(items: await database.loadBazar(), database: database);

  /// The list shown on the design canvas, in memory only (tests use it).
  factory BazarStore.demo() => BazarStore(
    items: const [
      BazarItem(id: 1, name: 'Rice, 5 kg', price: 450, checked: true),
      BazarItem(id: 2, name: 'Onion, 1 kg', price: 120, checked: true),
      BazarItem(id: 3, name: 'Eggs, 1 dozen', price: 150, checked: true),
      BazarItem(id: 4, name: 'Green chili', price: 30, checked: true),
      BazarItem(id: 5, name: 'Hilsa fish'),
      BazarItem(id: 6, name: 'Bath soap'),
    ],
  );

  final ExpenseDatabase? _database;
  final List<BazarItem> _items;
  int _nextId;
  Future<void> _writes = Future.value();

  List<BazarItem> get items => List.unmodifiable(_items);
  Iterable<BazarItem> get bought => _items.where((x) => x.checked);
  int get boughtCount => bought.length;

  /// Still to buy: the home screen's badge.
  int get leftCount => _items.length - boughtCount;
  double get boughtTotal => bought.fold(0, (sum, x) => sum + (x.price ?? 0));

  /// Adds [name] to the end of the list. Blank names are ignored.
  BazarItem? add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final item = BazarItem(id: _nextId++, name: trimmed);
    _items.add(item);
    _changed();
    return item;
  }

  void toggle(int id) => _update(id, (x) => x.copyWith(checked: !x.checked));

  void setPrice(int id, double? price) =>
      _update(id, (x) => x.copyWith(price: () => price));

  void remove(int id) {
    _items.removeWhere((x) => x.id == id);
    _changed();
  }

  /// Adds every ticked item to [date]'s Bazar Diary in [expenses] and takes
  /// them off the list; unticked items stay for next time.
  BazarMove? moveBought(ExpenseStore expenses, {required DateTime date}) {
    final bought = this.bought.toList();
    if (bought.isEmpty) return null;
    final move = BazarMove(
      date: date,
      count: bought.length,
      total: boughtTotal,
    );
    expenses.saveDay(
      date: date,
      items: [
        for (final x in bought) Expense(name: x.name, amount: x.price ?? 0),
      ],
    );
    _items.removeWhere((x) => x.checked);
    _changed();
    return move;
  }

  /// Completes once every change made so far has been written.
  Future<void> flush() => _writes;

  void _update(int id, BazarItem Function(BazarItem) change) {
    final i = _items.indexWhere((x) => x.id == id);
    if (i < 0) return;
    _items[i] = change(_items[i]);
    _changed();
  }

  void _changed() {
    notifyListeners();
    final db = _database;
    if (db == null) return;
    // Items are immutable, so this is a snapshot of right now.
    final snapshot = List.of(_items);
    _writes = _writes.then((_) async {
      try {
        await db.writeBazar(snapshot);
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'daily_bag',
            context: ErrorDescription('while saving the Bazar Note'),
          ),
        );
      }
    });
  }
}
