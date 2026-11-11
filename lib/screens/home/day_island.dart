import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../app/format.dart';
import '../../app/motion.dart';
import '../../app/strings.dart';
import '../../app/tokens.dart';
import '../../widgets/liquid_glass.dart';
import 'spending_map.dart';

/// `Friday, 20 Feb`: the island's date line.
String islandDate(DateTime d) =>
    '${weekdayName(d)}, ${digits(d.day)} ${tr.monthsAbbr[d.month - 1]}';

/// The day under the finger on the spending map, read out in a black
/// capsule: the day's shade, what was spent, the date, and how heavy a
/// day it was.
///
/// It floats on its own, centred just under the status bar (and so clear
/// of a Dynamic Island or notch), at least 12px from the top as on the
/// design's canvas. Place it at the top of the screen.
class DayIsland extends StatefulWidget {
  const DayIsland({super.key, required this.day});

  final ValueListenable<MapDay?> day;

  @override
  State<DayIsland> createState() => _DayIslandState();
}

class _DayIslandState extends State<DayIsland> with TickerProviderStateMixin {
  // Each property eases on its own, as the design's CSS transitions do.
  late final _size = _Track(this, 550, Motion.islandGrow);
  late final _lift = _Track(this, 500, Motion.islandPop);
  late final _fade = _Track(this, 250, Curves.ease);
  late final _shadow = _Track(this, 400, Curves.ease);
  late final _contentFade = _Track(this, 220, Curves.ease);
  late final _contentScale = _Track(this, 450, Motion.islandPop);
  late final _tracks = [
    _size,
    _lift,
    _fade,
    _shadow,
    _contentFade,
    _contentScale,
  ];

  /// The day on show; kept while the island folds away.
  MapDay? _last;
  bool _on = false;

  // The design's capsule, closed and open.
  static const _closed = Size(96, 30);
  static const _open = Size(252, 56);
  static const _minTop = 12.0;

  @override
  void initState() {
    super.initState();
    widget.day.addListener(_onDay);
  }

  @override
  void didUpdateWidget(DayIsland old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day) {
      old.day.removeListener(_onDay);
      widget.day.addListener(_onDay);
    }
  }

  @override
  void dispose() {
    widget.day.removeListener(_onDay);
    for (final t in _tracks) {
      t.dispose();
    }
    super.dispose();
  }

  void _onDay() {
    final day = widget.day.value;
    final on = day != null;
    setState(() {
      if (day != null) _last = day;
    });
    if (on == _on) return;
    _on = on;
    final to = on ? 1.0 : 0.0;
    final instant = MediaQuery.disableAnimationsOf(context);
    // The contents follow the capsule in a beat later, and leave at once.
    final delay = on ? const Duration(milliseconds: 80) : Duration.zero;
    for (final t in [_size, _lift, _fade, _shadow]) {
      t.retarget(to, instant: instant);
    }
    for (final t in [_contentFade, _contentScale]) {
      t.retarget(to, delay: delay, instant: instant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = math.max(_minTop, MediaQuery.viewPaddingOf(context).top);
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              for (final t in _tracks) t.controller,
            ]),
            builder: (context, _) => _capsule(),
          ),
        ),
      ),
    );
  }

  Widget _capsule() {
    final size = _size.value;
    final lift = _lift.value;
    final fade = _fade.value.clamp(0.0, 1.0);
    final shadow = _shadow.value.clamp(0.0, 1.0);
    final radius = lerpDouble(15, 28, size)!.clamp(0.0, 40.0);
    final day = _last;

    final contentFade = _contentFade.value.clamp(0.0, 1.0);
    Widget? content;
    if (day != null && contentFade > 0) {
      content = Opacity(
        opacity: contentFade,
        child: Transform.scale(
          scale: 0.92 + 0.08 * _contentScale.value,
          child: _Readout(day: day),
        ),
      );
    }

    final label = day == null
        ? null
        : '${formatMoney(day.amount)}, ${islandDate(day.date)}, '
              '${tr.levelNames[day.level]}';

    return Semantics(
      liveRegion: true,
      label: _on ? label : null,
      child: Opacity(
        opacity: fade,
        child: Transform.translate(
          offset: Offset(0, -10 * (1 - lift)),
          child: Transform.scale(
            scale: 0.9 + 0.1 * lift,
            child: LiquidBox(
              style: GlassStyle(
                radius: radius,
                color: const Color(0xFF000000),
                borderWidth: 0,
                shadows: [
                  CssShadow(
                    dy: 14,
                    blur: 34,
                    color: Color.fromRGBO(0, 0, 0, 0.35 * shadow),
                  ),
                  CssShadow(
                    spread: 1,
                    color: Color.fromRGBO(255, 255, 255, 0.06 * shadow),
                  ),
                ],
              ),
              width: lerpDouble(
                _closed.width,
                _open.width,
                size,
              )!.clamp(0.0, 400.0),
              height: lerpDouble(
                _closed.height,
                _open.height,
                size,
              )!.clamp(0.0, 100.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                // The readout is laid out at full size and revealed as the
                // capsule opens around it.
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: _open.width,
                  maxWidth: _open.width,
                  minHeight: _open.height,
                  maxHeight: _open.height,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The island's contents: the day's shade, amount and date, and its level.
class _Readout extends StatelessWidget {
  const _Readout({required this.day});

  final MapDay day;

  @override
  Widget build(BuildContext context) {
    final level = day.level;
    final busy = level >= 3;
    return SizedBox(
      width: 252,
      height: 56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 0, 16, 0),
        child: ExcludeSemantics(
          child: Row(
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: IslandColors.levels[level]),
                duration: const Duration(milliseconds: 200),
                curve: Curves.ease,
                builder: (context, color, _) => TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: busy ? IslandColors.glowBusy : IslandColors.glowQuiet,
                  ),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.ease,
                  builder: (context, glow, _) => LiquidBox(
                    width: 34,
                    height: 34,
                    style: GlassStyle(
                      radius: 11,
                      color: color!,
                      borderWidth: 0,
                      shadows: [
                        CssShadow(blur: 14, color: glow!),
                        const CssShadow.inset(
                          dy: 1,
                          color: Color.fromRGBO(255, 255, 255, 0.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMoney(day.amount),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 21 / 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: AppColors.white,
                        fontFeatures: AppText.tabular,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      islandDate(day.date),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 15 / 12,
                        color: IslandColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: level == 0
                      ? IslandColors.emptyTag
                      : IslandColors.levels[level],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tr.levelNames[level],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: level == 0
                        ? IslandColors.secondary
                        : busy
                        ? AppColors.white
                        : IslandColors.lightTagLabel,
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

/// One CSS transition: when its target changes, it eases from wherever it
/// is now, after an optional delay during which it holds still.
class _Track {
  _Track(TickerProvider vsync, int milliseconds, this.curve)
    : controller = AnimationController(
        vsync: vsync,
        duration: Duration(milliseconds: milliseconds),
      );

  final AnimationController controller;
  final Curve curve;
  double _from = 0;
  double _to = 0;
  Timer? _wait;

  double get value => _from + (_to - _from) * curve.transform(controller.value);

  void retarget(
    double to, {
    Duration delay = Duration.zero,
    bool instant = false,
  }) {
    _wait?.cancel();
    final now = value;
    controller.stop();
    _from = now;
    _to = now;
    controller.value = 0;
    void go() {
      _to = to;
      if (instant) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
    }

    if (instant || delay == Duration.zero) {
      go();
    } else {
      _wait = Timer(delay, go);
    }
  }

  void dispose() {
    _wait?.cancel();
    controller.dispose();
  }
}
