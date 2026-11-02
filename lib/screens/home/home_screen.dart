import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/strings.dart';
import '../../app/tokens.dart';
import '../../models/expense.dart';
import '../../state/bazar_store.dart';
import '../../state/expense_store.dart';
import '../../widgets/entrance.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_background.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_pressable.dart';
import '../add_expense/add_expense_sheet.dart';
import '../bazar_note/bazar_note_screen.dart';
import '../menu/view_menu.dart';
import '../scan/scan_screen.dart';
import '../thoughts/thoughts_popover.dart';
import 'spend_chart.dart';
import 'summary_card.dart';

/// "Daily Bag": the day (or month) list, the chart, and "Fill the bag".
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

  /// Opens the Bazar Diary: blank for a new entry (saved items are added to
  /// that day's), or filled from [existing] to edit it.
  Future<void> _openDiary({
    DayNote? existing,
    bool focusThoughts = false,
  }) async {
    final saved = await Navigator.of(context).push(
      AddExpenseSheet.route(
        date: DateTime.now(),
        existing: existing,
        focusThoughts: focusThoughts,
      ),
    );
    if (saved != null) _reveal(saved);
  }

  /// Opens "Scan to fill"; shows the day the scanned items went into.
  Future<void> _openScanner() async {
    final saved = await Navigator.of(
      context,
    ).push(ScanScreen.route(onTypeInstead: _openDiary));
    if (saved != null) _reveal(saved);
  }

  /// Opens the Bazar Note; shows the day bought items were moved to.
  Future<void> _openBazar() async {
    final moved = await Navigator.of(context).push(BazarNoteScreen.route());
    if (moved != null) _reveal(moved);
  }

  Future<void> _openThoughts(DayNote day) async {
    final box = _cardKeys[day.date]?.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final action = await Navigator.of(context).push(
      ThoughtsPopover.route(
        day.date,
        box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    if (!mounted || action != ThoughtsAction.edit) return;
    final latest = context.read<ExpenseStore>().dayFor(day.date);
    if (latest != null) _openDiary(existing: latest, focusThoughts: true);
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
      value: context.palette.statusBar,
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
                      onBazar: _openBazar,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GroupList(
                    keyFor: _keyFor,
                    onThoughts: _openThoughts,
                    onReveal: _reveal,
                  ),
                  const SizedBox(height: 14),
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.palette.background.withValues(alpha: 0.85),
                            context.palette.background.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
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
                      context.palette.background.withValues(alpha: 0),
                      context.palette.background.withValues(
                        alpha: context.palette.homeFade,
                      ),
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
              child: Row(
                children: [
                  Expanded(child: _AddButton(onTap: _openDiary)),
                  const SizedBox(width: 10),
                  _ScanButton(onTap: _openScanner),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.menuButtonKey,
    required this.onMenu,
    required this.onBazar,
  });

  final GlobalKey menuButtonKey;
  final VoidCallback onMenu;
  final VoidCallback onBazar;

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
                    style: context.palette.eyebrow,
                  ),
                ),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: Text(tr.dailyBag, style: AppText.largeTitle),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _BazarButton(onTap: onBazar),
        const SizedBox(width: 8),
        KeyedSubtree(
          key: menuButtonKey,
          child: LiquidPressable(
            onTap: onMenu,
            haptic: HapticKind.light,
            pressedScale: 0.9,
            borderRadius: 23,
            semanticLabel: tr.viewOptions,
            child: LiquidBox(
              style: context.palette.glass.menuButton,
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

/// Opens the Bazar Note; the orange badge counts what is left to buy.
class _BazarButton extends StatelessWidget {
  const _BazarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = context.select<BazarStore, int>((s) => s.leftCount);
    return LiquidPressable(
      onTap: onTap,
      haptic: HapticKind.light,
      pressedScale: 0.9,
      borderRadius: 23,
      semanticLabel: left == 0 ? tr.bazarNote : tr.bazarNoteLeft(left),
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            LiquidBox(
              style: context.palette.glass.menuButton,
              width: 44,
              height: 44,
              child: const Center(
                child: LineIcon(LineGlyph.clipboard, size: 22, strokeWidth: 2),
              ),
            ),
            Positioned(
              top: -3,
              right: -3,
              child: AnimatedScale(
                scale: left == 0 ? 0 : 1,
                duration: Motion.bouncy.duration,
                curve: left == 0 ? Curves.easeIn : Motion.bouncy,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: context.palette.badgeRing,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 3),
                        blurRadius: 8,
                        color: AppColors.orange.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  child: Text(
                    digits(math.max(left, 1)),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      fontFeatures: AppText.tabular,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.keyFor,
    required this.onThoughts,
    required this.onReveal,
  });

  final GlobalKey Function(DateTime date) keyFor;
  final ValueChanged<DayNote> onThoughts;
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
    final items = tr.items(day.items.length);
    final hint = day.hasThoughts ? tr.holdToRead : tr.holdToAdd;
    return SummaryCard(
      key: keyFor(day.date),
      title: dayTitle(day.date),
      subtitle: '$weekday · $items',
      expandedSubtitle: '$weekday · $hint',
      total: day.total,
      lines: [
        for (final e in day.items) SummaryLine(label: e.name, amount: e.amount),
      ],
      badgeGlyph: LineGlyph.note,
      expanded: expanded,
      onExpand: () => store.selectDay(day.date),
      onLongPress: () => onThoughts(day),
      onBadgeTap: () => onThoughts(day),
      badgeLabel: tr.showThoughtsFor(dayAndMonth(day.date)),
      semanticLabel:
          '${dayTitle(day.date)}, $weekday, $items, ${formatMoney(day.total)}',
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
        '${tr.days(month.days.length)} · ${tr.items(month.itemCount)}';
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
      semanticLabel:
          '${monthTitle(month.month)}, $summary, ${formatMoney(month.total)}',
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return LiquidBox(
      style: context.palette.glass.card,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(tr.noExpenses, style: context.palette.footnote),
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
                Flexible(
                  child: Text(
                    tr.recentSpending,
                    style: AppText.title3,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                _TotalToggle(total: store.grandTotal),
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
        style: context.palette.glass.primaryButton(),
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
              tr.fillTheBag,
              style: AppText.headline.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round glass button beside "Fill the bag" that opens the scanner.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidPressable(
      onTap: onTap,
      haptic: HapticKind.medium,
      pressedScale: 0.9,
      borderRadius: 29,
      semanticLabel: tr.scanWithCamera,
      child: LiquidBox(
        style: context.palette.glass.scanButton,
        width: 56,
        height: 56,
        child: const Center(child: LineIcon(LineGlyph.scan, size: 24)),
      ),
    );
  }
}

/// The chart header's "Total" pill: everything spent, hidden until asked.
class _TotalToggle extends StatefulWidget {
  const _TotalToggle({required this.total});

  final double total;

  @override
  State<_TotalToggle> createState() => _TotalToggleState();
}

class _TotalToggleState extends State<_TotalToggle> {
  bool _shown = false;

  static Widget _roll(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.45),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );

  static Widget _stackRight(Widget? current, List<Widget> previous) => Stack(
    alignment: Alignment.centerRight,
    children: [...previous, ?current],
  );

  @override
  Widget build(BuildContext context) {
    final amount = formatMoney(widget.total);
    return LiquidPressable(
      onTap: () => setState(() => _shown = !_shown),
      haptic: HapticKind.selection,
      pressedScale: 0.94,
      borderRadius: 16,
      semanticLabel: _shown ? tr.hideTotal(amount) : tr.showTotal,
      child: Container(
        height: 32,
        padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
        decoration: BoxDecoration(
          color: context.palette.quietFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ExcludeSemantics(
          child: AnimatedSize(
            duration: Motion.snappy.duration,
            curve: Motion.snappy,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr.total,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.secondaryLabelStrong,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: Motion.snappy.duration,
                  switchInCurve: Motion.snappy,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: _roll,
                  layoutBuilder: _stackRight,
                  child: _shown
                      ? Text(
                          amount,
                          key: const ValueKey('amount'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.palette.pillLabel,
                            fontFeatures: AppText.tabular,
                          ),
                        )
                      : Text(
                          '•••••',
                          key: ValueKey('hidden'),
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 1,
                            color: context.palette.chevron,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: Motion.snappy.duration,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: LineIcon(
                    _shown ? LineGlyph.eyeOff : LineGlyph.eye,
                    key: ValueKey(_shown),
                    size: 16,
                    strokeWidth: 2,
                    color: context.palette.secondaryLabelStrong,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
