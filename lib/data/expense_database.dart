import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../app/format.dart';
import '../models/expense.dart';

/// On-device storage: one row per expense, plus a small settings table.
///
/// Days are written whole (delete then insert), which keeps the stored
/// order identical to the note and is cheap at a few rows per day.
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
      options: OpenDatabaseOptions(version: 1, onCreate: _create),
    );
    return ExpenseDatabase._(db);
  }

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
      ..execute(
        'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    await batch.commit(noResult: true);
  }

  Future<Map<DateTime, List<Expense>>> loadDays() async {
    final rows = await _db.query('expenses', orderBy: 'day, position');
    final days = <DateTime, List<Expense>>{};
    for (final row in rows) {
      days
          .putIfAbsent(_parseDay(row['day']! as String), () => [])
          .add(
            Expense(
              name: row['name']! as String,
              amount: (row['amount_minor']! as int) / 100,
            ),
          );
    }
    return days;
  }

  /// Replaces the stored items of each given day, atomically. An empty
  /// list deletes that day.
  Future<void> writeDays(Map<DateTime, List<Expense>> days) {
    return _db.transaction((txn) async {
      final batch = txn.batch();
      days.forEach((day, items) {
        final key = _dayKey(day);
        batch.delete('expenses', where: 'day = ?', whereArgs: [key]);
        for (var i = 0; i < items.length; i++) {
          batch.insert('expenses', {
            'day': key,
            'position': i,
            'name': items[i].name,
            // Whole poisha, so money never passes through float rounding.
            'amount_minor': (items[i].amount * 100).round(),
          });
        }
      });
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
