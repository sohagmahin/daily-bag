import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/strings.dart';
import '../../app/tokens.dart';
import '../../models/expense.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_pressable.dart';

/// "Recent spending": the latest entries as glass bars, five to a screen.
/// It opens on the newest and scrolls back in time. The open day is the
/// solid bar and is kept in view; tapping a bar opens that day.
class SpendChart extends StatefulWidget {
  const SpendChart({super.key, required this.bars, required this.onSelect});

  final List<ChartBar> bars;
  final ValueChanged<DateTime> onSelect;

  @override
  State<SpendChart> createState() => _SpendChartState();
}

class _SpendChartState extends State<SpendChart> {
  /// Bars that fit in view at once.
  static const _columns = 5;
  static const _gap = 14.0;
  static const _inset = 18.0;
  static const _plotHeight = 132.0;
  static const _tallestBar = 120.0;

  /// Room either side of the row, so the outer bars sit [_inset] in.
  static const _edge = _inset - _gap / 2;

  final _scroll = ScrollController();

  /// One bar's width plus a gap, from the latest layout.
  double _slot = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: false),
    );
  }

  @override
  void didUpdateWidget(SpendChart old) {
    super.didUpdateWidget(old);
    if (_selectedKey(old.bars) != _selectedKey(widget.bars) ||
        old.bars.length != widget.bars.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static DateTime? _selectedKey(List<ChartBar> bars) {
    for (final bar in bars) {
      if (bar.selected) return bar.key;
    }
    return null;
  }

  /// Short histories still fill five slots from the left.
  int get _slots =>
      widget.bars.length < _columns ? _columns : widget.bars.length;

  /// Scrolls just enough to bring the open bar fully into view.
  void _reveal({bool animate = true}) {
    if (!mounted || !_scroll.hasClients || _slot == 0) return;
    final index = widget.bars.indexWhere((b) => b.selected);
    if (index < 0) return;

    // The view is reversed: offsets count back from the newest end.
    final position = _scroll.position;
    final start = _edge + (_slots - 1 - index) * _slot;
    final end = start + _slot;
    final double target;
    if (start < position.pixels) {
      target = start - _edge;
    } else if (end > position.pixels + position.viewportDimension) {
      target = end + _edge - position.viewportDimension;
    } else {
      return;
    }
    final to = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(
        to,
        duration: Motion.smooth.duration,
        curve: Motion.smooth,
      );
    } else {
      _scroll.jumpTo(to);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    final peak = bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);

    return LiquidBox(
      style: context.palette.glass.chart,
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        label: tr.spendingChart,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inner = constraints.maxWidth - 2 * _inset;
            _slot = (inner - (_columns - 1) * _gap) / _columns + _gap;
            final fade = _inset / constraints.maxWidth;
            return ShaderMask(
              // Bars dissolve into the glass at the edges, not cut off.
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                colors: const [
                  Color(0x00000000),
                  Color(0xFF000000),
                  Color(0xFF000000),
                  Color(0x00000000),
                ],
                stops: [0, fade, 1 - fade, 1],
              ).createShader(rect),
              child: _scrollView(bars, peak),
            );
          },
        ),
      ),
    );
  }

  Widget _scrollView(List<ChartBar> bars, double peak) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      // Offset zero is the newest end: the chart opens there and
      // stays put as new days arrive on the right.
      reverse: true,
      physics: const BouncingScrollPhysics(),
      // The top padding scrolls too, so the selected bar's amount
      // can rise above the plot without being clipped.
      padding: const EdgeInsets.fromLTRB(_edge, 16, _edge, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _slots; i++)
            SizedBox(
              key: i < bars.length ? ValueKey(bars[i].key) : null,
              width: _slot,
              child: i < bars.length
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
                      child: _Entry(
                        bar: bars[i],
                        height: peak == 0
                            ? 0
                            : bars[i].value / peak * _tallestBar,
                        onTap: () => widget.onSelect(bars[i].key),
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// One bar with its label underneath.
class _Entry extends StatelessWidget {
  const _Entry({required this.bar, required this.height, required this.onTap});

  final ChartBar bar;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _SpendChartState._plotHeight,
          child: _BarColumn(bar: bar, height: height, onTap: onTap),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: AnimatedDefaultTextStyle(
            duration: Motion.snappy.duration,
            curve: Curves.easeOut,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(
              color: bar.selected
                  ? context.palette.label
                  : context.palette.amountLabel,
              fontWeight: bar.selected ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: AppText.tabular,
            ),
            child: Text(bar.label),
          ),
        ),
      ],
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
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
                      context.palette.glass.chartBar,
                      context.palette.glass.chartBarSelected,
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
                        formatMoney(bar.value),
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
