import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';

/// Full-screen budget setup shown once after sign up / first sign in
/// when the user has no budget limit set yet.
class BudgetSetupScreen extends ConsumerStatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
  final _controller = TextEditingController();
  final _weeklyController = TextEditingController();
  bool _isSaving = false;
  var _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_formatAmount);
    _weeklyController.addListener(_formatWeeklyAmount);
  }

  void _formatAmount() {
    _formatController(_controller);
  }

  void _formatWeeklyAmount() {
    _formatController(_weeklyController);
  }

  void _formatController(TextEditingController controller) {
    if (_isFormatting) return;
    _isFormatting = true;
    final text = controller.text.replaceAll(',', '');
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      controller.text = '';
    } else {
      final formatted = _addCommas(digits);
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    _isFormatting = false;
  }

  static String _addCommas(String digits) {
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  void dispose() {
    _controller.removeListener(_formatAmount);
    _weeklyController.removeListener(_formatWeeklyAmount);
    _controller.dispose();
    _weeklyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Text(
                  'FinFlow',
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 36),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 48)),

                // Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 24),
                    vertical: Responsive.h(context, 32),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Icon
                      Container(
                        width: Responsive.w(context, 64),
                        height: Responsive.w(context, 64),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: Responsive.w(context, 32),
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 20)),

                      Text(
                        'Set Your Budget',
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 22),
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 8)),
                      Text(
                        'Set a monthly spending limit so we can\nhelp you stay on track.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 14),
                          color: AppColors.mutedGray,
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 28)),

                      // Monthly amount input
                      Container(
                        width: double.infinity,
                        height: Responsive.h(context, 56),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: Responsive.sp(context, 24),
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                          decoration: InputDecoration(
                            hintText: '5,000,000',
                            hintStyle: TextStyle(
                              fontSize: Responsive.sp(context, 24),
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedGray.withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: Responsive.h(context, 14),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 8)),
                      Text(
                        'VND / month',
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 13),
                          color: AppColors.mutedGray,
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 18)),

                      Container(
                        width: double.infinity,
                        height: Responsive.h(context, 52),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _weeklyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: Responsive.sp(context, 20),
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                          decoration: InputDecoration(
                            hintText: '1,250,000',
                            hintStyle: TextStyle(
                              fontSize: Responsive.sp(context, 20),
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedGray.withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: Responsive.h(context, 13),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 8)),
                      Text(
                        'VND / week (optional)',
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 13),
                          color: AppColors.mutedGray,
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 28)),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: Responsive.h(context, 48),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveBudget,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.darkText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: Responsive.w(context, 20),
                                  height: Responsive.h(context, 20),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF093030),
                                  ),
                                )
                              : Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: Responsive.sp(context, 16),
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 12)),

                      // Skip link
                      TextButton(
                        onPressed: _isSaving ? null : () => _goToDashboard(),
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            fontSize: Responsive.sp(context, 14),
                            color: AppColors.mutedGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveBudget() async {
    final raw = _controller.text.trim().replaceAll(',', '');
    final amount = int.tryParse(raw);
    final weeklyRaw = _weeklyController.text.trim().replaceAll(',', '');
    final weeklyAmount = weeklyRaw.isEmpty ? null : int.tryParse(weeklyRaw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = AuthService.instance.currentUser;
      await AuthService.instance.updateProfile(
        fullName: user?.fullName ?? 'New FinFlow User',
        budgetLimit: amount,
        weeklyBudget: weeklyAmount != null && weeklyAmount > 0
            ? weeklyAmount
            : null,
      );
      if (!mounted) return;
      _goToDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  void _goToDashboard() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
  }
}
