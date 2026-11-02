import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../app/format.dart';
import '../models/expense.dart';

/// On-device storage: one row per expense, one per day's Bazar thoughts,
/// the Bazar Note shopping list, and a small settings table.
///
/// Days are written whole (delete then insert), which keeps the stored
/// order identical to the diary and is cheap at a few rows per day.
class ExpenseDatabase {
  ExpenseDatabase._(this._db);

  static const _fileName = 'little_expense.db';
  static const _modeKey = 'group_mode';

  final Database _db;

  /// Opens (creating if needed) the app database. Tests pass an FFI
  /// [factory] and a temporary [path].
  static Future<ExpenseDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final location =
        path ?? p.join(await dbFactory.getDatabasesPath(), _fileName);
    final db = await dbFactory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    return ExpenseDatabase._(db);
  }

  static const _thoughtsTable =
      'CREATE TABLE thoughts (day TEXT PRIMARY KEY, text TEXT NOT NULL)';

  static const _bazarTable = '''
    CREATE TABLE bazar_items (
      id INTEGER PRIMARY KEY,
      position INTEGER NOT NULL,
      name TEXT NOT NULL,
      price_minor INTEGER,
      checked INTEGER NOT NULL
    )''';

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          day TEXT NOT NULL,
          position INTEGER NOT NULL,
          name TEXT NOT NULL,
          amount_minor INTEGER NOT NULL
        )''')
      ..execute('CREATE INDEX expenses_by_day ON expenses (day, position)')
      ..execute(_thoughtsTable)
      ..execute(_bazarTable)
      ..execute(
        'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    // v2: Bazar thoughts.
    if (from < 2) await db.execute(_thoughtsTable);
    // v3: the Bazar Note shopping list.
    if (from < 3) await db.execute(_bazarTable);
  }

  Future<List<DayNote>> loadDays() async {
    final items = <DateTime, List<Expense>>{};
    for (final row in await _db.query('expenses', orderBy: 'day, position')) {
      items
          .putIfAbsent(_parseDay(row['day']! as String), () => [])
          .add(
            Expense(
              name: row['name']! as String,
              amount: (row['amount_minor']! as int) / 100,
            ),
          );
    }
    final thoughts = {
      for (final row in await _db.query('thoughts'))
        _parseDay(row['day']! as String): row['text']! as String,
    };
    return [
      for (final day in {...items.keys, ...thoughts.keys})
        DayNote(day, items[day] ?? const [], thoughts: thoughts[day] ?? ''),
    ];
  }

  /// Replaces each given day, atomically. A null note deletes that day.
  Future<void> writeDays(Map<DateTime, DayNote?> days) {
    return _db.transaction((txn) async {
      final batch = txn.batch();
      days.forEach((day, note) {
        final key = _dayKey(day);
        batch
          ..delete('expenses', where: 'day = ?', whereArgs: [key])
          ..delete('thoughts', where: 'day = ?', whereArgs: [key]);
        if (note == null) return;
        for (var i = 0; i < note.items.length; i++) {
          batch.insert('expenses', {
            'day': key,
            'position': i,
            'name': note.items[i].name,
            // Whole poisha, so money never passes through float rounding.
            'amount_minor': (note.items[i].amount * 100).round(),
          });
        }
        if (note.hasThoughts) {
          batch.insert('thoughts', {'day': key, 'text': note.thoughts});
        }
      });
      await batch.commit(noResult: true);
    });
  }

  Future<List<BazarItem>> loadBazar() async => [
    for (final row in await _db.query('bazar_items', orderBy: 'position'))
      BazarItem(
        id: row['id']! as int,
        name: row['name']! as String,
        price: switch (row['price_minor']) {
          final int minor => minor / 100,
          _ => null,
        },
        checked: row['checked'] == 1,
      ),
  ];

  /// Replaces the whole shopping list, atomically.
  Future<void> writeBazar(List<BazarItem> items) {
    return _db.transaction((txn) async {
      final batch = txn.batch()..delete('bazar_items');
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        batch.insert('bazar_items', {
          'id': item.id,
          'position': i,
          'name': item.name,
          'price_minor': item.price == null
              ? null
              : (item.price! * 100).round(),
          'checked': item.checked ? 1 : 0,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<GroupMode> loadMode() async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_modeKey],
    );
    final name = rows.isEmpty ? null : rows.first['value'] as String?;
    return GroupMode.values.asNameMap()[name] ?? GroupMode.day;
  }

  Future<void> saveMode(GroupMode mode) => _db.insert('settings', {
    'key': _modeKey,
    'value': mode.name,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> close() => _db.close();

  /// `2026-03-02`: sorts as text, and has no time zone to drift.
  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${twoDigits(d.month)}-${twoDigits(d.day)}';

  static DateTime _parseDay(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }
}
