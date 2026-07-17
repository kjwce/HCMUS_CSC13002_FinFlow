import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';

/// Scan-specific color constants from the Figma design spec.
class _ScanColors {
  static const lettersIcons = Color(0xFF093030);
  static const blueButton = Color(0xFF3299FF);
  static const lightBlueButton = Color(0xFF6DB6FE);
}

/// Sample scanned item model — placeholder until OCR is wired in.
class _ScannedItem {
  final IconData icon;
  final String name;
  final String amount;
  final String time;
  final String date;

  const _ScannedItem({
    required this.icon,
    required this.name,
    required this.amount,
    required this.time,
    required this.date,
  });
}

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  static const _items = [
    _ScannedItem(
      icon: Icons.local_cafe,
      name: 'milk Tea',
      amount: '50000 VND',
      time: '18:27',
      date: 'April 30',
    ),
    _ScannedItem(
      icon: Icons.restaurant,
      name: 'Pizza',
      amount: '200000 VND',
      time: '18:27',
      date: 'April 30',
    ),
    _ScannedItem(
      icon: Icons.more_horiz,
      name: '.......',
      amount: '..... VND',
      time: '',
      date: '',
    ),
    _ScannedItem(
      icon: Icons.more_horiz,
      name: '........',
      amount: '...... VND',
      time: '18:27',
      date: 'April 30',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context),
              SizedBox(height: Responsive.h(context, 16)),
              _buildReceiptPreview(context),
              SizedBox(height: Responsive.h(context, 24)),
              _buildItemsList(context),
              SizedBox(height: Responsive.h(context, 24)),
              _buildAddButton(context),
              SizedBox(height: Responsive.h(context, 40)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top decorative area with gradient, back button, title and bell
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        // Decorative gradient cover
        Container(
          height: Responsive.h(context, 200),
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryGreen,
                AppColors.lightGreen,
                Color(0xFFF4FFF6),
              ],
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
          ),
        ),
        // App bar row: back, title, bell
        Positioned(
          top: Responsive.h(context, 16),
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
            child: Row(
              children: [
                // Back arrow at left:38,69 in Figma spec
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: Responsive.w(context, 40),
                    height: Responsive.h(context, 40),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: _ScanColors.lettersIcons,
                      size: Responsive.w(context, 20),
                    ),
                  ),
                ),
                const Spacer(),
                // Centered title
                Text(
                  AppStrings.scanReceipt,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.sp(context, 20),
                    color: _ScanColors.lettersIcons,
                  ),
                ),
                const Spacer(),
                // Notification bell
                const NotificationBell(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Receipt photo preview — centered, 232x283, rounded corners
  // ---------------------------------------------------------------------------
  Widget _buildReceiptPreview(BuildContext context) {
    return Center(
      child: Container(
        width: Responsive.w(context, 232),
        height: Responsive.h(context, 283),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Receipt icon
              Container(
                width: Responsive.w(context, 64),
                height: Responsive.h(context, 64),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: AppColors.primaryGreen,
                  size: Responsive.w(context, 32),
                ),
              ),
              SizedBox(height: Responsive.h(context, 12)),
              Text(
                'Tap to scan',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: Responsive.sp(context, 14),
                  color: AppColors.muted,
                ),
              ),
              SizedBox(height: Responsive.h(context, 4)),
              Text(
                'or upload a photo',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  fontSize: Responsive.sp(context, 12),
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scanned items list
  // ---------------------------------------------------------------------------
  Widget _buildItemsList(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 24)),
      child: Column(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final isLast = index == _items.length - 1;
          return Column(
            children: [
              _buildItemRow(context, item, index),
              if (!isLast) _buildDotsSeparator(context),
            ],
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Single scanned item row
  // ---------------------------------------------------------------------------
  Widget _buildItemRow(BuildContext context, _ScannedItem item, int index) {
    // Alternate background colors for the icon
    final iconBg = index.isEven
        ? _ScanColors.lightBlueButton
        : _ScanColors.blueButton;

    return Row(
      children: [
        // Category icon — rounded square 57x53, radius 22
        Container(
          width: Responsive.w(context, 57),
          height: Responsive.h(context, 53),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            item.icon,
            color: Colors.white,
            size: Responsive.w(context, 24),
          ),
        ),
        SizedBox(width: Responsive.w(context, 16)),
        // Item details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item name — Poppins Medium 15px, #052224
              Text(
                item.name,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: Responsive.sp(context, 15),
                  color: AppColors.darkText,
                ),
              ),
              if (item.time.isNotEmpty && item.date.isNotEmpty) ...[
                SizedBox(height: Responsive.h(context, 2)),
                // Date/time — Poppins SemiBold 12px, #0068FF
                Text(
                  '${item.time} - ${item.date}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.sp(context, 12),
                    color: AppColors.blueAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Amount — Poppins Medium 15px, #0068FF
        Text(
          item.amount,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: Responsive.sp(context, 15),
            color: AppColors.blueAccent,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dots separator between items — Poppins Medium 15px
  // ---------------------------------------------------------------------------
  Widget _buildDotsSeparator(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 8)),
      child: Row(
        children: [
          SizedBox(width: Responsive.w(context, 57 + 16)), // align with text area
          const Expanded(
            child: Text(
              '....................................',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: AppColors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // "Add Expenses" button — centered, green bg, 169x36, rounded 30px
  // ---------------------------------------------------------------------------
  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Items added',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      child: Center(
        child: Container(
          width: Responsive.w(context, 169),
          height: Responsive.h(context, 36),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(
            AppStrings.addExpense,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: Responsive.sp(context, 15),
              color: _ScanColors.lettersIcons,
            ),
          ),
        ),
      ),
    );
  }
}
