import 'package:flutter/material.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../models/transaction_category.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';
import 'add_transaction_sheet.dart';

/// Screen shown after a transaction has been successfully saved.
///
/// Displays the saved transaction details, current wallet balance, and
/// two actions: [Done] (pop to home) and [Add Another] (reopen Add flow).
class TransactionSavedScreen extends StatelessWidget {
  const TransactionSavedScreen({super.key, required this.transaction});

  /// The transaction that was just saved.
  final TransactionModel transaction;

  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.amount < 0;
    final absAmount = transaction.amount.abs();
    final wallet = WalletService.instance.byId(transaction.walletId);
    final walletName = switch (wallet?.name) {
      'Cash' => AppStrings.choose('Cash', 'Tiền mặt'),
      'Transfer' => AppStrings.choose('Transfer', 'Chuyển khoản'),
      final name? => name,
      null => '—',
    };
    final balance = TransactionService.instance.balanceByWallet(
      transaction.walletId ?? '',
    );
    final category = TransactionCategory.resolve(transaction.category);
    final themeColors = context.finFlowColors;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9F4),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 24)),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Success Icon ──
              Container(
                width: Responsive.w(context, 80),
                height: Responsive.w(context, 80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00C49A).withValues(alpha: 0.15),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: Responsive.w(context, 44),
                  color: const Color(0xFF006C53),
                ),
              ),
              SizedBox(height: Responsive.h(context, 20)),

              // ── Transaction Saved ──
              Text(
                AppStrings.transactionSaved,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 28),
                  fontWeight: FontWeight.w700,
                  color: themeColors.primaryText,
                ),
              ),
              SizedBox(height: Responsive.h(context, 8)),
              Text(
                AppStrings.transactionSavedSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: Responsive.sp(context, 15),
                  color: themeColors.secondaryText,
                ),
              ),

              SizedBox(height: Responsive.h(context, 40)),

              // ── Amount Card ──
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.h(context, 28),
                ),
                decoration: BoxDecoration(
                  color: themeColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF006C53).withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Amount
                    Text(
                      '${isExpense ? '-' : '+'}${_formatVnd(absAmount)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _headlineFont,
                        fontSize: Responsive.sp(context, 40),
                        fontWeight: FontWeight.bold,
                        color: isExpense
                            ? const Color(0xFFBA1A1A)
                            : const Color(0xFF006C53),
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 8)),
                    // Type badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(context, 18),
                        vertical: Responsive.h(context, 6),
                      ),
                      decoration: BoxDecoration(
                        color: isExpense
                            ? const Color(0xFFFFDAD6)
                            : const Color(0xFFD7F8D7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isExpense
                            ? AppStrings.choose('EXPENSE', 'CHI TIÊU')
                            : AppStrings.choose('INCOME', 'THU NHẬP'),
                        style: TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: Responsive.sp(context, 12),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isExpense
                              ? const Color(0xFF8C1D18)
                              : const Color(0xFF006C53),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: Responsive.h(context, 24)),

              // ── Details Card ──
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 20),
                  vertical: Responsive.h(context, 20),
                ),
                decoration: BoxDecoration(
                  color: themeColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF006C53).withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Category row
                    _detailRow(
                      context,
                      leadingIcon: category.buildIcon(
                        size: Responsive.w(context, 20),
                      ),
                      iconColor: category.color,
                      label: AppStrings.category,
                      value: AppStrings.categoryName(transaction.category),
                    ),
                    SizedBox(height: Responsive.h(context, 18)),
                    // Wallet row
                    _detailRow(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: const Color(0xFF006C53),
                      label: AppStrings.choose('Wallet', 'Ví'),
                      value: walletName,
                    ),
                    SizedBox(height: Responsive.h(context, 18)),
                    // Current Balance row
                    Divider(color: themeColors.divider, height: 1),
                    SizedBox(height: Responsive.h(context, 18)),
                    Row(
                      children: [
                        Container(
                          width: Responsive.w(context, 40),
                          height: Responsive.w(context, 40),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00C49A,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.account_balance_rounded,
                            size: Responsive.w(context, 20),
                            color: const Color(0xFF006C53),
                          ),
                        ),
                        SizedBox(width: Responsive.w(context, 14)),
                        Expanded(
                          child: Text(
                            AppStrings.currentBalance,
                            style: TextStyle(
                              fontFamily: _bodyFont,
                              fontSize: Responsive.sp(context, 15),
                              color: themeColors.secondaryText,
                            ),
                          ),
                        ),
                        Text(
                          '${balance >= 0 ? '' : '-'}${_formatVnd(balance.abs())}',
                          style: TextStyle(
                            fontFamily: _headlineFont,
                            fontSize: Responsive.sp(context, 18),
                            fontWeight: FontWeight.w700,
                            color: balance >= 0
                                ? const Color(0xFF006C53)
                                : const Color(0xFFBA1A1A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // ── Done Button ──
              SizedBox(
                width: double.infinity,
                height: Responsive.h(context, 56),
                child: ElevatedButton(
                  onPressed: () => _onDone(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D7AA),
                    foregroundColor: const Color(0xFF004A39),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF00D7AA).withValues(alpha: 0.3),
                  ),
                  child: Text(
                    AppStrings.done,
                    style: TextStyle(
                      fontFamily: _headlineFont,
                      fontWeight: FontWeight.w600,
                      fontSize: Responsive.sp(context, 16),
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.h(context, 12)),

              // ── Add Another Button ──
              SizedBox(
                width: double.infinity,
                height: Responsive.h(context, 48),
                child: TextButton(
                  onPressed: () => _onAddAnother(context),
                  child: Text(
                    AppStrings.addAnother,
                    style: TextStyle(
                      fontFamily: _headlineFont,
                      fontWeight: FontWeight.w600,
                      fontSize: Responsive.sp(context, 16),
                      color: const Color(0xFF006C53),
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.h(context, 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    IconData? icon,
    Widget? leadingIcon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: Responsive.w(context, 40),
          height: Responsive.w(context, 40),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              leadingIcon ??
              Icon(icon, size: Responsive.w(context, 20), color: iconColor),
        ),
        SizedBox(width: Responsive.w(context, 14)),
        Text(
          label,
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 15),
            color: context.finFlowColors.secondaryText,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontFamily: _headlineFont,
            fontSize: Responsive.sp(context, 16),
            fontWeight: FontWeight.w600,
            color: context.finFlowColors.primaryText,
          ),
        ),
      ],
    );
  }

  void _onDone(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _onAddAnother(BuildContext context) {
    Navigator.of(context).pop();
    AddTransactionSheet.show(context);
  }

  static String _formatVnd(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return '$buffer VND';
  }
}
