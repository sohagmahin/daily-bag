import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/tokens.dart';
import '../../models/expense.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_pressable.dart';

/// "Chart view": the last five entries as glass bars. The open day is the
/// solid bar; tapping a bar opens that day.
class SpendChart extends StatelessWidget {
  const SpendChart({super.key, required this.bars, required this.onSelect});

  static const _columns = 5;
  static const _gap = 14.0;
  static const _plotHeight = 132.0;
  static const _tallestBar = 120.0;

  final List<ChartBar> bars;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final peak = bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);

    List<Widget> spaced(Widget Function(ChartBar bar) cell) => [
      for (var i = 0; i < _columns; i++) ...[
        if (i > 0) const SizedBox(width: _gap),
        Expanded(child: i < bars.length ? cell(bars[i]) : const SizedBox()),
      ],
    ];

    return LiquidBox(
      style: Glass.chart,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Semantics(
        container: true,
        label: 'Spending chart',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _plotHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaced(
                  (bar) => _BarColumn(
                    key: ValueKey(bar.key),
                    bar: bar,
                    height: peak == 0 ? 0 : bar.value / peak * _tallestBar,
                    onTap: () => onSelect(bar.key),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Row(
                children: spaced(
                  (bar) => AnimatedDefaultTextStyle(
                    duration: Motion.snappy.duration,
                    curve: Curves.easeOut,
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(
                      color: bar.selected
                          ? AppColors.label
                          : AppColors.amountLabel,
                      fontWeight: bar.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontFeatures: AppText.tabular,
                    ),
                    child: Text(bar.label),
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

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    super.key,
    required this.bar,
    required this.height,
    required this.onTap,
  });

  final ChartBar bar;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidPressable(
      onTap: onTap,
      haptic: HapticKind.selection,
      pressedScale: 0.94,
      selected: bar.selected,
      semanticLabel: bar.semanticLabel,
      child: TweenAnimationBuilder<double>(
        // Bars grow in from the baseline the first time they appear.
        tween: Tween(begin: 0, end: height),
        duration: Motion.bouncy.duration,
        curve: Motion.bouncy,
        builder: (context, h, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: bar.selected ? 1 : 0),
          duration: Motion.snappy.duration,
          curve: Motion.snappy,
          builder: (context, s, _) {
            final cs = s.clamp(0.0, 1.0);
            final barHeight = (h + lerpDouble(2, 0, cs)!).clamp(
              0.0,
              double.infinity,
            );
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: barHeight,
                  child: LiquidBox(
                    style: GlassStyle.lerp(
                      Glass.chartBar,
                      Glass.chartBarSelected,
                      s,
                    ),
                  ),
                ),
                Positioned(
                  left: -8,
                  right: -8,
                  bottom: barHeight + 4,
                  child: Opacity(
                    opacity: cs,
                    child: Transform.translate(
                      offset: Offset(0, (1 - s) * 6),
                      child: Text(
                        formatTaka(bar.value),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          fontFeatures: AppText.tabular,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
