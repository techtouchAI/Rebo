import 'package:flutter/material.dart';

/// A very light geometric backdrop (thin arcs and a grid) that gives the
/// screens the feel of a sketchbook page without hurting readability.
class PatternBackdrop extends StatelessWidget {
  const PatternBackdrop({super.key, required this.child, this.accent});

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _BackdropPainter(
                color: (accent ?? scheme.primary).withValues(alpha: 0.06),
                lineColor: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.color, required this.lineColor});

  final Color color;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;

    // Faint grid, like a drawing sheet.
    const double step = 56;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Overlapping circles echoing a colour wheel in the corners.
    final circle = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26;
    canvas.drawCircle(Offset(size.width - 40, -30), 150, circle);
    canvas.drawCircle(Offset(size.width - 40, -30), 210, circle..strokeWidth = 12);
    canvas.drawCircle(const Offset(30, 0), 120, circle..strokeWidth = 8);
    paint.color = color;
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.lineColor != lineColor;
  }
}
