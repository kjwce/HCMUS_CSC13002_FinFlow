import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';

/// Reusable bottom navigation bar for all screens.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, this.selectedIndex = 0, this.onTabChanged});

  final int selectedIndex;
  final ValueChanged<int>? onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Responsive.h(context, 70),
      decoration: BoxDecoration(
        color: context.finFlowColors.navigationBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: Row(
        children: [
          Expanded(child: _navItem(context, const _FigmaHomeIcon(), 0)),
          Expanded(child: _navItem(context, const _FigmaAnalysisIcon(), 1)),
          Expanded(child: _scanButton(context)),
          Expanded(child: _navItem(context, const _FigmaCommunityIcon(), 3)),
          Expanded(child: _navItem(context, const _FigmaProfileIcon(), 4)),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, Widget icon, int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => _onTap(context, index),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: Responsive.w(context, 44),
          height: Responsive.w(context, 44),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: Responsive.w(context, 22),
            height: Responsive.w(context, 22),
            child: icon,
          ),
        ),
      ),
    );
  }

  Widget _scanButton(BuildContext context) {
    final isSelected = selectedIndex == 2;
    return GestureDetector(
      onTap: () => _onTap(context, 2),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: Responsive.w(context, 44),
          height: Responsive.w(context, 44),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blueAccent : AppColors.primaryGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.document_scanner_outlined,
            color: Colors.white,
            size: Responsive.w(context, 18),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    if (onTabChanged != null) {
      onTabChanged!(index);
    } else {
      // Pop back to the parent screen (MainShell) with the tab index
      // so it can switch to the correct tab.  This avoids destroying
      // and recreating the navigation stack (the old pushNamedAndRemoveUntil
      // approach) which caused pressing Back to land on unexpected screens.
      Navigator.of(context).pop(index);
    }
  }
}

// =============================================================================
// Figma bottom nav icons
// =============================================================================

abstract class _FigmaIcon extends StatelessWidget {
  const _FigmaIcon();
  Size get viewBox;
  void drawPath(Canvas canvas, Paint paint);
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IconPainter(
        viewBox: viewBox,
        draw: drawPath,
        color: context.finFlowColors.primaryText,
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter({
    required this.viewBox,
    required this.draw,
    required this.color,
  });
  final Size viewBox;
  final void Function(Canvas canvas, Paint paint) draw;
  final Color color;
  @override
  void paint(Canvas canvas, Size target) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final scale =
        (target.width * 0.65) /
        (viewBox.width > viewBox.height ? viewBox.width : viewBox.height);
    final dx = (target.width - viewBox.width * scale) / 2;
    final dy = (target.height - viewBox.height * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    draw(canvas, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _FigmaHomeIcon extends _FigmaIcon {
  const _FigmaHomeIcon();
  @override
  Size get viewBox => const Size(25, 31);
  @override
  void drawPath(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(23.768, 31)
      ..lineTo(1.232, 31)
      ..cubicTo(0.905, 31, 0.592, 30.869, 0.361, 30.635)
      ..cubicTo(0.13, 30.401, 0, 30.084, 0, 29.753)
      ..lineTo(0, 11.731)
      ..cubicTo(-0.001, 11.559, 0.034, 11.389, 0.103, 11.231)
      ..cubicTo(0.172, 11.074, 0.272, 10.933, 0.398, 10.817)
      ..lineTo(11.664, 0.331)
      ..cubicTo(11.89, 0.118, 12.188, 0, 12.497, 0)
      ..cubicTo(12.807, 0, 13.104, 0.118, 13.331, 0.331)
      ..lineTo(24.602, 10.817)
      ..cubicTo(24.727, 10.934, 24.827, 11.075, 24.895, 11.232)
      ..cubicTo(24.964, 11.389, 24.999, 11.559, 25, 11.731)
      ..lineTo(25, 29.753)
      ..cubicTo(25, 30.084, 24.87, 30.401, 24.639, 30.635)
      ..cubicTo(24.408, 30.869, 24.095, 31, 23.768, 31)
      ..close()
      ..moveTo(9.603, 22.18)
      ..lineTo(15.403, 22.18)
      ..cubicTo(15.523, 22.181, 15.641, 22.205, 15.752, 22.252)
      ..cubicTo(15.862, 22.299, 15.963, 22.368, 16.047, 22.454)
      ..cubicTo(16.131, 22.541, 16.198, 22.643, 16.243, 22.756)
      ..cubicTo(16.289, 22.868, 16.312, 22.988, 16.311, 23.11)
      ..lineTo(16.311, 31)
      ..lineTo(8.689, 31)
      ..lineTo(8.689, 23.11)
      ..cubicTo(8.688, 22.988, 8.712, 22.867, 8.757, 22.754)
      ..cubicTo(8.803, 22.641, 8.87, 22.539, 8.955, 22.453)
      ..cubicTo(9.04, 22.366, 9.141, 22.298, 9.252, 22.251)
      ..cubicTo(9.363, 22.204, 9.482, 22.18, 9.603, 22.18)
      ..close();
    canvas.drawPath(path, paint);
  }
}

class _FigmaAnalysisIcon extends _FigmaIcon {
  const _FigmaAnalysisIcon();
  @override
  Size get viewBox => const Size(31, 30);
  @override
  void drawPath(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(24.765, 23.967)
      ..lineTo(31, 30)
      ..moveTo(6.451, 8.296)
      ..lineTo(6.451, 19.777)
      ..moveTo(10.407, 19.777)
      ..lineTo(10.407, 14.461)
      ..moveTo(18.542, 19.777)
      ..lineTo(18.542, 17.121)
      ..moveTo(14.364, 19.777)
      ..lineTo(14.364, 8.296)
      ..moveTo(22.563, 19.777)
      ..lineTo(22.563, 12.685)
      ..moveTo(29.008, 14.036)
      ..cubicTo(29.008, 21.788, 22.515, 28.073, 14.504, 28.073)
      ..cubicTo(6.494, 28.073, 0, 21.788, 0, 14.036)
      ..cubicTo(0, 6.284, 6.494, 0, 14.504, 0)
      ..cubicTo(22.515, 0, 29.008, 6.284, 29.008, 14.036)
      ..close();
    canvas.drawPath(path, paint);
  }
}

class _FigmaCommunityIcon extends _FigmaIcon {
  const _FigmaCommunityIcon();
  @override
  Size get viewBox => const Size(33, 25);
  @override
  void drawPath(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(13.779, 12.506)
      ..lineTo(23.06, 12.506)
      ..lineTo(23.06, 17.54)
      ..lineTo(33, 8.77)
      ..lineTo(23.06, 0)
      ..lineTo(23.06, 5.034)
      ..lineTo(13.779, 5.034)
      ..moveTo(19.221, 12.494)
      ..lineTo(9.94, 12.494)
      ..lineTo(9.94, 7.461)
      ..lineTo(0, 16.23)
      ..lineTo(9.94, 25)
      ..lineTo(9.94, 19.966)
      ..lineTo(19.221, 19.966)
      ..close();
    canvas.drawPath(path, paint);
  }
}

class _FigmaProfileIcon extends _FigmaIcon {
  const _FigmaProfileIcon();
  @override
  Size get viewBox => const Size(22, 29);
  @override
  void drawPath(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0.769, 18.329)
      ..cubicTo(0.231, 19.666, -0.03, 21.094, 0.003, 22.531)
      ..cubicTo(0.003, 28.49, 21.986, 28.49, 21.997, 22.531)
      ..cubicTo(22.03, 21.094, 21.77, 19.666, 21.232, 18.329)
      ..cubicTo(20.694, 16.992, 19.889, 15.774, 18.864, 14.746)
      ..cubicTo(17.84, 13.719, 16.616, 12.902, 15.266, 12.345)
      ..cubicTo(13.915, 11.788, 12.465, 11.5, 11, 11.5)
      ..cubicTo(9.535, 11.5, 8.085, 11.788, 6.734, 12.345)
      ..cubicTo(5.384, 12.902, 4.16, 13.719, 3.136, 14.746)
      ..cubicTo(2.111, 15.774, 1.307, 16.992, 0.769, 18.329)
      ..close()
      ..moveTo(10.992, 8.663)
      ..cubicTo(13.43, 8.663, 15.407, 6.723, 15.407, 4.331)
      ..cubicTo(15.407, 1.939, 13.43, 0, 10.992, 0)
      ..cubicTo(8.553, 0, 6.577, 1.939, 6.577, 4.331)
      ..cubicTo(6.577, 6.723, 8.553, 8.663, 10.992, 8.663)
      ..close();
    canvas.drawPath(path, paint);
  }
}
