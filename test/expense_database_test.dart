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
    final dir = await Directory.systemTemp.createTemp('little_expense_test');
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

  test('added items survive a restart, in order and to the poisha', () async {
    final db = await open();
    final store = ExpenseStore(database: db)
      ..addItems(DateTime(2026, 3, 2), const [
        Expense(name: 'Rice', amount: 450),
        Expense(name: 'Lentils', amount: 160.5),
      ])
      ..addItems(DateTime(2026, 3, 2), const [
        Expense(name: 'Tea', amount: 0.1),
      ])
      ..addItems(DateTime(2026, 2, 20), const [
        Expense(name: 'Beef', amount: 820),
      ])
      ..setMode(GroupMode.month);

    final restored = await reopen(store, db);
    final day = restored.dayFor(DateTime(2026, 3, 2))!;
    expect(day.items.map((e) => e.name), ['Rice', 'Lentils', 'Tea']);
    expect(day.items.map((e) => e.amount), [450, 160.5, 0.1]);
    expect(restored.days.map((d) => d.date), [
      DateTime(2026, 2, 20),
      DateTime(2026, 3, 2),
    ]);
    expect(restored.mode, GroupMode.month);
    expect(restored.selectedDay, DateTime(2026, 3, 2));
  });

  test('editing a note can move it to another day, or delete it', () async {
    final db = await open();
    final store = ExpenseStore(database: db)
      ..addItems(DateTime(2026, 2, 20), const [
        Expense(name: 'Beef', amount: 820),
      ])
      ..addItems(DateTime(2026, 2, 21), const [
        Expense(name: 'Milk', amount: 60),
      ])
      ..addItems(DateTime(2026, 2, 26), const [
        Expense(name: 'Fish', amount: 520),
      ])
      // 20 Feb's note moves onto 21 Feb, joining what is already there.
      ..replaceDay(DateTime(2026, 2, 20), DateTime(2026, 2, 21), const [
        Expense(name: 'Beef', amount: 800),
      ])
      ..replaceDay(DateTime(2026, 2, 26), DateTime(2026, 2, 26), const []);

    final restored = await reopen(store, db);
    expect(restored.dayFor(DateTime(2026, 2, 20)), isNull);
    expect(restored.dayFor(DateTime(2026, 2, 26)), isNull);
    expect(restored.dayFor(DateTime(2026, 2, 21))!.items.map((e) => e.name), [
      'Milk',
      'Beef',
    ]);
    expect(restored.dayFor(DateTime(2026, 2, 21))!.total, 860);
  });
}
