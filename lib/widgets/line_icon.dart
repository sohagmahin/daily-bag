import 'package:flutter/widgets.dart';

import '../app/tokens.dart';

/// The stroke icons from the design, drawn on the same 24-unit grid as
/// their SVG source so weights match exactly.
enum LineGlyph {
  menu,
  chevronLeft,
  chevronRight,
  plus,
  note,
  check,
  calendarDay,
  calendarMonth,
  eye,
  eyeOff,
  pencil,
  share,
  trash,
  back,
  tick,
  clipboard,
  bag,
  moon,
  globe,
  cash,
  haptic,
  sheet,
  download,
  gear,
}

class LineIcon extends StatelessWidget {
  const LineIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.strokeWidth = 2,
    this.color,
  });

  final LineGlyph glyph;
  final double size;
  final double strokeWidth;

  /// Defaults to the palette's label colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LineIconPainter(
          glyph,
          strokeWidth,
          color ?? context.palette.label,
        ),
      ),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  _LineIconPainter(this.glyph, this.strokeWidth, this.color);

  final LineGlyph glyph;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_path(glyph), paint);
  }

  static Path _path(LineGlyph glyph) {
    final p = Path();
    void line(double x1, double y1, double x2, double y2) => p
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
    void calendar() {
      p.addRRect(RRect.fromLTRBR(4, 5, 20, 20, const Radius.circular(3)));
      line(4, 10, 20, 10);
      line(9, 3, 9, 7);
      line(15, 3, 15, 7);
    }

    switch (glyph) {
      case LineGlyph.menu:
        line(4, 7, 20, 7);
        line(7, 12, 17, 12);
        line(10, 17, 14, 17);
      case LineGlyph.chevronLeft:
        p
          ..moveTo(15, 6)
          ..lineTo(9, 12)
          ..lineTo(15, 18);
      case LineGlyph.chevronRight:
        p
          ..moveTo(9, 6)
          ..lineTo(15, 12)
          ..lineTo(9, 18);
      case LineGlyph.plus:
        line(12, 5, 12, 19);
        line(5, 12, 19, 12);
      case LineGlyph.note:
        p
          ..moveTo(5, 4)
          ..lineTo(15, 4)
          ..lineTo(19, 8)
          ..lineTo(19, 20)
          ..lineTo(5, 20)
          ..close();
        line(9, 12, 15, 12);
        line(9, 16, 13, 16);
      case LineGlyph.check:
        p
          ..moveTo(5, 12)
          ..lineTo(10, 17)
          ..lineTo(19, 7);
      case LineGlyph.calendarDay:
        calendar();
        line(8.5, 14.5, 8.51, 14.5);
      case LineGlyph.calendarMonth:
        calendar();
        line(8, 14, 16, 14);
        line(8, 17, 13, 17);
      // SVG shorthand (s/S, relative a/c) is expanded to absolute points.
      case LineGlyph.eye:
        p
          ..moveTo(2, 12)
          ..cubicTo(2, 12, 5.5, 6, 12, 6)
          ..cubicTo(18.5, 6, 22, 12, 22, 12)
          ..cubicTo(22, 12, 18.5, 18, 12, 18)
          ..cubicTo(5.5, 18, 2, 12, 2, 12)
          ..close()
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2.6));
      case LineGlyph.eyeOff:
        line(3, 3, 21, 21);
        p
          ..moveTo(10.6, 6.1)
          ..arcToPoint(const Offset(12, 6), radius: const Radius.circular(10))
          ..cubicTo(18.5, 6, 22, 12, 22, 12)
          ..arcToPoint(
            const Offset(19, 15.6),
            radius: const Radius.circular(17),
          )
          ..moveTo(6.6, 6.6)
          ..cubicTo(3.8, 8.4, 2, 12, 2, 12)
          ..cubicTo(2, 12, 5.5, 18, 12, 18)
          ..cubicTo(13.6, 18, 15, 17.6, 16.3, 17);
      case LineGlyph.pencil:
        p
          ..moveTo(4, 20)
          ..lineTo(8, 20)
          ..lineTo(19, 9)
          ..lineTo(15, 5)
          ..lineTo(4, 16)
          ..close();
        line(13.5, 6.5, 17.5, 10.5);
      case LineGlyph.share:
        line(12, 3, 12, 15);
        p
          ..moveTo(8, 7)
          ..lineTo(12, 3)
          ..lineTo(16, 7)
          ..moveTo(6, 11)
          ..lineTo(5, 11)
          ..lineTo(5, 20)
          ..lineTo(19, 20)
          ..lineTo(19, 11)
          ..lineTo(18, 11);
      case LineGlyph.trash:
        line(4, 7, 20, 7);
        p
          ..moveTo(9, 7)
          ..lineTo(9, 4)
          ..lineTo(15, 4)
          ..lineTo(15, 7)
          ..moveTo(6, 7)
          ..lineTo(7, 20)
          ..lineTo(17, 20)
          ..lineTo(18, 7);
      case LineGlyph.back:
        p
          ..moveTo(15, 5)
          ..lineTo(8, 12)
          ..lineTo(15, 19);
      case LineGlyph.tick:
        p
          ..moveTo(5, 12.5)
          ..lineTo(9.5, 17)
          ..lineTo(19, 7.5);
      case LineGlyph.clipboard:
        p
          ..addRRect(RRect.fromLTRBR(5, 4, 19, 21, const Radius.circular(3)))
          ..addRect(const Rect.fromLTRB(9, 3, 15, 6))
          ..moveTo(8.5, 11)
          ..lineTo(9.8, 12.3)
          ..lineTo(12, 10)
          ..moveTo(8.5, 16)
          ..lineTo(9.8, 17.3)
          ..lineTo(12, 15);
        line(14, 11.5, 16, 11.5);
        line(14, 16.5, 16, 16.5);
      case LineGlyph.bag:
        p
          ..moveTo(5, 8)
          ..lineTo(19, 8)
          ..lineTo(17.8, 19)
          ..arcToPoint(
            const Offset(15.8, 20.8),
            radius: const Radius.circular(2),
          )
          ..lineTo(8.2, 20.8)
          ..arcToPoint(const Offset(6.2, 19), radius: const Radius.circular(2))
          ..close()
          ..moveTo(9, 8)
          ..lineTo(9, 6.5)
          ..arcToPoint(const Offset(15, 6.5), radius: const Radius.circular(3))
          ..lineTo(15, 8);
      case LineGlyph.moon:
        svgPath(p, 'M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z');
      case LineGlyph.globe:
        p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9));
        svgPath(
          p,
          'M3 12h18M12 3c2.5 2.6 3.8 5.6 3.8 9s-1.3 6.4-3.8 9'
          'c-2.5-2.6-3.8-5.6-3.8-9S9.5 5.6 12 3z',
        );
      case LineGlyph.cash:
        p
          ..addRRect(
            RRect.fromLTRBR(2.5, 6, 21.5, 18, const Radius.circular(2.5)),
          )
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2.6));
        svgPath(p, 'M6 9.5v5M18 9.5v5');
      case LineGlyph.haptic:
        p.addRRect(RRect.fromLTRBR(8, 4, 16, 20, const Radius.circular(2)));
        svgPath(p, 'M4 9v6M20 9v6M1.5 11v2M22.5 11v2');
      case LineGlyph.sheet:
        p.addRRect(RRect.fromLTRBR(4, 3, 20, 21, const Radius.circular(2.5)));
        svgPath(p, 'M4 9h16M4 15h16M10 9v12');
      case LineGlyph.download:
        svgPath(p, 'M12 4v11M7.5 10.5L12 15l4.5-4.5M5 19h14');
      case LineGlyph.gear:
        p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 3));
        svgPath(
          p,
          'M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1'
          'a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1'
          'a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8'
          'l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1'
          'a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8'
          'l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1'
          'a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8'
          'l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4'
          'h-.1a1.7 1.7 0 0 0-1.5 1z',
        );
    }
    return p;
  }

  @override
  bool shouldRepaint(_LineIconPainter old) =>
      old.glyph != glyph ||
      old.strokeWidth != strokeWidth ||
      old.color != color;
}

final _svgToken = RegExp(r'[MmLlHhVvCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)');

/// Appends SVG path data to [path]. Covers what the design's icons use:
/// moves, lines, cubic and smooth-cubic curves, arcs, and close.
@visibleForTesting
void svgPath(Path path, String data) {
  final tokens = _svgToken.allMatches(data).map((m) => m[0]!).toList();
  var i = 0;
  var command = 'M';
  var current = Offset.zero;
  var start = Offset.zero;
  Offset? lastControl;
  double next() => double.parse(tokens[i++]);
  bool numberNext() =>
      i < tokens.length && !RegExp(r'[A-Za-z]').hasMatch(tokens[i]);

  while (i < tokens.length) {
    if (!numberNext()) command = tokens[i++];
    final relative = command == command.toLowerCase();
    Offset point(double x, double y) =>
        relative ? current + Offset(x, y) : Offset(x, y);
    switch (command.toUpperCase()) {
      case 'M':
        current = start = point(next(), next());
        path.moveTo(current.dx, current.dy);
        // Further pairs after a move are lines.
        command = relative ? 'l' : 'L';
        lastControl = null;
      case 'L':
        current = point(next(), next());
        path.lineTo(current.dx, current.dy);
        lastControl = null;
      case 'H':
        final x = next();
        current = Offset(relative ? current.dx + x : x, current.dy);
        path.lineTo(current.dx, current.dy);
        lastControl = null;
      case 'V':
        final y = next();
        current = Offset(current.dx, relative ? current.dy + y : y);
        path.lineTo(current.dx, current.dy);
        lastControl = null;
      case 'C':
        final c1 = point(next(), next());
        final c2 = point(next(), next());
        final end = point(next(), next());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastControl = c2;
        current = end;
      case 'S':
        final c1 = lastControl == null ? current : current * 2 - lastControl;
        final c2 = point(next(), next());
        final end = point(next(), next());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastControl = c2;
        current = end;
      case 'A':
        final rx = next();
        final ry = next();
        final rotation = next();
        final largeArc = next() != 0;
        final sweep = next() != 0;
        final end = point(next(), next());
        path.arcToPoint(
          end,
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
        current = end;
        lastControl = null;
      case 'Z':
        path.close();
        current = start;
        lastControl = null;
    }
  }
}
