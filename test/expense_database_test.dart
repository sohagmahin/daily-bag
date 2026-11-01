import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:little_expense/data/expense_database.dart';
import 'package:little_expense/models/expense.dart';
import 'package:little_expense/state/expense_store.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late String path;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('daily_bag_test');
    addTearDown(() => dir.delete(recursive: true));
    path = p.join(dir.path, 'expenses.db');
  });

  Future<ExpenseDatabase> open() =>
      ExpenseDatabase.open(factory: databaseFactoryFfi, path: path);

  /// Waits for pending writes, closes, and loads a fresh store from disk.
  Future<ExpenseStore> reopen(ExpenseStore store, ExpenseDatabase db) async {
    await store.flush();
    await db.close();
    final reopened = await open();
    addTearDown(reopened.close);
    return ExpenseStore.load(reopened);
  }

  test('a fresh install starts empty, by day', () async {
    final db = await open();
    addTearDown(db.close);
    final store = await ExpenseStore.load(db);
    expect(store.days, isEmpty);
    expect(store.mode, GroupMode.day);
    expect(store.selectedDay, isNull);
  });

  test('saved days survive a restart, in order and to the poisha', () async {
    final db = await open();
    final store = ExpenseStore(database: db)
      ..saveDay(
        date: DateTime(2026, 3, 2),
        items: const [
          Expense(name: 'Rice', amount: 450),
          Expense(name: 'Lentils', amount: 160.5),
        ],
        thoughts: 'Lentils went up again.',
      )
      ..saveDay(
        date: DateTime(2026, 3, 2),
        items: const [Expense(name: 'Tea', amount: 0.1)],
      )
      ..saveDay(
        date: DateTime(2026, 2, 20),
        items: const [Expense(name: 'Beef', amount: 820)],
      )
      ..setMode(GroupMode.month);

    final restored = await reopen(store, db);
    final day = restored.dayFor(DateTime(2026, 3, 2))!;
    expect(day.items.map((e) => e.name), ['Rice', 'Lentils', 'Tea']);
    expect(day.items.map((e) => e.amount), [450, 160.5, 0.1]);
    expect(day.thoughts, 'Lentils went up again.');
    expect(restored.days.map((d) => d.date), [
      DateTime(2026, 2, 20),
      DateTime(2026, 3, 2),
    ]);
    expect(restored.mode, GroupMode.month);
    expect(restored.selectedDay, DateTime(2026, 3, 2));
  });

  test('moves, deletions and thoughts-only days are saved', () async {
    final db = await open();
    final store = ExpenseStore(database: db)
      ..saveDay(
        date: DateTime(2026, 2, 20),
        items: const [Expense(name: 'Beef', amount: 820)],
        thoughts: 'Fresh beef.',
      )
      ..saveDay(
        date: DateTime(2026, 2, 21),
        items: const [Expense(name: 'Milk', amount: 60)],
      )
      ..saveDay(
        date: DateTime(2026, 2, 26),
        items: const [Expense(name: 'Fish', amount: 520)],
      )
      ..saveDay(
        date: DateTime(2026, 2, 28),
        items: const [],
        thoughts: 'Browsed only.',
      )
      // 20 Feb's diary moves onto 21 Feb, joining what is already there.
      ..saveDay(
        original: DateTime(2026, 2, 20),
        date: DateTime(2026, 2, 21),
        items: const [Expense(name: 'Beef', amount: 800)],
        thoughts: 'Fresh beef.',
      )
      ..saveDay(
        original: DateTime(2026, 2, 26),
        date: DateTime(2026, 2, 26),
        items: const [],
      )
      ..setThoughts(DateTime(2026, 2, 28), 'Browsed only, prices high.');

    final restored = await reopen(store, db);
    expect(restored.dayFor(DateTime(2026, 2, 20)), isNull);
    expect(restored.dayFor(DateTime(2026, 2, 26)), isNull);
    final moved = restored.dayFor(DateTime(2026, 2, 21))!;
    expect(moved.items.map((e) => e.name), ['Milk', 'Beef']);
    expect(moved.total, 860);
    expect(moved.thoughts, 'Fresh beef.');
    final browsed = restored.dayFor(DateTime(2026, 2, 28))!;
    expect(browsed.items, isEmpty);
    expect(browsed.thoughts, 'Browsed only, prices high.');
  });

  test('a version 1 database upgrades and keeps its expenses', () async {
    // The schema as first shipped, before Bazar thoughts.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'day TEXT NOT NULL, position INTEGER NOT NULL, name TEXT NOT NULL, '
            'amount_minor INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    await v1.insert('expenses', {
      'day': '2026-03-02',
      'position': 0,
      'name': 'Rice',
      'amount_minor': 45000,
    });
    await v1.close();

    final db = await open();
    final store = await ExpenseStore.load(db);
    expect(store.dayFor(DateTime(2026, 3, 2))!.total, 450);

    store.setThoughts(DateTime(2026, 3, 2), 'Written after the upgrade.');
    final restored = await reopen(store, db);
    expect(
      restored.dayFor(DateTime(2026, 3, 2))!.thoughts,
      'Written after the upgrade.',
    );
  });
}
