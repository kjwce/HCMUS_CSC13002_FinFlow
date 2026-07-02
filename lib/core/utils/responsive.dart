import 'package:flutter/material.dart';

/// Responsive helper — scales all pixel values proportionally to the
/// device's screen size, using the Pixel 9 (393 × 852) as the reference.
///
/// Usage:
///   EdgeInsets.all(Responsive.w(context, 20))
///   SizedBox(height: Responsive.h(context, 12))
///   fontSize: Responsive.sp(context, 16)
class Responsive {
  Responsive._();

  /// Reference dimensions (Pixel 9).
  static const double refWidth = 393;
  static const double refHeight = 852;

  /// Scale a width‑based value (padding, margin, icon size, etc.).
  static double w(BuildContext context, double px) =>
      MediaQuery.of(context).size.width / refWidth * px;

  /// Scale a height‑based value (vertical gaps, container heights, etc.).
  static double h(BuildContext context, double px) =>
      MediaQuery.of(context).size.height / refHeight * px;

  /// Scale a font size proportionally to screen width.
  static double sp(BuildContext context, double px) =>
      MediaQuery.of(context).size.width / refWidth * px;
}
