import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:little_expense/app/format.dart';
import 'package:little_expense/main.dart';
import 'package:little_expense/models/expense.dart';
import 'package:little_expense/screens/home/spend_chart.dart';
import 'package:little_expense/state/bazar_store.dart';
import 'package:little_expense/state/expense_draft.dart';
import 'package:little_expense/state/expense_store.dart';

/// One small purchase a day for [count] days from 1 Jan 2026.
List<DayNote> dailyDays(int count) => [
  for (var i = 0; i < count; i++)
    DayNote(DateTime(2026, 1, 1 + i), [Expense(name: 'Tea', amount: 10.0 + i)]),
];

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

    test('the chart keeps the last 30 days with spending', () {
      final store = ExpenseStore(days: dailyDays(35));
      expect(store.chartBars, hasLength(30));
      expect(store.chartBars.first.key, DateTime(2026, 1, 6));
      expect(store.chartBars.last.key, DateTime(2026, 2, 4));
      expect(store.chartBars.last.selected, isTrue);
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

  group('BazarStore', () {
    test('demo data matches the design', () {
      final bazar = BazarStore.demo();
      expect(bazar.boughtCount, 4);
      expect(bazar.leftCount, 2);
      expect(bazar.boughtTotal, 750);
    });

    test('moving bought items files them under the day', () {
      final store = ExpenseStore.demo();
      final bazar = BazarStore.demo();
      final move = bazar.moveBought(store, date: DateTime(2026, 3, 2))!;

      expect(move.count, 4);
      expect(move.total, 750);
      final day = store.dayFor(DateTime(2026, 3, 2))!;
      expect(day.items.map((e) => e.name), [
        'Rice',
        'Lentils',
        'Vegetables',
        'Rice, 5 kg',
        'Onion, 1 kg',
        'Eggs, 1 dozen',
        'Green chili',
      ]);
      expect(day.total, 950 + 750);
      expect(bazar.items.map((x) => x.name), ['Hilsa fish', 'Bath soap']);
      expect(bazar.moveBought(store, date: DateTime(2026, 3, 2)), isNull);
    });
  });

  group('home', () {
    Future<ExpenseStore> pumpHome(
      WidgetTester tester, [
      ExpenseStore? store,
      BazarStore? bazar,
    ]) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      store ??= ExpenseStore.demo();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider.value(value: bazar ?? BazarStore.demo()),
          ],
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

    testWidgets('the chart opens on the newest bar and scrolls back', (
      tester,
    ) async {
      final store = await pumpHome(tester, ExpenseStore(days: dailyDays(35)));
      bool shown(String label) => tester
          .getRect(find.byType(SpendChart))
          .contains(tester.getCenter(find.text(label)));

      expect(shown('04'), isTrue, reason: '4 Feb, the newest');
      expect(shown('06'), isFalse, reason: '6 Jan, the oldest kept');

      await tester.drag(find.byType(SpendChart), const Offset(2000, 0));
      await settle(tester);
      await settle(tester);
      expect(shown('06'), isTrue);
      expect(shown('04'), isFalse);

      // Opening a day elsewhere brings its bar back into view.
      store.selectDay(DateTime(2026, 2, 3));
      await settle(tester);
      await settle(tester);
      expect(shown('03'), isTrue);
    });

    testWidgets('"Fill the bag" starts blank and adds to today', (
      tester,
    ) async {
      final store = await pumpHome(tester);
      final today = DateTime.now();
      store.saveDay(
        date: today,
        items: const [Expense(name: 'Rice', amount: 100)],
      );
      await settle(tester);

      await tester.tap(find.text('Fill the bag'));
      await settle(tester);
      final fields = find.descendant(
        of: find.bySemanticsLabel('Bazar Diary'),
        matching: find.byType(EditableText),
      );
      for (final field in tester.widgetList<EditableText>(fields)) {
        expect(field.controller.text, isEmpty);
      }

      await tester.enterText(fields.at(0), 'Eggs');
      await tester.enterText(fields.at(1), '50');
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(store.dayFor(today)!.items.map((e) => e.name), ['Rice', 'Eggs']);
      expect(store.dayFor(today)!.total, 150);
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

    testWidgets('Bazar Note moves bought items into today', (tester) async {
      final store = ExpenseStore.demo();
      final bazar = BazarStore.demo();
      await pumpHome(tester, store, bazar);

      await tester.tap(
        find.bySemanticsLabel('Bazar Note, 2 items left to buy'),
      );
      await settle(tester);
      expect(find.text('Bazar Note'), findsOneWidget);
      expect(find.text('4 of 6 bought'), findsOneWidget);
      expect(find.text('৳750'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).first, 'Tea');
      await tester.tap(find.bySemanticsLabel('Add item'));
      await settle(tester);
      expect(bazar.items.last.name, 'Tea');
      expect(find.text('4 of 7 bought'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Mark bought: Tea'));
      await tester.enterText(
        // Tea is the last row, so its price is the last field.
        find.byType(EditableText).last,
        '40',
      );
      await settle(tester);
      expect(find.text('৳790'), findsOneWidget);

      await tester.tap(find.text('Move to Daily Bag'));
      await settle(tester);
      expect(find.text('Added to Daily Bag'), findsOneWidget);
      final today = dateOnly(DateTime.now());
      expect(store.dayFor(today)!.total, greaterThanOrEqualTo(790));
      expect(bazar.items.map((x) => x.name), ['Hilsa fish', 'Bath soap']);

      await tester.tap(find.text('View Daily Bag'));
      await settle(tester);
      await settle(tester);
      expect(find.text('Fill the bag'), findsOneWidget);
      expect(store.selectedDay, today);
    });
  });
}
