import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../finance/models/wallet_model.dart';
import '../../finance/services/transaction_service.dart';
import '../../finance/services/wallet_service.dart';

class MoneySourcesScreen extends StatefulWidget {
  const MoneySourcesScreen({super.key});

  @override
  State<MoneySourcesScreen> createState() => _MoneySourcesScreenState();
}

class _MoneySourcesScreenState extends State<MoneySourcesScreen> {
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await Future.wait([
        WalletService.instance.fetchWallets(),
        TransactionService.instance.fetchTransactions(),
      ]);
    } catch (_) {
      // Keep any already-cached data visible when an offline refresh fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _adjustBalances() async {
    final cash = _walletOfType(WalletType.cash);
    final transfer = _walletOfType(WalletType.transfer);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.finFlowColors.bottomSheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AdjustOpeningBalancesSheet(
        cashBalance: cash?.initialBalance ?? 0,
        transferBalance: transfer?.initialBalance ?? 0,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Opening balances updated.',
              'Đã cập nhật số dư ban đầu.',
            ),
          ),
        ),
      );
    }
  }

  WalletModel? _walletOfType(WalletType type) {
    for (final wallet in WalletService.instance.currentUserWallets) {
      if (wallet.type == type) return wallet;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLanguage.instance,
        WalletService.instance,
        TransactionService.instance,
      ]),
      builder: (context, _) {
        final colors = context.finFlowColors;
        final transactions = TransactionService.instance;
        final cash = _walletOfType(WalletType.cash);
        final transfer = _walletOfType(WalletType.transfer);
        final cashBalance = cash == null
            ? 0
            : transactions.balanceByWallet(cash.id);
        final transferBalance = transfer == null
            ? 0
            : transactions.balanceByWallet(transfer.id);

        return Scaffold(
          backgroundColor: colors.pageBackground,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            backgroundColor: colors.pageBackground,
            foregroundColor: colors.primaryText,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: Text(
              AppStrings.choose('Money Sources', 'Nguồn tiền'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 14),
                child: NotificationBell(),
              ),
            ],
          ),
          body: _loading && cash == null && transfer == null
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            Responsive.w(context, 16),
                            Responsive.h(context, 10),
                            Responsive.w(context, 16),
                            Responsive.h(context, 16),
                          ),
                          children: [
                            _TotalBalanceCard(
                              amount: cashBalance + transferBalance,
                            ),
                            SizedBox(height: Responsive.h(context, 18)),
                            _MoneySourceCard(
                              key: const Key('cash-money-source-card'),
                              type: WalletType.cash,
                              currentBalance: cashBalance,
                              openingBalance: cash?.initialBalance ?? 0,
                              income: cash == null
                                  ? 0
                                  : transactions.incomeByWallet(cash.id),
                              expense: cash == null
                                  ? 0
                                  : transactions.expenseByWallet(cash.id),
                              onEdit: _adjustBalances,
                            ),
                            SizedBox(height: Responsive.h(context, 14)),
                            _MoneySourceCard(
                              key: const Key('transfer-money-source-card'),
                              type: WalletType.transfer,
                              currentBalance: transferBalance,
                              openingBalance: transfer?.initialBalance ?? 0,
                              income: transfer == null
                                  ? 0
                                  : transactions.incomeByWallet(transfer.id),
                              expense: transfer == null
                                  ? 0
                                  : transactions.expenseByWallet(transfer.id),
                              onEdit: _adjustBalances,
                            ),
                            SizedBox(height: Responsive.h(context, 14)),
                            _BalanceExplanation(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          Responsive.w(context, 16),
                          Responsive.h(context, 8),
                          Responsive.w(context, 16),
                          Responsive.h(context, 10),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: Responsive.h(context, 48),
                          child: FilledButton.icon(
                            key: const Key('adjust-opening-balances-button'),
                            onPressed: _adjustBalances,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF006B52),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: Text(
                              AppStrings.choose(
                                'Adjust Opening Balances',
                                'Điều chỉnh số dư ban đầu',
                              ),
                              style: const TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Container(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 18)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C006B52),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFE5F7F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF006B52),
              size: 19,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            AppStrings.choose('TOTAL BALANCE', 'TỔNG SỐ DƯ'),
            style: TextStyle(
              fontSize: Responsive.sp(context, 9),
              fontWeight: FontWeight.w600,
              letterSpacing: .45,
              color: colors.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatVnd(amount),
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: Responsive.sp(context, 24),
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppStrings.choose(
              'Across Cash and Transfer',
              'Bao gồm Tiền mặt và Chuyển khoản',
            ),
            style: TextStyle(
              fontSize: Responsive.sp(context, 10),
              color: colors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneySourceCard extends StatelessWidget {
  const _MoneySourceCard({
    super.key,
    required this.type,
    required this.currentBalance,
    required this.openingBalance,
    required this.income,
    required this.expense,
    required this.onEdit,
  });

  final WalletType type;
  final int currentBalance;
  final int openingBalance;
  final int income;
  final int expense;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    final isCash = type == WalletType.cash;
    final accent = isCash ? const Color(0xFF00A77D) : const Color(0xFF2878D0);
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 16)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C006B52),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isCash
                      ? const Color(0xFFE5F7F2)
                      : const Color(0xFFE7F1FB),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCash
                      ? Icons.payments_outlined
                      : Icons.account_balance_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCash
                          ? AppStrings.choose('Cash', 'Tiền mặt')
                          : AppStrings.choose('Transfer', 'Chuyển khoản'),
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 14),
                        fontWeight: FontWeight.w700,
                        color: colors.primaryText,
                      ),
                    ),
                    Text(
                      isCash
                          ? AppStrings.choose(
                              'Money you hold and spend directly',
                              'Tiền bạn giữ và chi tiêu trực tiếp',
                            )
                          : AppStrings.choose(
                              'Bank accounts and e-wallets',
                              'Tài khoản ngân hàng và ví điện tử',
                            ),
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 9),
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('${type.name}-edit-opening-balance'),
                onPressed: onEdit,
                style: IconButton.styleFrom(
                  backgroundColor: colors.elevatedSurface,
                ),
                icon: const Icon(Icons.edit_rounded, size: 17),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 12)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Responsive.w(context, 14)),
            decoration: BoxDecoration(
              color: colors.elevatedSurface.withValues(alpha: .62),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: colors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.choose('Current balance', 'Số dư hiện tại'),
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 9),
                    color: colors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatVnd(currentBalance),
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: Responsive.sp(context, 20),
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                SizedBox(height: Responsive.h(context, 8)),
                Row(
                  children: [
                    Text(
                      AppStrings.choose('Opening balance', 'Số dư ban đầu'),
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 10),
                        fontWeight: FontWeight.w500,
                        color: colors.secondaryText,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatVnd(openingBalance),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: Responsive.sp(context, 12),
                            fontWeight: FontWeight.w700,
                            color: colors.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(context, 12)),
          Row(
            children: [
              Expanded(child: _FlowMetric(income: true, amount: income)),
              Container(width: 1, height: 38, color: colors.divider),
              Expanded(child: _FlowMetric(income: false, amount: expense)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowMetric extends StatelessWidget {
  const _FlowMetric({required this.income, required this.amount});

  final bool income;
  final int amount;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        income ? Icons.south_rounded : Icons.north_rounded,
        size: 17,
        color: income ? const Color(0xFF00A77D) : const Color(0xFFBA1A1A),
      ),
      const SizedBox(width: 7),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.choose(
                income ? 'INCOME' : 'EXPENSE',
                income ? 'THU NHẬP' : 'CHI TIÊU',
              ),
              style: TextStyle(
                fontSize: Responsive.sp(context, 8),
                color: context.finFlowColors.secondaryText,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _formatVnd(amount),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: Responsive.sp(context, 11),
                  fontWeight: FontWeight.w600,
                  color: context.finFlowColors.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _BalanceExplanation extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? context.finFlowColors.elevatedSurface
          : const Color(0xFFE2F7EF),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 17,
          color: Color(0xFF006B52),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            AppStrings.choose(
              'Current balance is calculated from the opening balance and all recorded income and expenses.',
              'Số dư hiện tại được tính từ số dư ban đầu cùng toàn bộ khoản thu và chi đã ghi nhận.',
            ),
            style: TextStyle(
              fontSize: Responsive.sp(context, 10),
              height: 1.35,
              color: context.finFlowColors.secondaryText,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AdjustOpeningBalancesSheet extends StatefulWidget {
  const _AdjustOpeningBalancesSheet({
    required this.cashBalance,
    required this.transferBalance,
  });

  final int cashBalance;
  final int transferBalance;

  @override
  State<_AdjustOpeningBalancesSheet> createState() =>
      _AdjustOpeningBalancesSheetState();
}

class _AdjustOpeningBalancesSheetState
    extends State<_AdjustOpeningBalancesSheet> {
  late final TextEditingController _cashController;
  late final TextEditingController _transferController;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(
      text: _formatDigits(widget.cashBalance),
    );
    _transferController = TextEditingController(
      text: _formatDigits(widget.transferBalance),
    );
  }

  @override
  void dispose() {
    _cashController.dispose();
    _transferController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WalletService.instance.saveSystemWallets(
        cashInitialBalance: _parseAmount(_cashController.text),
        transferInitialBalance: _parseAmount(_transferController.text),
      );
      TransactionService.instance.notifyListeners();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Could not update balances. Please try again.',
              'Không thể cập nhật số dư. Vui lòng thử lại.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        0,
        Responsive.w(context, 20),
        MediaQuery.viewInsetsOf(context).bottom + Responsive.h(context, 18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.choose(
              'Adjust Opening Balances',
              'Điều chỉnh số dư ban đầu',
            ),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: Responsive.sp(context, 20),
              fontWeight: FontWeight.w700,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            AppStrings.choose(
              'Enter the amount available before your first FinFlow transaction.',
              'Nhập số tiền có sẵn trước giao dịch FinFlow đầu tiên.',
            ),
            style: TextStyle(
              fontSize: Responsive.sp(context, 12),
              height: 1.4,
              color: colors.secondaryText,
            ),
          ),
          SizedBox(height: Responsive.h(context, 16)),
          _BalanceInput(
            key: const Key('cash-opening-balance-input'),
            label: AppStrings.choose('Cash', 'Tiền mặt'),
            icon: Icons.payments_outlined,
            color: const Color(0xFF00A77D),
            controller: _cashController,
          ),
          SizedBox(height: Responsive.h(context, 14)),
          _BalanceInput(
            key: const Key('transfer-opening-balance-input'),
            label: AppStrings.choose('Transfer', 'Chuyển khoản'),
            icon: Icons.account_balance_rounded,
            color: const Color(0xFF2878D0),
            controller: _transferController,
          ),
          SizedBox(height: Responsive.h(context, 18)),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3A2221)
                  : const Color(0xFFFFF4F2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFBA1A1A),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.choose(
                      'Changing these values will recalculate your current total balance. Existing transactions will not be modified.',
                      'Thay đổi các giá trị này sẽ tính lại tổng số dư hiện tại. Các giao dịch đã có sẽ không bị chỉnh sửa.',
                    ),
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 11),
                      height: 1.45,
                      color: colors.negativeAmount,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(context, 20)),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(AppStrings.choose('Cancel', 'Hủy')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const Key('save-opening-balances-button'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: const Color(0xFF006B52),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    AppStrings.choose('Save Changes', 'Lưu thay đổi'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
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

class _BalanceInput extends StatelessWidget {
  const _BalanceInput({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.controller,
  });

  final String label;
  final IconData icon;
  final Color color;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: Responsive.sp(context, 12),
                fontWeight: FontWeight.w600,
                color: colors.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: const [_VndInputFormatter()],
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w600,
            color: colors.primaryText,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.elevatedSurface,
            suffixText: 'VND',
            suffixStyle: TextStyle(
              color: colors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _VndInputFormatter extends TextInputFormatter {
  const _VndInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formatted = _formatDigits(int.parse(normalized));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

int _parseAmount(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

String _formatDigits(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _formatVnd(int amount) {
  final sign = amount < 0 ? '-' : '';
  return '$sign${_formatDigits(amount)} VND';
}
