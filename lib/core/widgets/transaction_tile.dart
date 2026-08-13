import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/responsive.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.timeInfo,
    required this.category,
    required this.amount,
    required this.isIncome,
  });

  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String timeInfo;
  final String category;
  final String amount;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(context, 16)),
      child: Row(
        children: [
          Container(
            width: Responsive.w(context, 50),
            height: Responsive.w(context, 50),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: Responsive.w(context, 24),
            ),
          ),
          SizedBox(width: Responsive.w(context, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 16),
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 4)),
                Text(
                  timeInfo,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 12),
                    color: AppColors.blueAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontSize: Responsive.sp(context, 12),
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: Responsive.h(context, 4)),
              Text(
                amount,
                style: TextStyle(
                  fontSize: Responsive.sp(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isIncome ? AppColors.darkText : AppColors.blueAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
