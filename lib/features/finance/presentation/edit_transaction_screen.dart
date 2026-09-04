import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/finflow_action_icon.dart';
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
    _isExpense = widget.transaction.amount < 0;
    final storedCategory = widget.transaction.category;
    final categoryExists =
        TransactionCategory.containsKey(storedCategory) ||
        CustomCategoryStore.instance.findByKey(storedCategory) != null;
    _selectedCategory = categoryExists
        ? TransactionCategory.fromKey(storedCategory).key
        : (_isExpense ? 'Other' : 'Other Income');
    _selectedWalletId = widget.transaction.walletId;
    _transactionDate = widget.transaction.date;
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
      backgroundColor: const Color(0xFFF1FAF6),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(context, 16),
                  Responsive.h(context, 16),
                  Responsive.w(context, 16),
                  MediaQuery.viewInsetsOf(context).bottom +
                      Responsive.h(context, 24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TransactionTypeSelector(
                      isExpense: _isExpense,
                      onSelected: _setTransactionType,
                    ),
                    SizedBox(height: Responsive.h(context, 16)),
                    Text(
                      AppStrings.choose('AMOUNT', 'SỐ TIỀN'),
                      style: _labelStyle,
                    ),
                    SizedBox(height: Responsive.h(context, 8)),
                    _buildAmountCard(),
                    SizedBox(height: Responsive.h(context, 22)),
                    Text(
                      AppStrings.choose(
                        'PAYMENT METHOD',
                        'PHƯƠNG THỨC THANH TOÁN',
                      ),
                      style: _labelStyle,
                    ),
                    SizedBox(height: Responsive.h(context, 10)),
                    Row(
                      key: const Key('edit_source_field'),
                      children: [
                        Expanded(
                          child: _buildPaymentMethodCard(
                            wallets: wallets,
                            type: WalletType.cash,
                            label: AppStrings.choose('Cash', 'Tiền mặt'),
                            icon: Icons.payments_outlined,
                            selected: wallet?.type == WalletType.cash,
                          ),
                        ),
                        SizedBox(width: Responsive.w(context, 10)),
                        Expanded(
                          child: _buildPaymentMethodCard(
                            wallets: wallets,
                            type: WalletType.transfer,
                            label: AppStrings.choose(
                              'Transfer',
                              'Chuyển khoản',
                            ),
                            icon: Icons.account_balance_outlined,
                            selected: wallet?.type == WalletType.transfer,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(context, 24)),
                    Text(
                      AppStrings.choose(
                        'TRANSACTION DETAILS',
                        'CHI TIẾT GIAO DỊCH',
                      ),
                      style: _labelStyle,
                    ),
                    SizedBox(height: Responsive.h(context, 10)),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDE8E3)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14004736),
                            blurRadius: 18,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildSelectionField(
                            fieldKey: const Key('edit_category_field'),
                            label: AppStrings.choose('CATEGORY', 'DANH MỤC'),
                            value: AppStrings.categoryName(category.label),
                            leading: _detailIcon(
                              category.buildIcon(color: _accent, size: 19),
                            ),
                            onTap: _showCategorySelection,
                            embedded: true,
                          ),
                          const Divider(
                            height: 1,
                            indent: 62,
                            color: Color(0xFFDDE8E3),
                          ),
                          _buildSelectionField(
                            label: AppStrings.choose('DATE', 'NGÀY'),
                            value: _formatDate(_transactionDate),
                            leading: _detailIcon(
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: Color(0xFF3F6FE5),
                                size: 18,
                              ),
                              background: const Color(0xFFE8F0FF),
                            ),
                            trailing: const Icon(
                              Icons.calendar_month_outlined,
                              size: 19,
                              color: Color(0xFF007C61),
                            ),
                            onTap: _pickDate,
                            embedded: true,
                          ),
                          const Divider(
                            height: 1,
                            indent: 62,
                            color: Color(0xFFDDE8E3),
                          ),
                          _buildNameField(embedded: true),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 24)),
                    FilledButton(
                      key: const Key('edit_save_button'),
                      onPressed: _isSaving || _isDeleting ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF007C61),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(
                          0xFF007C61,
                        ).withValues(alpha: 0.5),
                        minimumSize: Size.fromHeight(Responsive.h(context, 56)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 5,
                        shadowColor: const Color(0x33004736),
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
                                fontFamily: 'Hanken Grotesk',
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
      height: Responsive.h(context, 52),
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 10)),
      color: const Color(0xFFF1FAF6),
      child: Row(
        children: [
          IconButton(
            tooltip: AppStrings.choose('Back', 'Quay lại'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF43474E),
            ),
          ),
          Expanded(
            child: Text(
              AppStrings.editTransaction,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: Responsive.sp(context, 22),
                fontWeight: FontWeight.w700,
                color: AppColors.deepEmerald,
              ),
            ),
          ),
          _isDeleting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : PopupMenuButton<String>(
                  tooltip: AppStrings.choose('More options', 'Tùy chọn khác'),
                  enabled: !_isSaving,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF43474E),
                  ),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (value) {
                    if (value == 'delete') _delete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          const FinFlowTrashIcon(
                            color: AppColors.coral,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppStrings.choose(
                              'Delete transaction',
                              'Xóa giao dịch',
                            ),
                            style: const TextStyle(
                              color: AppColors.coral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      constraints: BoxConstraints(minHeight: Responsive.h(context, 104)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 18),
        vertical: Responsive.h(context, 12),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE8E3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16004736),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              key: const Key('edit_amount_field'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              cursorColor: _accent,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: Responsive.sp(context, 36),
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: _accent.withValues(alpha: 0.3)),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'VND',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required List<WalletModel> wallets,
    required WalletType type,
    required String label,
    required IconData icon,
    required bool selected,
  }) {
    const green = Color(0xFF007C61);
    return Material(
      color: selected ? const Color(0xFFE9F7F2) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: () => _selectWalletType(wallets, type),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          constraints: BoxConstraints(minHeight: Responsive.h(context, 64)),
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 13)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? green : const Color(0xFFDDE8E3),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10004736),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F4EF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: green),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF263831),
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, size: 18, color: green),
            ],
          ),
        ),
      ),
    );
  }

  void _selectWalletType(List<WalletModel> wallets, WalletType type) {
    final matches = wallets.where(
      (wallet) => wallet.type == type && wallet.isActive,
    );
    if (matches.isEmpty) {
      _showSourceSelection(wallets);
      return;
    }
    setState(() => _selectedWalletId = matches.first.id);
  }

  Widget _detailIcon(
    Widget icon, {
    Color background = const Color(0xFFE3F4EF),
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Center(child: icon),
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
    bool embedded = false,
  }) {
    return Material(
      key: fieldKey,
      color: embedded
          ? Colors.transparent
          : highlighted
          ? _accent.withValues(alpha: 0.06)
          : Colors.white,
      borderRadius: BorderRadius.circular(embedded ? 0 : 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(embedded ? 0 : 12),
        child: Container(
          constraints: BoxConstraints(minHeight: Responsive.h(context, 72)),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 16),
            vertical: Responsive.h(context, 11),
          ),
          decoration: embedded
              ? null
              : BoxDecoration(
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

  Widget _buildNameField({bool embedded = false}) {
    return Container(
      constraints: BoxConstraints(minHeight: Responsive.h(context, 72)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 16),
        vertical: Responsive.h(context, 8),
      ),
      decoration: embedded
          ? null
          : BoxDecoration(
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
          _detailIcon(Icon(Icons.edit_note_rounded, color: _accent, size: 20)),
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

  Future<void> _showCategorySelection() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: TransactionCategorySelectionSheet(
          initialKey: _selectedCategory,
          isIncome: !_isExpense,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _selectedCategory = result);
  }

  void _setTransactionType(bool isExpense) {
    final selected = TransactionCategory.resolve(_selectedCategory);
    setState(() {
      _isExpense = isExpense;
      final requiredType = isExpense
          ? TransactionCategoryType.expense
          : TransactionCategoryType.income;
      if (selected.type != requiredType) {
        _selectedCategory = isExpense ? 'Food' : 'Salary';
      }
    });
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
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate.isAfter(today) ? today : _transactionDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(
        () => _transactionDate = TransactionModel.withCalendarDate(
          picked,
          _transactionDate,
        ),
      );
    }
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
