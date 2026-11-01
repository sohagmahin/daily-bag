import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/tokens.dart';
import '../../models/expense.dart';
import '../../state/expense_draft.dart';
import '../../state/expense_store.dart';
import '../../widgets/entrance.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_overlay_route.dart';
import '../../widgets/liquid_pressable.dart';
import '../date_picker/date_picker_popover.dart';
import 'expense_row.dart';
import 'thoughts_field.dart';

/// "Bazar Diary": a day's items and thoughts. Starts empty for a new day,
/// or filled from [ExpenseDraft.existing]. Pops with the saved date.
class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({
    super.key,
    required this.animation,
    this.focusThoughts = false,
  });

  final Animation<double> animation;

  /// Opened from "Edit thoughts": lands in the thoughts field.
  final bool focusThoughts;

  static Route<DateTime?> route({
    required DateTime date,
    DayNote? existing,
    bool focusThoughts = false,
  }) => LiquidOverlayRoute<DateTime?>(
    curve: Motion.smooth,
    builder: (context, animation) => ChangeNotifierProvider(
      create: (_) => ExpenseDraft(date: date, existing: existing),
      child: AddExpenseSheet(
        animation: animation,
        focusThoughts: focusThoughts,
      ),
    ),
  );

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet>
    with SingleTickerProviderStateMixin {
  static const _dismissDistance = 140.0;

  late final _drag = AnimationController.unbounded(vsync: this);
  final _rowsScroll = ScrollController();
  final _badgeKey = GlobalKey();
  bool _pastThreshold = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusThoughts) widget.animation.addStatusListener(_onOpened);
  }

  void _onOpened(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    widget.animation.removeStatusListener(_onOpened);
    if (mounted) context.read<ExpenseDraft>().thoughtsFocus.requestFocus();
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onOpened);
    _drag.dispose();
    _rowsScroll.dispose();
    super.dispose();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).maybePop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // Rubber-band when pulled up past the resting position.
    final resistance = _drag.value < 0 ? 0.25 : 1.0;
    _drag.value = (_drag.value + d.delta.dy * resistance).clamp(
      -40.0,
      double.infinity,
    );
    final past = _drag.value > _dismissDistance;
    if (past != _pastThreshold) {
      _pastThreshold = past;
      Haptics.play(HapticKind.selection);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (_drag.value > _dismissDistance || velocity > 900) {
      _close();
    } else {
      _drag.animateWith(
        SpringSimulation(Motion.pressRelease, _drag.value, 0, velocity),
      );
    }
  }

  void _addRow() {
    final row = context.read<ExpenseDraft>().addRow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      row.nameFocus.requestFocus();
      if (_rowsScroll.hasClients) {
        _rowsScroll.animateTo(
          _rowsScroll.position.maxScrollExtent,
          duration: Motion.smooth.duration,
          curve: Motion.smooth,
        );
      }
    });
  }

  void _pickDate() {
    final box = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      DatePickerPopover.route(
        box.localToGlobal(Offset.zero) & box.size,
        context.read<ExpenseDraft>(),
      ),
    );
  }

  void _save() {
    final draft = context.read<ExpenseDraft>();
    final saved = draft.commit(context.read<ExpenseStore>());
    final changed = saved != null || draft.existing != null;
    Haptics.play(changed ? HapticKind.success : HapticKind.light);
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top + 17;
    final keyboard = mq.viewInsets.bottom;
    final bottom = keyboard > 0 ? keyboard + 8 : 8.0;
    final travel = mq.size.height - top + 40;

    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _drag]),
      child: _panel(),
      builder: (context, panel) {
        final t = widget.animation.value;
        final pulled = _drag.value.clamp(0.0, travel) / travel;
        return Stack(
          children: [
            Positioned.fill(
              child: GlassScrim(
                progress: t * (1 - pulled),
                color: AppColors.sheetScrim,
                semanticLabel: 'Dismiss',
                onTap: _close,
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: top,
              bottom: bottom,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * travel + _drag.value),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _panel() {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Bazar Diary',
      child: LiquidBox(
        style: Glass.sheet,
        padding: const EdgeInsets.only(top: 8, bottom: 26),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: SizedBox(
                          width: 36,
                          height: 5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.grabber,
                              borderRadius: BorderRadius.all(
                                Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _Header(badgeKey: _badgeKey, onPickDate: _pickDate),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _Rows(scroll: _rowsScroll, onAddRow: _addRow),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(26, 0, 26, 14),
                child: _TotalLine(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LiquidPressable(
                  onTap: _save,
                  haptic: HapticKind.none,
                  pressedScale: 0.97,
                  borderRadius: 29,
                  child: LiquidBox(
                    style: Glass.primaryButton(glow: 0.35),
                    height: 56,
                    child: Center(
                      child: Text(
                        'Done',
                        style: AppText.headline.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.badgeKey, required this.onPickDate});

  final GlobalKey badgeKey;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final date = context.select<ExpenseDraft, DateTime>((d) => d.date);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bazar Diary', style: AppText.title1),
              const SizedBox(height: 2),
              _Swap(
                value: date,
                child: Text(
                  longDay(date),
                  style: AppText.subhead.copyWith(
                    color: AppColors.secondaryLabelStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        KeyedSubtree(
          key: badgeKey,
          child: LiquidPressable(
            onTap: onPickDate,
            haptic: HapticKind.light,
            pressedScale: 0.92,
            borderRadius: 30,
            semanticLabel:
                'Date: ${date.day} ${monthName(date)}. Open calendar',
            child: LiquidBox(
              style: Glass.dateBadge,
              width: 58,
              height: 58,
              child: ExcludeSemantics(
                child: _Swap(
                  value: date,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        shortMonthName(date).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          height: 12 / 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.red,
                        ),
                      ),
                      Text(
                        twoDigits(date.day),
                        style: const TextStyle(
                          fontSize: 22,
                          height: 24 / 22,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppText.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rolls text up when the value it shows changes.
class _Swap extends StatelessWidget {
  const _Swap({
    required this.value,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  final Object value;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.snappy.duration,
      switchInCurve: Motion.snappy,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.scroll, required this.onAddRow});

  final ScrollController scroll;
  final VoidCallback onAddRow;

  @override
  Widget build(BuildContext context) {
    context.select<ExpenseDraft, int>((d) => d.version);
    final rows = context.read<ExpenseDraft>().rows;

    return ListView(
      controller: scroll,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RemovableRow(key: rows[i].key, row: rows[i], index: i),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: _AddMoreButton(onTap: onAddRow),
        ),
        const SizedBox(height: 18),
        const ThoughtsField(),
      ],
    );
  }
}

class _RemovableRow extends StatelessWidget {
  const _RemovableRow({super.key, required this.row, required this.index});

  final DraftRow row;
  final int index;

  @override
  Widget build(BuildContext context) {
    final field = ExpenseRow(row: row, index: index);
    return Dismissible(
      key: row.key,
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      onUpdate: (d) {
        if (d.reached != d.previousReached) Haptics.play(HapticKind.light);
      },
      onDismissed: (_) => context.read<ExpenseDraft>().removeRow(row),
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.destructiveTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              'Remove',
              style: AppText.subheadBold.copyWith(color: AppColors.red),
            ),
          ),
        ),
      ),
      child: row.fresh ? Entrance(offset: 10, child: field) : field,
    );
  }
}

class _AddMoreButton extends StatelessWidget {
  const _AddMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidPressable(
      onTap: onTap,
      haptic: HapticKind.light,
      pressedScale: 0.94,
      borderRadius: 25,
      child: LiquidBox(
        style: Glass.pill,
        height: 48,
        padding: const EdgeInsets.fromLTRB(14, 0, 20, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 30,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accentIconTint,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: LineIcon(
                    LineGlyph.plus,
                    size: 16,
                    strokeWidth: 2.8,
                    color: AppColors.accentText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Add more',
              style: AppText.callout.copyWith(color: AppColors.accentText),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine();

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ExpenseDraft>();
    final whole = draft.total == draft.total.roundToDouble();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            draft.totalLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.subhead.copyWith(
              color: AppColors.secondaryLabelStrong,
            ),
          ),
        ),
        const SizedBox(width: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(end: draft.total),
          duration: Motion.snappy.duration,
          // No overshoot: a total must never read below its target.
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            formatTaka(whole ? value.roundToDouble() : value),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFeatures: AppText.tabular,
            ),
          ),
        ),
      ],
    );
  }
}
