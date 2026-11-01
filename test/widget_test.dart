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
      expect(store.dayFor(DateTime(2026, 2, 20))!.hasThoughts, isTrue);
      expect(store.grandTotal, 5470);
      expect(store.chartBars.map((b) => b.label), [
        '12',
        '13',
        '20',
        '26',
        '02',
      ]);
      expect(store.chartBars.singleWhere((b) => b.selected).value, 1220);
    });

    test('saving a new day opens it', () {
      final store = ExpenseStore.demo()
        ..saveDay(
          date: DateTime(2026, 3, 5),
          items: const [Expense(name: 'Tea', amount: 40)],
          thoughts: 'Quick stop.',
        );
      expect(store.selectedDay, DateTime(2026, 3, 5));
      expect(store.eyebrow, 'March 2026');
      expect(store.chartBars.last.value, 40);
      expect(store.dayFor(DateTime(2026, 3, 5))!.thoughts, 'Quick stop.');
      expect(store.grandTotal, 5510);
    });

    test('editing can move a day onto another, keeping both', () {
      final store = ExpenseStore.demo()
        ..saveDay(
          original: DateTime(2026, 2, 20),
          date: DateTime(2026, 2, 26),
          items: const [Expense(name: 'Beef', amount: 820)],
          thoughts: 'Moved.',
        );
      expect(store.dayFor(DateTime(2026, 2, 20)), isNull);
      final day = store.dayFor(DateTime(2026, 2, 26))!;
      expect(day.items.map((e) => e.name), ['Fish', 'Tomato', 'Beef']);
      expect(day.thoughts, 'Moved.');
    });

    test('a day emptied of items and thoughts is removed', () {
      final store = ExpenseStore.demo()
        ..saveDay(
          original: DateTime(2026, 2, 20),
          date: DateTime(2026, 2, 20),
          items: const [],
        );
      expect(store.dayFor(DateTime(2026, 2, 20)), isNull);
    });

    test('a day can keep only its thoughts, off the chart', () {
      final store = ExpenseStore.demo()
        ..saveDay(
          date: DateTime(2026, 3, 9),
          items: const [],
          thoughts: 'Window shopping.',
        );
      expect(store.dayFor(DateTime(2026, 3, 9))!.total, 0);
      expect(store.chartBars.map((b) => b.label), isNot(contains('09')));
    });

    test('deleting thoughts keeps the items', () {
      final store = ExpenseStore.demo()..setThoughts(DateTime(2026, 2, 20), '');
      final day = store.dayFor(DateTime(2026, 2, 20))!;
      expect(day.hasThoughts, isFalse);
      expect(day.items, hasLength(3));
    });

    test('month mode groups and charts by month', () {
      final store = ExpenseStore.demo()..setMode(GroupMode.month);
      expect(store.months.map((m) => m.total), [4520, 950]);
      expect(store.eyebrow, '2026');
      expect(store.chartBars.map((b) => b.label), ['Feb', 'Mar']);
    });
  });

  test('draft edits a day: rows with an amount, plus thoughts', () {
    final store = ExpenseStore.demo();
    final draft = ExpenseDraft(
      date: DateTime.now(),
      existing: store.dayFor(DateTime(2026, 3, 2)),
    );
    expect(draft.rows, hasLength(4), reason: '3 loaded + 1 blank');
    draft.rows.last
      ..name.text = 'Salt'
      ..amount.text = '30';
    draft.addRow().name.text = 'No amount';
    draft.thoughts.text = '  Salt was on offer.  ';
    expect(draft.total, 980);
    expect(draft.commit(store), DateTime(2026, 3, 2));
    final day = store.dayFor(DateTime(2026, 3, 2))!;
    expect(day.total, 980);
    expect(day.thoughts, 'Salt was on offer.');
  });

  group('home', () {
    Future<ExpenseStore> pumpHome(WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
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
      return store;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('renders the design and expands a day on tap', (tester) async {
      final store = await pumpHome(tester);

      expect(find.text('Daily Bag'), findsOneWidget);
      expect(find.text('FEBRUARY 2026'), findsOneWidget);
      expect(find.text('Fill the bag'), findsOneWidget);
      // Only the open day (20 Feb) shows its items.
      expect(find.text('Beef'), findsOneWidget);
      expect(find.text('Soybean oil'), findsNothing);

      await tester.tap(find.text('12 Feb 2026'));
      await settle(tester);
      expect(store.selectedDay, DateTime(2026, 2, 12));
      expect(find.text('Soybean oil'), findsOneWidget);
      expect(find.text('Beef'), findsNothing);
    });

    testWidgets('the total stays hidden until tapped', (tester) async {
      await pumpHome(tester);
      expect(find.text('•••••'), findsOneWidget);
      expect(find.text('৳5,470'), findsNothing);

      await tester.tap(find.text('•••••'));
      await settle(tester);
      expect(find.text('৳5,470'), findsOneWidget);
    });

    testWidgets('long press shows the Bazar thoughts', (tester) async {
      final store = await pumpHome(tester);
      await tester.longPress(find.text('20 Feb 2026'));
      await settle(tester);

      expect(find.text('BAZAR THOUGHTS'), findsOneWidget);
      expect(find.textContaining('Beef was fresh today'), findsOneWidget);
      expect(find.text('Edit thoughts'), findsOneWidget);
      expect(find.text('Delete thoughts'), findsOneWidget);

      await tester.tap(find.text('Delete thoughts'));
      await settle(tester);
      expect(find.text('BAZAR THOUGHTS'), findsNothing);
      expect(store.dayFor(DateTime(2026, 2, 20))!.hasThoughts, isFalse);
      expect(store.dayFor(DateTime(2026, 2, 20))!.items, hasLength(3));
    });

    testWidgets('"Edit thoughts" opens the diary in the thoughts field', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.longPress(find.text('20 Feb 2026'));
      await settle(tester);
      await tester.tap(find.text('Edit thoughts'));
      await settle(tester);
      await settle(tester);

      expect(find.text('Bazar Diary'), findsOneWidget);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.bySemanticsLabel('Bazar thoughts'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, startsWith('Beef was fresh today'));
      expect(field.focusNode.hasFocus, isTrue);
    });
  });
}
