import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/tokens.dart';
import '../../models/expense.dart';
import '../../state/expense_store.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_overlay_route.dart';
import '../../widgets/liquid_pressable.dart';

/// "Group expenses" menu. The glass of the toolbar button stretches out
/// into the menu and folds back into it on dismiss.
class ViewMenu extends StatelessWidget {
  const ViewMenu({super.key, required this.anchor, required this.animation});

  static const _labelHeight = 29.5;
  static const _itemHeight = 48.0;
  // CSS content-box: 250 wide + 8 padding + 1 border on each side.
  static const _width = 250.0 + 16 + 2;
  static const _height = _labelHeight + _itemHeight * 2 + 16 + 2;

  /// The button the menu grows out of, in global coordinates.
  final Rect anchor;
  final Animation<double> animation;

  static Route<void> route(Rect anchor) => LiquidOverlayRoute<void>(
    builder: (context, animation) =>
        ViewMenu(anchor: anchor, animation: animation),
  );

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final target = Rect.fromLTWH(
      screen.width - 16 - _width,
      anchor.bottom - 4.5,
      _width,
      _height,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final contentOpacity = ((t - 0.3) / 0.6).clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(
              child: GlassScrim(
                progress: t,
                color: AppColors.menuScrim,
                blur: 3,
                semanticLabel: 'Close menu',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Positioned.fromRect(
              rect: Rect.lerp(anchor, target, t)!,
              child: LiquidBox(
                style: GlassStyle.lerp(Glass.menuButton, Glass.menu, t),
                child: OverflowBox(
                  alignment: Alignment.topRight,
                  minWidth: _width - 2,
                  maxWidth: _width - 2,
                  minHeight: _height - 2,
                  maxHeight: _height - 2,
                  child: Opacity(
                    opacity: contentOpacity,
                    child: const _MenuContent(),
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

class _MenuContent extends StatelessWidget {
  const _MenuContent();

  @override
  Widget build(BuildContext context) {
    final mode = context.select<ExpenseStore, GroupMode>((s) => s.mode);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: ViewMenu._labelHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Text(
                'Group expenses',
                style: TextStyle(
                  fontSize: 13,
                  height: 15.5 / 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryLabel,
                ),
              ),
            ),
          ),
          SizedBox(
            height: ViewMenu._itemHeight * 2,
            child: Stack(
              children: [
                // The selection is a single tinted lozenge that glides.
                AnimatedPositioned(
                  duration: Motion.bouncy.duration,
                  curve: Motion.bouncy,
                  left: 0,
                  right: 0,
                  top: mode == GroupMode.day ? 0 : ViewMenu._itemHeight,
                  height: ViewMenu._itemHeight,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accentTint,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                Column(
                  children: [
                    _MenuItem(
                      label: 'View by date',
                      glyph: LineGlyph.calendarDay,
                      value: GroupMode.day,
                      selected: mode == GroupMode.day,
                    ),
                    _MenuItem(
                      label: 'View by month',
                      glyph: LineGlyph.calendarMonth,
                      value: GroupMode.month,
                      selected: mode == GroupMode.month,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.glyph,
    required this.value,
    required this.selected,
  });

  final String label;
  final LineGlyph glyph;
  final GroupMode value;
  final bool selected;

  void _choose(BuildContext context) {
    context.read<ExpenseStore>().setMode(value);
    final route = ModalRoute.of(context);
    // Let the lozenge land before the menu folds away.
    Future.delayed(const Duration(milliseconds: 240), () {
      if (context.mounted && (route?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: LiquidPressable(
        onTap: () => _choose(context),
        haptic: HapticKind.selection,
        pressedScale: 0.97,
        borderRadius: 16,
        semanticLabel: label,
        child: SizedBox(
          height: ViewMenu._itemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                AnimatedScale(
                  scale: selected ? 1 : 0.4,
                  duration: Motion.bouncy.duration,
                  curve: Motion.bouncy,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: Motion.snappy.duration,
                    child: const LineIcon(
                      LineGlyph.check,
                      size: 18,
                      strokeWidth: 2.4,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: AppText.body)),
                LineIcon(glyph, size: 18, strokeWidth: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
