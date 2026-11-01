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
}

class LineIcon extends StatelessWidget {
  const LineIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.strokeWidth = 2,
    this.color = AppColors.label,
  });

  final LineGlyph glyph;
  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LineIconPainter(glyph, strokeWidth, color),
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
    }
    return p;
  }

  @override
  bool shouldRepaint(_LineIconPainter old) =>
      old.glyph != glyph ||
      old.strokeWidth != strokeWidth ||
      old.color != color;
}
