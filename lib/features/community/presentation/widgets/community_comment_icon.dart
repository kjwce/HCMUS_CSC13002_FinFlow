import 'package:flutter/material.dart';

/// The outlined, three-dot comment bubble from the FinFlow Stitch design.
class CommunityCommentIcon extends StatelessWidget {
  const CommunityCommentIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;

    return SizedBox.square(
      dimension: resolvedSize,
      child: CustomPaint(painter: _CommunityCommentIconPainter(resolvedColor)),
    );
  }
}

class _CommunityCommentIconPainter extends CustomPainter {
  const _CommunityCommentIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bubble = Path()
      ..moveTo(width * 0.50, height * 0.11)
      ..cubicTo(
        width * 0.26,
        height * 0.11,
        width * 0.10,
        height * 0.25,
        width * 0.10,
        height * 0.45,
      )
      ..cubicTo(
        width * 0.10,
        height * 0.61,
        width * 0.20,
        height * 0.72,
        width * 0.36,
        height * 0.77,
      )
      ..lineTo(width * 0.19, height * 0.89)
      ..lineTo(width * 0.49, height * 0.79)
      ..cubicTo(
        width * 0.73,
        height * 0.79,
        width * 0.90,
        height * 0.65,
        width * 0.90,
        height * 0.45,
      )
      ..cubicTo(
        width * 0.90,
        height * 0.25,
        width * 0.74,
        height * 0.11,
        width * 0.50,
        height * 0.11,
      )
      ..close();
    canvas.drawPath(bubble, outline);

    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dotRadius = width * 0.045;
    for (final x in <double>[0.36, 0.50, 0.64]) {
      canvas.drawCircle(Offset(width * x, height * 0.45), dotRadius, dot);
    }
  }

  @override
  bool shouldRepaint(_CommunityCommentIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
