import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../models/transaction_category.dart';
import '../models/goal_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/wallet_service.dart';
import 'add_transaction_sheet.dart';
import 'goal_sheets.dart';
import 'widgets/goal_ui.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  const EditTransactionScreen({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String _selectedCategory;
  late DateTime _transactionDate;
  late bool _isExpense;
  String? _selectedWalletId;
  var _isFormatting = false;
  var _isSaving = false;
  var _isDeleting = false;

  Color get _accent =>
      _isExpense ? const Color(0xFFBA1A1A) : const Color(0xFF006C46);

  TextStyle get _labelStyle => TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: Responsive.sp(context, 10),
    letterSpacing: 0.8,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF5F6368),
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.transaction.name);
    _amountController = TextEditingController(
      text: _addCommas(widget.transaction.amount.abs().toString()),
    )..addListener(_formatAmount);
    final storedCategory = widget.transaction.category;
    final categoryExists =
        TransactionCategory.all.any(
          (category) => category.key == storedCategory,
        ) ||
        CustomCategoryStore.instance.findByKey(storedCategory) != null;
    _selectedCategory = categoryExists ? storedCategory : 'Other';
    _selectedWalletId = widget.transaction.walletId;
    _transactionDate = widget.transaction.date;
    _isExpense = widget.transaction.amount < 0;
    WalletService.instance.addListener(_onWalletsChanged);
    Future.microtask(() {
      ref
          .read(walletServiceProvider)
          .fetchWallets()
          .catchError((error) => debugPrint('fetchWallets error: $error'));
    });
  }

  @override
  void dispose() {
    WalletService.instance.removeListener(_onWalletsChanged);
    _amountController.removeListener(_formatAmount);
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onWalletsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletServiceProvider).currentUserWallets;
    final wallet = _walletById(wallets, _selectedWalletId);
    final category = _categoryForKey(_selectedCategory);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(context, 20),
                  Responsive.h(context, 20),
                  Responsive.w(context, 20),
                  Responsive.h(context, 30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TransactionTypeSelector(
                      isExpense: _isExpense,
                      onSelected: (value) => setState(() => _isExpense = value),
                    ),
                    SizedBox(height: Responsive.h(context, 22)),
                    Text(
                      AppStrings.choose('AMOUNT (VND)', 'SỐ TIỀN (VND)'),
                      style: _labelStyle,
                    ),
                    SizedBox(height: Responsive.h(context, 4)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('edit_amount_field'),
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            cursorColor: _accent,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: Responsive.sp(context, 44),
                              fontWeight: FontWeight.w700,
                              color: _accent,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: _accent.withValues(alpha: 0.28),
                              ),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xFFC3C7CF),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: _accent,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: Responsive.w(context, 6),
                                vertical: Responsive.h(context, 8),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: Responsive.w(context, 8),
                            bottom: Responsive.h(context, 18),
                          ),
                          child: Text(
                            'VND',
                            style: _labelStyle.copyWith(
                              color: _accent.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(context, 18)),
                    _buildSelectionField(
                      fieldKey: const Key('edit_category_field'),
                      label: AppStrings.choose('CATEGORY', 'DANH MỤC'),
                      value: AppStrings.categoryName(category.label),
                      leading: category.buildIcon(color: _accent, size: 20),
                      highlighted: true,
                      onTap: _showCategorySelection,
                    ),
                    SizedBox(height: Responsive.h(context, 12)),
                    _buildSelectionField(
                      fieldKey: const Key('edit_source_field'),
                      label: AppStrings.choose(
                        'PAYMENT METHOD',
                        'PHƯƠNG THỨC THANH TOÁN',
                      ),
                      value: _sourceName(wallet),
                      leading: wallet == null
                          ? Icon(
                              Icons.account_balance_rounded,
                              color: _accent,
                              size: 22,
                            )
                          : _walletLogo(wallet),
                      onTap: () => _showSourceSelection(wallets),
                    ),
                    SizedBox(height: Responsive.h(context, 12)),
                    _buildSelectionField(
                      label: AppStrings.choose('DATE', 'NGÀY'),
                      value: _formatDate(_transactionDate),
                      leading: Icon(
                        Icons.calendar_today_outlined,
                        color: _accent,
                        size: 21,
                      ),
                      trailing: const Icon(
                        Icons.calendar_month_outlined,
                        size: 19,
                      ),
                      onTap: _pickDate,
                    ),
                    SizedBox(height: Responsive.h(context, 12)),
                    _buildNameField(),
                    SizedBox(height: Responsive.h(context, 18)),
                    FilledButton(
                      key: const Key('edit_save_button'),
                      onPressed: _isSaving || _isDeleting ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                        minimumSize: Size.fromHeight(Responsive.h(context, 56)),
                        shape: const StadiumBorder(),
                        elevation: 7,
                        shadowColor: _accent.withValues(alpha: 0.35),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppStrings.choose(
                                'Update Transaction',
                                'Cập nhật giao dịch',
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: Responsive.h(context, 64),
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 8)),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCFF),
        border: Border(bottom: BorderSide(color: Color(0xFFC3C7CF))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: AppStrings.choose('Back', 'Quay lại'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF43474E),
              ),
            ),
          ),
          Text(
            AppStrings.editTransaction,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: Responsive.sp(context, 18),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1C1E),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: AppStrings.choose('Delete transaction', 'Xóa giao dịch'),
              onPressed: _isSaving || _isDeleting ? null : _delete,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.coral,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionField({
    Key? fieldKey,
    required String label,
    required String value,
    required Widget leading,
    required VoidCallback onTap,
    Widget? trailing,
    bool highlighted = false,
  }) {
    return Material(
      key: fieldKey,
      color: highlighted ? _accent.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(minHeight: Responsive.h(context, 72)),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 16),
            vertical: Responsive.h(context, 11),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted
                  ? _accent.withValues(alpha: 0.55)
                  : const Color(0xFFC3C7CF),
              width: highlighted ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 7,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(width: 30, child: Center(child: leading)),
              SizedBox(width: Responsive.w(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: _labelStyle),
                    SizedBox(height: Responsive.h(context, 3)),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 15),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1C1E),
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF5F6368),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
      constraints: BoxConstraints(minHeight: Responsive.h(context, 72)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 16),
        vertical: Responsive.h(context, 8),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC3C7CF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded, color: _accent, size: 24),
          SizedBox(width: Responsive.w(context, 12)),
          Expanded(
            child: TextField(
              key: const Key('edit_name_field'),
              controller: _nameController,
              cursorColor: _accent,
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: Responsive.sp(context, 15),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: AppStrings.choose(
                  'TRANSACTION NAME',
                  'TÊN GIAO DỊCH',
                ),
                labelStyle: _labelStyle,
                hintText: AppStrings.choose('Enter a name', 'Nhập tên'),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletLogo(WalletModel wallet) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Image.asset(
        wallet.logoAssetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(_walletIcon(wallet.type), color: wallet.brandColor, size: 22),
      ),
    );
  }

  Future<void> _showCategorySelection() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: TransactionCategorySelectionSheet(initialKey: _selectedCategory),
      ),
    );
    if (result != null && mounted) setState(() => _selectedCategory = result);
  }

  Future<void> _showSourceSelection(List<WalletModel> wallets) async {
    final result = await showModalBottomSheet<WalletModel>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: _EditSourceSelectionSheet(
          wallets: wallets,
          initialWalletId: _selectedWalletId,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedWalletId = result.id);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _transactionDate = picked);
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showMessage(AppStrings.pleaseEnterValidAmount);
      return;
    }
    if (_selectedWalletId == null) {
      _showMessage(
        AppStrings.choose(
          'Please select a payment method',
          'Vui lòng chọn phương thức thanh toán',
        ),
      );
      return;
    }
    final signedAmount = amount * (_isExpense ? -1 : 1);
    final goalService = ref.read(goalServiceProvider);
    final transactionService = ref.read(transactionServiceProvider);
    setState(() => _isSaving = true);
    try {
      // Calculate against the same fresh snapshot the RPC will use. Stale goal
      // entries or wallet balances can otherwise understate the real shortfall.
      await Future.wait([
        transactionService.fetchTransactions(),
        goalService.fetchGoals(),
        ref.read(walletServiceProvider).fetchWallets(),
      ]);
    } catch (error) {
      if (mounted) _showMessage('$error');
      return;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (!mounted) return;
    final linkedByGoal = <String, int>{};
    for (final entry in goalService.entries.where(
      (entry) =>
          entry.sourceTransactionId == widget.transaction.id &&
          entry.amount > 0 &&
          (entry.entryType == 'automatic_allocation' ||
              entry.entryType == 'completion_transfer'),
    )) {
      linkedByGoal.update(
        entry.goalId,
        (amount) => amount + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    final availableByGoal = <String, int>{
      for (final goal in goalService.goals)
        goal.id: (goal.allocatedAmount - (linkedByGoal[goal.id] ?? 0)).clamp(
          0,
          1 << 62,
        ),
    };
    final actualAfter =
        transactionService.totalBalance -
        widget.transaction.amount +
        signedAmount;
    final allocatedAfter = availableByGoal.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );
    final shortfall = (allocatedAfter - actualAfter).clamp(0, 1 << 62);
    if (shortfall > allocatedAfter) {
      _showMessage(
        AppStrings.choose(
          'This change would make your total balance negative by ${formatVnd(-actualAfter)} VND. Increase the income amount before saving.',
          'Thay đổi này sẽ làm tổng số dư âm ${formatVnd(-actualAfter)} VND. Hãy tăng số tiền thu nhập trước khi lưu.',
        ),
      );
      return;
    }
    var goalWithdrawals = <String, int>{};
    if (shortfall > 0 &&
        goalService.settings.expenseShortfallPolicy ==
            ExpenseShortfallPolicy.askEachTime) {
      final selected = await ExpenseGoalWithdrawalSheet.show(
        context,
        shortfall: shortfall,
        availableByGoal: availableByGoal,
        explanation: signedAmount > 0
            ? AppStrings.choose(
                'This income change requires ${formatVnd(shortfall)} VND to be released from goal allocations. Amounts shown already exclude allocations linked to this transaction.',
                'Thay đổi thu nhập này cần giải phóng ${formatVnd(shortfall)} VND từ tiền phân bổ mục tiêu. Số tiền hiển thị đã loại trừ phần phân bổ liên kết với giao dịch này.',
              )
            : null,
        primaryActionLabel: signedAmount > 0
            ? AppStrings.choose('Continue with Changes', 'Tiếp tục thay đổi')
            : AppStrings.choose(
                'Continue with Expense',
                'Tiếp tục với khoản chi',
              ),
      );
      if (selected == null || !mounted) return;
      goalWithdrawals = selected;
    }
    setState(() => _isSaving = true);
    try {
      final name = _nameController.text.trim();
      await ref
          .read(transactionServiceProvider)
          .update(
            TransactionModel(
              id: widget.transaction.id,
              userId: widget.transaction.userId,
              name: name.isEmpty ? _selectedCategory : name,
              category: _selectedCategory,
              amount: signedAmount,
              date: _transactionDate,
              walletId: _selectedWalletId,
            ),
            goalWithdrawals: goalWithdrawals,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.choose('Delete transaction?', 'Xóa giao dịch?')),
        content: Text(
          AppStrings.choose(
            'This action cannot be undone.',
            'Không thể hoàn tác thao tác này.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppStrings.choose('Delete', 'Xóa'),
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      await ref.read(transactionServiceProvider).delete(widget.transaction.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _formatAmount() {
    if (_isFormatting) return;
    _isFormatting = true;
    final digits = _amountController.text
        .replaceAll(',', '')
        .replaceAll(RegExp(r'\D'), '');
    final formatted = digits.isEmpty ? '' : _addCommas(digits);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormatting = false;
  }

  TransactionCategory _categoryForKey(String key) {
    final custom = CustomCategoryStore.instance.findByKey(key);
    if (custom != null) {
      return TransactionCategory(
        key: custom.name,
        label: custom.name,
        icon: custom.iconData,
        color: custom.color,
      );
    }
    return TransactionCategory.fromKey(key);
  }

  WalletModel? _walletById(List<WalletModel> wallets, String? id) {
    if (id == null) return null;
    for (final wallet in wallets) {
      if (wallet.id == id) return wallet;
    }
    return null;
  }

  String _sourceName(WalletModel? wallet) {
    if (wallet == null) {
      return AppStrings.choose(
        'Select payment method',
        'Chọn phương thức thanh toán',
      );
    }
    return switch (wallet.name) {
      'Cash' => AppStrings.choose('Cash', 'Tiền mặt'),
      'Transfer' => AppStrings.choose('Transfer', 'Chuyển khoản'),
      _ => wallet.name,
    };
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day/${value.year}';
  }

  static String _addCommas(String digits) => digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TransactionTypeSelector extends StatelessWidget {
  const _TransactionTypeSelector({
    required this.isExpense,
    required this.onSelected,
  });

  final bool isExpense;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = isExpense
        ? const Color(0xFFBA1A1A)
        : const Color(0xFF006C46);
    return Container(
      height: Responsive.h(context, 48),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E9EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _item(
            context,
            AppStrings.choose('INCOME', 'THU NHẬP'),
            false,
            !isExpense,
            accent,
          ),
          _item(
            context,
            AppStrings.choose('EXPENSE', 'CHI TIÊU'),
            true,
            isExpense,
            accent,
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String label,
    bool value,
    bool active,
    Color accent,
  ) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        child: InkWell(
          onTap: () => onSelected(value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: Responsive.sp(context, 10),
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF7B8188),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditSourceSelectionSheet extends StatefulWidget {
  const _EditSourceSelectionSheet({
    required this.wallets,
    required this.initialWalletId,
  });

  final List<WalletModel> wallets;
  final String? initialWalletId;

  @override
  State<_EditSourceSelectionSheet> createState() =>
      _EditSourceSelectionSheetState();
}

class _EditSourceSelectionSheetState extends State<_EditSourceSelectionSheet> {
  String? _selectedWalletId;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC3C7CF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.choose(
                          'Select Payment Method',
                          'Chọn phương thức thanh toán',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: widget.wallets.isEmpty
                    ? Center(
                        child: Text(
                          AppStrings.choose(
                            'No payment methods available',
                            'Không có phương thức thanh toán',
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        children: [
                          _section(
                            AppStrings.choose(
                              'PAYMENT METHOD',
                              'PHƯƠNG THỨC THANH TOÁN',
                            ),
                            WalletType.cash,
                          ),
                          _section('', WalletType.transfer),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: FilledButton(
                  onPressed: _selectedWalletId == null ? null : _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: const Color(0xFF002112),
                    minimumSize: const Size.fromHeight(54),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    AppStrings.choose('Apply Selection', 'Áp dụng lựa chọn'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, WalletType type) {
    final wallets = widget.wallets
        .where((wallet) => wallet.type == type)
        .toList(growable: false);
    if (wallets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 7),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                letterSpacing: 0.8,
                color: Color(0xFF5F6368),
              ),
            ),
          ),
        ...wallets.map(_walletRow),
      ],
    );
  }

  Widget _walletRow(WalletModel wallet) {
    final selected = wallet.id == _selectedWalletId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () => setState(() => _selectedWalletId = wallet.id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E4E2)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: wallet.brandColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  wallet.logoAssetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      Icon(_walletIcon(wallet.type), color: wallet.brandColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  switch (wallet.name) {
                    'Cash' => AppStrings.choose('Cash', 'Tiền mặt'),
                    'Transfer' => AppStrings.choose('Transfer', 'Chuyển khoản'),
                    _ => wallet.name,
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? AppColors.primaryGreen
                    : const Color(0xFF1A1C1E),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _apply() {
    for (final wallet in widget.wallets) {
      if (wallet.id == _selectedWalletId) {
        Navigator.of(context).pop(wallet);
        return;
      }
    }
  }
}

IconData _walletIcon(WalletType type) => switch (type) {
  WalletType.cash => Icons.payments_outlined,
  WalletType.transfer => Icons.swap_horiz_rounded,
};
