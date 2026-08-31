import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/finflow_action_icon.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../providers/transaction_provider.dart';

/// Full-height modal for viewing and creating saving goals.
///
/// The public name is retained so existing call sites keep working.
class GoalSetupSheet extends ConsumerStatefulWidget {
  const GoalSetupSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66001F17),
      builder: (_) => const SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.96,
          child: GoalSetupSheet(),
        ),
      ),
    );
  }

  @override
  ConsumerState<GoalSetupSheet> createState() => _GoalSetupSheetState();
}

class _GoalSetupSheetState extends ConsumerState<GoalSetupSheet> {
  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';
  static const _pageColor = Color(0xFFF7FAF9);
  static const _textColor = Color(0xFF17201D);
  static const _mutedColor = Color(0xFF52655E);

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  GoalModel? _editingGoal;
  var _showCreateForm = false;
  var _isSaving = false;
  var _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_formatAmount);
    Future.microtask(() async {
      try {
        await ref.read(goalServiceProvider).fetchGoals();
        if (mounted) setState(() {});
      } catch (_) {
        // Keep cached goals visible when a refresh is unavailable.
      }
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_formatAmount);
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: _pageColor,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            _buildSheetHandle(),
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showCreateForm ? _buildCreateForm() : _buildGoalsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetHandle() {
    return Padding(
      padding: EdgeInsets.only(top: Responsive.h(context, 10)),
      child: Container(
        width: Responsive.w(context, 42),
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFC5CFCA),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        Responsive.h(context, 8),
        Responsive.w(context, 10),
        Responsive.h(context, 8),
      ),
      child: Row(
        children: [
          if (_showCreateForm)
            IconButton(
              key: const Key('saving-goals-back-button'),
              tooltip: AppStrings.choose('Back to goals', 'Quay lại mục tiêu'),
              onPressed: _isSaving ? null : _closeGoalForm,
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            Container(
              width: Responsive.w(context, 28),
              height: Responsive.w(context, 28),
              decoration: const BoxDecoration(
                color: Color(0xFFE2F5ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_outlined,
                size: 17,
                color: Color(0xFF006C53),
              ),
            ),
          SizedBox(width: Responsive.w(context, 8)),
          Expanded(
            child: Text(
              _showCreateForm
                  ? (_editingGoal == null
                        ? AppStrings.choose('Add New Goal', 'Thêm mục tiêu mới')
                        : AppStrings.choose(
                            'Edit Saving Goal',
                            'Sửa mục tiêu tiết kiệm',
                          ))
                  : 'FinFlow',
              style: TextStyle(
                fontFamily: _headlineFont,
                fontSize: Responsive.sp(context, 13),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF07513F),
              ),
            ),
          ),
          IconButton(
            key: const Key('saving-goals-close-button'),
            tooltip: AppStrings.choose('Close', 'Đóng'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: _textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsList() {
    final goalService = ref.watch(goalServiceProvider);
    final goals = goalService.goals;
    final totalBalance = ref.watch(transactionServiceProvider).totalBalance;

    return ListView(
      key: const Key('saving-goals-list'),
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        Responsive.h(context, 4),
        Responsive.w(context, 20),
        Responsive.h(context, 28),
      ),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          AppStrings.choose('Savings Goals', 'Mục tiêu tiết kiệm'),
          style: TextStyle(
            fontFamily: _headlineFont,
            fontSize: Responsive.sp(context, 24),
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        SizedBox(height: Responsive.h(context, 3)),
        Text(
          AppStrings.choose(
            'Manage and track your financial goals.',
            'Quản lý và theo dõi các mục tiêu tài chính của bạn.',
          ),
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 13),
            color: _mutedColor,
          ),
        ),
        SizedBox(height: Responsive.h(context, 12)),
        SizedBox(
          height: Responsive.h(context, 44),
          child: FilledButton.icon(
            key: const Key('add-new-saving-goal-button'),
            onPressed: _startCreateGoal,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(AppStrings.choose('Add New Goal', 'Thêm mục tiêu mới')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF006C53),
              foregroundColor: Colors.white,
              textStyle: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 13),
                fontWeight: FontWeight.w700,
              ),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 14)),
        if (goals.isEmpty)
          _buildEmptyState()
        else
          ...List.generate(goals.length, (index) {
            final goal = goals[index];
            final progress = goalService.progressRatioFor(goal, totalBalance);
            final saved = goalService
                .savedAmountFor(goal, totalBalance)
                .clamp(0, goal.targetAmount);
            return Padding(
              padding: EdgeInsets.only(bottom: Responsive.h(context, 10)),
              child: _buildGoalCard(
                goal: goal,
                progress: progress,
                saved: saved,
                accent: _accentFor(index),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      key: const Key('saving-goals-empty-state'),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 24),
        vertical: Responsive.h(context, 34),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAE6)),
      ),
      child: Column(
        children: [
          const Icon(Icons.flag_outlined, size: 38, color: Color(0xFF7D9189)),
          SizedBox(height: Responsive.h(context, 10)),
          Text(
            AppStrings.choose(
              'No savings goals yet',
              'Chưa có mục tiêu tiết kiệm',
            ),
            style: TextStyle(
              fontFamily: _headlineFont,
              fontSize: Responsive.sp(context, 16),
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          SizedBox(height: Responsive.h(context, 4)),
          Text(
            AppStrings.choose(
              'Create your first goal and start tracking your progress.',
              'Tạo mục tiêu đầu tiên và bắt đầu theo dõi tiến độ.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: Responsive.sp(context, 13),
              color: _mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard({
    required GoalModel goal,
    required double progress,
    required int saved,
    required Color accent,
  }) {
    final percent = (progress * 100).round();
    return Material(
      key: ValueKey('saving-goal-${goal.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _editGoal(goal),
        child: Container(
          constraints: BoxConstraints(minHeight: Responsive.h(context, 132)),
          padding: EdgeInsets.fromLTRB(
            Responsive.w(context, 16),
            Responsive.h(context, 13),
            Responsive.w(context, 10),
            Responsive.h(context, 12),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7ECEA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D003B2C),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  key: ValueKey('pin-saving-goal-${goal.id}'),
                  tooltip: goal.isPrimary
                      ? AppStrings.choose(
                          'Primary saving goal',
                          'Mục tiêu tiết kiệm chính',
                        )
                      : AppStrings.choose(
                          'Set as primary goal',
                          'Đặt làm mục tiêu chính',
                        ),
                  visualDensity: VisualDensity.compact,
                  onPressed: goal.isPrimary ? null : () => _activateGoal(goal),
                  icon: Icon(
                    goal.isPrimary
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 18,
                    color: goal.isPrimary
                        ? const Color(0xFF006C53)
                        : const Color(0xFF8A9993),
                  ),
                ),
              ),
              Center(
                child: Column(
                  children: [
                    _buildProgressRing(goal, progress, accent),
                    SizedBox(height: Responsive.h(context, 7)),
                    Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 14),
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 2)),
                    Text(
                      '${_formatMoneyValue(saved)} / '
                      '${_formatMoneyValue(goal.targetAmount)} VND',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 10),
                        color: _mutedColor,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 3)),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontFamily: _headlineFont,
                        fontSize: Responsive.sp(context, 15),
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRing(GoalModel goal, double progress, Color accent) {
    return SizedBox(
      width: Responsive.w(context, 76),
      height: Responsive.w(context, 76),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: Responsive.w(context, 6),
              strokeCap: StrokeCap.round,
              color: accent,
              backgroundColor: const Color(0xFFE1E7E4),
            ),
          ),
          Container(
            width: Responsive.w(context, 34),
            height: Responsive.w(context, 34),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForGoal(goal.name),
              size: Responsive.w(context, 17),
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      key: const Key('saving-goal-create-form'),
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        Responsive.h(context, 8),
        Responsive.w(context, 20),
        Responsive.h(context, 28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingGoal == null
                ? AppStrings.choose(
                    'Create a savings goal',
                    'Tạo mục tiêu tiết kiệm',
                  )
                : AppStrings.choose(
                    'Edit your savings goal',
                    'Sửa mục tiêu tiết kiệm',
                  ),
            style: TextStyle(
              fontFamily: _headlineFont,
              fontSize: Responsive.sp(context, 24),
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          SizedBox(height: Responsive.h(context, 4)),
          Text(
            _editingGoal == null
                ? AppStrings.choose(
                    'Give your goal a clear name and target amount.',
                    'Đặt tên rõ ràng và số tiền đích cho mục tiêu.',
                  )
                : AppStrings.choose(
                    'Update the goal name or target amount below.',
                    'Cập nhật tên hoặc số tiền đích bên dưới.',
                  ),
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: Responsive.sp(context, 13),
              color: _mutedColor,
            ),
          ),
          SizedBox(height: Responsive.h(context, 22)),
          TextField(
            key: const Key('saving-goal-name-field'),
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: AppStrings.choose('Goal name', 'Tên mục tiêu'),
              hint: AppStrings.choose(
                'e.g. Buy a new laptop',
                'Ví dụ: Mua máy tính xách tay mới',
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 14)),
          TextField(
            key: const Key('saving-goal-amount-field'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration(
              label: AppStrings.choose(
                'Target amount (VND)',
                'Số tiền mục tiêu (VND)',
              ),
              hint: '15,000,000',
            ),
          ),
          SizedBox(height: Responsive.h(context, 22)),
          SizedBox(
            width: double.infinity,
            height: Responsive.h(context, 50),
            child: FilledButton(
              key: const Key('save-saving-goal-button'),
              onPressed: _isSaving ? null : _saveGoal,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF006C53),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _editingGoal == null
                          ? AppStrings.choose(
                              'Start Saving',
                              'Bắt đầu tiết kiệm',
                            )
                          : AppStrings.choose('Save Changes', 'Lưu thay đổi'),
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          if (_editingGoal != null) ...[
            SizedBox(height: Responsive.h(context, 12)),
            SizedBox(
              width: double.infinity,
              height: Responsive.h(context, 48),
              child: OutlinedButton.icon(
                key: const Key('delete-saving-goal-button'),
                onPressed: _isSaving
                    ? null
                    : () => _confirmDelete(_editingGoal!),
                icon: const FinFlowTrashIcon(color: Color(0xFFBA1A1A)),
                label: Text(AppStrings.choose('Delete Goal', 'Xóa mục tiêu')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBA1A1A),
                  side: const BorderSide(color: Color(0xFFBA1A1A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Color(0xFF53665F)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD7E1DC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF00A77E), width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 16),
        vertical: Responsive.h(context, 15),
      ),
    );
  }

  Future<void> _activateGoal(GoalModel goal) async {
    try {
      await ref.read(goalServiceProvider).activateGoal(goal.id);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showError(
        AppStrings.choose(
          'Unable to pin this goal: $error',
          'Không thể ghim mục tiêu này: $error',
        ),
      );
    }
  }

  void _startCreateGoal() {
    _nameController.clear();
    _amountController.clear();
    setState(() {
      _editingGoal = null;
      _showCreateForm = true;
    });
  }

  void _editGoal(GoalModel goal) {
    _nameController.text = goal.name;
    _amountController.text = goal.targetAmount.toString();
    setState(() {
      _editingGoal = goal;
      _showCreateForm = true;
    });
  }

  void _closeGoalForm() {
    _nameController.clear();
    _amountController.clear();
    setState(() {
      _editingGoal = null;
      _showCreateForm = false;
    });
  }

  Future<void> _confirmDelete(GoalModel goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.choose('Delete Goal', 'Xóa mục tiêu')),
        content: Text(
          AppStrings.choose('Delete "${goal.name}"?', 'Xóa "${goal.name}"?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.choose('Cancel', 'Hủy')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.choose('Delete', 'Xóa')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(goalServiceProvider).deleteGoal(goal.id);
      if (mounted) _closeGoalForm();
    } catch (error) {
      if (!mounted) return;
      _showError(
        AppStrings.choose(
          'Unable to delete this goal: $error',
          'Không thể xóa mục tiêu này: $error',
        ),
      );
    }
  }

  Future<void> _saveGoal() async {
    final name = _nameController.text.trim();
    final raw = _amountController.text.replaceAll(',', '').trim();
    final amount = int.tryParse(raw);
    if (name.isEmpty || amount == null || amount <= 0) {
      _showError(
        AppStrings.choose(
          'Please enter a name and a valid amount',
          'Vui lòng nhập tên và số tiền hợp lệ',
        ),
      );
      return;
    }

    final editingGoal = _editingGoal;
    setState(() => _isSaving = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) {
        throw Exception(
          AppStrings.choose('Not authenticated', 'Chưa xác thực'),
        );
      }
      final goalService = ref.read(goalServiceProvider);
      if (editingGoal == null) {
        await goalService.setGoal(
          GoalModel(
            id: 'g_${DateTime.now().millisecondsSinceEpoch}',
            userId: user.id,
            name: name,
            targetAmount: amount,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await goalService.updateGoal(
          GoalModel(
            id: editingGoal.id,
            userId: editingGoal.userId,
            name: name,
            targetAmount: amount,
            createdAt: editingGoal.createdAt,
            isPrimary: editingGoal.isPrimary,
            category: editingGoal.category,
            targetDate: editingGoal.targetDate,
            fundingMethod: editingGoal.fundingMethod,
            autoAllocationPercent: editingGoal.autoAllocationPercent,
            isProtected: editingGoal.isProtected,
            withdrawalPriority: editingGoal.withdrawalPriority,
            status: editingGoal.status,
            completionBehavior: editingGoal.completionBehavior,
            redirectGoalId: editingGoal.redirectGoalId,
            imageUrl: editingGoal.imageUrl,
            allocatedAmount: editingGoal.allocatedAmount,
          ),
        );
      }
      if (!mounted) return;
      _isSaving = false;
      _closeGoalForm();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(
        editingGoal == null
            ? AppStrings.choose(
                'Failed to create goal: $error',
                'Không thể tạo mục tiêu: $error',
              )
            : AppStrings.choose(
                'Failed to update goal: $error',
                'Không thể cập nhật mục tiêu: $error',
              ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _formatAmount() {
    if (_isFormatting) return;
    _isFormatting = true;
    final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final formatted = _addCommas(digits);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormatting = false;
  }

  static String _addCommas(String digits) {
    if (digits.isEmpty) return '';
    return digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  static String _formatMoneyValue(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  static Color _accentFor(int index) {
    const accents = [
      Color(0xFF006C53),
      Color(0xFF0060AC),
      Color(0xFF4D7B0B),
      Color(0xFF00A77E),
    ];
    return accents[index % accents.length];
  }

  static IconData _iconForGoal(String name) {
    final value = name.toLowerCase();
    if (value.contains('laptop') || value.contains('computer')) {
      return Icons.laptop_mac_rounded;
    }
    if (value.contains('motor') ||
        value.contains('bike') ||
        value.contains('car')) {
      return Icons.two_wheeler_rounded;
    }
    if (value.contains('travel') ||
        value.contains('trip') ||
        value.contains('vacation')) {
      return Icons.flight_takeoff_rounded;
    }
    if (value.contains('emergency') || value.contains('fund')) {
      return Icons.health_and_safety_outlined;
    }
    if (value.contains('home') || value.contains('house')) {
      return Icons.home_outlined;
    }
    return Icons.savings_outlined;
  }
}
