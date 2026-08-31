import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n/app_language.dart';
import '../theme/app_theme_manager.dart';
import '../utils/responsive.dart';

/// Opens the shared FinFlow language picker used by Home and Settings.
Future<void> showFinFlowLanguageDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xB3000000)
        : const Color(0x73031D17),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const Center(child: _LanguageDialog()),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Compact flag-and-chevron language selector used by the Home header.
class HomeLanguageSelector extends StatefulWidget {
  const HomeLanguageSelector({super.key});

  @override
  State<HomeLanguageSelector> createState() => _HomeLanguageSelectorState();
}

class _HomeLanguageSelectorState extends State<HomeLanguageSelector> {
  var _isOpen = false;

  Future<void> _showLanguageDialog() async {
    if (_isOpen) return;
    setState(() => _isOpen = true);

    await showFinFlowLanguageDialog(context);

    if (mounted) setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        final locale = AppLanguage.instance.locale;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Semantics(
          button: true,
          label: AppStrings.choose('Choose language', 'Chọn ngôn ngữ'),
          child: Tooltip(
            message: AppStrings.choose('Choose language', 'Chọn ngôn ngữ'),
            child: InkWell(
              key: const Key('home-language-selector'),
              onTap: _showLanguageDialog,
              borderRadius: BorderRadius.circular(Responsive.w(context, 22)),
              child: Container(
                width: Responsive.w(context, 58),
                height: Responsive.w(context, 40),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 6),
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0A241F)
                      : const Color(0xFFE2F7EF),
                  borderRadius: BorderRadius.circular(
                    Responsive.w(context, 22),
                  ),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF29483F)
                        : const Color(0xFFD3EFE5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    LanguageFlag(
                      locale: locale,
                      size: Responsive.w(context, 25),
                    ),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: Responsive.w(context, 15),
                        color: isDark
                            ? const Color(0xFF38D6AC)
                            : const Color(0xFF006C53),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Home-only theme toggle. Dark mode shows a sun and light mode shows a moon.
class HomeThemeToggle extends StatelessWidget {
  const HomeThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeManager.instance,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final tooltip = isDark
            ? AppStrings.choose(
                'Switch to light mode',
                'Chuyển sang chế độ sáng',
              )
            : AppStrings.choose(
                'Switch to dark mode',
                'Chuyển sang chế độ tối',
              );
        return Semantics(
          button: true,
          label: tooltip,
          child: Tooltip(
            message: tooltip,
            child: InkWell(
              key: const Key('home-theme-toggle'),
              onTap: AppThemeManager.instance.toggle,
              customBorder: const CircleBorder(),
              child: Container(
                width: Responsive.w(context, 40),
                height: Responsive.w(context, 40),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0A241F)
                      : const Color(0xFFD7F5EA),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF29483F)
                        : const Color(0xFFD3EFE5),
                  ),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: Responsive.w(context, 22),
                  color: isDark
                      ? const Color(0xFF38D6AC)
                      : const Color(0xFF006C53),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        final selected = AppLanguage.instance.locale;
        return Material(
          key: const Key('home-language-dialog'),
          color: Colors.transparent,
          child: Container(
            width: math.min(
              Responsive.w(context, 330),
              MediaQuery.sizeOf(context).width - Responsive.w(context, 40),
            ),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A241F) : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(Responsive.w(context, 22)),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF29483F)
                    : const Color(0xFFE1EAE6),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0x6600C49A)
                      : const Color(0x33031D17),
                  blurRadius: Responsive.w(context, 24),
                  offset: Offset(0, Responsive.h(context, 10)),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.h(context, 20),
                  ),
                  child: Text(
                    AppStrings.choose('Choose language', 'Chọn ngôn ngữ'),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: Responsive.sp(context, 18),
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFF4FBF8)
                          : const Color(0xFF12251F),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF2A574C)
                      : const Color(0xFFE7ECE9),
                ),
                Padding(
                  padding: EdgeInsets.all(Responsive.w(context, 10)),
                  child: Column(
                    children: [
                      _LanguageOption(
                        locale: AppLocale.vietnamese,
                        selected: selected == AppLocale.vietnamese,
                      ),
                      SizedBox(height: Responsive.h(context, 4)),
                      _LanguageOption(
                        locale: AppLocale.english,
                        selected: selected == AppLocale.english,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.locale, required this.selected});

  final AppLocale locale;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: Key('language-option-${locale.code}'),
        onTap: () {
          AppLanguage.instance.setLocale(locale);
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(Responsive.w(context, 12)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: BoxConstraints(minHeight: Responsive.h(context, 64)),
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 12)),
          decoration: BoxDecoration(
            color: selected
                ? isDark
                      ? const Color(0xFF1D4A40)
                      : const Color(0xFFE5F7F0)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(Responsive.w(context, 12)),
          ),
          child: Row(
            children: [
              LanguageFlag(locale: locale, size: Responsive.w(context, 36)),
              SizedBox(width: Responsive.w(context, 14)),
              Expanded(
                child: Text(
                  locale.label,
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 16),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: isDark
                        ? selected
                              ? const Color(0xFFF4FBF8)
                              : const Color(0xFFB8CCC5)
                        : const Color(0xFF1B2924),
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: Responsive.w(context, 22),
                  color: isDark
                      ? const Color(0xFF38D6AC)
                      : const Color(0xFF006C53),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Crisp vector flag that stays consistent across Android and iOS.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({required this.locale, required this.size, super.key});

  final AppLocale locale;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      image: true,
      label: locale.label,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(math.max(1, size * 0.045)),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? const Color(0xFF6A8C82) : const Color(0xFFD5DFDB),
          ),
        ),
        child: CustomPaint(
          painter: locale == AppLocale.vietnamese
              ? const _VietnamFlagPainter()
              : const _UnitedKingdomFlagPainter(),
        ),
      ),
    );
  }
}

class _VietnamFlagPainter extends CustomPainter {
  const _VietnamFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFDA251D));

    final outer = radius * 0.5;
    final inner = outer * 0.382;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final pointRadius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(
        center.dx + math.cos(angle) * pointRadius,
        center.dy + math.sin(angle) * pointRadius,
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFCD00));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnitedKingdomFlagPainter extends CustomPainter {
  const _UnitedKingdomFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final clip = Path()..addOval(bounds);
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF012169));

    final whiteDiagonal = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.2
      ..strokeCap = StrokeCap.square;
    final redDiagonal = Paint()
      ..color = const Color(0xFFC8102E)
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.square;
    final topLeft = Offset.zero;
    final bottomRight = Offset(size.width, size.height);
    final bottomLeft = Offset(0, size.height);
    final topRight = Offset(size.width, 0);
    canvas
      ..drawLine(topLeft, bottomRight, whiteDiagonal)
      ..drawLine(bottomLeft, topRight, whiteDiagonal)
      ..drawLine(topLeft, bottomRight, redDiagonal)
      ..drawLine(bottomLeft, topRight, redDiagonal);

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.36, 0, size.width * 0.28, size.height),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.36, size.width, size.height * 0.28),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.42, 0, size.width * 0.16, size.height),
      Paint()..color = const Color(0xFFC8102E),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.42, size.width, size.height * 0.16),
      Paint()..color = const Color(0xFFC8102E),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
