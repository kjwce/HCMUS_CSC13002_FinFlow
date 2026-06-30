import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/theme/app_colors.dart';
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
  bool _isSaving = false;
  var _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_formatAmount);
  }

  void _formatAmount() {
    if (_isFormatting) return;
    _isFormatting = true;
    final text = _controller.text.replaceAll(',', '');
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _controller.text = '';
    } else {
      final formatted = _addCommas(digits);
      _controller.value = TextEditingValue(
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Text(
                  'FinFlow',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 48),

                // Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
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
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 32,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Set Your Budget',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set a monthly spending limit so we can\nhelp you stay on track.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.mutedGray,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Amount input
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                          decoration: InputDecoration(
                            hintText: '5,000,000',
                            hintStyle: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedGray.withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'VND / month',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedGray,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
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
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF093030),
                                  ),
                                )
                              : const Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Skip link
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () => _goToDashboard(),
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            fontSize: 14,
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
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = AuthService.instance.currentUser;
      await AuthService.instance.updateProfile(
        fullName: user?.fullName ?? 'New FinFlow User',
        budgetLimit: amount,
      );
      if (!mounted) return;
      _goToDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  void _goToDashboard() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
      (route) => false,
    );
  }
}
