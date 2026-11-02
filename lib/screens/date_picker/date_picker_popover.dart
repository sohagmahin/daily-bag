import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/strings.dart';
import '../../app/tokens.dart';
import '../../state/expense_draft.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_overlay_route.dart';
import '../../widgets/liquid_pressable.dart';

/// "Pick a date": the date badge's glass blooms into a calendar. Picking a
/// day updates the note behind it live.
class DatePickerPopover extends StatefulWidget {
  const DatePickerPopover({
    super.key,
    required this.anchor,
    required this.animation,
  });

  final Rect anchor;
  final Animation<double> animation;

  static Route<void> route(Rect anchor, ExpenseDraft draft) =>
      LiquidOverlayRoute<void>(
        builder: (context, animation) => ChangeNotifierProvider.value(
          value: draft,
          child: DatePickerPopover(anchor: anchor, animation: animation),
        ),
      );

  @override
  State<DatePickerPopover> createState() => _DatePickerPopoverState();
}

// Vertical rhythm of the popover, top to bottom (CSS px).
const _border = 1.0;
const _padTop = 16.0;
const _padBottom = 14.0;
const _padX = 14.0;
const _headerHeight = 36.0;
const _weekdayHeight = 14.3;
const _gap = 10.0;
const _dividerBlock = 5.0;
const _footerHeight = 36.0;
const _cell = 40.0;
const _rowGap = 4.0;

int _leadingBlanks(DateTime month) =>
    DateTime(month.year, month.month).weekday % 7;
int _daysIn(DateTime month) => DateTime(month.year, month.month + 1, 0).day;
int _rowsIn(DateTime month) =>
    ((_leadingBlanks(month) + _daysIn(month)) / 7).ceil();
double _gridHeight(int rows) => rows * _cell + (rows - 1) * _rowGap;

class _DatePickerPopoverState extends State<DatePickerPopover> {
  late DateTime _month;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _month = monthOf(context.read<ExpenseDraft>().date);
  }

  void _showMonth(int delta) {
    setState(() {
      _direction = delta;
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  void _pick(DateTime day) => context.read<ExpenseDraft>().setDate(day);

  void _today() {
    final now = dateOnly(DateTime.now());
    _pick(now);
    final month = monthOf(now);
    if (month == _month) return;
    setState(() {
      _direction = month.isAfter(_month) ? 1 : -1;
      _month = month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final selected = context.watch<ExpenseDraft>().date;
    final width = math.min(330.0 + _padX * 2 + _border * 2, screen.width - 32);
    final innerWidth = width - _border * 2;
    final targetHeight =
        _border * 2 +
        _padTop +
        _headerHeight +
        _gap +
        _weekdayHeight +
        _gap +
        _gridHeight(_rowsIn(_month)) +
        _gap +
        _dividerBlock +
        _gap +
        _footerHeight +
        _padBottom;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: targetHeight),
      duration: Motion.smooth.duration,
      curve: Motion.smooth,
      builder: (context, height, _) => AnimatedBuilder(
        animation: widget.animation,
        builder: (context, _) {
          final t = widget.animation.value;
          final target = Rect.fromLTWH(
            screen.width - 16 - width,
            widget.anchor.bottom + 22,
            width,
            height,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: GlassScrim(
                  progress: t,
                  color: context.palette.pickerScrim,
                  blur: 2,
                  semanticLabel: tr.closeCalendar,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned.fromRect(
                rect: Rect.lerp(widget.anchor, target, t)!,
                child: Semantics(
                  scopesRoute: true,
                  namesRoute: true,
                  explicitChildNodes: true,
                  label: tr.chooseDate,
                  child: LiquidBox(
                    style: GlassStyle.lerp(
                      context.palette.glass.dateBadge,
                      context.palette.glass.calendar,
                      t,
                    ),
                    child: OverflowBox(
                      alignment: Alignment.topRight,
                      minWidth: innerWidth,
                      maxWidth: innerWidth,
                      minHeight: height - _border * 2,
                      maxHeight: height - _border * 2,
                      child: Opacity(
                        opacity: ((t - 0.3) / 0.6).clamp(0.0, 1.0),
                        child: _calendar(innerWidth - _padX * 2, selected),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _calendar(double gridWidth, DateTime selected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_padX, _padTop, _padX, _padBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _SlideSwitcher(
                      direction: _direction,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        monthTitle(_month),
                        key: ValueKey(_month),
                        style: AppText.headline,
                      ),
                    ),
                  ),
                  _NavButton(
                    glyph: LineGlyph.chevronLeft,
                    label: tr.previousMonth,
                    onTap: () => _showMonth(-1),
                  ),
                  const SizedBox(width: 6),
                  _NavButton(
                    glyph: LineGlyph.chevronRight,
                    label: tr.nextMonth,
                    onTap: () => _showMonth(1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _gap),
          SizedBox(
            height: _weekdayHeight,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (final d in tr.weekdaysShort)
                    Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: _weekdayHeight / 12,
                          fontWeight: FontWeight.w600,
                          color: context.palette.weekdayLabel,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: ClipRect(
              child: _SlideSwitcher(
                direction: _direction,
                alignment: Alignment.topCenter,
                child: _MonthGrid(
                  key: ValueKey(_month),
                  month: _month,
                  width: gridWidth,
                  selected: selected,
                  onPick: _pick,
                ),
              ),
            ),
          ),
          const SizedBox(height: _gap),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: context.palette.separator),
            ),
          ),
          const SizedBox(height: _gap),
          SizedBox(
            height: _footerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FooterButton(
                    label: tr.today,
                    padding: 14,
                    background: context.palette.accentTint,
                    foreground: context.palette.accentText,
                    haptic: HapticKind.selection,
                    onTap: _today,
                  ),
                  _FooterButton(
                    label: tr.done,
                    padding: 18,
                    background: AppColors.accent,
                    foreground: AppColors.white,
                    haptic: HapticKind.light,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    super.key,
    required this.month,
    required this.width,
    required this.selected,
    required this.onPick,
  });

  final DateTime month;
  final double width;
  final DateTime selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final blanks = _leadingBlanks(month);
    final count = _daysIn(month);
    final column = width / 7;
    final today = DateTime.now();
    final showSelection = isSameMonth(selected, month);
    final selIndex = blanks + selected.day - 1;

    Offset cellOrigin(int index) =>
        Offset((index % 7) * column, (index ~/ 7) * (_cell + _rowGap));

    final indicator = cellOrigin(showSelection ? selIndex : 0);

    return SizedBox(
      width: width,
      height: _gridHeight(_rowsIn(month)),
      child: Stack(
        children: [
          // One selection disc that glides between days.
          AnimatedPositioned(
            duration: Motion.bouncy.duration,
            curve: Motion.bouncy,
            left: indicator.dx + (column - _cell) / 2,
            top: indicator.dy,
            width: _cell,
            height: _cell,
            child: AnimatedScale(
              scale: showSelection ? 1 : 0,
              duration: Motion.snappy.duration,
              curve: Motion.snappy,
              child: LiquidBox(style: context.palette.glass.daySelected),
            ),
          ),
          for (var day = 1; day <= count; day++)
            _DayCell(
              origin: cellOrigin(blanks + day - 1),
              width: column,
              date: DateTime(month.year, month.month, day),
              selected: showSelection && selected.day == day,
              isToday: isSameDay(today, DateTime(month.year, month.month, day)),
              onPick: onPick,
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.origin,
    required this.width,
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onPick,
  });

  final Offset origin;
  final double width;
  final DateTime date;
  final bool selected;
  final bool isToday;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: origin.dx,
      top: origin.dy,
      width: width,
      height: _cell + _rowGap,
      child: Semantics(
        button: true,
        selected: selected,
        label: longDay(date),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (selected) return;
            Haptics.play(HapticKind.selection);
            onPick(date);
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox.square(
              dimension: _cell,
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: Motion.snappy.duration,
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected
                        ? AppColors.white
                        : (isToday ? AppColors.accent : context.palette.label),
                    fontFeatures: AppText.tabular,
                  ),
                  child: Text(digits(date.day)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final LineGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidPressable(
      onTap: onTap,
      haptic: HapticKind.light,
      pressedScale: 0.88,
      semanticLabel: label,
      child: SizedBox.square(
        dimension: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.palette.fill,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: LineIcon(
              glyph,
              size: 14,
              strokeWidth: 2.8,
              color: context.palette.accentText,
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.label,
    required this.padding,
    required this.background,
    required this.foreground,
    required this.haptic,
    required this.onTap,
  });

  final String label;
  final double padding;
  final Color background;
  final Color foreground;
  final HapticKind haptic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidPressable(
      onTap: onTap,
      haptic: haptic,
      pressedScale: 0.94,
      borderRadius: 18,
      child: Container(
        height: _footerHeight,
        padding: EdgeInsets.symmetric(horizontal: padding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: AppText.subheadBold.copyWith(color: foreground),
        ),
      ),
    );
  }
}

/// Slides content sideways in the direction the month moved.
class _SlideSwitcher extends StatelessWidget {
  const _SlideSwitcher({
    required this.direction,
    required this.alignment,
    required this.child,
  });

  final int direction;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.smooth.duration,
      switchInCurve: Motion.smooth,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final incoming = child.key == this.child.key;
        final from = Offset(incoming ? 0.35 * direction : -0.35 * direction, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: from, end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
