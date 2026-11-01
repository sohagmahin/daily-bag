import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:little_expense/main.dart';
import 'package:little_expense/models/expense.dart';
import 'package:little_expense/state/expense_draft.dart';
import 'package:little_expense/state/expense_store.dart';

void main() {
  group('ExpenseStore', () {
    test('demo data matches the design', () {
      final store = ExpenseStore.demo();
      expect(store.eyebrow, 'February 2026');
      expect(store.dayFor(DateTime(2026, 2, 20))!.total, 1220);
      expect(store.chartBars.map((b) => b.label), [
        '12',
        '13',
        '20',
        '26',
        '02',
      ]);
      expect(store.chartBars.singleWhere((b) => b.selected).value, 1220);
    });

    test('adding items opens that day', () {
      final store = ExpenseStore.demo();
      store.addItems(DateTime(2026, 3, 5), const [
        Expense(name: 'Tea', amount: 40),
      ]);
      expect(store.selectedDay, DateTime(2026, 3, 5));
      expect(store.eyebrow, 'March 2026');
      expect(store.chartBars.last.value, 40);
    });

    test('editing a note can move or delete it', () {
      final store = ExpenseStore.demo();
      store.replaceDay(DateTime(2026, 2, 20), DateTime(2026, 2, 21), const [
        Expense(name: 'Beef', amount: 820),
      ]);
      expect(store.dayFor(DateTime(2026, 2, 20)), isNull);
      expect(store.dayFor(DateTime(2026, 2, 21))!.total, 820);

      store.replaceDay(DateTime(2026, 2, 21), DateTime(2026, 2, 21), const []);
      expect(store.dayFor(DateTime(2026, 2, 21)), isNull);
    });

    test('month mode groups and charts by month', () {
      final store = ExpenseStore.demo()..setMode(GroupMode.month);
      expect(store.months.map((m) => m.total), [4520, 950]);
      expect(store.eyebrow, '2026');
      expect(store.chartBars.map((b) => b.label), ['Feb', 'Mar']);
    });
  });

  test('draft keeps only rows with an amount', () {
    final store = ExpenseStore.demo();
    final draft = ExpenseDraft(date: DateTime(2026, 3, 2));
    draft.rows.first
      ..name.text = 'Rice'
      ..amount.text = '450';
    draft.addRow().name.text = 'No amount';
    expect(draft.total, 450);
    expect(draft.commit(store), DateTime(2026, 3, 2));
    expect(store.dayFor(DateTime(2026, 3, 2))!.total, 1400);
  });

  testWidgets('home renders the design and expands a day on tap', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = ExpenseStore.demo();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const LittleExpenseApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('FEBRUARY 2026'), findsOneWidget);
    // Only the open day (20 Feb) shows its items.
    expect(find.text('Beef'), findsOneWidget);
    expect(find.text('Soybean oil'), findsNothing);
    expect(find.text('Add expense'), findsOneWidget);

    await tester.tap(find.text('12 Feb 2026'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(store.selectedDay, DateTime(2026, 2, 12));
    expect(find.text('Soybean oil'), findsOneWidget);
    expect(find.text('Beef'), findsNothing);
  });
}
