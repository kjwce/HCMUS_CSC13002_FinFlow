import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../../finance/presentation/add_transaction_sheet.dart';
import '../../finance/services/transaction_service.dart';

class BudgetOverviewScreen extends StatelessWidget {
  const BudgetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.finFlowColors.pageBackground,
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: 0,
        onAddTap: () => AddTransactionSheet.show(context),
      ),
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: context.finFlowColors.pageBackground,
        foregroundColor: context.finFlowColors.primaryText,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          AppStrings.choose('Budgets', 'Ngân sách'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFF4FBF8)
                : AppColors.deepEmerald,
            fontFamily: 'Manrope',
            fontSize: Responsive.sp(context, 22),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          AuthService.instance,
          TransactionService.instance,
        ]),
        builder: (context, _) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            Responsive.w(context, 16),
            Responsive.h(context, 16),
            Responsive.w(context, 16),
            Responsive.h(context, 28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.choose('Budget breakdown', 'Chi tiết ngân sách'),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: Responsive.sp(context, 20),
                  fontWeight: FontWeight.w800,
                  color: context.finFlowColors.primaryText,
                ),
              ),
              SizedBox(height: Responsive.h(context, 12)),
              _buildCard(
                context,
                title: AppStrings.choose('Daily budget', 'Ngân sách ngày'),
                period: ChartPeriod.day,
                limit: AuthService.instance.dailyBudget,
                onEdit: () => _editBudget(
                  context,
                  title: AppStrings.choose('Daily budget', 'Ngân sách ngày'),
                  period: ChartPeriod.day,
                  currentLimit: AuthService.instance.dailyBudget,
                ),
              ),
              SizedBox(height: Responsive.h(context, 14)),
              _buildCard(
                context,
                title: AppStrings.choose('Weekly budget', 'Ngân sách tuần'),
                period: ChartPeriod.week,
                limit: AuthService.instance.weeklyBudget,
                onEdit: () => _editBudget(
                  context,
                  title: AppStrings.choose('Weekly budget', 'Ngân sách tuần'),
                  period: ChartPeriod.week,
                  currentLimit: AuthService.instance.weeklyBudget,
                ),
              ),
              SizedBox(height: Responsive.h(context, 14)),
              _buildCard(
                context,
                title: AppStrings.choose('Monthly budget', 'Ngân sách tháng'),
                period: ChartPeriod.month,
                limit: AuthService.instance.currentUser?.budgetLimit ?? 0,
                onEdit: () => _editBudget(
                  context,
                  title: AppStrings.choose('Monthly budget', 'Ngân sách tháng'),
                  period: ChartPeriod.month,
                  currentLimit:
                      AuthService.instance.currentUser?.budgetLimit ?? 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required ChartPeriod period,
    required int limit,
    required VoidCallback onEdit,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.finFlowColors;
    final range = TransactionService.instance.dateRangeForPeriod(period);
    final spent = _safeExpense(range);
    final rawPercent = limit > 0 ? spent / limit * 100 : 0.0;
    final percent = rawPercent.clamp(0.0, 100.0);
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final status = limit <= 0
        ? AppStrings.choose('NO LIMIT', 'CHƯA ĐẶT')
        : rawPercent >= 100
        ? AppStrings.choose('OVER BUDGET', 'VƯỢT NGÂN SÁCH')
        : rawPercent >= 75
        ? AppStrings.choose('NEAR LIMIT', 'GẦN HẠN MỨC')
        : AppStrings.choose('ON TRACK', 'ĐÚNG KẾ HOẠCH');
    final statusColor = limit <= 0
        ? colors.secondaryText
        : rawPercent >= 100
        ? (isDark ? const Color(0xFFFF6B70) : const Color(0xFFBA1A1A))
        : rawPercent >= 75
        ? const Color(0xFFE49A18)
        : (isDark ? const Color(0xFF38D6AC) : AppColors.deepEmerald);

    return Container(
      key: Key('budget-overview-card-${period.name}'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16352E) : colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF29483F) : const Color(0xFFD6E7E0),
        ),
        boxShadow: isDark
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x1800523C),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Color(0x2400523C),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.w(context, 20),
              Responsive.h(context, 20),
              Responsive.w(context, 20),
              Responsive.h(context, 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 18),
                          fontWeight: FontWeight.w600,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 11.5),
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                          color: statusColor,
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.w(context, 8)),
                    Container(
                      width: Responsive.w(context, 34),
                      height: Responsive.w(context, 34),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF21483E)
                            : const Color(0xFFE7F5EF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: Responsive.w(context, 17),
                        color: isDark
                            ? const Color(0xFF38D6AC)
                            : AppColors.deepEmerald,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 14)),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${percent.round()}%',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: Responsive.sp(context, 34),
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      TextSpan(
                        text: AppStrings.choose(' used', ' đã dùng'),
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 17),
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.h(context, 10)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: Responsive.h(context, 10),
                    value: progress,
                    backgroundColor: isDark
                        ? const Color(0xFF29483F)
                        : const Color(0xFFE8ECEA),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                SizedBox(height: Responsive.h(context, 10)),
                Text(
                  limit > 0
                      ? AppStrings.choose(
                          'Spent ${_formatBudgetMoney(spent)} / ${_formatBudgetMoney(limit)} VND',
                          'Đã chi ${_formatBudgetMoney(spent)} / ${_formatBudgetMoney(limit)} VND',
                        )
                      : AppStrings.choose(
                          'Spent ${_formatBudgetMoney(spent)} VND · No limit',
                          'Đã chi ${_formatBudgetMoney(spent)} VND · Chưa đặt hạn mức',
                        ),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 12),
                    color: colors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editBudget(
    BuildContext context, {
    required String title,
    required ChartPeriod period,
    required int currentLimit,
  }) async {
    final range = TransactionService.instance.dateRangeForPeriod(period);
    final spent = _safeExpense(range);
    final value = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditBudgetDialog(
        title: title,
        period: period,
        currentLimit: currentLimit,
        spent: spent,
      ),
    );
    if (value == null || !context.mounted) return;

    final auth = AuthService.instance;
    final monthly = period == ChartPeriod.month
        ? value
        : auth.currentUser?.budgetLimit ?? 0;
    try {
      await auth.updateProfile(
        fullName:
            auth.currentUser?.fullName ??
            AppStrings.choose('FinFlow User', 'Người dùng FinFlow'),
        dailyBudget: period == ChartPeriod.day ? value : auth.dailyBudget,
        weeklyBudget: period == ChartPeriod.week ? value : auth.weeklyBudget,
        budgetLimit: monthly,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose('$title updated.', 'Đã cập nhật $title.'),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Unable to update budget: $error',
              'Không thể cập nhật ngân sách: $error',
            ),
          ),
        ),
      );
    }
  }

  int _safeExpense(DateRange range) {
    try {
      return TransactionService.instance.expenseBetween(range.start, range.end);
    } catch (_) {
      return 0;
    }
  }
}

class _EditBudgetDialog extends StatefulWidget {
  const _EditBudgetDialog({
    required this.title,
    required this.period,
    required this.currentLimit,
    required this.spent,
  });

  final String title;
  final ChartPeriod period;
  final int currentLimit;
  final int spent;

  @override
  State<_EditBudgetDialog> createState() => _EditBudgetDialogState();
}

class _EditBudgetDialogState extends State<_EditBudgetDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentLimit > 0
          ? _formatBudgetMoney(widget.currentLimit)
          : '',
    )..addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  int get _value =>
      int.tryParse(_controller.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  IconData get _icon => switch (widget.period) {
    ChartPeriod.day => Icons.schedule_rounded,
    ChartPeriod.week => Icons.date_range_rounded,
    ChartPeriod.month => Icons.calendar_month_rounded,
    _ => Icons.account_balance_wallet_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.finFlowColors;
    final value = _value;
    final remaining = value - widget.spent;
    final valid = value > 0;
    final progress = valid ? (widget.spent / value).clamp(0.0, 1.0) : 0.0;
    final accent = remaining < 0
        ? colors.negativeAmount
        : isDark
        ? const Color(0xFF38D6AC)
        : AppColors.deepEmerald;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 20),
        vertical: Responsive.h(context, 24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          key: const Key('edit-budget-dialog'),
          padding: EdgeInsets.all(Responsive.w(context, 22)),
          decoration: BoxDecoration(
            color: colors.dialogBackground,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark ? const Color(0xFF31564B) : const Color(0xFFCBE8DC),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x80000000)
                    : const Color(0x33002D22),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: Responsive.w(context, 46),
                      height: Responsive.w(context, 46),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF21483E)
                            : const Color(0xFFE4F6EF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon, color: accent, size: 24),
                    ),
                    SizedBox(width: Responsive.w(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.choose(
                              'Edit ${widget.title.toLowerCase()}',
                              'Sửa ${widget.title.toLowerCase()}',
                            ),
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: Responsive.sp(context, 19),
                              fontWeight: FontWeight.w800,
                              color: colors.primaryText,
                            ),
                          ),
                          SizedBox(height: Responsive.h(context, 2)),
                          Text(
                            AppStrings.choose(
                              'Update this limit only',
                              'Chỉ cập nhật hạn mức này',
                            ),
                            style: TextStyle(
                              fontSize: Responsive.sp(context, 12.5),
                              color: colors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('close-edit-budget-dialog'),
                      tooltip: AppStrings.choose('Close', 'Đóng'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 20)),
                Container(
                  padding: EdgeInsets.all(Responsive.w(context, 14)),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF18372F)
                        : const Color(0xFFF1FAF6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _BudgetDialogMetric(
                              label: AppStrings.choose('Spent', 'Đã chi'),
                              value: widget.spent,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 34,
                            color: colors.divider,
                          ),
                          Expanded(
                            child: _BudgetDialogMetric(
                              label: AppStrings.choose(
                                'Current limit',
                                'Hạn mức hiện tại',
                              ),
                              value: widget.currentLimit,
                              alignRight: true,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(context, 12)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: Responsive.h(context, 8),
                          backgroundColor: isDark
                              ? const Color(0xFF29483F)
                              : const Color(0xFFDDEAE5),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.h(context, 18)),
                Text(
                  AppStrings.choose('New budget limit', 'Hạn mức mới'),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 13),
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 7)),
                TextField(
                  key: const Key('edit-budget-amount-field'),
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_BudgetThousandsFormatter()],
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 24),
                    fontWeight: FontWeight.w800,
                    color: colors.primaryText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: 'VND',
                    suffixStyle: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                    filled: true,
                    fillColor: colors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: accent, width: 1.6),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.h(context, 10)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Row(
                    key: ValueKey(remaining),
                    children: [
                      Icon(
                        remaining < 0
                            ? Icons.warning_amber_rounded
                            : Icons.savings_outlined,
                        color: accent,
                        size: 18,
                      ),
                      SizedBox(width: Responsive.w(context, 7)),
                      Expanded(
                        child: Text(
                          !valid
                              ? AppStrings.choose(
                                  'Enter an amount greater than 0 VND',
                                  'Nhập số tiền lớn hơn 0 VND',
                                )
                              : remaining < 0
                              ? AppStrings.choose(
                                  '${_formatBudgetMoney(remaining.abs())} VND over the new limit',
                                  'Vượt hạn mức mới ${_formatBudgetMoney(remaining.abs())} VND',
                                )
                              : AppStrings.choose(
                                  '${_formatBudgetMoney(remaining)} VND remaining',
                                  'Còn lại ${_formatBudgetMoney(remaining)} VND',
                                ),
                          style: TextStyle(
                            fontSize: Responsive.sp(context, 12.5),
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.h(context, 22)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(
                            Responsive.h(context, 50),
                          ),
                          foregroundColor: colors.primaryText,
                          side: BorderSide(color: colors.inputBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(AppStrings.choose('Cancel', 'Hủy')),
                      ),
                    ),
                    SizedBox(width: Responsive.w(context, 10)),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        key: const Key('save-edited-budget'),
                        onPressed: valid
                            ? () => Navigator.of(context).pop(value)
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: Size.fromHeight(
                            Responsive.h(context, 50),
                          ),
                          backgroundColor: AppColors.deepEmerald,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 19),
                        label: Text(
                          AppStrings.choose('Save budget', 'Lưu ngân sách'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetDialogMetric extends StatelessWidget {
  const _BudgetDialogMetric({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  final String label;
  final int value;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.sp(context, 12),
            color: colors.secondaryText,
          ),
        ),
        SizedBox(height: Responsive.h(context, 3)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${_formatBudgetMoney(value)} VND',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: Responsive.sp(context, 12),
              fontWeight: FontWeight.w700,
              color: colors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetThousandsFormatter extends TextInputFormatter {
  const _BudgetThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 15) return oldValue;
    final formatted = digits.isEmpty
        ? ''
        : _formatBudgetMoney(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatBudgetMoney(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}
