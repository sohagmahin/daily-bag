import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/strings.dart';
import '../../app/tokens.dart';
import '../../state/expense_store.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_pressable.dart';

// The grid, in the design's CSS pixels: 14px days, 4px apart, with room
// for the month names above and the weekday names to the left.
const _cell = 14.0;
const _pitch = 18.0;
const _gridWidth = 284.0;
const _gridHeight = 122.0;
const _gridLeft = 26.0;
// The labels and grid start 10px down (the design's `margin-top: 10px`).
const _monthsTop = 10.0;
const _gridTop = 30.0;
const _heatWidth = 310.0;
const _heatHeight = 176.0;
const _legendTop = 162.0;
const _stripHeight = 24.0;

/// `Fri, 20 Feb`, `শুক্র, ২০ ফেব্রু`: a day on the spending map.
String mapDayLabel(DateTime d) =>
    '${tr.weekdaysAbbr[d.weekday % 7]}, ${digits(d.day)} '
    '${tr.monthsAbbr[d.month - 1]}';

/// One square on the spending map.
@immutable
class MapDay {
  const MapDay({
    required this.date,
    required this.amount,
    required this.level,
    required this.isFuture,
    required this.isToday,
  });

  final DateTime date;
  final double amount;

  /// 0 when nothing was spent, then 1–4 by quarters of the busiest day.
  final int level;
  final bool isFuture;
  final bool isToday;

  String get label => mapDayLabel(date);

  /// `৳1,220`, or "No spending".
  String get amountLabel => amount > 0 ? formatMoney(amount) : tr.noSpending;
}

/// The last 16 weeks, GitHub style: a column per week with Sunday on top,
/// the current week last. Days after today stay blank.
@immutable
class SpendingWindow {
  const SpendingWindow._(this.days, this.todayIndex, this.total, this._months);

  factory SpendingWindow.of(ExpenseStore store, DateTime now) {
    final today = dateOnly(now);
    final todayIndex = 7 * (weeks - 1) + today.weekday % 7;
    final dates = [
      for (var i = 0; i < length; i++)
        DateTime(today.year, today.month, today.day - todayIndex + i),
    ];
    final amounts = [
      for (var i = 0; i < length; i++)
        i > todayIndex ? 0.0 : store.dayFor(dates[i])?.total ?? 0.0,
    ];
    final peak = amounts.fold<double>(0, math.max);
    final days = [
      for (var i = 0; i < length; i++)
        MapDay(
          date: dates[i],
          amount: amounts[i],
          level: amounts[i] <= 0
              ? 0
              : math.min(4, math.max(1, (4 * amounts[i] / peak).ceil())),
          isFuture: i > todayIndex,
          isToday: i == todayIndex,
        ),
    ];
    // A month is named over the week it starts in. The first column is
    // named too, unless the next month's name would crowd it.
    bool starts(int c) => c > 0 && dates[c * 7].day <= 7;
    final months = [
      for (var c = 0; c < weeks; c++)
        starts(c) || (c == 0 && !starts(1) && !starts(2))
            ? dates[c * 7].month
            : null,
    ];
    return SpendingWindow._(
      days,
      todayIndex,
      amounts.fold<double>(0, (a, b) => a + b),
      months,
    );
  }

  static const weeks = 16;
  static const length = weeks * 7;

  final List<MapDay> days;
  final int todayIndex;

  /// Everything spent in the window: the pill's "Total".
  final double total;
  final List<int?> _months;

  /// The short month name over column [column], if any.
  String? monthLabel(int column) {
    final m = _months[column];
    return m == null ? null : tr.monthsAbbr[m - 1];
  }

  /// Where [date] sits on the grid; null outside the window or after today.
  int? indexOf(DateTime date) {
    final first = days.first.date;
    final i = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
    return i < 0 || i > todayIndex ? null : i;
  }
}

/// "Spending map": the last 16 weeks of spending, one square per day.
///
/// Touching the grid (or hovering it with a pointer) runs an Apple
/// Watch–style fisheye over it: days near the finger swell and brighten,
/// their neighbours shrink and lean away, and [hovered] carries the day
/// under the finger to the island at the top of the screen. A tap picks
/// the day.
///
/// The map folds into a three-week strip as the list scrolls under it.
class SpendingMap extends StatefulWidget {
  const SpendingMap({
    super.key,
    required this.fold,
    required this.pillHidden,
    required this.selected,
    required this.onSelect,
    required this.onToggleFold,
    required this.hovered,
  });

  /// How far the map has folded into its strip, 0 (open) to 1.
  final ValueListenable<double> fold;

  /// The "Total" pill steps aside while the list scrolls down.
  final ValueListenable<bool> pillHidden;

  /// The day picked on the map, which the list below is showing.
  final DateTime? selected;

  /// Picks a day, or null to show every day again.
  final ValueChanged<DateTime?> onSelect;
  final VoidCallback onToggleFold;

  /// The day under the finger, or null; the map writes it.
  final ValueNotifier<MapDay?> hovered;

  /// Scroll distance over which the map folds.
  static const foldRange = 150.0;

  /// Today, as the map sees it. Tests pin it to the design's date.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @override
  State<SpendingMap> createState() => _SpendingMapState();
}

class _SpendingMapState extends State<SpendingMap>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _lens = _Lens();
  late SpendingWindow _window;
  Duration? _lastTick;
  bool _reduced = false;

  /// The day under the finger (or pointer).
  int? _hover;

  int? _pointer;
  Offset? _downAt;
  int? _downIndex;
  bool _scrubbed = false;

  @override
  void initState() {
    super.initState();
    widget.fold.addListener(_onFold);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _window = SpendingWindow.of(
      Provider.of<ExpenseStore>(context),
      SpendingMap.clock(),
    );
    _kick();
  }

  @override
  void didUpdateWidget(SpendingMap old) {
    super.didUpdateWidget(old);
    if (old.fold != widget.fold) {
      old.fold.removeListener(_onFold);
      widget.fold.addListener(_onFold);
    }
    if (old.selected != widget.selected) _kick();
  }

  @override
  void dispose() {
    widget.fold.removeListener(_onFold);
    _ticker.dispose();
    _lens.dispose();
    super.dispose();
  }

  int? get _selectedIndex {
    final s = widget.selected;
    return s == null ? null : _window.indexOf(s);
  }

  /// Scrolling the list puts the lens away.
  void _onFold() {
    if (_lens.active || _hover != null) _endLens(keepHover: false);
  }

  void _kick() {
    if (_ticker.isActive) return;
    _lastTick = null;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    final dt = last == null
        ? 1 / 60
        : ((elapsed - last).inMicroseconds / 1e6).clamp(0.001, 0.032);
    final moving = _lens.step(
      dt,
      window: _window,
      selected: _selectedIndex,
      reduced: _reduced,
    );
    if (!moving) _ticker.stop();
  }

  /// The day whose square is under [p], within 11px of its centre.
  int? _indexAt(Offset p) {
    final col = ((p.dx - _cell / 2) / _pitch).round();
    final row = ((p.dy - _cell / 2) / _pitch).round();
    if (col < 0 || col >= SpendingWindow.weeks || row < 0 || row > 6) {
      return null;
    }
    if ((p.dx - (col * _pitch + _cell / 2)).abs() >= 11 ||
        (p.dy - (row * _pitch + _cell / 2)).abs() >= 11) {
      return null;
    }
    final i = col * 7 + row;
    return i <= _window.todayIndex ? i : null;
  }

  void _moveLens(Offset local) {
    _lens
      ..active = !_reduced
      ..pointer = local;
    final i = _indexAt(local);
    if (i != _hover) {
      // A detent under the finger for every day it crosses.
      if (i != null) Haptics.play(HapticKind.selection);
      _setHover(i);
    }
    _kick();
  }

  void _endLens({required bool keepHover}) {
    _lens.active = false;
    if (!keepHover) _setHover(null);
    _kick();
  }

  void _setHover(int? i) {
    _lens.hover = i;
    if (_hover == i) return;
    _hover = i;
    widget.hovered.value = i == null ? null : _window.days[i];
  }

  void _pick(int i) {
    Haptics.play(HapticKind.selection);
    final date = _window.days[i].date;
    final current = widget.selected;
    widget.onSelect(current != null && isSameDay(current, date) ? null : date);
  }

  void _onDown(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _downAt = e.localPosition;
    _downIndex = _indexAt(e.localPosition);
    _scrubbed = false;
    if (e.kind != PointerDeviceKind.mouse) _moveLens(e.localPosition);
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final down = _downAt;
    // Sliding onto another day, or far enough, makes it a scrub.
    if (down != null &&
        ((e.localPosition - down).distance > kTouchSlop ||
            _indexAt(e.localPosition) != _downIndex)) {
      _scrubbed = true;
    }
    _moveLens(e.localPosition);
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final i = _indexAt(e.localPosition);
    final mouse = e.kind == PointerDeviceKind.mouse;
    // A click picks where it was pressed; a touch picks only on a tap,
    // so lifting after a scrub just puts the lens away.
    final tapped = mouse ? i == _downIndex : !_scrubbed;
    if (!mouse) _endLens(keepHover: false);
    if (tapped && i != null) _pick(i);
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _endLens(keepHover: false);
  }

  @override
  Widget build(BuildContext context) {
    final window = _window;
    final heat = _heat(context, window);
    final header = Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _FoldTitle(fold: widget.fold, onTap: widget.onToggleFold),
          ),
        ),
        const SizedBox(width: 10),
        _TotalPill(total: window.total, hidden: widget.pillHidden),
      ],
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: AnimatedBuilder(
        animation: widget.fold,
        builder: (context, _) {
          final p = widget.fold.value.clamp(0.0, 1.0);
          final q = ((p - 0.55) / 0.45).clamp(0.0, 1.0);
          final pad = 12 - 2 * p;
          final glass = context.palette.glass;
          return Stack(
            children: [
              Positioned.fill(
                child: LiquidBox(
                  style: GlassStyle.lerp(glass.map, glass.mapFolded, p),
                ),
              ),
              Padding(
                // 16px padding plus the 1px rim.
                padding: EdgeInsets.fromLTRB(17, 1 + pad, 17, 1 + pad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 32, child: FadeWithGlass(child: header)),
                    _folding(context, p, heat),
                    FadeWithGlass(
                      child: _Strip(
                        window: window,
                        p: p,
                        q: q,
                        onTap: widget.onToggleFold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The grid and its labels shrink, lift and fade away as the map folds.
  Widget _folding(BuildContext context, double p, Widget heat) {
    final opacity = math.max(0.0, 1 - p * 1.6);
    final scale = 1 - 0.06 * p;
    Widget content = Transform(
      transform: Matrix4.identity()
        ..translateByDouble(_heatWidth / 2, 0, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-_heatWidth / 2, -12 * p, 0, 1),
      child: GlassFade(opacity: GlassFade.of(context) * opacity, child: heat),
    );
    content = OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: _heatHeight,
      maxHeight: _heatHeight,
      child: content,
    );
    // Fully open, the lens may spill past the grid; once folding, clip.
    if (p >= 0.01) content = ClipRect(child: content);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: _heatWidth,
        height: _heatHeight * (1 - p),
        child: content,
      ),
    );
  }

  Widget _heat(BuildContext context, SpendingWindow window) {
    final palette = context.palette;
    final label = TextStyle(
      fontSize: 11,
      height: 14 / 11,
      color: palette.secondaryLabel,
    );
    final grid = MouseRegion(
      onExit: (_) => _endLens(keepHover: false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        onPointerHover: (e) => _moveLens(e.localPosition),
        child: Semantics(
          container: true,
          label: tr.dailySpending,
          child: CustomPaint(
            size: const Size(_gridWidth, _gridHeight),
            painter: _GridPainter(
              lens: _lens,
              window: window,
              selected: _selectedIndex,
              palette: palette,
              format: '$bangla$currencySymbol',
              onPick: _pick,
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: _heatWidth,
      height: _heatHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: FadeWithGlass(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var c = 0; c < SpendingWindow.weeks; c++)
                    if (window.monthLabel(c) case final month?)
                      Positioned(
                        left: _gridLeft + c * _pitch,
                        top: _monthsTop,
                        child: ExcludeSemantics(
                          child: Text(month, style: label, softWrap: false),
                        ),
                      ),
                  for (final row in const [1, 3, 5])
                    Positioned(
                      left: 0,
                      top: _gridTop + row * _pitch,
                      child: ExcludeSemantics(
                        child: Text(
                          tr.weekdaysAbbr[row],
                          softWrap: false,
                          style: label.copyWith(fontSize: 10, height: 1.4),
                        ),
                      ),
                    ),
                  Positioned(
                    left: _gridLeft,
                    top: _gridTop,
                    width: _gridWidth,
                    height: _gridHeight,
                    child: grid,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _legendTop,
                    child: ExcludeSemantics(
                      child: _Legend(
                        total: window.total,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.secondaryLabel,
                        ),
                      ),
                    ),
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

/// One day's motion: the lens's scale and push (springs), the pick's
/// extra size (a spring too), and eased opacity and rings.
class _Cell {
  double s = 1, vs = 0;
  double x = 0, vx = 0;
  double y = 0, vy = 0;
  double b = 1, vb = 0;

  /// 0..1: how close the finger is, over a wide radius.
  double near = 0;
  double o = 1;

  /// Ring weights: hovered (halo + glow), picked (halo + accent), today.
  double hv = 0, sv = 0, tv = 0;
}

/// The fisheye. Each day is pulled toward a size and offset set by its
/// distance from the finger, through a damped spring, so the grid swells
/// and settles like liquid rather than snapping.
class _Lens extends ChangeNotifier {
  // Lens radius, and the spring's stiffness and damping (unit mass).
  static const _radius = 66.0;
  static const _k = 360.0;
  static const _c = 25.0;

  final cells = List.generate(SpendingWindow.length, (_) => _Cell());
  bool active = false;
  Offset pointer = Offset.zero;
  int? hover;

  bool _primed = false;

  /// Advances everything by [dt] seconds; false once all is at rest.
  bool step(
    double dt, {
    required SpendingWindow window,
    required int? selected,
    required bool reduced,
  }) {
    final snap = !_primed;
    _primed = true;
    var moving = false;

    // CSS `transition: … 0.25s ease` (0.2s when motion is reduced),
    // followed continuously: an exponential ease toward the target.
    final fade = snap ? 1.0 : 1 - math.exp(-dt / 0.08);
    final glide = snap ? 1.0 : 1 - math.exp(-dt / 0.065);
    double ease(double v, double target, double f) {
      final next = v + (target - v) * f;
      if ((target - next).abs() < 0.002) return target;
      moving = true;
      return next;
    }

    final anyPicked = selected != null;
    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      final cx = (i ~/ 7) * _pitch + _cell / 2;
      final cy = (i % 7) * _pitch + _cell / 2;
      var ts = 1.0, tx = 0.0, ty = 0.0, near = 0.0;
      if (active) {
        final dx = cx - pointer.dx, dy = cy - pointer.dy;
        final d = math.sqrt(dx * dx + dy * dy);
        final u = math.max(0.0, 1 - d / _radius);
        final f = u * u * (3 - 2 * u);
        final u2 = math.max(0.0, 1 - d / (_radius * 2.4));
        // Up to 2.55× right under the finger.
        ts = 0.78 + 0.22 * u2 + 1.55 * f;
        if (d > 0.5 && d < _radius * 1.2) {
          final push = 10 * math.sin(math.pi * d / (_radius * 1.2));
          tx = dx / d * push;
          ty = dy / d * push;
        }
        near = u2;
      }
      final isHover = hover == i, isPicked = selected == i;
      final tb = isPicked ? 1.18 : 1.0;
      cell.near = near;

      if (reduced) {
        cell
          ..s = 1
          ..x = 0
          ..y = 0
          ..vs = 0
          ..vx = 0
          ..vy = 0
          ..vb = 0
          ..b = ease(cell.b, tb, glide);
      } else if (snap) {
        cell
          ..s = ts
          ..x = tx
          ..y = ty
          ..b = tb;
      } else {
        cell
          ..vs += (_k * (ts - cell.s) - _c * cell.vs) * dt
          ..s += cell.vs * dt
          ..vx += (_k * (tx - cell.x) - _c * cell.vx) * dt
          ..x += cell.vx * dt
          ..vy += (_k * (ty - cell.y) - _c * cell.vy) * dt
          ..y += cell.vy * dt
          ..vb += (_k * (tb - cell.b) - _c * cell.vb) * dt
          ..b += cell.vb * dt;
        if (cell.vs.abs() + cell.vx.abs() + cell.vy.abs() + cell.vb.abs() >
                0.02 ||
            (ts - cell.s).abs() > 0.002 ||
            (tb - cell.b).abs() > 0.002 ||
            (tx - cell.x).abs() + (ty - cell.y).abs() > 0.02) {
          moving = true;
        } else {
          cell
            ..s = ts
            ..x = tx
            ..y = ty
            ..b = tb
            ..vs = 0
            ..vx = 0
            ..vy = 0
            ..vb = 0;
        }
      }

      // Under the lens, days fade with distance; once a day is picked
      // the rest step back so it stands out.
      final lensOn = active || (cell.s - 1).abs() > 0.01;
      final double to;
      if (active) {
        to = isHover || isPicked ? 1 : 0.42 + 0.58 * math.min(1, near * 1.4);
      } else if (lensOn && !anyPicked) {
        to = 1;
      } else if (hover != null) {
        to = isHover || isPicked ? 1 : 0.55;
      } else if (anyPicked) {
        to = isPicked ? 1 : 0.5;
      } else {
        to = 1;
      }
      cell
        ..o = ease(cell.o, to, fade)
        ..hv = ease(cell.hv, isHover ? 1 : 0, fade)
        ..sv = ease(cell.sv, !isHover && isPicked ? 1 : 0, fade)
        ..tv = ease(
          cell.tv,
          !isHover && !isPicked && window.days[i].isToday ? 1 : 0,
          fade,
        );
    }

    notifyListeners();
    return moving;
  }
}

Color _alpha(Color c, double factor) =>
    c.withValues(alpha: (c.a * factor).clamp(0.0, 1.0));

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.lens,
    required this.window,
    required this.selected,
    required this.palette,
    required this.format,
    required this.onPick,
  }) : super(repaint: lens);

  static final _base = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-_cell / 2, -_cell / 2, _cell, _cell),
    const Radius.circular(5),
  );
  static final _outside = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(_base.outerRect.inflate(40))
    ..addRRect(_base);

  final _Lens lens;
  final SpendingWindow window;
  final int? selected;
  final Palette palette;

  /// Language and currency: labels change with them.
  final String format;
  final ValueChanged<int> onPick;

  @override
  void paint(Canvas canvas, Size size) {
    final cells = lens.cells;
    final hover = lens.hover;
    // The hovered day on top, then the bigger days over the smaller.
    int z(int i) => i == hover ? 4 : math.max(1, (cells[i].s * 2).round());
    final order = [for (var i = 0; i <= window.todayIndex; i++) i]
      ..sort((a, b) {
        final d = z(a) - z(b);
        return d != 0 ? d : a - b;
      });
    for (final i in order) {
      _paintDay(canvas, i, cells[i]);
    }
  }

  void _paintDay(Canvas canvas, int i, _Cell cell) {
    final o = cell.o;
    canvas
      ..save()
      ..translate(
        (i ~/ 7) * _pitch + _cell / 2 + cell.x,
        (i % 7) * _pitch + _cell / 2 + cell.y,
      )
      ..scale(cell.s * cell.b);

    // CSS box-shadows: drawn outside the square only.
    if (cell.hv > 0.001) {
      canvas
        ..save()
        ..clipPath(_outside)
        ..drawRRect(
          _base.shift(const Offset(0, 6)),
          Paint()
            ..color = _alpha(palette.heatGlow, cell.hv * o)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        )
        ..restore();
    }
    if (cell.sv > 0.001) {
      canvas.drawDRRect(
        _base.inflate(3.5),
        _base,
        Paint()..color = _alpha(palette.heatSelect, cell.sv * o),
      );
    }
    if (cell.tv > 0.001) {
      canvas.drawDRRect(
        _base.inflate(1.5),
        _base,
        Paint()..color = _alpha(palette.heatToday, cell.tv * o),
      );
    }
    final halo = math.min(1.0, cell.hv + cell.sv);
    if (halo > 0.001) {
      canvas.drawDRRect(
        _base.inflate(2),
        _base,
        Paint()..color = _alpha(palette.heatHalo, halo * o),
      );
    }
    canvas
      ..drawRRect(
        _base,
        Paint()..color = _alpha(palette.heatLevels[window.days[i].level], o),
      )
      ..restore();
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (var i = 0; i <= window.todayIndex; i++)
          CustomPainterSemantics(
            key: ValueKey(i),
            rect: Rect.fromLTWH(
              (i ~/ 7) * _pitch,
              (i % 7) * _pitch,
              _cell,
              _cell,
            ),
            properties: SemanticsProperties(
              label: '${window.days[i].label}, ${window.days[i].amountLabel}',
              button: true,
              selected: i == selected,
              textDirection: TextDirection.ltr,
              onTap: () => onPick(i),
            ),
          ),
      ];

  @override
  bool shouldRebuildSemantics(_GridPainter old) =>
      old.window != window || old.selected != selected || old.format != format;

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.window != window ||
      old.selected != selected ||
      old.palette != palette;
}

/// "Spending map" and its chevron, which turns as the map folds; a tap
/// folds or unfolds it.
class _FoldTitle extends StatelessWidget {
  const _FoldTitle({required this.fold, required this.onTap});

  final ValueListenable<double> fold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: fold,
    builder: (context, value, _) => _build(context, value.clamp(0.0, 1.0)),
  );

  Widget _build(BuildContext context, double p) {
    return Semantics(
      expanded: p < 0.5,
      header: true,
      child: LiquidPressable(
        onTap: onTap,
        haptic: HapticKind.selection,
        pressedScale: 0.96,
        borderRadius: 16,
        semanticLabel: tr.spendingMap,
        child: ExcludeSemantics(
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 6, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      tr.spendingMap,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Follows the fold with a little spring, as the design's
                  // 0.35s overshooting transition does.
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      end: -(p * 90).roundToDouble() * math.pi / 180,
                    ),
                    duration: const Duration(milliseconds: 350),
                    curve: Motion.pop,
                    builder: (context, angle, child) =>
                        Transform.rotate(angle: angle, child: child),
                    child: LineIcon(
                      LineGlyph.chevronDown,
                      size: 14,
                      strokeWidth: 2.8,
                      color: _alpha(context.palette.label, 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's pill: "Total", with the amount hidden until tapped.
class _TotalPill extends StatefulWidget {
  const _TotalPill({required this.total, required this.hidden});

  final double total;
  final ValueListenable<bool> hidden;

  @override
  State<_TotalPill> createState() => _TotalPillState();
}

class _TotalPillState extends State<_TotalPill> {
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
    final palette = context.palette;
    final total = formatMoney(widget.total);
    final pill = LiquidPressable(
      onTap: () => setState(() => _shown = !_shown),
      haptic: HapticKind.selection,
      pressedScale: 0.94,
      borderRadius: 16,
      semanticLabel: _shown ? tr.hideTotal(total) : tr.showTotal,
      child: Container(
        height: 32,
        padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
        decoration: BoxDecoration(
          color: palette.quietFill,
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
                  style: TextStyle(fontSize: 13, color: palette.secondaryLabel),
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
                          total,
                          key: const ValueKey('amount'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.label,
                            fontFeatures: AppText.tabular,
                          ),
                        )
                      : Text(
                          '•••••',
                          key: const ValueKey('hidden'),
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 1,
                            color: _alpha(palette.secondaryLabel, 0.8),
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
                    color: palette.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Steps aside (and out of reach) while the list scrolls down.
    return ValueListenableBuilder<bool>(
      valueListenable: widget.hidden,
      child: pill,
      builder: (context, hidden, child) => IgnorePointer(
        ignoring: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: hidden ? 0 : 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.ease,
            child: child,
            builder: (context, opacity, child) => Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: hidden ? 1 : 0),
                duration: const Duration(milliseconds: 400),
                curve: Motion.pop,
                child: child,
                builder: (context, away, child) => Transform.translate(
                  offset: Offset(14 * away, 0),
                  child: Transform.scale(scale: 1 - 0.15 * away, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Last 16 weeks · ৳5,470" and the Less–More key.
class _Legend extends StatelessWidget {
  const _Legend({required this.total, required this.style});

  final double total;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            tr.lastWeeks(formatMoney(total)),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr.less, style: style),
            for (final level in context.palette.heatLevels) ...[
              const SizedBox(width: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: level,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                child: const SizedBox.square(dimension: 11),
              ),
            ],
            const SizedBox(width: 4),
            Text(tr.more, style: style),
          ],
        ),
      ],
    );
  }
}

/// The folded map: the last three weeks in a row, today ringed. A tap
/// opens the full map again.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.window,
    required this.p,
    required this.q,
    required this.onTap,
  });

  final SpendingWindow window;
  final double p;
  final double q;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = window.days.sublist(
      window.todayIndex - 20,
      window.todayIndex + 1,
    );
    final row = Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            // The design's flex row squeezes the squares (not the label)
            // when they don't all fit.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(
                  10.0,
                  (constraints.maxWidth - 3 * (days.length - 1)) / days.length,
                );
                return Row(
                  children: [
                    for (var i = 0; i < days.length; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      CustomPaint(
                        size: Size(width, 10),
                        painter: _DotPainter(
                          color: palette.heatLevels[days[i].level],
                          ring: days[i].isToday ? palette.heatToday : null,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            tr.lastThreeWeeks,
            softWrap: false,
            style: TextStyle(fontSize: 12, color: palette.secondaryLabel),
          ),
        ),
      ],
    );

    return IgnorePointer(
      ignoring: q <= 0,
      child: ExcludeSemantics(
        excluding: p <= 0.5,
        child: LiquidPressable(
          onTap: onTap,
          haptic: HapticKind.selection,
          pressedScale: 0.98,
          semanticLabel: tr.showFullMap,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _stripHeight * q),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                fit: OverflowBoxFit.deferToChild,
                child: Opacity(
                  opacity: q,
                  child: ExcludeSemantics(child: row),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({required this.color, required this.ring});

  final Color color;
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    if (ring != null) {
      canvas.drawDRRect(box.inflate(1.5), box, Paint()..color = ring!);
    }
    canvas.drawRRect(box, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.color != color || old.ring != ring;
}
