import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../providers/transaction_provider.dart';
import 'widgets/goal_ui.dart';

class AllocateMoneySheet extends ConsumerStatefulWidget {
  const AllocateMoneySheet({
    super.key,
    this.initialGoal,
    required this.allowGoalSelection,
  });

  final GoalModel? initialGoal;
  final bool allowGoalSelection;

  static Future<void> show(
    BuildContext context, {
    GoalModel? initialGoal,
    bool allowGoalSelection = false,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      top: false,
      child: AllocateMoneySheet(
        initialGoal: initialGoal,
        allowGoalSelection: allowGoalSelection,
      ),
    ),
  );

  @override
  ConsumerState<AllocateMoneySheet> createState() => _AllocateMoneySheetState();
}

class _AllocateMoneySheetState extends ConsumerState<AllocateMoneySheet> {
  final _controller = TextEditingController();
  GoalModel? _goal;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _goal = widget.initialGoal;
    _controller.addListener(_validate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _goal ??= ref.read(goalServiceProvider).activeGoals.firstOrNull;
  }

  @override
  void dispose() {
    _controller.removeListener(_validate);
    _controller.dispose();
    super.dispose();
  }

  int get _amount => _parseAmount(_controller.text);

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(goalServiceProvider);
    final balance = ref.watch(transactionServiceProvider).totalBalance;
    final available = service.availableForGoals(balance);
    final goal = _goal == null ? null : service.byId(_goal!.id) ?? _goal;
    final after = goal == null
        ? 0
        : (goal.allocatedAmount + _amount).clamp(0, goal.targetAmount);
    final progress = goal == null || goal.targetAmount == 0
        ? 0.0
        : after / goal.targetAmount;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Handle(),
              _SheetTitle(
                title: AppStrings.choose('Allocate Money', 'Phân bổ tiền'),
                onClose: () => Navigator.pop(context),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (goal == null)
                        _InfoPanel(
                          text: AppStrings.choose(
                            'Create an active goal before allocating money.',
                            'Hãy tạo một mục tiêu đang hoạt động trước khi phân bổ tiền.',
                          ),
                        )
                      else ...[
                        _GoalSelector(
                          goal: goal,
                          showChevron: widget.allowGoalSelection,
                          onTap: widget.allowGoalSelection ? _chooseGoal : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.choose(
                            'Allocation Amount',
                            'Số tiền phân bổ',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: goalMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _controller,
                          autofocus: false,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _AmountFormatter(),
                          ],
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            color: goalDark,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            suffixText: 'VND',
                            filled: true,
                            fillColor: goalMint,
                            errorText: _error,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryTile(
                                label: AppStrings.choose(
                                  'Available for goals',
                                  'Có thể phân bổ cho mục tiêu',
                                ),
                                value: '${formatVnd(available)} VND',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SummaryTile(
                                label: AppStrings.choose(
                                  'Remaining to target',
                                  'Còn thiếu để đạt mục tiêu',
                                ),
                                value: '${formatVnd(goal.remainingAmount)} VND',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          AppStrings.choose(
                            'Quick allocation',
                            'Phân bổ nhanh',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickButton(
                                label: '25%',
                                onTap: () => _setAmount(
                                  (goal.remainingAmount * .25).round().clamp(
                                    0,
                                    available,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickButton(
                                label: '50%',
                                onTap: () => _setAmount(
                                  (goal.remainingAmount * .5).round().clamp(
                                    0,
                                    available,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickButton(
                                label: AppStrings.choose(
                                  'Fill goal',
                                  'Đủ mục tiêu',
                                ),
                                onTap: () => _setAmount(
                                  goal.remainingAmount.clamp(0, available),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppStrings.choose(
                                'After allocation',
                                'Sau khi phân bổ',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              AppStrings.choose(
                                '${(progress * 100).round()}% achieved',
                                'Đã đạt ${(progress * 100).round()}%',
                              ),
                              style: const TextStyle(
                                color: goalSuccess,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${formatVnd(after)} / ${formatVnd(goal.targetAmount)} VND',
                          style: const TextStyle(
                            fontSize: 12,
                            color: goalMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GoalProgressBar(value: progress),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.choose(
                            'Available afterward: ${formatVnd((available - _amount).clamp(0, available))} VND',
                            'Khả dụng sau đó: ${formatVnd((available - _amount).clamp(0, available))} VND',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: goalPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: FilledButton(
                  style: goalFilledButtonStyle(),
                  onPressed:
                      goal == null || _saving || _error != null || _amount <= 0
                      ? null
                      : () => _confirm(goal),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          AppStrings.choose(
                            'Confirm Allocation',
                            'Xác nhận phân bổ',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _validate() {
    if (!mounted) return;
    final service = ref.read(goalServiceProvider);
    final balance = ref.read(transactionServiceProvider).totalBalance;
    final available = service.availableForGoals(balance);
    final goal = _goal;
    final amount = _amount;
    setState(() {
      _error = amount == 0
          ? (_controller.text.isEmpty
                ? null
                : AppStrings.choose(
                    'Enter an amount greater than zero',
                    'Nhập số tiền lớn hơn 0',
                  ))
          : amount < 0
          ? AppStrings.choose(
              'Amount cannot be negative',
              'Số tiền không thể âm',
            )
          : amount > available
          ? AppStrings.choose(
              'Amount exceeds available funds',
              'Số tiền vượt quá số dư khả dụng',
            )
          : goal != null && amount > goal.remainingAmount
          ? AppStrings.choose(
              'Amount exceeds the remaining target',
              'Số tiền vượt quá phần còn thiếu của mục tiêu',
            )
          : null;
    });
  }

  void _setAmount(int amount) {
    _controller.text = formatVnd(amount);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  Future<void> _chooseGoal() async {
    final goals = ref.read(goalServiceProvider).activeGoals;
    final selected = await showDialog<GoalModel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppStrings.choose('Select a Goal', 'Chọn mục tiêu')),
        children: goals
            .map(
              (goal) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, goal),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: GoalIconTile(category: goal.category),
                  title: Text(goal.name),
                  subtitle: Text(
                    '${formatVnd(goal.allocatedAmount)} / ${formatVnd(goal.targetAmount)} VND',
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      setState(() => _goal = selected);
      _validate();
    }
  }

  Future<void> _confirm(GoalModel goal) async {
    setState(() => _saving = true);
    try {
      final navigator = Navigator.of(context);
      final completed = await ref
          .read(goalServiceProvider)
          .allocate(goal.id, _amount);
      if (!mounted) return;
      navigator.pop();
      if (completed) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (navigator.mounted) {
          final action = await GoalCompletionDialog.show(
            navigator.context,
            goalId: goal.id,
          );
          if (navigator.mounted) {
            if (action == GoalCompletionAction.viewGoal &&
                widget.allowGoalSelection) {
              navigator.pushNamed(AppRoutes.goalDetails, arguments: goal.id);
            } else if (action == GoalCompletionAction.editAllocation) {
              navigator.pushNamed(AppRoutes.editGoal, arguments: goal.id);
            }
          }
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = _goalErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class WithdrawMoneySheet extends ConsumerStatefulWidget {
  const WithdrawMoneySheet({super.key, required this.goal});
  final GoalModel goal;

  static Future<void> show(BuildContext context, {required GoalModel goal}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            SafeArea(top: false, child: WithdrawMoneySheet(goal: goal)),
      );

  @override
  ConsumerState<WithdrawMoneySheet> createState() => _WithdrawMoneySheetState();
}

class _WithdrawMoneySheetState extends ConsumerState<WithdrawMoneySheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _showNote = false;
  bool _saving = false;
  String? _error;

  int get _amount => _parseAmount(_amountController.text);

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_validate);
  }

  @override
  void dispose() {
    _amountController.removeListener(_validate);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(goalServiceProvider);
    final goal = service.byId(widget.goal.id) ?? widget.goal;
    final balance = ref.watch(transactionServiceProvider).totalBalance;
    final available = service.availableForGoals(balance);
    final after = (goal.allocatedAmount - _amount).clamp(
      0,
      goal.allocatedAmount,
    );
    final progress = goal.targetAmount == 0 ? 0.0 : after / goal.targetAmount;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Handle(),
              _SheetTitle(
                title: AppStrings.choose('Withdraw Money', 'Rút tiền'),
                onClose: () => Navigator.pop(context),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GoalSelector(goal: goal, showChevron: false),
                      if (goal.isProtected) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              size: 16,
                              color: goalPrimary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                AppStrings.choose(
                                  'Protected goal — manual withdrawal is still allowed.',
                                  'Mục tiêu được bảo vệ — vẫn có thể rút tiền thủ công.',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: goalMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _AmountFormatter(),
                        ],
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: goalError,
                        ),
                        decoration: InputDecoration(
                          labelText: AppStrings.choose(
                            'Withdrawal Amount',
                            'Số tiền rút',
                          ),
                          suffixText: 'VND',
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: goalOutline.withValues(alpha: .3),
                          ),
                        ),
                        child: Column(
                          children: [
                            _BalanceLine(
                              label: AppStrings.choose(
                                'Currently allocated',
                                'Đang phân bổ',
                              ),
                              value: '${formatVnd(goal.allocatedAmount)} VND',
                            ),
                            const SizedBox(height: 10),
                            _BalanceLine(
                              label: AppStrings.choose(
                                'Available after withdrawal',
                                'Khả dụng sau khi rút',
                              ),
                              value: '${formatVnd(available + _amount)} VND',
                              emphasize: true,
                            ),
                            const Divider(height: 22),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppStrings.choose(
                                  'Withdrawn money will return to your available funds.',
                                  'Tiền đã rút sẽ trở lại số dư khả dụng.',
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: goalMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _QuickChip(
                              label: AppStrings.choose(
                                'Withdraw 25%',
                                'Rút 25%',
                              ),
                              onTap: () => _setAmount(
                                (goal.allocatedAmount * .25).round(),
                              ),
                            ),
                            _QuickChip(
                              label: AppStrings.choose(
                                'Withdraw 50%',
                                'Rút 50%',
                              ),
                              onTap: () => _setAmount(
                                (goal.allocatedAmount * .5).round(),
                              ),
                            ),
                            _QuickChip(
                              label: AppStrings.choose(
                                'Withdraw all',
                                'Rút tất cả',
                              ),
                              onTap: () => _setAmount(goal.allocatedAmount),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _showNote = !_showNote),
                        icon: Icon(
                          _showNote ? Icons.remove_rounded : Icons.add_rounded,
                        ),
                        label: Text(
                          _showNote
                              ? AppStrings.choose('Remove note', 'Xóa ghi chú')
                              : AppStrings.choose('Add a note', 'Thêm ghi chú'),
                        ),
                      ),
                      if (_showNote)
                        TextField(
                          controller: _noteController,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: AppStrings.choose(
                              'Reason (Optional)',
                              'Lý do (Tùy chọn)',
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: goalMint.withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppStrings.choose(
                                    'Goal balance after withdrawal',
                                    'Số dư mục tiêu sau khi rút',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: goalDark,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: goalDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${formatVnd(after)} / ${formatVnd(goal.targetAmount)} VND',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: goalPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GoalProgressBar(value: progress),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: FilledButton(
                  style: goalFilledButtonStyle(),
                  onPressed: _saving || _amount <= 0 || _error != null
                      ? null
                      : () => _confirm(goal),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          AppStrings.choose(
                            'Confirm Withdrawal',
                            'Xác nhận rút tiền',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _validate() {
    if (!mounted) return;
    setState(() {
      _error = _amount == 0
          ? (_amountController.text.isEmpty
                ? null
                : AppStrings.choose(
                    'Enter an amount greater than zero',
                    'Nhập số tiền lớn hơn 0',
                  ))
          : _amount > widget.goal.allocatedAmount
          ? AppStrings.choose(
              'Amount exceeds the goal balance',
              'Số tiền vượt quá số dư mục tiêu',
            )
          : null;
    });
  }

  void _setAmount(int amount) {
    _amountController.text = formatVnd(amount);
    _amountController.selection = TextSelection.collapsed(
      offset: _amountController.text.length,
    );
  }

  Future<void> _confirm(GoalModel goal) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(goalServiceProvider)
          .withdraw(
            goal.id,
            _amount,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = _goalErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class GoalWithdrawalSettingsSheet extends ConsumerStatefulWidget {
  const GoalWithdrawalSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        const SafeArea(top: false, child: GoalWithdrawalSettingsSheet()),
  );

  @override
  ConsumerState<GoalWithdrawalSettingsSheet> createState() =>
      _GoalWithdrawalSettingsSheetState();
}

class _GoalWithdrawalSettingsSheetState
    extends ConsumerState<GoalWithdrawalSettingsSheet> {
  late ExpenseShortfallPolicy _policy;
  late List<GoalModel> _goals;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final service = ref.read(goalServiceProvider);
    _policy = service.settings.expenseShortfallPolicy;
    _goals = [...service.activeGoals]
      ..sort((a, b) => a.withdrawalPriority.compareTo(b.withdrawalPriority));
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .92,
      child: Column(
        children: [
          const _Handle(),
          _SheetTitle(
            title: AppStrings.choose(
              'Goal Withdrawal Settings',
              'Cài đặt rút tiền mục tiêu',
            ),
            onClose: () => Navigator.pop(context),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  AppStrings.choose(
                    'When an expense exceeds\nunallocated funds',
                    'Khi một khoản chi vượt quá\nsố dư chưa phân bổ',
                  ),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _PolicyCard(
                  selected: _policy == ExpenseShortfallPolicy.askEachTime,
                  title: AppStrings.choose('Ask Me Every Time', 'Luôn hỏi tôi'),
                  description: AppStrings.choose(
                    'Choose which goals to withdraw from before saving the expense.',
                    'Chọn mục tiêu để rút tiền trước khi lưu khoản chi.',
                  ),
                  onTap: () => setState(
                    () => _policy = ExpenseShortfallPolicy.askEachTime,
                  ),
                ),
                const SizedBox(height: 10),
                _PolicyCard(
                  selected: _policy == ExpenseShortfallPolicy.autoWithdraw,
                  title: AppStrings.choose(
                    'Withdraw Automatically',
                    'Rút tự động',
                  ),
                  description: AppStrings.choose(
                    'Withdraw from lower-priority goals first and skip protected goals.',
                    'Rút từ mục tiêu ưu tiên thấp trước và bỏ qua mục tiêu được bảo vệ.',
                  ),
                  onTap: () => setState(
                    () => _policy = ExpenseShortfallPolicy.autoWithdraw,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: goalMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppStrings.choose(
                          'This changes virtual goal allocations only. It does not move money between bank accounts.',
                          'Thao tác này chỉ thay đổi phân bổ mục tiêu ảo, không chuyển tiền giữa các tài khoản ngân hàng.',
                        ),
                        style: const TextStyle(fontSize: 10, color: goalMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.choose(
                    'Automatically Imported\nTransactions',
                    'Giao dịch nhập\ntự động',
                  ),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoPanel(
                  text: AppStrings.choose(
                    'REQUIRED FALLBACK     Withdraw automatically by priority\n\nImported bank transactions may not be able to wait for immediate user input.',
                    'PHƯƠNG ÁN DỰ PHÒNG BẮT BUỘC     Tự động rút theo mức ưu tiên\n\nGiao dịch ngân hàng được nhập có thể không thể chờ người dùng phản hồi ngay.',
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  AppStrings.choose('Withdrawal Priority', 'Ưu tiên rút tiền'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  AppStrings.choose(
                    'Drag to set which unprotected goal is used first.',
                    'Kéo để chọn mục tiêu không được bảo vệ sẽ được dùng trước.',
                  ),
                  style: const TextStyle(fontSize: 11, color: goalMuted),
                ),
                const SizedBox(height: 10),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _goals.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final goal = _goals.removeAt(oldIndex);
                      _goals.insert(newIndex, goal);
                    });
                  },
                  itemBuilder: (_, index) {
                    final goal = _goals[index];
                    return Container(
                      key: ValueKey(goal.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: goalSurfaceLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.drag_indicator_rounded,
                            color: goalMuted,
                          ),
                          const SizedBox(width: 8),
                          GoalIconTile(category: goal.category, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              goal.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (goal.isProtected)
                            const Icon(
                              Icons.lock_rounded,
                              color: goalMuted,
                              size: 18,
                            ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: goalMint,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: goalDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                style: goalFilledButtonStyle(),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(AppStrings.choose('Save Settings', 'Lưu cài đặt')),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(goalServiceProvider);
      await service.saveSettings(_policy);
      await service.reorderWithdrawalPriority(
        _goals.map((goal) => goal.id).toList(),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

enum GoalCompletionAction { done, viewGoal, editAllocation }

class GoalCompletionDialog extends ConsumerWidget {
  const GoalCompletionDialog({super.key, required this.goalId});
  final String goalId;

  static Future<GoalCompletionAction?> show(
    BuildContext context, {
    required String goalId,
  }) => showDialog<GoalCompletionAction>(
    context: context,
    builder: (_) => GoalCompletionDialog(goalId: goalId),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(goalServiceProvider).byId(goalId);
    if (goal == null) return const SizedBox.shrink();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: goalMint,
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: goalPrimary,
                size: 40,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              AppStrings.choose('Goal Completed!', 'Đã hoàn thành mục tiêu!'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(goal.name),
            const SizedBox(height: 18),
            Text(
              '${formatVnd(goal.targetAmount)} VND',
              style: const TextStyle(
                fontFamily: 'Manrope',
                color: goalDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              AppStrings.choose('✓ 100% achieved', '✓ Đã đạt 100%'),
              style: const TextStyle(fontSize: 11, color: goalMuted),
            ),
            const SizedBox(height: 20),
            _InfoPanel(
              text: goal.completionBehavior == GoalCompletionBehavior.redirect
                  ? AppStrings.choose(
                      'Automatic allocation has stopped for this goal. Future allocated income will be redirected to your selected next goal.',
                      'Phân bổ tự động cho mục tiêu này đã dừng. Thu nhập được phân bổ trong tương lai sẽ chuyển sang mục tiêu tiếp theo bạn đã chọn.',
                    )
                  : AppStrings.choose(
                      'Automatic allocation has stopped. Future income previously assigned to this goal will remain available.',
                      'Phân bổ tự động đã dừng. Phần thu nhập tương lai trước đây dành cho mục tiêu này sẽ được giữ ở số dư khả dụng.',
                    ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: goalFilledButtonStyle(),
              onPressed: () =>
                  Navigator.pop(context, GoalCompletionAction.viewGoal),
              child: Text(AppStrings.choose('View Goal', 'Xem mục tiêu')),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, GoalCompletionAction.done),
              child: Text(AppStrings.done),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, GoalCompletionAction.editAllocation);
              },
              child: Text(
                AppStrings.choose(
                  'CHANGE FUTURE ALLOCATION',
                  'THAY ĐỔI PHÂN BỔ TƯƠNG LAI',
                ),
                style: const TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseGoalWithdrawalSheet extends ConsumerStatefulWidget {
  const ExpenseGoalWithdrawalSheet({
    super.key,
    required this.shortfall,
    this.availableByGoal,
    this.explanation,
    this.primaryActionLabel = 'Continue with Expense',
  });

  final int shortfall;
  final Map<String, int>? availableByGoal;
  final String? explanation;
  final String primaryActionLabel;

  static Future<Map<String, int>?> show(
    BuildContext context, {
    required int shortfall,
    Map<String, int>? availableByGoal,
    String? explanation,
    String primaryActionLabel = 'Continue with Expense',
  }) => showModalBottomSheet<Map<String, int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      top: false,
      child: ExpenseGoalWithdrawalSheet(
        shortfall: shortfall,
        availableByGoal: availableByGoal,
        explanation: explanation,
        primaryActionLabel: primaryActionLabel,
      ),
    ),
  );

  @override
  ConsumerState<ExpenseGoalWithdrawalSheet> createState() =>
      _ExpenseGoalWithdrawalSheetState();
}

class _ExpenseGoalWithdrawalSheetState
    extends ConsumerState<ExpenseGoalWithdrawalSheet> {
  final _selected = <String>{};

  int _availableFor(GoalModel goal) =>
      (widget.availableByGoal?[goal.id] ?? goal.allocatedAmount).clamp(
        0,
        1 << 62,
      );

  Map<String, int> _withdrawalCaps(List<GoalModel> goals) {
    final result = <String, int>{};
    for (final goal in goals.where((goal) => _selected.contains(goal.id))) {
      // The amount is only a cap. Sending a high int64-safe cap makes the goal
      // id the user's actual choice while the RPC remains responsible for
      // reading its current balance and taking only the exact shortfall.
      result[goal.id] = 1 << 62;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(goalServiceProvider);
    final candidateGoals = widget.availableByGoal == null
        ? service.activeGoals
        : service.goals;
    final goals = candidateGoals
        .where((goal) => _availableFor(goal) > 0)
        .toList(growable: false);
    final withdrawalCaps = _withdrawalCaps(goals);
    final selectedCapacity = goals
        .where((goal) => _selected.contains(goal.id))
        .fold<int>(0, (sum, goal) => sum + _availableFor(goal));
    final covered = selectedCapacity.clamp(0, widget.shortfall);
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Handle(),
            _SheetTitle(
              title: AppStrings.choose(
                'Choose Goals to Withdraw',
                'Chọn mục tiêu để rút tiền',
              ),
              onClose: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _InfoPanel(
                text:
                    widget.explanation ??
                    AppStrings.choose(
                      'This expense needs ${formatVnd(widget.shortfall)} VND from goal allocations. Protected goals can still be selected manually.',
                      'Khoản chi này cần ${formatVnd(widget.shortfall)} VND từ tiền đã phân bổ cho mục tiêu. Bạn vẫn có thể chọn thủ công mục tiêu được bảo vệ.',
                    ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: goals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final goal = goals[index];
                  final selected = _selected.contains(goal.id);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (value) => setState(() {
                      value == true
                          ? _selected.add(goal.id)
                          : _selected.remove(goal.id);
                    }),
                    secondary: GoalIconTile(category: goal.category),
                    title: Row(
                      children: [
                        Expanded(child: Text(goal.name)),
                        if (goal.isProtected)
                          const Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: goalMuted,
                          ),
                      ],
                    ),
                    subtitle: Text(
                      AppStrings.choose(
                        '${formatVnd(_availableFor(goal))} VND allocated',
                        'Đã phân bổ ${formatVnd(_availableFor(goal))} VND',
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected ? goalPrimary : goalOutline,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.choose(
                          'Selected withdrawal',
                          'Khoản rút đã chọn',
                        ),
                      ),
                      Text(
                        '${formatVnd(covered)} / ${formatVnd(widget.shortfall)} VND',
                        style: TextStyle(
                          color: covered >= widget.shortfall
                              ? goalPrimary
                              : goalError,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: goalFilledButtonStyle(),
                      onPressed: covered >= widget.shortfall
                          ? () => Navigator.pop(context, withdrawalCaps)
                          : null,
                      child: Text(
                        widget.primaryActionLabel == 'Continue with Expense'
                            ? AppStrings.choose(
                                'Continue with Expense',
                                'Tiếp tục với khoản chi',
                              )
                            : widget.primaryActionLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.onClose});
  final String title;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        SizedBox(
          width: 56,
          child: IconButton(
            tooltip: AppStrings.choose('Close', 'Đóng'),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 56),
      ],
    ),
  );
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: goalOutline.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

class _GoalSelector extends StatelessWidget {
  const _GoalSelector({
    required this.goal,
    required this.showChevron,
    this.onTap,
  });
  final GoalModel goal;
  final bool showChevron;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: goalSurfaceLow,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            GoalIconTile(category: goal.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${formatVnd(goal.allocatedAmount)} of ${formatVnd(goal.targetAmount)} VND',
                    style: const TextStyle(fontSize: 10, color: goalMuted),
                  ),
                ],
              ),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded, color: goalMuted),
          ],
        ),
      ),
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: goalMint,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: goalOutline.withValues(alpha: .25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: goalMuted)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: goalDark,
          ),
        ),
      ],
    ),
  );
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      foregroundColor: goalPrimary,
      side: const BorderSide(color: goalOutline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Text(label),
  );
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: goalOutline),
      shape: const StadiumBorder(),
    ),
  );
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final bool emphasize;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: goalMuted, fontSize: 12)),
      Text(
        value,
        style: TextStyle(
          color: emphasize ? goalDark : goalText,
          fontSize: 12,
          fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    ],
  );
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.selected,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final bool selected;
  final String title;
  final String description;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? goalMint.withValues(alpha: .55) : goalSurfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? goalPrimary : goalOutline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: goalMuted),
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? goalPrimary : goalOutline,
          ),
        ],
      ),
    ),
  );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: goalMint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11, color: goalDark)),
  );
}

class _AmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = formatVnd(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

int _parseAmount(String value) =>
    int.tryParse(value.replaceAll(',', '').trim()) ?? 0;

String _goalErrorMessage(Object error) {
  final message = error.toString();
  if (message.contains('AMOUNT_EXCEEDS_AVAILABLE')) {
    return AppStrings.choose(
      'Amount exceeds available funds',
      'Số tiền vượt quá số dư khả dụng',
    );
  }
  if (message.contains('AMOUNT_EXCEEDS_TARGET')) {
    return AppStrings.choose(
      'Amount exceeds the remaining target',
      'Số tiền vượt quá phần còn thiếu của mục tiêu',
    );
  }
  if (message.contains('AMOUNT_EXCEEDS_ALLOCATION')) {
    return AppStrings.choose(
      'Amount exceeds the goal balance',
      'Số tiền vượt quá số dư mục tiêu',
    );
  }
  if (message.contains('operator does not exist') ||
      message.contains('code: 42883')) {
    return AppStrings.choose(
      'Savings data could not be updated. Please try again after syncing.',
      'Không thể cập nhật dữ liệu tiết kiệm. Vui lòng thử lại sau khi đồng bộ.',
    );
  }
  return AppStrings.choose(
    'Could not update this goal. Please try again.',
    'Không thể cập nhật mục tiêu này. Vui lòng thử lại.',
  );
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
