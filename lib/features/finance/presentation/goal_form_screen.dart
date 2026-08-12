import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../models/goal_model.dart';
import '../models/transaction_category.dart';
import '../providers/goal_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/goal_service.dart';
import 'widgets/goal_ui.dart';

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.goalId});

  final String? goalId;

  bool get isEditing => goalId != null;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  static const _darkBackground = Color(0xFF081C18);
  static const _darkCard = Color(0xFF16352E);
  static const _darkBorder = Color(0xFF29483F);
  static const _darkText = Color(0xFFF4FBF8);
  static const _darkSecondary = Color(0xFFA9C1B9);
  static const _darkInput = Color(0xFF0A241F);
  static const _darkSurface = Color(0xFF112622);
  static const _darkAccent = Color(0xFF38D6AC);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _initialController = TextEditingController(text: '0');
  String _category = 'Food';
  DateTime? _targetDate;
  GoalFundingMethod _fundingMethod = GoalFundingMethod.manual;
  double _autoPercent = 10;
  bool _protected = false;
  bool _primary = false;
  int _priority = 2;
  GoalCompletionBehavior _completionBehavior =
      GoalCompletionBehavior.keepAvailable;
  String? _redirectGoalId;
  bool _saving = false;
  bool _loaded = false;
  bool _advancedExpanded = true;

  GoalModel? get _existing => widget.goalId == null
      ? null
      : ref.read(goalServiceProvider).byId(widget.goalId!);

  bool get _useDarkGoalTheme => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final goal = _existing;
    if (goal != null) {
      _nameController.text = goal.name;
      _targetController.text = formatVnd(goal.targetAmount);
      _category = goal.category;
      _targetDate = goal.targetDate;
      _fundingMethod = goal.fundingMethod;
      _autoPercent = goal.autoAllocationPercent;
      _protected = goal.isProtected;
      _primary = goal.isPrimary;
      _priority = goal.withdrawalPriority.clamp(1, 3);
      _completionBehavior = goal.completionBehavior;
      _redirectGoalId = goal.redirectGoalId;
    }
    _loaded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(goalServiceProvider);
    final balance = ref.watch(transactionServiceProvider).totalBalance;
    final available = service.availableForGoals(balance);
    final current = _existing?.allocatedAmount ?? 0;
    final existingIsAssigned =
        _existing != null &&
        _existing!.fundingMethod == GoalFundingMethod.automatic &&
        (_existing!.status == GoalStatus.active ||
            (_existing!.status == GoalStatus.completed &&
                _existing!.completionBehavior ==
                    GoalCompletionBehavior.redirect));
    final assignedWithoutCurrent =
        service.assignedAutomaticPercent -
        (existingIsAssigned ? _existing!.autoAllocationPercent : 0);
    final automaticRemaining = (100 - assignedWithoutCurrent)
        .clamp(0, 100)
        .toDouble();

    final bottomPadding = widget.isEditing ? 32.0 : 116.0;
    return Scaffold(
      backgroundColor: _useDarkGoalTheme
          ? _darkBackground
          : const Color(0xFFE4F4ED),
      appBar: AppBar(
        backgroundColor: _useDarkGoalTheme
            ? _darkBackground.withValues(alpha: .96)
            : Colors.white.withValues(alpha: .76),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            widget.isEditing ? Icons.arrow_back_rounded : Icons.close_rounded,
            color: _useDarkGoalTheme ? _darkText : goalPrimary,
          ),
        ),
        title: Text(
          widget.isEditing
              ? AppStrings.choose('Edit Goal', 'Sửa mục tiêu')
              : AppStrings.choose('Create New Goal', 'Tạo mục tiêu mới'),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _useDarkGoalTheme ? _darkText : goalDark,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
          children: [
            _basicInformationCard(current),
            if (!widget.isEditing) ...[
              const SizedBox(height: 24),
              _initialAllocationCard(available),
            ],
            const SizedBox(height: 16),
            _fundingMethodCard(
              assignedWithoutCurrent: assignedWithoutCurrent,
              automaticRemaining: automaticRemaining,
            ),
            const SizedBox(height: 16),
            _advancedSettingsCard(service),
            if (widget.isEditing) ...[
              const SizedBox(height: 32),
              _editingActions(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: widget.isEditing
          ? null
          : Container(
              decoration: BoxDecoration(
                color: _useDarkGoalTheme
                    ? _darkBackground
                    : Colors.white.withValues(alpha: .78),
                border: Border(
                  top: BorderSide(
                    color: _useDarkGoalTheme ? _darkBorder : Colors.transparent,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    style: goalFilledButtonStyle().copyWith(
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    iconAlignment: IconAlignment.end,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.rocket_launch_outlined, size: 20),
                    label: Text(
                      AppStrings.choose('Create Goal', 'Tạo mục tiêu'),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _basicInformationCard(int current) {
    final category = _goalCategory(_category);
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _GoalSectionTitle(
                  AppStrings.choose('Basic Information', 'Thông tin cơ bản'),
                  dark: _useDarkGoalTheme,
                ),
              ),
              TextButton(
                onPressed: _showCategoryPicker,
                child: Text(
                  AppStrings.choose(
                    'View all\ncategories',
                    'Xem tất cả\ndanh mục',
                  ),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: _useDarkGoalTheme ? _darkAccent : goalPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showCategoryPicker,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _useDarkGoalTheme ? _darkInput : null,
                border: Border.all(
                  color: _useDarkGoalTheme ? _darkBorder : goalOutline,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: category.buildIcon(size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.category, style: _fieldCaptionStyle),
                        Text(
                          AppStrings.categoryName(category.label),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _useDarkGoalTheme ? _darkText : goalDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel(AppStrings.choose('Goal Name', 'Tên mục tiêu')),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: _fieldDecoration(
              AppStrings.choose(
                'e.g., Summer Trip to Da Nang',
                'VD: Chuyến du lịch hè đến Đà Nẵng',
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? AppStrings.choose('Enter a goal name', 'Nhập tên mục tiêu')
                : null,
          ),
          const SizedBox(height: 16),
          _fieldLabel(AppStrings.choose('Target Amount', 'Số tiền mục tiêu')),
          const SizedBox(height: 8),
          TextFormField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _ThousandsFormatter(),
            ],
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _useDarkGoalTheme ? _darkText : goalPrimary,
            ),
            decoration: _fieldDecoration('20,000,000', suffixText: 'VND')
                .copyWith(
                  hintStyle: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _useDarkGoalTheme
                        ? _darkSecondary
                        : const Color(0xFF7C8983),
                  ),
                  suffixStyle: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
                  ),
                ),
            validator: (value) {
              final amount = _parseAmount(value);
              if (amount <= 0) {
                return AppStrings.choose(
                  'Enter a target amount',
                  'Nhập số tiền mục tiêu',
                );
              }
              if (amount < current) {
                return AppStrings.choose(
                  'Target cannot be below the current balance',
                  'Mục tiêu không thể thấp hơn số dư hiện tại',
                );
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _fieldLabel(AppStrings.choose('Target Date', 'Ngày mục tiêu')),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: _fieldDecoration(
                '',
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
              ),
              child: Text(formatGoalDate(_targetDate)),
            ),
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 16),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _useDarkGoalTheme
                    ? _darkSurface
                    : const Color(0xFFF3F3F6),
                borderRadius: BorderRadius.circular(14),
                border: _useDarkGoalTheme
                    ? Border.all(color: _darkBorder.withValues(alpha: .5))
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    AppStrings.choose('Current Balance', 'Số dư hiện tại'),
                    style: _fieldCaptionStyle,
                  ),
                  const Spacer(),
                  Text(
                    '${formatVnd(current)} VND',
                    style: TextStyle(
                      color: _useDarkGoalTheme ? _darkAccent : goalPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _initialAllocationCard(int available) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GoalSectionTitle(
          AppStrings.choose('Initial Allocation', 'Phân bổ ban đầu'),
          dark: _useDarkGoalTheme,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _initialController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandsFormatter(),
          ],
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: _useDarkGoalTheme ? _darkText : goalPrimary,
          ),
          decoration: _fieldDecoration('0', suffixText: 'VND').copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 22,
            ),
          ),
          validator: (value) {
            final amount = _parseAmount(value);
            if (amount < 0) {
              return AppStrings.choose(
                'Amount cannot be negative',
                'Số tiền không thể âm',
              );
            }
            if (amount > available) {
              return AppStrings.choose(
                'Amount exceeds available funds',
                'Số tiền vượt quá số dư khả dụng',
              );
            }
            final target = _parseAmount(_targetController.text);
            if (target > 0 && amount > target) {
              return AppStrings.choose(
                'Amount exceeds the target',
                'Số tiền vượt quá mục tiêu',
              );
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 18,
              color: _useDarkGoalTheme ? _darkAccent : goalPrimary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: AppStrings.choose(
                    'Available for goals: ',
                    'Có thể phân bổ cho mục tiêu: ',
                  ),
                  children: [
                    TextSpan(
                      text: '${formatVnd(available)} VND',
                      style: TextStyle(
                        color: _useDarkGoalTheme ? _darkText : goalDark,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _fundingMethodCard({
    required double assignedWithoutCurrent,
    required double automaticRemaining,
  }) {
    final maxPercent = automaticRemaining == 0 ? 1.0 : automaticRemaining;
    final displayedPercent = _autoPercent
        .clamp(0, automaticRemaining)
        .toDouble();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoalSectionTitle(
            AppStrings.choose('Funding Method', 'Phương thức cấp vốn'),
            color: goalPrimary,
            dark: _useDarkGoalTheme,
          ),
          const SizedBox(height: 2),
          Text(
            AppStrings.choose(
              'Choose how you want to grow this goal',
              'Chọn cách bạn muốn tích lũy cho mục tiêu',
            ),
            style: TextStyle(
              fontSize: 12,
              color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _useDarkGoalTheme ? _darkInput : const Color(0xFFF3F3F6),
              borderRadius: BorderRadius.circular(24),
              border: _useDarkGoalTheme
                  ? Border.all(color: _darkBorder.withValues(alpha: .5))
                  : null,
            ),
            child: Row(
              children: [
                _fundingTab(
                  AppStrings.choose('Manual', 'Thủ công'),
                  GoalFundingMethod.manual,
                ),
                _fundingTab(
                  AppStrings.choose('Automatic', 'Tự động'),
                  GoalFundingMethod.automatic,
                ),
              ],
            ),
          ),
          if (_fundingMethod == GoalFundingMethod.automatic) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${displayedPercent.round()}%',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 44,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: _useDarkGoalTheme ? _darkText : goalPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _percentButton(
                  Icons.remove_rounded,
                  displayedPercent > 0
                      ? () => _setAutoPercent(
                          displayedPercent - 1,
                          automaticRemaining,
                        )
                      : null,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _useDarkGoalTheme
                          ? _darkAccent
                          : goalPrimary,
                      inactiveTrackColor: _useDarkGoalTheme
                          ? _darkBorder
                          : null,
                      thumbColor: goalPrimary,
                      overlayColor:
                          (_useDarkGoalTheme ? _darkAccent : goalPrimary)
                              .withValues(alpha: .14),
                    ),
                    child: Slider(
                      value: displayedPercent,
                      min: 0,
                      max: maxPercent,
                      divisions: automaticRemaining < 1
                          ? 1
                          : automaticRemaining.round(),
                      onChanged: automaticRemaining == 0
                          ? null
                          : (value) => setState(() => _autoPercent = value),
                    ),
                  ),
                ),
                _percentButton(
                  Icons.add_rounded,
                  displayedPercent < automaticRemaining
                      ? () => _setAutoPercent(
                          displayedPercent + 1,
                          automaticRemaining,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [5, 10, 20, 30]
                  .map((value) => _percentageChip(value, automaticRemaining))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _useDarkGoalTheme
                    ? _darkSurface
                    : const Color(0xFFE4F4ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _useDarkGoalTheme
                      ? _darkAccent.withValues(alpha: .30)
                      : goalPrimary.withValues(alpha: .10),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.choose(
                            'This goal: ${displayedPercent.round()}% of each income',
                            'Mục tiêu này: ${displayedPercent.round()}% mỗi khoản thu nhập',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: _useDarkGoalTheme
                                ? _darkSecondary
                                : goalMuted,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: _useDarkGoalTheme
                            ? _darkAccent
                            : const Color(0xFF00A77F),
                        size: 17,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.choose(
                            'Other automatic goals: ${assignedWithoutCurrent.round()}%',
                            'Mục tiêu tự động khác: ${assignedWithoutCurrent.round()}%',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: _useDarkGoalTheme
                                ? _darkSecondary
                                : goalMuted,
                          ),
                        ),
                      ),
                      Text(
                        AppStrings.choose(
                          'Available: ${(100 - assignedWithoutCurrent - displayedPercent).round()}%',
                          'Khả dụng: ${(100 - assignedWithoutCurrent - displayedPercent).round()}%',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _useDarkGoalTheme ? _darkAccent : goalPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              AppStrings.choose(
                'Add money whenever you choose. New income stays available until you allocate it.',
                'Thêm tiền bất cứ lúc nào bạn muốn. Thu nhập mới vẫn khả dụng cho đến khi bạn phân bổ.',
              ),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _advancedSettingsCard(GoalService service) => Container(
    decoration: BoxDecoration(
      color: _useDarkGoalTheme ? _darkCard : Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: _useDarkGoalTheme
            ? _darkBorder
            : goalOutline.withValues(alpha: .24),
      ),
      boxShadow: _useDarkGoalTheme
          ? const []
          : const [
              BoxShadow(
                color: Color(0x1000513E),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
    ),
    child: Column(
      children: [
        InkWell(
          onTap: () => setState(() => _advancedExpanded = !_advancedExpanded),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (widget.isEditing) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _useDarkGoalTheme
                          ? _darkSurface
                          : const Color(0xFFE4F4ED),
                      borderRadius: BorderRadius.circular(12),
                      border: _useDarkGoalTheme
                          ? Border.all(color: _darkBorder)
                          : null,
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: _useDarkGoalTheme ? _darkText : goalPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Icon(
                    Icons.settings_outlined,
                    color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GoalSectionTitle(
                        AppStrings.choose(
                          'Advanced Settings',
                          'Cài đặt nâng cao',
                        ),
                        color: goalPrimary,
                        dark: _useDarkGoalTheme,
                      ),
                      if (widget.isEditing)
                        Text(
                          AppStrings.choose(
                            'Priority, behavior, and protection',
                            'Ưu tiên, cách xử lý và bảo vệ',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: _useDarkGoalTheme
                                ? _darkSecondary
                                : goalMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _advancedExpanded ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                _sectionDivider(),
                _advancedSwitchRow(
                  icon: Icons.lock_outline_rounded,
                  title: AppStrings.choose(
                    'Protect This Goal',
                    'Bảo vệ mục tiêu này',
                  ),
                  subtitle: AppStrings.choose(
                    'Skip this goal during automatic withdrawals.',
                    'Bỏ qua mục tiêu này khi rút tiền tự động.',
                  ),
                  value: _protected,
                  onChanged: (value) => setState(() => _protected = value),
                ),
                _sectionDivider(),
                _advancedSwitchRow(
                  icon: Icons.star_border_rounded,
                  title: AppStrings.choose(
                    'Set as Primary Goal',
                    'Đặt làm mục tiêu ưu tiên',
                  ),
                  subtitle: AppStrings.choose(
                    'Prioritize this goal in displays only.',
                    'Chỉ ưu tiên mục tiêu này khi hiển thị.',
                  ),
                  value: _primary,
                  onChanged: (value) => setState(() => _primary = value),
                ),
                _sectionDivider(),
                _advancedLinkRow(
                  icon: Icons.priority_high_rounded,
                  title: AppStrings.choose(
                    'Withdrawal Priority',
                    'Ưu tiên rút tiền',
                  ),
                  value: _priorityLabel,
                  onTap: _pickPriority,
                ),
                _sectionDivider(),
                _advancedLinkRow(
                  icon: Icons.auto_awesome_outlined,
                  title: AppStrings.choose(
                    'Completion behavior',
                    'Xử lý khi hoàn thành',
                  ),
                  value: _completionLabel,
                  onTap: () => _pickCompletionBehavior(service),
                ),
              ],
            ),
          ),
          crossFadeState: _advancedExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    ),
  );

  Widget _editingActions() => Column(
    children: [
      SizedBox(
        width: double.infinity,
        height: 56,
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
              : Text(AppStrings.choose('Save Changes', 'Lưu thay đổi')),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(
          AppStrings.cancel,
          style: TextStyle(
            color: _useDarkGoalTheme ? _darkSecondary : goalPrimary,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Divider(color: _useDarkGoalTheme ? _darkBorder : null),
      TextButton.icon(
        onPressed: _delete,
        style: TextButton.styleFrom(foregroundColor: goalError),
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        label: Text(AppStrings.choose('Delete Goal', 'Xóa mục tiêu')),
      ),
    ],
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _useDarkGoalTheme ? _darkCard : Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: _useDarkGoalTheme
            ? _darkBorder
            : goalOutline.withValues(alpha: .25),
      ),
      boxShadow: _useDarkGoalTheme
          ? const []
          : const [
              BoxShadow(
                color: Color(0x12006C53),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
    ),
    child: child,
  );

  Widget _sectionDivider() =>
      Divider(height: 1, color: _useDarkGoalTheme ? _darkBorder : null);

  TextStyle get _fieldCaptionStyle => TextStyle(
    fontSize: 12,
    color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
  );

  Widget _fieldLabel(String value) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      value,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
      ),
    ),
  );

  InputDecoration _fieldDecoration(
    String hint, {
    String? suffixText,
    Widget? suffixIcon,
  }) => InputDecoration(
    hintText: hint,
    suffixText: suffixText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: _useDarkGoalTheme ? _darkInput : const Color(0xFFF3F3F6),
    hintStyle: TextStyle(color: _useDarkGoalTheme ? _darkSecondary : null),
    suffixStyle: TextStyle(color: _useDarkGoalTheme ? _darkSecondary : null),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: _useDarkGoalTheme
          ? const BorderSide(color: _darkBorder)
          : BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: _useDarkGoalTheme
          ? const BorderSide(color: _darkBorder)
          : BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: _useDarkGoalTheme ? _darkAccent : goalPrimary,
        width: 1.5,
      ),
    ),
  );

  Widget _fundingTab(String label, GoalFundingMethod method) {
    final selected = _fundingMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _fundingMethod = method),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? goalPrimary
                : (_useDarkGoalTheme ? _darkSurface : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x2400513E),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (_useDarkGoalTheme ? _darkSecondary : goalMuted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _percentButton(IconData icon, VoidCallback? onPressed) => IconButton(
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: _useDarkGoalTheme
          ? _darkSurface
          : const Color(0xFFE8E8EA),
      disabledBackgroundColor: _useDarkGoalTheme
          ? _darkInput
          : const Color(0xFFF3F3F6),
      foregroundColor: _useDarkGoalTheme ? _darkText : goalPrimary,
      side: _useDarkGoalTheme ? const BorderSide(color: _darkBorder) : null,
      minimumSize: const Size.square(40),
    ),
    icon: Icon(icon, size: 20),
  );

  Widget _percentageChip(int value, double maximum) {
    final selected = _autoPercent.round() == value;
    final enabled = value <= maximum;
    return ChoiceChip(
      label: Text('$value%'),
      selected: selected,
      showCheckmark: false,
      onSelected: enabled
          ? (_) => _setAutoPercent(value.toDouble(), maximum)
          : null,
      selectedColor: goalPrimary,
      backgroundColor: _useDarkGoalTheme
          ? _darkSurface
          : const Color(0xFFF3F3F6),
      disabledColor: _useDarkGoalTheme ? _darkInput : const Color(0xFFF3F3F6),
      side: BorderSide(
        color: selected
            ? goalPrimary
            : (_useDarkGoalTheme
                  ? _darkBorder
                  : goalPrimary.withValues(alpha: .12)),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected
            ? Colors.white
            : enabled
            ? (_useDarkGoalTheme ? _darkText : goalPrimary)
            : (_useDarkGoalTheme
                  ? _darkSecondary.withValues(alpha: .55)
                  : goalMuted.withValues(alpha: .55)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _advancedSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(
          icon,
          color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
          size: 21,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: _useDarkGoalTheme ? _darkText : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: _useDarkGoalTheme ? _darkText : null,
          activeTrackColor: _useDarkGoalTheme ? goalPrimary : null,
          inactiveThumbColor: _useDarkGoalTheme ? _darkSecondary : null,
          inactiveTrackColor: _useDarkGoalTheme ? _darkBorder : null,
        ),
      ],
    ),
  );

  Widget _advancedLinkRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Icon(
            icon,
            color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: _useDarkGoalTheme ? _darkText : null,
              ),
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: _useDarkGoalTheme ? _darkAccent : goalPrimary,
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: _useDarkGoalTheme ? _darkSecondary : goalMuted,
          ),
        ],
      ),
    ),
  );

  String get _priorityLabel => switch (_priority) {
    1 => AppStrings.choose('High', 'Cao'),
    3 => AppStrings.choose('Low', 'Thấp'),
    _ => AppStrings.choose('Medium', 'Trung bình'),
  };

  String get _completionLabel =>
      _completionBehavior == GoalCompletionBehavior.redirect
      ? AppStrings.choose('Redirect', 'Chuyển hướng')
      : AppStrings.choose('Keep available', 'Giữ khả dụng');

  void _setAutoPercent(double value, double maximum) =>
      setState(() => _autoPercent = value.clamp(0, maximum).toDouble());

  TransactionCategory _goalCategory(String key) => _goalCategories.firstWhere(
    (category) => category.key == key || category.label == key,
    orElse: () => TransactionCategory.all.first,
  );

  List<TransactionCategory> get _goalCategories => <TransactionCategory>[
    ...TransactionCategory.all,
    ...CustomCategoryStore.instance.items.map(
      (item) => TransactionCategory(
        key: item.name,
        label: item.name,
        icon: item.iconData,
        color: item.color,
      ),
    ),
  ];

  Future<void> _showCategoryPicker() async {
    final dark = _useDarkGoalTheme;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? _darkSurface : null,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: dark ? const BorderSide(color: _darkBorder) : BorderSide.none,
        ),
        title: Text(
          AppStrings.choose('Choose Category', 'Chọn danh mục'),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: dark ? _darkText : goalDark,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        content: SizedBox(
          width: 420,
          height: MediaQuery.sizeOf(context).height.clamp(320, 500).toDouble(),
          child: GridView.builder(
            itemCount: _goalCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.15,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final item = _goalCategories[index];
              final active = item.key == _category;
              return InkWell(
                onTap: () => Navigator.pop(context, item.key),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: active
                        ? item.color.withValues(alpha: dark ? .20 : .14)
                        : dark
                        ? _darkInput
                        : const Color(0xFFF9F9FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active
                          ? item.color
                          : dark
                          ? _darkBorder
                          : goalOutline.withValues(alpha: .25),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      item.buildIcon(size: 20),
                      const SizedBox(height: 6),
                      Text(
                        AppStrings.categoryName(item.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: dark
                              ? (active ? _darkText : _darkSecondary)
                              : goalDark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.cancel,
              style: TextStyle(color: dark ? _darkAccent : goalPrimary),
            ),
          ),
        ],
      ),
    );
    if (selected != null && mounted) setState(() => _category = selected);
  }

  Future<void> _pickPriority() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          AppStrings.choose('Withdrawal Priority', 'Ưu tiên rút tiền'),
        ),
        children: [
          RadioGroup<int>(
            groupValue: _priority,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in [
                  (1, AppStrings.choose('High', 'Cao')),
                  (2, AppStrings.choose('Medium', 'Trung bình')),
                  (3, AppStrings.choose('Low', 'Thấp')),
                ])
                  RadioListTile<int>(value: entry.$1, title: Text(entry.$2)),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected != null && mounted) setState(() => _priority = selected);
  }

  Future<void> _pickCompletionBehavior(GoalService service) async {
    final selected = await showDialog<GoalCompletionBehavior>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppStrings.choose('Upon Completion', 'Khi hoàn thành')),
        children: [
          RadioGroup<GoalCompletionBehavior>(
            groupValue: _completionBehavior,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<GoalCompletionBehavior>(
                  value: GoalCompletionBehavior.keepAvailable,
                  title: Text(
                    AppStrings.choose(
                      'Keep future money available',
                      'Giữ tiền tương lai ở số dư khả dụng',
                    ),
                  ),
                ),
                RadioListTile<GoalCompletionBehavior>(
                  value: GoalCompletionBehavior.redirect,
                  title: Text(
                    AppStrings.choose(
                      'Redirect it to the next goal',
                      'Chuyển sang mục tiêu tiếp theo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _completionBehavior = selected);
    if (selected == GoalCompletionBehavior.redirect) {
      final candidates = service.activeGoals
          .where((goal) => goal.id != widget.goalId)
          .toList();
      if (candidates.isEmpty) {
        if (mounted) {
          setState(
            () => _completionBehavior = GoalCompletionBehavior.keepAvailable,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.choose(
                  'Create another active goal first.',
                  'Hãy tạo một mục tiêu đang hoạt động khác trước.',
                ),
              ),
            ),
          );
        }
        return;
      }
      final redirect = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(AppStrings.choose('Redirect to', 'Chuyển đến')),
          children: candidates
              .map(
                (goal) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, goal.id),
                  child: Text(goal.name),
                ),
              )
              .toList(),
        ),
      );
      if (!mounted) return;
      if (redirect == null) {
        setState(
          () => _completionBehavior = GoalCompletionBehavior.keepAvailable,
        );
      } else {
        setState(() => _redirectGoalId = redirect);
      }
    } else {
      setState(() => _redirectGoalId = null);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      final existing = _existing;
      final goal = GoalModel(
        id: existing?.id ?? 'goal_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        name: _nameController.text.trim(),
        targetAmount: _parseAmount(_targetController.text),
        createdAt: existing?.createdAt ?? DateTime.now(),
        category: _category,
        targetDate: _targetDate,
        fundingMethod: _fundingMethod,
        autoAllocationPercent: _fundingMethod == GoalFundingMethod.automatic
            ? _autoPercent
            : 0,
        isPrimary: _primary,
        isProtected: _protected,
        withdrawalPriority: _priority,
        status: existing?.status ?? GoalStatus.active,
        completionBehavior: _completionBehavior,
        redirectGoalId: _completionBehavior == GoalCompletionBehavior.redirect
            ? _redirectGoalId
            : null,
        imageUrl: existing?.imageUrl,
        allocatedAmount:
            existing?.allocatedAmount ?? _parseAmount(_initialController.text),
      );
      if (existing == null) {
        await ref.read(goalServiceProvider).setGoal(goal);
      } else {
        await ref.read(goalServiceProvider).updateGoal(goal);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final goal = _existing;
    if (goal == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.choose('Delete goal?', 'Xóa mục tiêu?')),
        content: Text(
          AppStrings.choose(
            'Allocated money will return to available funds.',
            'Tiền đã phân bổ sẽ trở lại số dư khả dụng.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: goalError),
            child: Text(AppStrings.choose('Delete', 'Xóa')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(goalServiceProvider).deleteGoal(goal.id);
    if (!mounted) return;
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AppRoutes.savingGoals || route.isFirst,
    );
  }

  static int _parseAmount(String? value) =>
      int.tryParse((value ?? '').replaceAll(',', '').trim()) ?? 0;
}

class _GoalSectionTitle extends StatelessWidget {
  const _GoalSectionTitle(
    this.text, {
    this.color = goalDark,
    this.dark = false,
  });

  final String text;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily: 'Manrope',
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: dark ? const Color(0xFFF4FBF8) : color,
    ),
  );
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = formatVnd(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
