import 'dart:async';
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
import 'day_island.dart';
import 'spending_map.dart';
import 'summary_card.dart';

/// "Daily Bag": the spending map over the day (or month) list, and
/// "Fill the bag".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 56px button + 1px border top and bottom, as the design renders it.
  static const _addButtonHeight = 58.0;

  // The list's first card starts under the open map (see [_TopLayout]);
  // its foot clears "Fill the bag".
  static const _listInset = 250.0;
  static const _listFoot = 220.0;

  /// From the list's top edge to just under the folded map.
  static const _underFoldedMap = 100.0;

  final _scroll = ScrollController();
  final _fold = ValueNotifier<double>(0);
  final _pillHidden = ValueNotifier<bool>(false);
  final _hovered = ValueNotifier<MapDay?>(null);
  final _menuButtonKey = GlobalKey();
  final _cardKeys = <String, GlobalKey>{};
  Timer? _idle;
  double _lastY = 0;

  /// The day picked on the map; the list shows only it.
  DateTime? _filter;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _idle?.cancel();
    _scroll.dispose();
    _fold.dispose();
    _pillHidden.dispose();
    _hovered.dispose();
    super.dispose();
  }

  /// Day cards appear in the full list and alone under a picked day;
  /// both can be on screen while one gives way to the other.
  String get _scope => _filter == null ? 'all' : 'one';

  GlobalKey _keyFor(DateTime date) =>
      _cardKeys.putIfAbsent('$_scope ${dateOnly(date)}', GlobalKey.new);

  GlobalKey? _cardKey(DateTime date) => _cardKeys['$_scope ${dateOnly(date)}'];

  double get _buttonInset => math.max(MediaQuery.paddingOf(context).bottom, 20);

  /// The map folds over the first [SpendingMap.foldRange] of scrolling, and
  /// the "Total" pill steps aside while the list moves down.
  void _onScroll() {
    final y = _scroll.offset;
    _fold.value = (y / SpendingMap.foldRange).clamp(0.0, 1.0);
    if (y > _lastY + 1 && y > 8) {
      _pillHidden.value = true;
    } else if (y < _lastY - 1) {
      _pillHidden.value = false;
    }
    _lastY = y;
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 160), () {
      if (mounted) _pillHidden.value = false;
    });
  }

  /// The map rests open or folded, never in between.
  bool _onScrollEnd(ScrollEndNotification n) {
    final y = n.metrics.pixels;
    if (y > 0 && y < SpendingMap.foldRange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final at = _scroll.offset;
        if (at > 0 && at < SpendingMap.foldRange) {
          _glideTo(at < SpendingMap.foldRange / 2 ? 0 : SpendingMap.foldRange);
        }
      });
    }
    return false;
  }

  void _glideTo(double offset) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      offset,
      duration: Motion.foldDuration,
      curve: Motion.fold,
    );
  }

  void _toggleFold() => _glideTo(_fold.value > 0.5 ? 0 : SpendingMap.foldRange);

  Future<void> _openMenu() async {
    final box = _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final store = context.read<ExpenseStore>();
    final mode = store.mode;
    await Navigator.of(
      context,
    ).push(ViewMenu.route(box.localToGlobal(Offset.zero) & box.size));
    // A new grouping shows the whole list again.
    if (mounted && store.mode != mode && _filter != null) {
      setState(() => _filter = null);
    }
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
    if (saved != null) _show(saved);
  }

  /// Opens "Scan to fill"; shows the day the scanned items went into.
  Future<void> _openScanner() async {
    final saved = await Navigator.of(
      context,
    ).push(ScanScreen.route(onTypeInstead: _openDiary));
    if (saved != null) _show(saved);
  }

  /// Opens the Bazar Note; shows the day bought items were moved to.
  Future<void> _openBazar() async {
    final moved = await Navigator.of(context).push(BazarNoteScreen.route());
    if (moved != null) _show(moved);
  }

  Future<void> _openThoughts(DayNote day) async {
    final box = _cardKey(day.date)?.currentContext?.findRenderObject();
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

  /// A day picked on the map opens alone under it; null shows every day.
  void _selectFromMap(DateTime? date) {
    final store = context.read<ExpenseStore>();
    setState(() => _filter = date);
    if (date == null) {
      final open = store.selectedDay;
      if (open != null) _reveal(open);
      return;
    }
    if (store.dayFor(date) != null) store.selectDay(date);
    // The list shrinks to one day: bring it up under the map.
    if (_scroll.hasClients && _scroll.offset > SpendingMap.foldRange) {
      _glideTo(SpendingMap.foldRange);
    }
  }

  /// Shows a day that was just filled, leaving any other picked day.
  void _show(DateTime date) {
    final filter = _filter;
    if (filter != null && !isSameDay(filter, date)) {
      setState(() => _filter = null);
    }
    _reveal(date);
  }

  /// Scrolls just enough to show a day's card once it has opened: below
  /// the (folded) map at the top, above "Fill the bag" at the bottom.
  void _reveal(DateTime date) {
    Future.delayed(const Duration(milliseconds: 360), () {
      if (!mounted || !_scroll.hasClients) return;
      final box = _cardKey(date)?.currentContext?.findRenderObject();
      if (box == null) return;
      final viewport = RenderAbstractViewport.of(box);
      final position = _scroll.position;
      final top = viewport.getOffsetToReveal(box, 0).offset - _underFoldedMap;
      final bottom =
          viewport.getOffsetToReveal(box, 1).offset +
          _buttonInset +
          _addButtonHeight +
          16;
      double target;
      if (position.pixels > top) {
        target = top;
      } else if (position.pixels < bottom) {
        target = bottom;
      } else {
        return;
      }
      // Room is made by folding the map, not by leaving it half open.
      if (target > 0 && target < SpendingMap.foldRange) {
        target = SpendingMap.foldRange;
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
            child: CustomMultiChildLayout(
              delegate: _TopLayout(safeTop),
              children: [
                LayoutId(
                  id: _Slot.list,
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: _onScrollEnd,
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: ConstrainedBox(
                          // However short the list, there is room to fold
                          // the map.
                          constraints: BoxConstraints(
                            minHeight:
                                constraints.maxHeight + SpendingMap.foldRange,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              _listInset,
                              16,
                              _listFoot,
                            ),
                            child: _GroupList(
                              keyFor: _keyFor,
                              onThoughts: _openThoughts,
                              onReveal: _reveal,
                              filter: _filter,
                              onShowAll: () => _selectFromMap(null),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                LayoutId(
                  id: _Slot.header,
                  child: Entrance(
                    child: _Header(
                      menuButtonKey: _menuButtonKey,
                      onMenu: _openMenu,
                      onBazar: _openBazar,
                    ),
                  ),
                ),
                LayoutId(
                  id: _Slot.map,
                  child: Entrance(
                    delay: const Duration(milliseconds: 40),
                    child: SpendingMap(
                      fold: _fold,
                      pillHidden: _pillHidden,
                      selected: _filter,
                      onSelect: _selectFromMap,
                      onToggleFold: _toggleFold,
                      hovered: _hovered,
                    ),
                  ),
                ),
              ],
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
          // Over everything, floating just under the status bar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DayIsland(day: _hovered),
          ),
        ],
      ),
    );
  }
}

enum _Slot { list, header, map }

/// Places the header, the spending map over the list, and the list.
///
/// Below the safe area (47px on the design's canvas) the header sits at
/// 62, the map at 134 and the list's top edge 8px above the map, at 126.
/// A header grown by large text pushes the map and list down with it.
class _TopLayout extends MultiChildLayoutDelegate {
  _TopLayout(this.safeTop);

  final double safeTop;

  static const _headerTop = 15.0;
  static const _mapTop = 87.0;
  static const _mapGap = 13.0;
  static const _listAboveMap = 8.0;

  @override
  void performLayout(Size size) {
    final width = size.width - 32;
    final header = layoutChild(
      _Slot.header,
      BoxConstraints(minWidth: width, maxWidth: width),
    );
    positionChild(_Slot.header, Offset(16, safeTop + _headerTop));

    final mapTop =
        safeTop + math.max(_mapTop, _headerTop + header.height + _mapGap);
    layoutChild(_Slot.map, BoxConstraints(minWidth: width, maxWidth: width));
    positionChild(_Slot.map, Offset(16, mapTop));

    final listTop = mapTop - _listAboveMap;
    layoutChild(
      _Slot.list,
      BoxConstraints.tight(
        Size(size.width, math.max(0, size.height - listTop)),
      ),
    );
    positionChild(_Slot.list, Offset(0, listTop));
  }

  @override
  bool shouldRelayout(_TopLayout oldDelegate) => oldDelegate.safeTop != safeTop;
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
    required this.filter,
    required this.onShowAll,
  });

  final GlobalKey Function(DateTime date) keyFor;
  final ValueChanged<DayNote> onThoughts;
  final ValueChanged<DateTime> onReveal;
  final DateTime? filter;
  final VoidCallback onShowAll;

  /// Cards rise in one after another; far down the list they arrive
  /// together rather than seconds late.
  static Duration _stagger(int index) =>
      Duration(milliseconds: 60 + 50 * math.min(index, 8));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final byDay = store.mode == GroupMode.day;
    final filter = this.filter;

    final cards = filter != null
        ? _oneDay(store, filter)
        : byDay
        ? _dayCards(store)
        : _monthCards(store);
    final list = cards.isEmpty
        ? const _EmptyCard()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          );

    return AnimatedSwitcher(
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
        key: ValueKey(
          filter != null
              ? 'one ${dateOnly(filter)}'
              : byDay
              ? 'days'
              : 'months',
        ),
        child: list,
      ),
    );
  }

  /// Newest first, the open day expanded.
  List<Widget> _dayCards(ExpenseStore store) {
    final days = store.days.reversed.toList();
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

  /// The day picked on the map, under "Showing one day".
  List<Widget> _oneDay(ExpenseStore store, DateTime date) {
    final day = store.dayFor(date);
    final selected = store.selectedDay;
    return [
      Entrance(
        delay: _stagger(0),
        child: _OneDayHeader(date: date, onShowAll: onShowAll),
      ),
      const SizedBox(height: 10),
      Entrance(
        delay: _stagger(1),
        child: day == null
            ? _NothingThisDay(date: date)
            : _dayCard(
                store,
                day,
                selected != null && isSameDay(day.date, selected),
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

  /// Newest first, the focused month expanded.
  List<Widget> _monthCards(ExpenseStore store) {
    final months = store.months.reversed.toList();
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

/// "SHOWING ONE DAY", and the picked day as a chip that clears it.
class _OneDayHeader extends StatelessWidget {
  const _OneDayHeader({required this.date, required this.onShowAll});

  final DateTime date;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: FadeWithGlass(
                child: Text(
                  tr.showingOneDay.toUpperCase(),
                  style: palette.eyebrow,
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            LiquidPressable(
              onTap: onShowAll,
              haptic: HapticKind.selection,
              pressedScale: 0.94,
              borderRadius: 16,
              semanticLabel: tr.showAllDays,
              child: FadeWithGlass(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                  decoration: BoxDecoration(
                    color: palette.accentWash,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mapDayLabel(date),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.accentText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.quietFill,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: 18,
                            child: Center(
                              child: LineIcon(
                                LineGlyph.close,
                                size: 10,
                                strokeWidth: 3.4,
                                color: palette.accentText,
                              ),
                            ),
                          ),
                        ),
                      ],
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

/// A picked day with nothing in the bag.
class _NothingThisDay extends StatelessWidget {
  const _NothingThisDay({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CustomPaint(
      foregroundPainter: _DashedRim(
        color: palette.separator.withValues(
          alpha: palette.separator.a * GlassFade.of(context).clamp(0.0, 1.0),
        ),
        radius: palette.glass.emptyDay.radius,
      ),
      child: LiquidBox(
        style: palette.glass.emptyDay,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.5,
              child: const LineIcon(LineGlyph.bag, size: 28, strokeWidth: 1.8),
            ),
            const SizedBox(height: 6),
            Text(
              tr.nothingThisDay,
              textAlign: TextAlign.center,
              style: AppText.callout,
            ),
            const SizedBox(height: 6),
            Text(
              dayTitle(date),
              textAlign: TextAlign.center,
              style: palette.footnote,
            ),
          ],
        ),
      ),
    );
  }
}

/// A CSS `1px dashed` border.
class _DashedRim extends CustomPainter {
  _DashedRim({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rim = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(radius - 0.5),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in (Path()..addRRect(rim)).computeMetrics()) {
      // Dashes as long as the gaps, evened out to close the loop.
      final count = (metric.length / 6).round();
      final step = metric.length / count;
      for (var i = 0; i < count; i++) {
        canvas.drawPath(
          metric.extractPath(i * step, i * step + step / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRim old) =>
      old.color != color || old.radius != radius;
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
