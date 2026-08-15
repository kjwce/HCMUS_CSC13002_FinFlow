import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../../finance/presentation/add_transaction_sheet.dart';

class BudgetLimitsScreen extends StatefulWidget {
  const BudgetLimitsScreen({super.key});

  @override
  State<BudgetLimitsScreen> createState() => _BudgetLimitsScreenState();
}

class _BudgetLimitsScreenState extends State<BudgetLimitsScreen> {
  late final TextEditingController _dailyController;
  late final TextEditingController _weeklyController;
  late final TextEditingController _monthlyController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = AuthService.instance;
    _dailyController = TextEditingController(
      text: _formatAmount(auth.dailyBudget),
    );
    _weeklyController = TextEditingController(
      text: _formatAmount(auth.weeklyBudget),
    );
    _monthlyController = TextEditingController(
      text: _formatAmount(auth.currentUser?.budgetLimit ?? 0),
    );
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _weeklyController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final daily = _parseAmount(_dailyController.text);
    final weekly = _parseAmount(_weeklyController.text);
    final monthly = _parseAmount(_monthlyController.text);
    if (monthly <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Please enter a valid monthly budget.',
              'Vui lòng nhập ngân sách tháng hợp lệ.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final auth = AuthService.instance;
      await auth.updateProfile(
        fullName:
            auth.currentUser?.fullName ??
            AppStrings.choose('FinFlow User', 'Người dùng FinFlow'),
        dailyBudget: daily,
        weeklyBudget: weekly,
        budgetLimit: monthly,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Budget limits saved.',
              'Đã lưu hạn mức ngân sách.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Unable to save budget limits: $error',
              'Không thể lưu hạn mức ngân sách: $error',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Scaffold(
      backgroundColor: colors.pageBackground,
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: 4,
        onAddTap: () => AddTransactionSheet.show(context),
      ),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.primaryText,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        centerTitle: true,
        title: Text(
          AppStrings.choose('Budget Limits', 'Hạn mức ngân sách'),
          style: const TextStyle(
            color: Color(0xFF00785D),
            fontFamily: 'Hanken Grotesk',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.choose(
              'About budget limits',
              'Giới thiệu hạn mức ngân sách',
            ),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  AppStrings.choose('Budget limits', 'Hạn mức ngân sách'),
                ),
                content: Text(
                  AppStrings.choose(
                    'Daily resets every day, weekly resets every Monday, and monthly resets on the first day of each month.',
                    'Hạn mức ngày được đặt lại mỗi ngày, hạn mức tuần đặt lại vào thứ Hai và hạn mức tháng đặt lại vào ngày đầu tháng.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppStrings.choose('OK', 'Đồng ý')),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          Responsive.w(context, 16),
          Responsive.h(context, 16),
          Responsive.w(context, 16),
          Responsive.h(context, 28),
        ),
        children: [
          _BudgetLimitCard(
            icon: const Icon(
              Icons.schedule_rounded,
              color: Color(0xFF00785D),
              size: 20,
            ),
            title: AppStrings.choose('Daily Budget', 'Ngân sách ngày'),
            subtitle: AppStrings.choose(
              'Manage everyday spending',
              'Quản lý chi tiêu hằng ngày',
            ),
            controller: _dailyController,
          ),
          SizedBox(height: Responsive.h(context, 18)),
          _BudgetLimitCard(
            icon: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF00785D),
              size: 20,
            ),
            title: AppStrings.choose('Weekly Budget', 'Ngân sách tuần'),
            subtitle: AppStrings.choose(
              'Set goals for the week',
              'Đặt mục tiêu cho tuần',
            ),
            controller: _weeklyController,
          ),
          SizedBox(height: Responsive.h(context, 18)),
          _BudgetLimitCard(
            icon: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFF00785D),
              size: 20,
            ),
            title: AppStrings.choose('Monthly Budget', 'Ngân sách tháng'),
            subtitle: AppStrings.choose(
              'Main financial limit',
              'Hạn mức tài chính chính',
            ),
            controller: _monthlyController,
          ),
          SizedBox(height: Responsive.h(context, 42)),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF007F62),
              foregroundColor: Colors.white,
              minimumSize: Size.fromHeight(Responsive.h(context, 52)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isSaving
                ? SizedBox.square(
                    dimension: Responsive.w(context, 18),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 19),
            label: Text(
              _isSaving
                  ? AppStrings.choose('Saving...', 'Đang lưu...')
                  : AppStrings.choose('Save Limits', 'Lưu hạn mức'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetLimitCard extends StatelessWidget {
  const _BudgetLimitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.controller,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 16)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10002D22),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: Responsive.w(context, 38),
                height: Responsive.w(context, 38),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F5F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: icon),
              ),
              SizedBox(width: Responsive.w(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 15),
                        fontWeight: FontWeight.w700,
                        color: colors.primaryText,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 11),
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_ThousandsFormatter()],
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 44),
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                    hintText: '0',
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(context, 12)),
              const Padding(
                padding: EdgeInsets.only(bottom: 9),
                child: Text(
                  'VND',
                  style: TextStyle(
                    color: Color(0xFF00785D),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  const _ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = _formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatAmount(int amount) => amount > 0 ? _formatDigits('$amount') : '';

String _formatDigits(String digits) {
  if (digits.isEmpty) return '';
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

int _parseAmount(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'\D'), '')) ?? 0;
