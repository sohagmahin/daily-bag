import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/strings.dart';
import '../../app/tokens.dart';
import '../../models/expense.dart';
import '../../state/expense_store.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_overlay_route.dart';
import '../../widgets/liquid_pressable.dart';

/// What the home screen should do after the popover closes.
enum ThoughtsAction { edit }

/// Long press on a day: its "Bazar thoughts" rise over a frosted screen,
/// with Edit / Share / Delete beneath.
class ThoughtsPopover extends StatefulWidget {
  const ThoughtsPopover({
    super.key,
    required this.date,
    required this.anchor,
    required this.animation,
  });

  final DateTime date;

  /// The pressed day card, in global coordinates.
  final Rect anchor;
  final Animation<double> animation;

  static Route<ThoughtsAction> route(DateTime date, Rect anchor) =>
      LiquidOverlayRoute<ThoughtsAction>(
        builder: (context, animation) =>
            ThoughtsPopover(date: date, anchor: anchor, animation: animation),
      );

  @override
  State<ThoughtsPopover> createState() => _ThoughtsPopoverState();
}

class _ThoughtsPopoverState extends State<ThoughtsPopover> {
  // The design lifts the card 26.5px above the day it belongs to.
  static const _lift = 26.5;

  late DayNote _day = context.read<ExpenseStore>().dayFor(widget.date)!;

  void _close([ThoughtsAction? action]) {
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) Navigator.of(context).pop(action);
  }

  void _share(BuildContext itemContext) {
    final box = itemContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    _close();
    SharePlus.instance.share(
      ShareParams(
        text: _shareText(_day),
        subject: '${tr.dailyBag} · ${dayTitle(_day.date)}',
        sharePositionOrigin: origin,
      ),
    );
  }

  void _delete() {
    context.read<ExpenseStore>().setThoughts(_day.date, '');
    _close();
  }

  @override
  Widget build(BuildContext context) {
    // Keep showing the last known day while closing after a delete.
    _day =
        context.select<ExpenseStore, DayNote?>((s) => s.dayFor(widget.date)) ??
        _day;
    final padding = MediaQuery.paddingOf(context);
    final insets = EdgeInsets.only(
      top: padding.top + 8,
      bottom: math.max(padding.bottom, 20) + 8,
    );

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final t = widget.animation.value;
        final menuT = ((t - 0.12) / 0.88).clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(
              child: GlassScrim(
                progress: t,
                color: context.palette.thoughtsScrim,
                blur: 16,
                saturation: 1.4,
                semanticLabel: tr.closeThoughts,
                onTap: _close,
              ),
            ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _AnchoredLayout(
                  preferredTop: widget.anchor.top - _lift,
                  insets: insets,
                ),
                child: Semantics(
                  scopesRoute: true,
                  namesRoute: true,
                  explicitChildNodes: true,
                  label: tr.thoughtsFor(dayAndMonth(_day.date)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: GlassFade(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 16),
                            child: Transform.scale(
                              scale: 0.94 + 0.06 * t,
                              alignment: Alignment.topCenter,
                              child: _ThoughtsCard(day: _day),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GlassFade(
                          opacity: menuT,
                          child: Transform.scale(
                            scale: 0.5 + 0.5 * menuT,
                            alignment: Alignment.topRight,
                            child: _ActionMenu(
                              hasThoughts: _day.hasThoughts,
                              onEdit: () => _close(ThoughtsAction.edit),
                              onShare: _share,
                              onDelete: _delete,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _shareText(DayNote day) => [
  '${tr.dailyBag} · ${dayTitle(day.date)}',
  for (final e in day.items) '${e.name} — ${formatMoney(e.amount)}',
  if (day.items.isNotEmpty) '${tr.total} — ${formatMoney(day.total)}',
  if (day.hasThoughts) ...['', '${tr.bazarThoughts}:', day.thoughts],
].join('\n');

/// Places the stack at its preferred top, nudged to stay on screen.
class _AnchoredLayout extends SingleChildLayoutDelegate {
  _AnchoredLayout({required this.preferredTop, required this.insets});

  final double preferredTop;
  final EdgeInsets insets;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = constraints.maxWidth - 32;
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0, constraints.maxHeight - insets.vertical),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minTop = insets.top;
    final maxTop = math.max(
      minTop,
      size.height - insets.bottom - childSize.height,
    );
    return Offset(16, preferredTop.clamp(minTop, maxTop));
  }

  @override
  bool shouldRelayout(_AnchoredLayout oldDelegate) =>
      oldDelegate.preferredTop != preferredTop || oldDelegate.insets != insets;
}

class _ThoughtsCard extends StatelessWidget {
  const _ThoughtsCard({required this.day});

  final DayNote day;

  @override
  Widget build(BuildContext context) {
    return LiquidBox(
      style: context.palette.glass.thoughtsCard,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayTitle(day.date), style: AppText.headline),
                    Text(
                      '${weekdayName(day.date)} · ${tr.items(day.items.length)}',
                      style: context.palette.footnote,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.palette.fill,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  formatMoney(day.total),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.palette.pillLabel,
                    fontFeatures: AppText.tabular,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 1,
            child: ColoredBox(color: context.palette.separatorSoft),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              LineIcon(
                LineGlyph.note,
                size: 14,
                strokeWidth: 2.2,
                color: context.palette.accentText,
              ),
              SizedBox(width: 6),
              Text(
                tr.bazarThoughts.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: context.palette.accentText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                day.hasThoughts ? day.thoughts : tr.noThoughts,
                style: TextStyle(
                  fontSize: 17,
                  height: 25 / 17,
                  color: day.hasThoughts
                      ? context.palette.label
                      : context.palette.secondaryLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.hasThoughts,
    required this.onEdit,
    required this.onShare,
    required this.onDelete,
  });

  final bool hasThoughts;
  final VoidCallback onEdit;
  final void Function(BuildContext itemContext) onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return LiquidBox(
      style: context.palette.glass.contextMenu,
      width: 230,
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Action(
            label: hasThoughts ? tr.editThoughts : tr.addThoughts,
            glyph: LineGlyph.pencil,
            onTap: (_) => onEdit(),
          ),
          _Action(label: tr.share, glyph: LineGlyph.share, onTap: onShare),
          if (hasThoughts) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: context.palette.separator),
              ),
            ),
            _Action(
              label: tr.deleteThoughts,
              glyph: LineGlyph.trash,
              color: context.palette.destructive,
              haptic: HapticKind.warning,
              onTap: (_) => onDelete(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.glyph,
    required this.onTap,
    this.color,
    this.haptic = HapticKind.light,
  });

  final String label;
  final LineGlyph glyph;
  final void Function(BuildContext itemContext) onTap;

  /// Defaults to the label colour.
  final Color? color;
  final HapticKind haptic;

  @override
  Widget build(BuildContext context) {
    return LiquidPressable(
      onTap: () => onTap(context),
      haptic: haptic,
      pressedScale: 0.97,
      borderRadius: 16,
      semanticLabel: label,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      color: color ?? context.palette.label,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LineIcon(glyph, size: 18, strokeWidth: 2, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
