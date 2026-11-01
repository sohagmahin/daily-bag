import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/tokens.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_pressable.dart';

class SummaryLine {
  const SummaryLine({
    required this.label,
    required this.amount,
    this.detail,
    this.onTap,
  });

  final String label;
  final String? detail;
  final double amount;
  final VoidCallback? onTap;
}

/// A day (or month) on the home screen. Collapsed it is a single glass row;
/// expanded it lifts into a brighter pane with its items and total.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.expandedSubtitle,
    required this.total,
    required this.lines,
    required this.badgeGlyph,
    required this.expanded,
    required this.onExpand,
    required this.onOpen,
    required this.semanticLabel,
  });

  final String title;
  final String subtitle;
  final String expandedSubtitle;
  final double total;
  final List<SummaryLine> lines;
  final LineGlyph badgeGlyph;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback? onOpen;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: expanded ? 1 : 0),
      duration: Motion.smooth.duration,
      curve: Motion.smooth,
      builder: (context, t, _) => _buildAt(t),
    );
  }

  Widget _buildAt(double t) {
    final ct = t.clamp(0.0, 1.0);
    final style = GlassStyle.lerp(Glass.card, Glass.cardRaised, t);

    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(
        height: lerpDouble(56, 58, t),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.headline, maxLines: 1),
                  Stack(
                    children: [
                      Opacity(
                        opacity: 1 - ct,
                        child: Text(
                          subtitle,
                          style: AppText.footnote,
                          maxLines: 1,
                        ),
                      ),
                      Opacity(
                        opacity: ct,
                        child: Text(
                          expandedSubtitle,
                          style: AppText.footnote,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Stack(
              alignment: Alignment.centerRight,
              children: [
                Opacity(
                  opacity: 1 - ct,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatTaka(total),
                        style: AppText.headline.copyWith(
                          fontFeatures: AppText.tabular,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const LineIcon(
                        LineGlyph.chevronRight,
                        size: 14,
                        strokeWidth: 2.6,
                        color: AppColors.chevron,
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: ct,
                  child: Transform.scale(
                    scale: 0.5 + 0.5 * t,
                    child: _Badge(glyph: badgeGlyph),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return LiquidPressable(
      onTap: expanded ? onOpen : onExpand,
      haptic: expanded ? HapticKind.light : HapticKind.selection,
      pressedScale: 0.98,
      borderRadius: style.radius,
      semanticLabel: semanticLabel,
      selected: expanded,
      child: LiquidBox(
        style: style,
        padding: EdgeInsets.only(bottom: 8 * ct),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (t > 0.001)
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: t.clamp(0.0, 1.2),
                  child: Opacity(
                    opacity: ct,
                    child: _Details(lines: lines, total: total),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.glyph});

  final LineGlyph glyph;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.accentRing, spreadRadius: 4)],
        ),
        child: Center(
          child: LineIcon(
            glyph,
            size: 14,
            strokeWidth: 2.4,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.lines, required this.total});

  final List<SummaryLine> lines;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: AppColors.separator),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
          child: Column(
            children: [for (final line in lines) _LineRow(line: line)],
          ),
        ),
        // The design pulls the total 10px wider than the card's padding.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.accentWash,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: AppText.subheadBold),
                Text(
                  formatTaka(total),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    fontFeatures: AppText.tabular,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final SummaryLine line;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 30,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    line.label,
                    style: AppText.subhead,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (line.detail != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    line.detail!,
                    style: AppText.subhead.copyWith(
                      color: AppColors.secondaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatTaka(line.amount),
            style: AppText.subhead.copyWith(
              color: AppColors.amountLabel,
              fontFeatures: AppText.tabular,
            ),
          ),
        ],
      ),
    );
    if (line.onTap == null) return row;
    return LiquidPressable(
      onTap: line.onTap,
      haptic: HapticKind.selection,
      pressedScale: 0.98,
      semanticLabel: '${line.label}, ${formatTaka(line.amount)}',
      child: row,
    );
  }
}
