import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/tokens.dart';
import '../../models/expense.dart';
import '../../state/expense_store.dart';
import '../../widgets/entrance.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_background.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_pressable.dart';
import '../add_expense/add_expense_sheet.dart';
import '../menu/view_menu.dart';
import 'spend_chart.dart';
import 'summary_card.dart';

/// "Expenses": the day (or month) list, the chart, and the add button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 56px button + 1px border top and bottom, as the design renders it.
  static const _addButtonHeight = 58.0;

  final _scroll = ScrollController();
  final _menuButtonKey = GlobalKey();
  final _cardKeys = <DateTime, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(DateTime date) =>
      _cardKeys.putIfAbsent(date, GlobalKey.new);

  double get _buttonInset => math.max(MediaQuery.paddingOf(context).bottom, 20);

  void _openMenu() {
    final box = _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    Navigator.of(
      context,
    ).push(ViewMenu.route(box.localToGlobal(Offset.zero) & box.size));
  }

  Future<void> _openSheet({DayNote? editing}) async {
    final saved = await Navigator.of(
      context,
    ).push(AddExpenseSheet.route(date: DateTime.now(), editing: editing));
    if (saved != null) _reveal(saved);
  }

  void _selectFromChart(DateTime key) {
    final store = context.read<ExpenseStore>();
    if (store.mode == GroupMode.month) {
      store.selectMonth(key);
    } else {
      store.selectDay(key);
      _reveal(key);
    }
  }

  /// Scrolls just enough to show a day's card once it has opened.
  void _reveal(DateTime date) {
    Future.delayed(const Duration(milliseconds: 360), () {
      if (!mounted || !_scroll.hasClients) return;
      final box = _cardKeys[dateOnly(date)]?.currentContext?.findRenderObject();
      if (box == null) return;
      final viewport = RenderAbstractViewport.of(box);
      final position = _scroll.position;
      final top =
          viewport.getOffsetToReveal(box, 0).offset -
          (MediaQuery.paddingOf(context).top + 15);
      final bottom =
          viewport.getOffsetToReveal(box, 1).offset +
          _buttonInset +
          _addButtonHeight +
          16;
      final double target;
      if (position.pixels > top) {
        target = top;
      } else if (position.pixels < bottom) {
        target = bottom;
      } else {
        return;
      }
      _scroll.animateTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: Motion.smooth.duration,
        curve: Motion.smooth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final buttonInset = _buttonInset;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Stack(
        children: [
          const Positioned.fill(child: LiquidBackground()),
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                safeTop + 15,
                16,
                buttonInset + _addButtonHeight + 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Entrance(
                    child: _Header(
                      menuButtonKey: _menuButtonKey,
                      onMenu: _openMenu,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _GroupList(
                    keyFor: _keyFor,
                    onOpenNote: (day) => _openSheet(editing: day),
                    onReveal: _reveal,
                  ),
                  const SizedBox(height: 18),
                  Entrance(
                    delay: const Duration(milliseconds: 260),
                    child: _ChartSection(onSelect: _selectFromChart),
                  ),
                ],
              ),
            ),
          ),
          // Content scrolling under the status bar fades into the canvas.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: safeTop + 20,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  final shown = _scroll.hasClients
                      ? (_scroll.offset / 24).clamp(0.0, 1.0)
                      : 0.0;
                  return Opacity(
                    opacity: shown,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.fromRGBO(238, 241, 247, 0.85),
                            Color.fromRGBO(238, 241, 247, 0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 130,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(238, 241, 247, 0),
                      Color.fromRGBO(238, 241, 247, 0.7),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: buttonInset,
            child: Entrance(
              delay: const Duration(milliseconds: 320),
              offset: 40,
              child: _AddButton(onTap: _openSheet),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.menuButtonKey, required this.onMenu});

  final GlobalKey menuButtonKey;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final eyebrow = context.select<ExpenseStore, String>((s) => s.eyebrow);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: FadeWithGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: Motion.snappy.duration,
                  switchInCurve: Motion.snappy,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    eyebrow.toUpperCase(),
                    key: ValueKey(eyebrow),
                    style: AppText.eyebrow,
                  ),
                ),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: const Text('Expenses', style: AppText.largeTitle),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        KeyedSubtree(
          key: menuButtonKey,
          child: LiquidPressable(
            onTap: onMenu,
            haptic: HapticKind.light,
            pressedScale: 0.9,
            borderRadius: 23,
            semanticLabel: 'View options',
            child: LiquidBox(
              style: Glass.menuButton,
              width: 44,
              height: 44,
              child: const Center(
                child: LineIcon(LineGlyph.menu, size: 20, strokeWidth: 2.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.keyFor,
    required this.onOpenNote,
    required this.onReveal,
  });

  final GlobalKey Function(DateTime date) keyFor;
  final ValueChanged<DayNote> onOpenNote;
  final ValueChanged<DateTime> onReveal;

  static Duration _stagger(int index) =>
      Duration(milliseconds: 60 + 50 * index);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final byDay = store.mode == GroupMode.day;

    final cards = byDay ? _dayCards(store) : _monthCards(store);
    final list = cards.isEmpty
        ? const _EmptyCard()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          );

    return GestureDetector(
      // Swipe sideways to move between months.
      onHorizontalDragEnd: byDay
          ? (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 250) return;
              if (store.shiftMonth(v < 0 ? 1 : -1)) {
                Haptics.play(HapticKind.light);
              }
            }
          : null,
      child: AnimatedSwitcher(
        duration: Motion.smooth.duration,
        switchInCurve: Motion.smooth,
        switchOutCurve: Curves.easeOut,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final t = animation.value;
            return GlassFade(
              opacity: GlassFade.of(context) * t.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.97 + 0.03 * t,
                alignment: Alignment.topCenter,
                child: child,
              ),
            );
          },
        ),
        child: KeyedSubtree(
          key: ValueKey(byDay ? 'day-${store.focusedMonth}' : 'month'),
          child: list,
        ),
      ),
    );
  }

  List<Widget> _dayCards(ExpenseStore store) {
    final days = store.daysInFocusedMonth;
    final selected = store.selectedDay;
    return [
      for (var i = 0; i < days.length; i++)
        Padding(
          key: ValueKey(days[i].date),
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
          child: Entrance(
            delay: _stagger(i),
            child: _dayCard(
              store,
              days[i],
              selected != null && isSameDay(days[i].date, selected),
            ),
          ),
        ),
    ];
  }

  Widget _dayCard(ExpenseStore store, DayNote day, bool expanded) {
    final weekday = weekdayName(day.date);
    final items = plural(day.items.length, 'item');
    return SummaryCard(
      key: keyFor(day.date),
      title: dayTitle(day.date),
      subtitle: '$weekday · $items',
      expandedSubtitle: '$weekday · Note',
      total: day.total,
      lines: [
        for (final e in day.items) SummaryLine(label: e.name, amount: e.amount),
      ],
      badgeGlyph: LineGlyph.note,
      expanded: expanded,
      onExpand: () => store.selectDay(day.date),
      onOpen: () => onOpenNote(day),
      semanticLabel:
          '${dayTitle(day.date)}, $weekday, $items, '
          '${formatTaka(day.total)}${expanded ? '. Edit note' : ''}',
    );
  }

  List<Widget> _monthCards(ExpenseStore store) {
    final months = store.months;
    final focused = store.focusedMonth;
    return [
      for (var i = 0; i < months.length; i++)
        Padding(
          key: ValueKey(months[i].month),
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
          child: Entrance(
            delay: _stagger(i),
            child: _monthCard(
              store,
              months[i],
              focused != null && isSameMonth(months[i].month, focused),
            ),
          ),
        ),
    ];
  }

  Widget _monthCard(ExpenseStore store, MonthSummary month, bool expanded) {
    final summary =
        '${plural(month.days.length, 'day')} · '
        '${plural(month.itemCount, 'item')}';
    return SummaryCard(
      title: monthTitle(month.month),
      subtitle: summary,
      expandedSubtitle: summary,
      total: month.total,
      lines: [
        for (final d in month.days)
          SummaryLine(
            label: shortDay(d.date),
            detail: weekdayName(d.date).substring(0, 3),
            amount: d.total,
            onTap: () {
              store.selectDay(d.date);
              onReveal(d.date);
            },
          ),
      ],
      badgeGlyph: LineGlyph.calendarMonth,
      expanded: expanded,
      onExpand: () => store.selectMonth(month.month),
      onOpen: null,
      semanticLabel:
          '${monthTitle(month.month)}, $summary, ${formatTaka(month.total)}',
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return LiquidBox(
      style: Glass.card,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text('No expenses yet', style: AppText.footnote),
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.onSelect});

  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final bars = store.chartBars;
    if (bars.isEmpty) return const SizedBox.shrink();

    final n = bars.length;
    final caption = store.mode == GroupMode.day
        ? (n == 1 ? 'Last entry' : 'Last $n entries')
        : (n == 1 ? 'This month' : 'Last $n months');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeWithGlass(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Flexible(
                  child: Text('Chart view', style: AppText.title3, maxLines: 1),
                ),
                const SizedBox(width: 12),
                Text(caption, style: AppText.footnote, maxLines: 1),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SpendChart(bars: bars, onSelect: onSelect),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidPressable(
      onTap: onTap,
      haptic: HapticKind.medium,
      pressedScale: 0.97,
      borderRadius: 29,
      child: LiquidBox(
        style: Glass.primaryButton(),
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LineIcon(
              LineGlyph.plus,
              size: 18,
              strokeWidth: 2.6,
              color: AppColors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'Add expense',
              style: AppText.headline.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
