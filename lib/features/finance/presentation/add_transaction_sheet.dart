import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../scan/presentation/scan_screen.dart';
import '../models/quick_add_draft_model.dart';
import '../models/transaction_category.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/transaction_provider.dart';
import '../services/quick_add_service.dart';
import '../services/quick_add_speech_recognition_service.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';
import 'quick_add_review_sheet.dart';
import 'transaction_saved_screen.dart';
import 'widgets/quick_add_card.dart';

const _customIcons = <IconData>[
  Icons.school,
  Icons.pets,
  Icons.flight,
  Icons.fitness_center,
  Icons.movie,
  Icons.music_note,
  Icons.photo_camera,
  Icons.phone_iphone,
  Icons.computer,
  Icons.book,
  Icons.coffee,
  Icons.work,
];

const _customColors = <Color>[
  Color(0xFFE53935),
  Color(0xFFD81B60),
  Color(0xFF8E24AA),
  Color(0xFF3949AB),
  Color(0xFF1E88E5),
  Color(0xFF00ACC1),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFFFFB300),
  Color(0xFFFB8C00),
  Color(0xFF6D4C41),
  Color(0xFF757575),
];

/// Full-screen Add Transaction flow. The historical class name is preserved so
/// existing callers keep the same API while [show] now pushes a page.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.initialIsExpense,
    this.initialAmount,
    this.initialName,
    this.initialCategoryKey,
    this.initialWalletId,
    this.initialDate,
    this.fromQuickAdd = false,
  });

  final bool? initialIsExpense;
  final int? initialAmount;
  final String? initialName;
  final String? initialCategoryKey;
  final String? initialWalletId;
  final DateTime? initialDate;
  final bool fromQuickAdd;

  static Future<bool?> show(
    BuildContext context, {
    bool? initialIsExpense,
    int? initialAmount,
    String? initialName,
    String? initialCategoryKey,
    String? initialWalletId,
    DateTime? initialDate,
    bool fromQuickAdd = false,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionSheet(
          initialIsExpense: initialIsExpense,
          initialAmount: initialAmount,
          initialName: initialName,
          initialCategoryKey: initialCategoryKey,
          initialWalletId: initialWalletId,
          initialDate: initialDate,
          fromQuickAdd: fromQuickAdd,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

enum _AddMode { manual, quick, scan }

enum _AccountCategory { cash, transfer }

enum _QuickAddVoiceState {
  idle,
  initializing,
  listening,
  processingFinal,
  parsing,
  error,
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _quickAddController = TextEditingController();
  _AddMode? _mode;
  _AddMode? _selectedInputMode;
  var _isExpense = false;
  var _isSavingTransaction = false;
  String? _selectedWalletId;
  String? _selectedWalletName;
  _AccountCategory? _selectedAcctCategory;
  var _selectedCategory = 'Food';
  DateTime? _transactionDate;
  var _isFormatting = false;
  var _allowPop = false;

  var _isQuickAddParsing = false;
  var _isQuickAddReviewOpen = false;
  var _voiceState = _QuickAddVoiceState.idle;
  var _voiceSession = 0;
  var _voiceFinalHandled = false;
  var _latestVoiceTranscript = '';
  Timer? _voiceTimeout;
  Timer? _modeNavigationTimer;

  bool get _isVoiceRecording => _voiceState == _QuickAddVoiceState.listening;
  bool get _isVoiceProcessing =>
      _voiceState == _QuickAddVoiceState.initializing ||
      _voiceState == _QuickAddVoiceState.processingFinal;

  @override
  void initState() {
    super.initState();
    final hasInitialDraft =
        widget.fromQuickAdd ||
        widget.initialIsExpense != null ||
        widget.initialAmount != null ||
        widget.initialName != null ||
        widget.initialCategoryKey != null ||
        widget.initialWalletId != null ||
        widget.initialDate != null;
    _mode = hasInitialDraft ? _AddMode.manual : null;
    _isExpense = widget.initialIsExpense ?? false;
    _selectedCategory = widget.initialCategoryKey ?? 'Food';
    _selectedWalletId = widget.initialWalletId;
    _transactionDate = widget.initialDate;
    _nameController.text = widget.initialName ?? '';
    if (widget.initialAmount != null) {
      _amountController.text = _addCommas(
        widget.initialAmount!.abs().toString(),
      );
    }
    final wallet = WalletService.instance.byId(widget.initialWalletId);
    if (wallet != null && wallet.isActive) {
      _selectedWalletName = wallet.name;
      _selectedAcctCategory = _accountCategoryFor(wallet.type);
    }
    _amountController.addListener(_formatAmount);
  }

  @override
  void dispose() {
    _amountController.removeListener(_formatAmount);
    _amountController.dispose();
    _nameController.dispose();
    _quickAddController.dispose();
    _voiceTimeout?.cancel();
    _modeNavigationTimer?.cancel();
    if (_voiceState != _QuickAddVoiceState.idle) {
      unawaited(QuickAddSpeechRecognitionService.instance.cancelListening());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionService = ref.read(transactionServiceProvider);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_mode != null && !widget.fromQuickAdd) {
            setState(() => _mode = null);
          } else {
            unawaited(_requestClose());
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBF9),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: _buildHorizontalPageTransition,
                  child: _mode == null
                      ? ListenableBuilder(
                          key: const ValueKey('add-mode-picker'),
                          listenable: transactionService,
                          builder: (_, _) =>
                              _buildModePicker(transactionService),
                        )
                      : SingleChildScrollView(
                          key: ValueKey(_mode),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: _mode == _AddMode.scan
                              ? EdgeInsets.zero
                              : EdgeInsets.fromLTRB(
                                  Responsive.w(context, 20),
                                  Responsive.h(context, 20),
                                  Responsive.w(context, 20),
                                  MediaQuery.viewInsetsOf(context).bottom +
                                      Responsive.h(context, 24),
                                ),
                          child: switch (_mode!) {
                            _AddMode.manual => _buildManualMode(),
                            _AddMode.quick => _buildQuickMode(),
                            _AddMode.scan => _buildScanMode(),
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = switch (_mode) {
      _AddMode.manual => 'Manual Entry',
      _AddMode.quick => 'Voice',
      _AddMode.scan => 'Scan',
      _ => 'Add transaction',
    };
    return Container(
      height: Responsive.h(context, 64),
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 10)),
      decoration: const BoxDecoration(color: Color(0xFFF7FBF9)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _handleHeaderBack,
              tooltip: 'Back',
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 22,
                color: Color(0xFF43474E),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: Responsive.sp(context, 18),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1C1E),
            ),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.more_horiz_rounded, color: Color(0xFF43474E)),
          ),
        ],
      ),
    );
  }

  void _handleHeaderBack() {
    if (_mode != null && !widget.fromQuickAdd) {
      setState(() {
        _mode = null;
        _selectedInputMode = null;
      });
      return;
    }
    unawaited(_requestClose());
  }

  Widget _buildHorizontalPageTransition(
    Widget child,
    Animation<double> animation,
  ) {
    final isModePicker = child.key == const ValueKey('add-mode-picker');
    final begin = isModePicker ? const Offset(-1, 0) : const Offset(1, 0);
    return ClipRect(
      child: SlideTransition(
        position: Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  void _selectInputMode(_AddMode mode) {
    if (_selectedInputMode != null) return;
    setState(() => _selectedInputMode = mode);
    _modeNavigationTimer?.cancel();
    _modeNavigationTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _selectedInputMode != mode) return;
      setState(() {
        _mode = mode;
        _selectedInputMode = null;
      });
    });
  }

  Widget _buildModePicker(TransactionService transactionService) {
    final budgetLimit = AuthService.instance.currentUser?.budgetLimit ?? 0;
    final spent = _safeMonthlyExpense(transactionService);
    final remaining = budgetLimit - spent;
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = (lastDay - now.day + 1).clamp(1, lastDay);
    final shouldSpend = remaining > 0 ? remaining ~/ daysLeft : 0;
    final isOverBudget = budgetLimit > 0 && remaining < 0;
    final recent = _safeCurrentUserTransactions(transactionService)
      ..sort((a, b) => b.date.compareTo(a.date));

    return SingleChildScrollView(
      key: const ValueKey('add-transaction-mode-picker'),
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        Responsive.h(context, 4),
        Responsive.w(context, 20),
        Responsive.h(context, 28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPromptRow(isOverBudget: isOverBudget),
          SizedBox(height: Responsive.h(context, 16)),
          _buildBudgetInsightCard(
            budgetLimit: budgetLimit,
            remaining: remaining,
            shouldSpend: shouldSpend,
            daysLeft: daysLeft,
            isOverBudget: isOverBudget,
          ),
          SizedBox(height: Responsive.h(context, 16)),
          _buildHabitBanner(),
          SizedBox(height: Responsive.h(context, 20)),
          Text('CHOOSE INPUT METHOD', style: _labelStyle),
          SizedBox(height: Responsive.h(context, 10)),
          Row(
            children: [
              Expanded(
                child: _buildInputModeCard(
                  key: const Key('add_mode_manual'),
                  mode: _AddMode.manual,
                  icon: Icons.keyboard_alt_outlined,
                  label: 'MANUAL ENTRY',
                  tint: const Color(0xFFE5F5F0),
                  foreground: const Color(0xFF006C53),
                  selected: _selectedInputMode == _AddMode.manual,
                ),
              ),
              SizedBox(width: Responsive.w(context, 10)),
              Expanded(
                child: _buildInputModeCard(
                  key: const Key('add_mode_quick'),
                  mode: _AddMode.quick,
                  icon: Icons.mic_none_rounded,
                  label: 'VOICE',
                  tint: const Color(0xFFE5F5F0),
                  foreground: const Color(0xFF006C53),
                  selected: _selectedInputMode == _AddMode.quick,
                  badge: 'FAST',
                ),
              ),
              SizedBox(width: Responsive.w(context, 10)),
              Expanded(
                child: _buildInputModeCard(
                  key: const Key('add_mode_scan'),
                  mode: _AddMode.scan,
                  icon: Icons.photo_camera_outlined,
                  label: 'SCAN',
                  tint: const Color(0xFFFFE7E1),
                  foreground: const Color(0xFFBA4B3D),
                  selected: _selectedInputMode == _AddMode.scan,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 22)),
          Text('QUICK CATEGORIES', style: _labelStyle),
          SizedBox(height: Responsive.h(context, 10)),
          _buildQuickCategories(),
          SizedBox(height: Responsive.h(context, 22)),
          Text('RECENT TRANSACTIONS', style: _labelStyle),
          SizedBox(height: Responsive.h(context, 10)),
          if (recent.isEmpty)
            _buildEmptyRecentTransactions()
          else
            ...recent.take(2).map(_buildRecentTransaction),
        ],
      ),
    );
  }

  Widget _buildPromptRow({required bool isOverBudget}) {
    return Row(
      children: [
        Container(
          width: Responsive.w(context, 42),
          height: Responsive.w(context, 42),
          decoration: BoxDecoration(
            color: isOverBudget ? Colors.transparent : const Color(0xFF64D2AE),
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: isOverBudget
                ? Image.asset(
                    'assets/images/over_budget_worried.png',
                    key: const ValueKey('over-budget-worried-mood'),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    cacheWidth: 128,
                    errorBuilder: (_, _, _) => const Center(
                      key: ValueKey('over-budget-worried-mood-fallback'),
                      child: Text('😟', style: TextStyle(fontSize: 24)),
                    ),
                  )
                : const Center(
                    key: ValueKey('on-track-happy-mood'),
                    child: Text('😊', style: TextStyle(fontSize: 21)),
                  ),
          ),
        ),
        SizedBox(width: Responsive.w(context, 10)),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 14),
              vertical: Responsive.h(context, 12),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F4EF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'What did you spend money on today?',
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: 13,
                color: Color(0xFF34443F),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetInsightCard({
    required int budgetLimit,
    required int remaining,
    required int shouldSpend,
    required int daysLeft,
    required bool isOverBudget,
  }) {
    final hasBudget = budgetLimit > 0;
    final cardColors = isOverBudget
        ? const [Color(0xFF10182B), Color(0xFF172139)]
        : const [Color(0xFF006C53), Color(0xFF008F70)];
    final amountColor = isOverBudget ? const Color(0xFFFF777C) : Colors.white;

    return Container(
      constraints: BoxConstraints(minHeight: Responsive.h(context, 116)),
      padding: EdgeInsets.all(Responsive.w(context, 16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26006C53),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'REMAINING BALANCE',
                  style: _labelStyle.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 9,
                  ),
                ),
              ),
              _buildDaysLeftChip(daysLeft),
            ],
          ),
          const SizedBox(height: 3),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: hasBudget
                      ? _formatInsightMoney(remaining)
                      : 'No budget set',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, hasBudget ? 27 : 21),
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (hasBudget)
                  TextSpan(
                    text: ' VND',
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 12),
                      fontWeight: FontWeight.w500,
                      color: amountColor.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(context, 16)),
          Row(
            children: [
              Icon(
                isOverBudget
                    ? Icons.warning_amber_rounded
                    : Icons.savings_outlined,
                color: isOverBudget
                    ? const Color(0xFFFF777C)
                    : const Color(0xFFA6F2D7),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverBudget ? 'DEFICIT WARNING' : 'YOU SHOULD SPEND',
                      style: _labelStyle.copyWith(
                        color: isOverBudget
                            ? const Color(0xFFFF777C)
                            : Colors.white.withValues(alpha: 0.65),
                        fontSize: 8,
                      ),
                    ),
                    Text(
                      isOverBudget
                          ? 'Reduce spending to recover balance'
                          : hasBudget
                          ? '${_formatInsightMoney(shouldSpend)} VND/day'
                          : 'Set a monthly budget to see insights',
                      style: const TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              _buildBudgetStatusChip(isOverBudget, hasBudget),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaysLeftChip(int daysLeft) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            '$daysLeft DAYS LEFT',
            style: _labelStyle.copyWith(color: Colors.white, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStatusChip(bool isOverBudget, bool hasBudget) {
    final background = !hasBudget
        ? Colors.white.withValues(alpha: 0.16)
        : isOverBudget
        ? const Color(0xFFFF3D4E)
        : const Color(0xFFFFCF3F);
    final foreground = !hasBudget
        ? Colors.white
        : isOverBudget
        ? Colors.white
        : const Color(0xFF594500);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        !hasBudget
            ? 'NO BUDGET'
            : isOverBudget
            ? 'OVER BUDGET'
            : 'ON TRACK',
        style: _labelStyle.copyWith(
          color: foreground,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildHabitBanner() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 14),
        vertical: Responsive.h(context, 11),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0D9),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Row(
        children: [
          Text('🔥', style: TextStyle(fontSize: 17)),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              "You're building a healthy money habit. Keep it up!",
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: 11,
                color: Color(0xFF704E24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputModeCard({
    required Key key,
    required _AddMode mode,
    required IconData icon,
    required String label,
    required Color tint,
    required Color foreground,
    required bool selected,
    String? badge,
  }) {
    return SizedBox(
      height: Responsive.h(context, 104),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            key: key,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF00513E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF00513E)
                    : const Color(0xFFDDE5E1),
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x3000513E),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _selectedInputMode == null
                    ? () => _selectInputMode(mode)
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 6),
                    vertical: Responsive.h(context, 10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 90),
                        width: Responsive.w(context, 38),
                        height: Responsive.w(context, 38),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF58CCA9) : tint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: selected ? Colors.white : foreground,
                          size: 21,
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 7)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 90),
                          style: _labelStyle.copyWith(
                            color: selected ? Colors.white : foreground,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                          child: Text(label),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: -3,
              top: -7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC84B),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge,
                  style: _labelStyle.copyWith(
                    color: const Color(0xFF5C4300),
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickCategories() {
    final categories = TransactionCategory.popular.take(4).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ...categories.map(
          (category) => _QuickCategoryButton(
            category: category,
            onTap: () {
              setState(() {
                _selectedCategory = category.key;
                _mode = _AddMode.manual;
              });
            },
          ),
        ),
        _QuickCategoryButton(
          category: const TransactionCategory(
            key: 'More',
            label: 'More',
            icon: Icons.add_rounded,
            color: Color(0xFFE6F4EF),
          ),
          outlined: true,
          onTap: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => TransactionCategorySelectionSheet(
                initialKey: _selectedCategory,
              ),
            );
            if (result != null && mounted) {
              setState(() {
                _selectedCategory = result;
                _mode = _AddMode.manual;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildRecentTransaction(TransactionModel transaction) {
    final category = _categoryForKey(transaction.category);
    final isExpense = transaction.amount < 0;
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(context, 9)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 12),
        vertical: Responsive.h(context, 11),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EAE7)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(category.icon, size: 18, color: category.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                Text(
                  _formatRecentDate(transaction.date),
                  style: const TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 10,
                    color: Color(0xFF74817B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${_formatInsightMoney(transaction.amount.abs())}đ',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isExpense
                  ? const Color(0xFFC24444)
                  : const Color(0xFF006C53),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecentTransactions() {
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EAE7)),
      ),
      child: const Text(
        'Your latest transactions will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontSize: 12,
          color: Color(0xFF74817B),
        ),
      ),
    );
  }

  static String _formatInsightMoney(int value) {
    final sign = value < 0 ? '-' : '';
    return '$sign${_addCommas(value.abs().toString())}';
  }

  static int _safeMonthlyExpense(TransactionService transactionService) {
    try {
      return transactionService.monthlyExpense;
    } catch (_) {
      // Widget previews and tests can render before Supabase is initialized.
      return 0;
    }
  }

  static List<TransactionModel> _safeCurrentUserTransactions(
    TransactionService transactionService,
  ) {
    try {
      return transactionService.currentUserTransactions.toList();
    } catch (_) {
      // Widget previews and tests can render before Supabase is initialized.
      return <TransactionModel>[];
    }
  }

  static String _formatRecentDate(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final difference = today.difference(date).inDays;
    final prefix = difference == 0
        ? 'Today'
        : difference == 1
        ? 'Yesterday'
        : '${value.month}/${value.day}/${value.year}';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$prefix, $hour:$minute $period';
  }

  Widget _buildManualMode() {
    final accent = _isExpense
        ? const Color(0xFFBA1A1A)
        : const Color(0xFF006C53);
    final category = _categoryForKey(_selectedCategory);
    final wallet = WalletService.instance.byId(_selectedWalletId);
    final date = _transactionDate ?? DateTime.now();

    return Column(
      key: const ValueKey(_AddMode.manual),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTransactionTypeTabs(accent),
        SizedBox(height: Responsive.h(context, 16)),
        _buildRefinedAmountField(accent),
        SizedBox(height: Responsive.h(context, 22)),
        Material(
          key: const Key('manual_source_field'),
          color: Colors.transparent,
          child: InkWell(
            onTap: _showSourceSelection,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payment method',
                      style: _manualSectionTitleStyle,
                    ),
                  ),
                  Text(
                    _sourceDisplayName(wallet?.name ?? _selectedWalletName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: 11,
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18, color: accent),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 10)),
        Row(
          children: [
            Expanded(
              child: _buildPaymentMethodChip(
                type: WalletType.cash,
                label: 'Cash',
                icon: Icons.payments_outlined,
                accent: accent,
                selected:
                    wallet?.type == WalletType.cash ||
                    _selectedAcctCategory == _AccountCategory.cash,
              ),
            ),
            SizedBox(width: Responsive.w(context, 10)),
            Expanded(
              child: _buildPaymentMethodChip(
                type: WalletType.transfer,
                label: 'Transfer',
                icon: Icons.swap_horiz_rounded,
                accent: accent,
                selected:
                    wallet?.type == WalletType.transfer ||
                    _selectedAcctCategory == _AccountCategory.transfer,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(context, 24)),
        Text('From category', style: _manualSectionTitleStyle),
        SizedBox(height: Responsive.h(context, 10)),
        _buildSelectionField(
          fieldKey: const Key('manual_category_field'),
          label: 'CATEGORY',
          value: category.label,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(category.icon, color: category.color, size: 20),
          ),
          onTap: _showCategorySelection,
          accent: accent,
          highlighted: false,
        ),
        SizedBox(height: Responsive.h(context, 16)),
        _buildSelectionField(
          label: 'DATE',
          value: _formatDate(date),
          leading: Icon(Icons.calendar_today_outlined, color: accent, size: 21),
          trailing: const Icon(Icons.calendar_month_outlined, size: 19),
          onTap: _pickDate,
          accent: accent,
        ),
        SizedBox(height: Responsive.h(context, 12)),
        _buildNameField(accent),
        if (widget.fromQuickAdd) ...[
          SizedBox(height: Responsive.h(context, 10)),
          const Text(
            'From Quick Add',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              color: Color(0xFF006C46),
            ),
          ),
        ],
        SizedBox(height: Responsive.h(context, 18)),
        _buildPrimaryButton(
          label: 'Save Transaction',
          color: const Color(0xFF006C53),
          foregroundColor: Colors.white,
          isLoading: _isSavingTransaction,
          onPressed: _saveManualTransaction,
        ),
      ],
    );
  }

  TextStyle get _manualSectionTitleStyle => const TextStyle(
    fontFamily: 'Hanken Grotesk',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFF45534D),
  );

  Widget _buildTransactionTypeTabs(Color accent) {
    return Row(
      children: [
        Expanded(
          child: _buildTransactionTypeTab(
            label: 'New Income',
            selected: !_isExpense,
            accent: accent,
            onTap: () => setState(() => _isExpense = false),
          ),
        ),
        Expanded(
          child: _buildTransactionTypeTab(
            label: 'New Expense',
            selected: _isExpense,
            accent: accent,
            onTap: () => setState(() => _isExpense = true),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTypeTab({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 11)),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? accent : const Color(0xFFDDE5E1),
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? accent : const Color(0xFF7A8781),
          ),
        ),
      ),
    );
  }

  Widget _buildRefinedAmountField(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('AMOUNT (VND)', style: _labelStyle),
        SizedBox(height: Responsive.h(context, 4)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('manual_amount_field'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                cursorColor: accent,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: Responsive.sp(context, 44),
                  fontWeight: FontWeight.w700,
                  color: accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: accent.withValues(alpha: 0.26)),
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0xFFC3C7CF),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0xFFC3C7CF),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent, width: 1.8),
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
                  color: accent.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodChip({
    required WalletType type,
    required String label,
    required IconData icon,
    required Color accent,
    required bool selected,
  }) {
    return Material(
      color: selected ? accent : Colors.white,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: () => _selectWalletType(type),
        borderRadius: BorderRadius.circular(99),
        child: Container(
          constraints: BoxConstraints(minHeight: Responsive.h(context, 42)),
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? accent : const Color(0xFFDDE5E1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_rounded : icon,
                size: 17,
                color: selected ? Colors.white : const Color(0xFF56645E),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF45534D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectWalletType(WalletType type) async {
    final matches = WalletService.instance.currentUserWallets
        .where((wallet) => wallet.type == type && wallet.isActive)
        .toList(growable: false);
    if (matches.isEmpty) {
      await _showSourceSelection();
      return;
    }
    final wallet = matches.first;
    if (!mounted) return;
    setState(() {
      _selectedWalletId = wallet.id;
      _selectedWalletName = wallet.name;
      _selectedAcctCategory = _accountCategoryFor(wallet.type);
    });
  }

  String _sourceDisplayName(String? name) {
    if (name == null || name.isEmpty) return 'Select payment method';
    return name;
  }

  Widget _buildQuickMode() {
    return QuickAddCard(
      key: const ValueKey(_AddMode.quick),
      controller: _quickAddController,
      isLoading: _isQuickAddParsing,
      isRecording: _isVoiceRecording,
      isVoiceProcessing: _isVoiceProcessing,
      onSubmit: _submitQuickAdd,
      onVoiceTap: _handleVoiceTap,
    );
  }

  Widget _buildScanMode() {
    return const ScanScreen(key: ValueKey(_AddMode.scan), embedded: true);
  }

  Widget _buildSelectionField({
    Key? fieldKey,
    required String label,
    required String value,
    required Widget leading,
    required VoidCallback onTap,
    required Color accent,
    Widget? trailing,
    bool highlighted = false,
  }) {
    return Semantics(
      button: true,
      label: '$label, $value',
      child: Material(
        key: fieldKey,
        color: highlighted ? accent.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: BoxConstraints(minHeight: Responsive.h(context, 70)),
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 14),
              vertical: Responsive.h(context, 10),
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: highlighted ? accent : const Color(0xFFC3C7CF),
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(width: 30, height: 40, child: Center(child: leading)),
                SizedBox(width: Responsive.w(context, 10)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: _labelStyle.copyWith(fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: 15,
                          color: Color(0xFF1A1C1E),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('TRANSACTION NAME', style: _labelStyle),
        SizedBox(height: Responsive.h(context, 4)),
        TextField(
          key: const Key('manual_name_field'),
          controller: _nameController,
          textInputAction: TextInputAction.done,
          cursorColor: accent,
          decoration: InputDecoration(
            hintText: 'Enter transaction name...',
            prefixIcon: Icon(Icons.edit_note_rounded, color: accent, size: 24),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFC3C7CF), width: 1.5),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFC3C7CF), width: 1.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent, width: 1.8),
            ),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              vertical: Responsive.h(context, 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required Color color,
    required Color foregroundColor,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: color.withValues(alpha: 0.55),
        minimumSize: Size.fromHeight(Responsive.h(context, 54)),
        shape: const StadiumBorder(),
        elevation: 6,
        shadowColor: color.withValues(alpha: 0.35),
      ),
      child: isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: foregroundColor,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
    );
  }

  TextStyle get _labelStyle => const TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 11,
    height: 1.2,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
    color: Color(0xFF5F6368),
  );

  void _formatAmount() {
    if (_isFormatting) return;
    _isFormatting = true;
    final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final formatted = digits.isEmpty ? '' : _addCommas(digits);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormatting = false;
  }

  static String _addCommas(String digits) {
    return digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _transactionDate = picked);
  }

  Future<void> _showCategorySelection() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          TransactionCategorySelectionSheet(initialKey: _selectedCategory),
    );
    if (result != null && mounted) setState(() => _selectedCategory = result);
  }

  Future<void> _showSourceSelection() async {
    final selected = await showModalBottomSheet<WalletPreset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SourceSelectionSheet(
        selectedName: _selectedWalletName,
        selectedType: _selectedAcctCategory,
      ),
    );
    if (selected == null || !mounted) return;
    _selectedWalletName = selected.name;
    _selectedAcctCategory = _accountCategoryFor(selected.type);
    await _createWalletSync(
      name: selected.name,
      logoAssetPath: selected.logoAssetPath,
      brandColor: selected.brandColor,
      type: selected.type,
    );
    if (mounted) setState(() {});
  }

  Future<void> _createWalletSync({
    required String name,
    required String logoAssetPath,
    required Color brandColor,
    required WalletType type,
  }) async {
    final existing = WalletService.instance.currentUserWallets
        .where((wallet) => wallet.name == name && wallet.type == type)
        .toList();
    if (existing.isNotEmpty) {
      _selectedWalletId = existing.first.id;
      return;
    }
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    final id = 'w_${DateTime.now().millisecondsSinceEpoch}';
    await WalletService.instance.insertWallets([
      WalletModel(
        id: id,
        userId: userId,
        name: name,
        logoAssetPath: logoAssetPath,
        brandColor: brandColor,
        type: type,
        initialBalance: 0,
      ),
    ]);
    _selectedWalletId = id;
  }

  Future<void> _saveManualTransaction() async {
    final amount = int.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showMessage(AppStrings.pleaseEnterValidAmount);
      return;
    }
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      _showMessage(AppStrings.pleaseSignInFirst);
      return;
    }
    if (_selectedWalletId == null) {
      _showMessage('Please select a payment method');
      return;
    }
    try {
      setState(() => _isSavingTransaction = true);
      final inputName = _nameController.text.trim();
      final transaction = TransactionModel(
        id: 't_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        name: inputName.isNotEmpty ? inputName : _selectedCategory,
        category: _selectedCategory,
        amount: amount * (_isExpense ? -1 : 1),
        date: _transactionDate ?? DateTime.now(),
        walletId: _selectedWalletId,
      );
      await ref.read(transactionServiceProvider).add(transaction);
      if (!mounted) return;
      if (widget.fromQuickAdd) {
        _popRoute(true);
      } else {
        _allowPop = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TransactionSavedScreen(transaction: transaction),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isSavingTransaction = false);
    }
  }

  Future<void> _requestClose() async {
    final hasInput =
        _amountController.text.isNotEmpty ||
        _nameController.text.isNotEmpty ||
        _quickAddController.text.isNotEmpty ||
        _selectedWalletId != null;
    if (hasInput) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard transaction?'),
          content: const Text('Your unsaved changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    _popRoute();
  }

  void _popRoute([bool? result]) {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
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

  static _AccountCategory _accountCategoryFor(WalletType type) {
    return switch (type) {
      WalletType.cash => _AccountCategory.cash,
      WalletType.transfer => _AccountCategory.transfer,
    };
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day/${value.year}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Quick Add behavior below mirrors the former Home implementation.
  Future<void> _submitQuickAdd(String input) async {
    if (_isQuickAddParsing ||
        _isQuickAddReviewOpen ||
        _isVoiceRecording ||
        _isVoiceProcessing) {
      return;
    }
    final text = input.trim();
    if (text.isEmpty) {
      _showMessage(
        AppLanguage.instance.locale == AppLocale.vietnamese
            ? 'Vui lòng nhập nội dung giao dịch.'
            : 'Please enter a transaction.',
      );
      return;
    }
    setState(() => _isQuickAddParsing = true);
    try {
      final draft = await QuickAddService.instance.parse(text);
      if (!mounted) return;
      setState(() {
        _isQuickAddParsing = false;
        _isQuickAddReviewOpen = true;
        if (_voiceState == _QuickAddVoiceState.parsing) {
          _voiceState = _QuickAddVoiceState.idle;
        }
      });
      final action = await QuickAddReviewSheet.show(
        context,
        draft: draft,
        onConfirm: () => _confirmQuickAdd(draft),
      );
      if (!mounted) return;
      _isQuickAddReviewOpen = false;
      if (action == QuickAddReviewAction.confirmed) {
        _quickAddController.clear();
        final userId = ref.read(authServiceProvider).currentUser?.id;
        if (userId == null || !mounted) return;
        final saved = draft.toTransactionModel(
          id: 't_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
        );
        _allowPop = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TransactionSavedScreen(transaction: saved),
          ),
        );
      } else if (action == QuickAddReviewAction.editDetails) {
        _applyDraftToManual(draft);
      }
    } on QuickAddException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          AppLanguage.instance.locale == AppLocale.vietnamese
              ? 'Không thể phân tích giao dịch lúc này.'
              : 'Unable to parse the transaction right now.',
        );
      }
    } finally {
      if (mounted &&
          (_isQuickAddParsing || _voiceState == _QuickAddVoiceState.parsing)) {
        setState(() {
          _isQuickAddParsing = false;
          if (_voiceState == _QuickAddVoiceState.parsing) {
            _voiceState = _QuickAddVoiceState.idle;
          }
        });
      }
    }
  }

  Future<void> _confirmQuickAdd(QuickAddDraft draft) async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    await ref
        .read(transactionServiceProvider)
        .add(
          draft.toTransactionModel(
            id: 't_${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
          ),
        );
  }

  void _applyDraftToManual(QuickAddDraft draft) {
    setState(() {
      _mode = _AddMode.manual;
      _isExpense = draft.type != QuickAddTransactionType.income;
      _amountController.text = draft.amount == null
          ? ''
          : _addCommas(draft.amount!.abs().toString());
      _nameController.text = draft.name ?? '';
      _selectedCategory = draft.categoryKey ?? 'Other';
      _selectedWalletId = draft.walletId;
      _selectedWalletName = draft.walletName;
      _transactionDate = draft.date;
      final wallet = WalletService.instance.byId(draft.walletId);
      if (wallet != null) {
        _selectedWalletName = wallet.name;
        _selectedAcctCategory = _accountCategoryFor(wallet.type);
      }
    });
  }

  Future<void> _handleVoiceTap() async {
    if (_isQuickAddParsing || _isQuickAddReviewOpen || _isVoiceProcessing) {
      return;
    }
    if (_isVoiceRecording) {
      await _stopVoiceListening();
      return;
    }
    final session = ++_voiceSession;
    _voiceFinalHandled = false;
    _latestVoiceTranscript = '';
    setState(() => _voiceState = _QuickAddVoiceState.initializing);
    try {
      final speech = QuickAddSpeechRecognitionService.instance;
      final available = await speech.initialize(
        onStatus: (status) => _handleVoiceStatus(session, status),
        onError: (error) => _handleVoiceError(session, error),
      );
      if (!mounted || session != _voiceSession) return;
      if (!available) {
        throw const QuickAddSpeechException(
          'RECOGNIZER_UNAVAILABLE',
          'Speech recognition is unavailable.',
        );
      }
      if (!speech.usesVietnameseLocale) {
        _showMessage(
          AppLanguage.instance.locale == AppLocale.vietnamese
              ? 'Không có nhận diện tiếng Việt; đang dùng ngôn ngữ hệ thống.'
              : 'Vietnamese recognition is unavailable; using system locale.',
        );
      }
      await speech.startListening(
        onResult: (result) => _handleVoiceResult(session, result),
      );
      if (!mounted || session != _voiceSession) {
        await speech.cancelListening();
        return;
      }
      setState(() => _voiceState = _QuickAddVoiceState.listening);
      _voiceTimeout?.cancel();
      _voiceTimeout = Timer(
        const Duration(seconds: 30),
        () => _finishVoiceAfterStop(session, timedOut: true),
      );
    } on QuickAddSpeechException catch (error) {
      _showVoiceErrorIfCurrent(session, error.code);
    } catch (_) {
      _showVoiceErrorIfCurrent(session, 'RECOGNIZER_UNAVAILABLE');
    }
  }

  void _handleVoiceResult(int session, QuickAddSpeechResult result) {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    final transcript = result.text.trim();
    if (transcript.isNotEmpty) {
      _latestVoiceTranscript = transcript;
      _quickAddController.value = TextEditingValue(
        text: transcript,
        selection: TextSelection.collapsed(offset: transcript.length),
      );
    }
    if (result.isFinal) {
      unawaited(_submitFinalVoiceTranscript(session, transcript));
    }
  }

  void _handleVoiceStatus(int session, String status) {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    final normalized = status.toLowerCase();
    if (normalized == 'done' || normalized == 'notlistening') {
      _voiceTimeout?.cancel();
      _voiceTimeout = Timer(
        const Duration(milliseconds: 300),
        () => _submitFinalVoiceTranscript(session, _latestVoiceTranscript),
      );
    }
  }

  void _handleVoiceError(int session, QuickAddSpeechException error) {
    _showVoiceErrorIfCurrent(session, error.code);
  }

  Future<void> _stopVoiceListening() async {
    if (!_isVoiceRecording || _isVoiceProcessing) return;
    final session = _voiceSession;
    _voiceTimeout?.cancel();
    setState(() => _voiceState = _QuickAddVoiceState.processingFinal);
    try {
      await QuickAddSpeechRecognitionService.instance.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _submitFinalVoiceTranscript(session, _latestVoiceTranscript);
    } on QuickAddSpeechException catch (error) {
      _showVoiceErrorIfCurrent(session, error.code);
    } catch (_) {
      _showVoiceErrorIfCurrent(session, 'RECOGNIZER_ERROR');
    }
  }

  Future<void> _finishVoiceAfterStop(
    int session, {
    required bool timedOut,
  }) async {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    setState(() => _voiceState = _QuickAddVoiceState.processingFinal);
    try {
      await QuickAddSpeechRecognitionService.instance.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (_latestVoiceTranscript.trim().isEmpty && timedOut) {
        _showVoiceErrorIfCurrent(session, 'RECOGNITION_TIMEOUT');
        return;
      }
      await _submitFinalVoiceTranscript(session, _latestVoiceTranscript);
    } catch (_) {
      _showVoiceErrorIfCurrent(session, 'RECOGNIZER_ERROR');
    }
  }

  Future<void> _submitFinalVoiceTranscript(int session, String value) async {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    final transcript = value.trim();
    if (transcript.isEmpty) {
      _showVoiceErrorIfCurrent(session, 'EMPTY_TRANSCRIPT');
      return;
    }
    _voiceFinalHandled = true;
    _voiceTimeout?.cancel();
    _quickAddController.value = TextEditingValue(
      text: transcript,
      selection: TextSelection.collapsed(offset: transcript.length),
    );
    setState(() => _voiceState = _QuickAddVoiceState.parsing);
    await _submitQuickAdd(transcript);
  }

  void _showVoiceErrorIfCurrent(int session, String code) {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    _voiceFinalHandled = true;
    _voiceTimeout?.cancel();
    setState(() => _voiceState = _QuickAddVoiceState.error);
    _showMessage(_localizedVoiceError(code));
    if (mounted && session == _voiceSession) {
      setState(() => _voiceState = _QuickAddVoiceState.idle);
    }
  }

  String _localizedVoiceError(String code) {
    final vi = AppLanguage.instance.locale == AppLocale.vietnamese;
    return switch (code) {
      'MICROPHONE_PERMISSION_DENIED' || 'error_permission' =>
        vi
            ? 'Cần quyền microphone để nhập giao dịch bằng giọng nói.'
            : 'Microphone permission is required for voice Quick Add.',
      'EMPTY_TRANSCRIPT' || 'error_no_match' =>
        vi
            ? 'Không nhận diện được nội dung giọng nói.'
            : 'No speech could be recognized.',
      'RECOGNITION_TIMEOUT' || 'error_speech_timeout' =>
        vi
            ? 'Không nhận diện được giọng nói trong thời gian cho phép.'
            : 'No speech was recognized before the timeout.',
      'RECOGNIZER_UNAVAILABLE' =>
        vi
            ? 'Thiết bị không có dịch vụ nhận diện giọng nói khả dụng.'
            : 'Speech recognition is unavailable on this device.',
      _ =>
        vi
            ? 'Nhận diện giọng nói hiện không khả dụng. Vui lòng thử lại.'
            : 'Speech recognition is unavailable. Please try again.',
    };
  }
}

class _QuickCategoryButton extends StatelessWidget {
  const _QuickCategoryButton({
    required this.category,
    required this.onTap,
    this.outlined = false,
  });

  final TransactionCategory category;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          width: Responsive.w(context, 58),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: Responsive.w(context, 42),
                height: Responsive.w(context, 42),
                decoration: BoxDecoration(
                  color: outlined
                      ? Colors.transparent
                      : category.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: outlined
                      ? Border.all(
                          color: const Color(0xFF8CB3A7),
                          style: BorderStyle.solid,
                        )
                      : null,
                ),
                child: Icon(
                  category.icon,
                  size: 20,
                  color: outlined ? const Color(0xFF006C53) : category.color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: 9,
                  color: Color(0xFF617069),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionCategorySelectionSheet extends StatefulWidget {
  const TransactionCategorySelectionSheet({
    super.key,
    required this.initialKey,
  });

  final String initialKey;

  @override
  State<TransactionCategorySelectionSheet> createState() =>
      _TransactionCategorySelectionSheetState();
}

class _TransactionCategorySelectionSheetState
    extends State<TransactionCategorySelectionSheet> {
  late String _selectedKey = widget.initialKey;

  List<TransactionCategory> get _categories => [
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

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const _SheetHandle(),
              _SheetHeader(
                title: 'Select Category',
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: _categories.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == _categories.length) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5EF),
                          child: Icon(
                            Icons.add_rounded,
                            color: Color(0xFF006C46),
                          ),
                        ),
                        title: const Text('Create custom category'),
                        onTap: _createCustomCategory,
                      );
                    }
                    final category = _categories[index];
                    final selected = category.key == _selectedKey;
                    return Semantics(
                      button: true,
                      selected: selected,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        onTap: () =>
                            setState(() => _selectedKey = category.key),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: category.color,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 7,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            category.icon,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                        title: Text(
                          category.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF00D09E),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              _SheetApplyButton(
                label: 'Apply Selection',
                onPressed: () => Navigator.of(context).pop(_selectedKey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCustomCategory() async {
    final created = await showDialog<CustomCategoryDef>(
      context: context,
      builder: (_) => const _CreateCategoryDialog(),
    );
    if (created == null || !mounted) return;
    CustomCategoryStore.instance.add(created);
    setState(() => _selectedKey = created.name);
  }
}

class _SourceSelectionSheet extends StatefulWidget {
  const _SourceSelectionSheet({this.selectedName, this.selectedType});

  final String? selectedName;
  final _AccountCategory? selectedType;

  @override
  State<_SourceSelectionSheet> createState() => _SourceSelectionSheetState();
}

class _SourceSelectionSheetState extends State<_SourceSelectionSheet> {
  WalletPreset? _selected;

  static const _cash = WalletPreset(
    name: 'Tiền mặt',
    logoAssetPath: 'assets/logos/ewallets/cash.png',
    brandColor: Color(0xFF4CAF50),
    type: WalletType.cash,
  );

  static const _transfer = WalletPreset(
    name: 'Chuyển khoản',
    logoAssetPath: 'assets/logos/ewallets/other.png',
    brandColor: Color(0xFF2878D0),
    type: WalletType.transfer,
  );

  @override
  void initState() {
    super.initState();
    const all = [_cash, _transfer];
    for (final preset in all) {
      if (preset.name == widget.selectedName &&
          _AddTransactionSheetState._accountCategoryFor(preset.type) ==
              widget.selectedType) {
        _selected = preset;
        break;
      }
    }
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
              const _SheetHandle(),
              _SheetHeader(
                title: 'Select Payment Method',
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _section('PAYMENT METHOD', const [_cash, _transfer]),
                  ],
                ),
              ),
              _SheetApplyButton(
                label: 'Apply Selection',
                onPressed: _selected == null
                    ? null
                    : () => Navigator.of(context).pop(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<WalletPreset> presets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ...presets.map(_sourceRow),
      ],
    );
  }

  Widget _sourceRow(WalletPreset preset) {
    final selected =
        _selected?.name == preset.name && _selected?.type == preset.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => setState(() => _selected = preset),
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
                    color: preset.brandColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    preset.logoAssetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      preset.type == WalletType.cash
                          ? Icons.payments_outlined
                          : Icons.swap_horiz_rounded,
                      color: preset.brandColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        switch (preset.type) {
                          WalletType.cash => 'Cash payment',
                          WalletType.transfer => 'Cashless payment',
                        },
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6D7B74),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected
                      ? const Color(0xFF00D09E)
                      : const Color(0xFF1A1C1E),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD5DAD7),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SheetApplyButton extends StatelessWidget {
  const _SheetApplyButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: const Color(0xFF002112),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _CreateCategoryDialog extends StatefulWidget {
  const _CreateCategoryDialog();

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  final _controller = TextEditingController();
  var _icon = _customIcons.first;
  var _color = _customColors.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLength: 24,
              decoration: const InputDecoration(labelText: 'Category name'),
            ),
            const SizedBox(height: 12),
            const Text('Icon'),
            Wrap(
              spacing: 6,
              children: _customIcons.map((icon) {
                return IconButton.filledTonal(
                  onPressed: () => setState(() => _icon = icon),
                  style: IconButton.styleFrom(
                    backgroundColor: _icon == icon
                        ? _color.withValues(alpha: 0.22)
                        : null,
                  ),
                  icon: Icon(icon, color: _icon == icon ? _color : null),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            const Text('Color'),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _customColors.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == color
                            ? Colors.black
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              CustomCategoryDef(name: name, iconData: _icon, color: _color),
            );
          },
          child: const Text('Save Category'),
        ),
      ],
    );
  }
}
