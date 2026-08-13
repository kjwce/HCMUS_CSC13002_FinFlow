import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../app/shell/finflow_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../scan/models/scan_result_model.dart';
import '../../scan/presentation/scan_screen.dart';
import '../models/quick_add_draft_model.dart';
import '../models/goal_model.dart';
import '../models/transaction_category.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/goal_provider.dart';
import '../services/quick_add_service.dart';
import '../services/quick_add_speech_recognition_service.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';
import 'quick_add_review_sheet.dart';
import 'goal_sheets.dart';
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

const _addTransactionBackground = Color(0xFFEDF7F3);
const _addTransactionDarkBackground = Color(0xFF081C18);
const _addTransactionDarkSurface = Color(0xFF16352E);
const _addTransactionDarkRaisedSurface = Color(0xFF1C4037);
const _addTransactionDarkBorder = Color(0xFF29483F);
const _addTransactionDarkText = Color(0xFFF4FBF8);
const _addTransactionDarkSecondaryText = Color(0xFFA9C1B9);
const _addTransactionDarkMutedText = Color(0xFF708D84);

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
    this.scanImagePicker,
    this.scanReceiptParser,
  });

  final bool? initialIsExpense;
  final int? initialAmount;
  final String? initialName;
  final String? initialCategoryKey;
  final String? initialWalletId;
  final DateTime? initialDate;
  final bool fromQuickAdd;

  /// Test seams for exercising the embedded receipt flow without platform I/O.
  final ReceiptImagePicker? scanImagePicker;
  final ReceiptFileParser? scanReceiptParser;

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
  success,
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
  QuickAddDraft? _quickAddDraft;
  String? _quickAddErrorMessage;
  var _voiceState = _QuickAddVoiceState.idle;
  var _voiceSession = 0;
  var _quickParseSession = 0;
  var _voiceFinalHandled = false;
  var _latestVoiceTranscript = '';
  var _voiceSoundLevel = 0.0;
  Timer? _voiceTimeout;
  Timer? _modeNavigationTimer;

  bool get _isVoiceRecording => _voiceState == _QuickAddVoiceState.listening;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDark ? _addTransactionDarkBackground : _addTransactionBackground;
  Color get _surface => _isDark ? _addTransactionDarkSurface : Colors.white;
  Color get _raisedSurface =>
      _isDark ? _addTransactionDarkRaisedSurface : const Color(0xFFE0F2ED);
  Color get _border =>
      _isDark ? _addTransactionDarkBorder : const Color(0xFFE4EAE7);
  Color get _primaryText =>
      _isDark ? _addTransactionDarkText : const Color(0xFF1A1C1E);
  Color get _mutedText =>
      _isDark ? _addTransactionDarkMutedText : const Color(0xFF74817B);
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
            _returnToModePicker();
          } else {
            unawaited(_requestClose());
          }
        }
      },
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [...previousChildren, ?currentChild],
                    );
                  },
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
                                  Responsive.w(
                                    context,
                                    _mode == _AddMode.manual ? 16 : 20,
                                  ),
                                  Responsive.h(
                                    context,
                                    _mode == _AddMode.manual ? 16 : 20,
                                  ),
                                  Responsive.w(
                                    context,
                                    _mode == _AddMode.manual ? 16 : 20,
                                  ),
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
      _AddMode.manual => AppStrings.choose('Manual Entry', 'Nhập thủ công'),
      _AddMode.quick => AppStrings.choose(
        'Voice - Quick Add',
        'Giọng nói - Thêm nhanh',
      ),
      _AddMode.scan => AppStrings.choose('Scan', 'Quét'),
      _ => AppStrings.choose('Add transaction', 'Thêm giao dịch'),
    };
    return Container(
      height: Responsive.h(context, _mode == _AddMode.manual ? 52 : 64),
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 10)),
      decoration: BoxDecoration(color: _pageBackground),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _handleHeaderBack,
              tooltip: AppStrings.choose('Back', 'Quay lại'),
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 22,
                color: _isDark
                    ? _addTransactionDarkText
                    : const Color(0xFF43474E),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: Responsive.sp(context, 18),
              fontWeight: FontWeight.w600,
              color: _primaryText,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.more_horiz_rounded,
              color: _isDark
                  ? _addTransactionDarkText
                  : const Color(0xFF43474E),
            ),
          ),
        ],
      ),
    );
  }

  void _handleHeaderBack() {
    if (_mode != null && !widget.fromQuickAdd) {
      _returnToModePicker();
      return;
    }
    unawaited(_requestClose());
  }

  void _returnToModePicker() {
    if (_mode == _AddMode.quick) {
      _voiceSession++;
      _quickParseSession++;
      _voiceTimeout?.cancel();
      unawaited(QuickAddSpeechRecognitionService.instance.cancelListening());
    }
    setState(() {
      _mode = null;
      _selectedInputMode = null;
      _voiceState = _QuickAddVoiceState.idle;
      _voiceSoundLevel = 0;
      _isQuickAddParsing = false;
      _quickAddDraft = null;
      _quickAddErrorMessage = null;
    });
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
        Responsive.w(context, 16),
        Responsive.h(context, 6),
        Responsive.w(context, 16),
        Responsive.h(context, 28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPromptRow(isOverBudget: isOverBudget),
          SizedBox(height: Responsive.h(context, 14)),
          _buildBudgetInsightCard(
            budgetLimit: budgetLimit,
            remaining: remaining,
            shouldSpend: shouldSpend,
            daysLeft: daysLeft,
            isOverBudget: isOverBudget,
          ),
          SizedBox(height: Responsive.h(context, 14)),
          _buildHabitBanner(),
          SizedBox(height: Responsive.h(context, 22)),
          Text(
            AppStrings.choose('CHOOSE INPUT METHOD', 'CHỌN CÁCH NHẬP'),
            style: _labelStyle,
          ),
          SizedBox(height: Responsive.h(context, 11)),
          Row(
            children: [
              Expanded(
                child: _buildInputModeCard(
                  key: const Key('add_mode_manual'),
                  mode: _AddMode.manual,
                  icon: Icons.keyboard_alt_outlined,
                  label: AppStrings.choose('MANUAL ENTRY', 'NHẬP THỦ CÔNG'),
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
                  label: AppStrings.choose('VOICE', 'GIỌNG NÓI'),
                  tint: const Color(0xFFE5F5F0),
                  foreground: const Color(0xFF006C53),
                  selected: _selectedInputMode == _AddMode.quick,
                  badge: AppStrings.choose('FAST', 'NHANH'),
                ),
              ),
              SizedBox(width: Responsive.w(context, 10)),
              Expanded(
                child: _buildInputModeCard(
                  key: const Key('add_mode_scan'),
                  mode: _AddMode.scan,
                  icon: Icons.photo_camera_outlined,
                  label: AppStrings.choose('SCAN', 'QUÉT'),
                  tint: const Color(0xFFFFE7E1),
                  foreground: const Color(0xFFBA4B3D),
                  selected: _selectedInputMode == _AddMode.scan,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 24)),
          Text(
            AppStrings.choose('QUICK CATEGORIES', 'DANH MỤC NHANH'),
            style: _labelStyle,
          ),
          SizedBox(height: Responsive.h(context, 11)),
          _buildQuickCategories(),
          SizedBox(height: Responsive.h(context, 24)),
          Text(
            AppStrings.choose('RECENT TRANSACTIONS', 'GIAO DỊCH GẦN ĐÂY'),
            style: _labelStyle,
          ),
          SizedBox(height: Responsive.h(context, 11)),
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
          width: Responsive.w(context, 48),
          height: Responsive.w(context, 48),
          decoration: BoxDecoration(
            color: isOverBudget ? Colors.transparent : const Color(0xFF64D2AE),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x2464D2AE),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
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
                    child: Text('😊', style: TextStyle(fontSize: 24)),
                  ),
          ),
        ),
        SizedBox(width: Responsive.w(context, 12)),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 16),
              vertical: Responsive.h(context, 14),
            ),
            decoration: BoxDecoration(
              color: _raisedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
              boxShadow: _isDark
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x0F006C53),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Text(
              AppStrings.choose(
                'What did you spend money on today?',
                'Hôm nay bạn đã chi tiền cho việc gì?',
              ),
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _isDark
                    ? _addTransactionDarkSecondaryText
                    : const Color(0xFF30413B),
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
        : _isDark
        ? const [Color(0xFF005C47), Color(0xFF004233)]
        : const [Color(0xFF006C53), Color(0xFF008F70)];
    final amountColor = isOverBudget ? const Color(0xFFFF777C) : Colors.white;

    return Container(
      constraints: BoxConstraints(minHeight: Responsive.h(context, 132)),
      padding: EdgeInsets.all(Responsive.w(context, 18)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x36005A45),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x18006C53),
            blurRadius: 7,
            offset: Offset(0, 3),
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
                  AppStrings.choose('REMAINING BALANCE', 'SỐ DƯ CÒN LẠI'),
                  style: _labelStyle.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 10,
                  ),
                ),
              ),
              _buildDaysLeftChip(daysLeft),
            ],
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: hasBudget
                      ? _formatInsightMoney(remaining)
                      : AppStrings.choose(
                          'No budget set',
                          'Chưa đặt ngân sách',
                        ),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, hasBudget ? 29 : 22),
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
          SizedBox(height: Responsive.h(context, 14)),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
          SizedBox(height: Responsive.h(context, 13)),
          Row(
            children: [
              Icon(
                isOverBudget
                    ? Icons.warning_amber_rounded
                    : Icons.savings_outlined,
                color: isOverBudget
                    ? const Color(0xFFFF777C)
                    : const Color(0xFFA6F2D7),
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverBudget
                          ? AppStrings.choose(
                              'DEFICIT WARNING',
                              'CẢNH BÁO THÂM HỤT',
                            )
                          : AppStrings.choose(
                              'YOU SHOULD SPEND',
                              'BẠN NÊN CHI',
                            ),
                      style: _labelStyle.copyWith(
                        color: isOverBudget
                            ? const Color(0xFFFF777C)
                            : Colors.white.withValues(alpha: 0.65),
                        fontSize: 8.5,
                      ),
                    ),
                    Text(
                      isOverBudget
                          ? AppStrings.choose(
                              'Reduce spending to recover balance',
                              'Giảm chi tiêu để cân đối lại số dư',
                            )
                          : hasBudget
                          ? AppStrings.choose(
                              '${_formatInsightMoney(shouldSpend)} VND/day',
                              '${_formatInsightMoney(shouldSpend)} VND/ngày',
                            )
                          : AppStrings.choose(
                              'Set a monthly budget to see insights',
                              'Đặt ngân sách tháng để xem phân tích',
                            ),
                      style: const TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            AppStrings.choose('$daysLeft DAYS LEFT', 'CÒN $daysLeft NGÀY'),
            style: _labelStyle.copyWith(color: Colors.white, fontSize: 8.5),
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
            ? AppStrings.choose('NO BUDGET', 'CHƯA CÓ NGÂN SÁCH')
            : isOverBudget
            ? AppStrings.choose('OVER BUDGET', 'VƯỢT NGÂN SÁCH')
            : AppStrings.choose('ON TRACK', 'ĐÚNG KẾ HOẠCH'),
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
        horizontal: Responsive.w(context, 15),
        vertical: Responsive.h(context, 12),
      ),
      decoration: BoxDecoration(
        color: _isDark
            ? _addTransactionDarkRaisedSurface
            : const Color(0xFFFFF0D9),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: _isDark ? _addTransactionDarkBorder : const Color(0xFFFFDFC0),
        ),
        boxShadow: _isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x12A45C18),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Text('🔥', style: TextStyle(fontSize: 17)),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              AppStrings.choose(
                "You're building a healthy money habit. Keep it up!",
                'Bạn đang xây dựng thói quen tài chính tốt. Hãy tiếp tục nhé!',
              ),
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _isDark
                    ? const Color(0xFFFFBF47)
                    : const Color(0xFF704E24),
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
      height: Responsive.h(context, 110),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            key: key,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF00513E) : _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFF00513E)
                    : _isDark
                    ? _addTransactionDarkBorder
                    : const Color(0xFFDDE5E1),
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x3000513E),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ]
                  : _isDark
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x18004736),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _selectedInputMode == null
                    ? () => _selectInputMode(mode)
                    : null,
                borderRadius: BorderRadius.circular(16),
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
                        width: Responsive.w(context, 44),
                        height: Responsive.w(context, 44),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF58CCA9)
                              : _isDark
                              ? _addTransactionDarkRaisedSurface
                              : tint,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: selected
                              ? Colors.white
                              : _isDark
                              ? foreground == const Color(0xFFBA4B3D)
                                    ? const Color(0xFFFF6B70)
                                    : const Color(0xFF66C0AA)
                              : foreground,
                          size: 22,
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 7)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 90),
                          style: _labelStyle.copyWith(
                            color: selected
                                ? Colors.white
                                : _isDark
                                ? _addTransactionDarkSecondaryText
                                : foreground,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
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
                    fontSize: 8,
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
              useSafeArea: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => SafeArea(
                top: false,
                child: TransactionCategorySelectionSheet(
                  initialKey: _selectedCategory,
                ),
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
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
        boxShadow: _isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x14004736),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: category.buildIcon(size: 18),
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
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _primaryText,
                  ),
                ),
                Text(
                  _formatRecentDate(transaction.date),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 10.5,
                    color: _mutedText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${_formatInsightMoney(transaction.amount.abs())}đ',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isExpense
                  ? (_isDark
                        ? const Color(0xFFFF6B70)
                        : const Color(0xFFC24444))
                  : (_isDark
                        ? const Color(0xFF38D6AC)
                        : const Color(0xFF006C53)),
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
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Text(
        AppStrings.choose(
          'Your latest transactions will appear here.',
          'Các giao dịch mới nhất sẽ xuất hiện tại đây.',
        ),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontSize: 12,
          color: _mutedText,
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
        ? AppStrings.choose('Today', 'Hôm nay')
        : difference == 1
        ? AppStrings.choose('Yesterday', 'Hôm qua')
        : AppStrings.isVietnamese
        ? '${value.day}/${value.month}/${value.year}'
        : '${value.month}/${value.day}/${value.year}';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return AppStrings.isVietnamese
        ? '$prefix, ${value.hour.toString().padLeft(2, '0')}:$minute'
        : '$prefix, $hour:$minute $period';
  }

  Widget _buildManualMode() {
    final accent = _isExpense
        ? (_isDark ? const Color(0xFFD9434E) : const Color(0xFFBA1A1A))
        : (_isDark ? const Color(0xFF82D7B8) : const Color(0xFF006C53));
    final controlAccent = _isDark ? const Color(0xFF82D7B8) : accent;
    final category = _categoryForKey(_selectedCategory);
    final wallet = WalletService.instance.byId(_selectedWalletId);
    final date = _transactionDate ?? DateTime.now();

    return Column(
      key: const ValueKey(_AddMode.manual),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTransactionTypeTabs(accent),
        SizedBox(height: Responsive.h(context, 16)),
        Text(
          AppStrings.choose('AMOUNT', 'SỐ TIỀN'),
          style: _manualSectionTitleStyle,
        ),
        SizedBox(height: Responsive.h(context, 8)),
        _buildRefinedAmountField(controlAccent),
        SizedBox(height: Responsive.h(context, 22)),
        Text(
          AppStrings.choose('PAYMENT METHOD', 'PHƯƠNG THỨC THANH TOÁN'),
          style: _manualSectionTitleStyle,
        ),
        SizedBox(height: Responsive.h(context, 10)),
        GestureDetector(
          key: const Key('manual_source_field'),
          behavior: HitTestBehavior.opaque,
          onTap: _showSourceSelection,
          child: Semantics(
            button: true,
            label: _sourceDisplayName(wallet?.name ?? _selectedWalletName),
            child: Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodChip(
                    type: WalletType.cash,
                    label: AppStrings.choose('Cash', 'Tiền mặt'),
                    icon: Icons.payments_outlined,
                    accent: controlAccent,
                    selected:
                        wallet?.type == WalletType.cash ||
                        _selectedAcctCategory == _AccountCategory.cash,
                  ),
                ),
                SizedBox(width: Responsive.w(context, 10)),
                Expanded(
                  child: _buildPaymentMethodChip(
                    type: WalletType.transfer,
                    label: AppStrings.choose('Transfer', 'Chuyển khoản'),
                    icon: Icons.account_balance_outlined,
                    accent: controlAccent,
                    selected:
                        wallet?.type == WalletType.transfer ||
                        _selectedAcctCategory == _AccountCategory.transfer,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 24)),
        Text(
          AppStrings.choose('TRANSACTION DETAILS', 'CHI TIẾT GIAO DỊCH'),
          style: _manualSectionTitleStyle,
        ),
        SizedBox(height: Responsive.h(context, 10)),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: _isDark
                ? const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ]
                : const [
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
                fieldKey: const Key('manual_category_field'),
                label: AppStrings.choose('CATEGORY', 'DANH MỤC'),
                value: AppStrings.categoryName(category.label),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: category.color.withValues(
                      alpha: _isDark ? 0.2 : 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: category.buildIcon(size: 18),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: controlAccent,
                ),
                onTap: _showCategorySelection,
                accent: controlAccent,
                embedded: true,
              ),
              Divider(height: 1, indent: 62, color: _border),
              _buildSelectionField(
                label: AppStrings.choose('DATE', 'NGÀY'),
                value: _formatDate(date),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xFF123650)
                        : const Color(0xFFE8F0FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    color: _isDark
                        ? const Color(0xFF5B9BFF)
                        : const Color(0xFF3F6FE5),
                    size: 18,
                  ),
                ),
                trailing: Icon(
                  Icons.calendar_month_outlined,
                  size: 19,
                  color: controlAccent,
                ),
                onTap: _pickDate,
                accent: controlAccent,
                embedded: true,
              ),
              Divider(height: 1, indent: 62, color: _border),
              _buildNameField(controlAccent, embedded: true),
            ],
          ),
        ),
        if (widget.fromQuickAdd) ...[
          SizedBox(height: Responsive.h(context, 10)),
          Text(
            AppStrings.choose('From Quick Add', 'Từ Thêm nhanh'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              color: _isDark
                  ? const Color(0xFF82D7B8)
                  : const Color(0xFF006C46),
            ),
          ),
        ],
        SizedBox(height: Responsive.h(context, 24)),
        _buildPrimaryButton(
          label: AppStrings.choose('Save Transaction', 'Lưu giao dịch'),
          color: const Color(0xFF006C53),
          foregroundColor: Colors.white,
          isLoading: _isSavingTransaction,
          onPressed: _saveManualTransaction,
        ),
      ],
    );
  }

  TextStyle get _manualSectionTitleStyle => TextStyle(
    fontFamily: 'Manrope',
    fontSize: 11,
    letterSpacing: 0.45,
    fontWeight: FontWeight.w700,
    color: _isDark ? _addTransactionDarkMutedText : const Color(0xFF263831),
  );

  Widget _buildTransactionTypeTabs(Color accent) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: _isDark
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x12004736),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTransactionTypeTab(
              label: AppStrings.income,
              selected: !_isExpense,
              accent: _isDark
                  ? const Color(0xFF006C53)
                  : const Color(0xFF007C61),
              onTap: () => setState(() => _isExpense = false),
            ),
          ),
          Expanded(
            child: _buildTransactionTypeTab(
              label: AppStrings.expense,
              selected: _isExpense,
              accent: _isDark
                  ? const Color(0xFFD9434E)
                  : const Color(0xFFDF394A),
              onTap: () => setState(() => _isExpense = true),
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 12)),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Colors.white
                : _isDark
                ? _addTransactionDarkSecondaryText
                : const Color(0xFF53615B),
          ),
        ),
      ),
    );
  }

  Widget _buildRefinedAmountField(Color accent) {
    final amountStyle = TextStyle(
      fontFamily: 'Manrope',
      fontSize: Responsive.sp(context, 36),
      height: 1.05,
      fontWeight: FontWeight.w700,
      color: _isDark ? _addTransactionDarkText : accent,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      constraints: BoxConstraints(minHeight: Responsive.h(context, 88)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 18),
        vertical: Responsive.h(context, 12),
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: _isDark
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x16004736),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.centerLeft,
            child: ListenableBuilder(
              listenable: _amountController,
              builder: (context, _) {
                final display = _amountController.text.isEmpty
                    ? '0'
                    : _amountController.text;
                final maxAmountWidth = constraints.maxWidth - 42;
                final baseFontSize = amountStyle.fontSize!;
                var effectiveStyle = amountStyle;
                var painter = TextPainter(
                  text: TextSpan(text: display, style: effectiveStyle),
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                )..layout();

                // Preserve the complete amount for as long as possible.
                // Only very long values fall back to a right-aligned,
                // horizontally scrolling field so their final digits remain
                // visible while editing.
                if (painter.width + 10 > maxAmountWidth) {
                  final fittedSize =
                      (baseFontSize * maxAmountWidth / (painter.width + 10))
                          .clamp(24.0, baseFontSize)
                          .toDouble();
                  effectiveStyle = amountStyle.copyWith(fontSize: fittedSize);
                  painter = TextPainter(
                    text: TextSpan(text: display, style: effectiveStyle),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                  )..layout();
                }

                final isTooLong = painter.width + 10 > maxAmountWidth;
                final fieldWidth = isTooLong
                    ? maxAmountWidth
                    : (painter.width + 10)
                          .clamp(46.0, maxAmountWidth)
                          .toDouble();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        key: const Key('manual_amount_field'),
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textAlign: isTooLong ? TextAlign.right : TextAlign.left,
                        cursorColor: accent,
                        style: effectiveStyle,
                        decoration: InputDecoration(
                          filled: false,
                          hintText: '0',
                          hintStyle: effectiveStyle.copyWith(
                            color: accent.withValues(alpha: 0.3),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        'VND',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isDark ? _addTransactionDarkText : accent,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentMethodChip({
    required WalletType type,
    required String label,
    required IconData icon,
    required Color accent,
    required bool selected,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: _isDark
              ? selected
                    ? const Color(0xFF1B3D35)
                    : _surface
              : selected
              ? accent.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: () => _selectWalletType(type),
            borderRadius: BorderRadius.circular(13),
            child: Container(
              constraints: BoxConstraints(minHeight: Responsive.h(context, 56)),
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 13),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _isDark
                      ? _addTransactionDarkBorder
                      : selected
                      ? accent
                      : const Color(0xFFE2E8E5),
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: _isDark
                    ? const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ]
                    : const [
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? (_isDark ? _surface : Colors.white)
                          : accent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 17, color: accent),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isDark
                            ? _addTransactionDarkText
                            : const Color(0xFF263831),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selected)
          Positioned(
            right: -3,
            top: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: _pageBackground, width: 2),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 11,
                color: _isDark ? _addTransactionDarkBackground : Colors.white,
              ),
            ),
          ),
      ],
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
    if (name == null || name.isEmpty) {
      return AppStrings.choose(
        'Select payment method',
        'Chọn phương thức thanh toán',
      );
    }
    return switch (name) {
      'Cash' => AppStrings.choose('Cash', 'Tiền mặt'),
      'Transfer' => AppStrings.choose('Transfer', 'Chuyển khoản'),
      _ => name,
    };
  }

  Widget _buildQuickMode() {
    final displayState = switch (_voiceState) {
      _QuickAddVoiceState.idle => QuickAddDisplayState.idle,
      _QuickAddVoiceState.initializing ||
      _QuickAddVoiceState.listening => QuickAddDisplayState.listening,
      _QuickAddVoiceState.processingFinal ||
      _QuickAddVoiceState.parsing => QuickAddDisplayState.processing,
      _QuickAddVoiceState.error => QuickAddDisplayState.error,
      _QuickAddVoiceState.success => QuickAddDisplayState.success,
    };
    return QuickAddCard(
      key: const ValueKey(_AddMode.quick),
      controller: _quickAddController,
      displayState: displayState,
      draft: _quickAddDraft,
      errorMessage: _quickAddErrorMessage,
      isLoading: _isQuickAddParsing,
      isRecording: _isVoiceRecording,
      isVoiceProcessing: _isVoiceProcessing,
      voiceSoundLevel: _voiceSoundLevel,
      onSubmit: _submitQuickAdd,
      onVoiceTap: _handleVoiceTap,
      onRetry: _retryQuickAdd,
      onTypeInstead: _switchQuickAddToTyping,
      onReview: _reviewQuickAddDraft,
    );
  }

  Widget _buildScanMode() {
    return ScanScreen(
      key: const ValueKey(_AddMode.scan),
      embedded: true,
      imagePicker: widget.scanImagePicker,
      receiptParser: widget.scanReceiptParser,
      onConfirmed: _applyScanResult,
    );
  }

  void _applyScanResult(ScanResultModel result) {
    final amount = result.totalAmount > 0
        ? result.totalAmount
        : result.calculatedTotal;
    if (result.items.isEmpty || amount <= 0) {
      _showMessage(
        AppStrings.choose(
          'No valid amount was found on the receipt.',
          'Không tìm thấy số tiền hợp lệ trên hóa đơn.',
        ),
      );
      return;
    }

    final categoryTotals = <String, int>{};
    for (final item in result.items) {
      categoryTotals.update(
        item.category,
        (current) => current + item.amount,
        ifAbsent: () => item.amount,
      );
    }
    final dominantCategory = categoryTotals.entries.reduce(
      (current, candidate) =>
          candidate.value > current.value ? candidate : current,
    );
    final merchantName = result.merchantName?.trim();

    setState(() {
      _isExpense = true;
      _amountController.text = _addCommas(amount.toString());
      _nameController.text = merchantName?.isNotEmpty == true
          ? merchantName!
          : AppStrings.choose('Scanned receipt', 'Hóa đơn đã quét');
      _selectedCategory = TransactionCategory.fromKey(dominantCategory.key).key;
      _transactionDate = result.receiptDate;
      _mode = _AddMode.manual;
      _selectedInputMode = null;
    });
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
    bool embedded = false,
  }) {
    return Semantics(
      button: true,
      label: '$label, $value',
      child: Material(
        key: fieldKey,
        color: highlighted
            ? accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(embedded ? 0 : 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(embedded ? 0 : 10),
          child: Container(
            constraints: BoxConstraints(
              minHeight: Responsive.h(context, embedded ? 64 : 70),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 14),
              vertical: Responsive.h(context, embedded ? 7 : 10),
            ),
            decoration: BoxDecoration(
              border: embedded
                  ? null
                  : Border.all(
                      color: highlighted ? accent : const Color(0xFFC3C7CF),
                    ),
              borderRadius: BorderRadius.circular(embedded ? 0 : 10),
              boxShadow: embedded
                  ? null
                  : const [
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
                      Text(label, style: _labelStyle.copyWith(fontSize: 9)),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryText,
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

  Widget _buildNameField(Color accent, {bool embedded = false}) {
    return Container(
      constraints: BoxConstraints(minHeight: Responsive.h(context, 64)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 14),
        vertical: Responsive.h(context, 7),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _isDark
                  ? _addTransactionDarkRaisedSurface
                  : const Color(0xFFE1F5EF),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.edit_note_rounded, color: accent, size: 20),
          ),
          SizedBox(width: Responsive.w(context, 10)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.choose('TRANSACTION NAME', 'TÊN GIAO DỊCH'),
                  style: _labelStyle.copyWith(fontSize: 9),
                ),
                TextField(
                  key: const Key('manual_name_field'),
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  cursorColor: accent,
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _primaryText,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    hintText: AppStrings.choose(
                      'Enter transaction name...',
                      'Nhập tên giao dịch...',
                    ),
                    hintStyle: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _mutedText,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.only(top: 2),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, color: accent, size: 19),
        ],
      ),
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
        minimumSize: Size.fromHeight(Responsive.h(context, 56)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 19),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }

  TextStyle get _labelStyle => TextStyle(
    fontFamily: 'Manrope',
    fontSize: 11.5,
    height: 1.2,
    letterSpacing: 0.65,
    fontWeight: FontWeight.w700,
    color: _isDark ? _addTransactionDarkMutedText : const Color(0xFF53615C),
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

  Future<void> _showSourceSelection() async {
    final selected = await showModalBottomSheet<WalletPreset>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: _SourceSelectionSheet(
          selectedName: _selectedWalletName,
          selectedType: _selectedAcctCategory,
        ),
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
      _showMessage(
        AppStrings.choose(
          'Please select a payment method',
          'Vui lòng chọn phương thức thanh toán',
        ),
      );
      return;
    }
    var goalWithdrawals = <String, int>{};
    if (_isExpense) {
      final goalService = ref.read(goalServiceProvider);
      final transactionService = ref.read(transactionServiceProvider);
      final shortfall =
          (goalService.totalAllocated -
                  (transactionService.totalBalance - amount))
              .clamp(0, 1 << 62);
      if (shortfall > 0 &&
          goalService.settings.expenseShortfallPolicy ==
              ExpenseShortfallPolicy.askEachTime) {
        final selected = await ExpenseGoalWithdrawalSheet.show(
          context,
          shortfall: shortfall,
        );
        if (selected == null || !mounted) return;
        goalWithdrawals = selected;
      }
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
      final completedGoalIds = await ref
          .read(transactionServiceProvider)
          .add(transaction, goalWithdrawals: goalWithdrawals);
      if (!mounted) return;
      for (final goalId in completedGoalIds) {
        final completionAction = await GoalCompletionDialog.show(
          context,
          goalId: goalId,
        );
        if (!mounted) return;
        if (completionAction == GoalCompletionAction.viewGoal ||
            completionAction == GoalCompletionAction.editAllocation) {
          _allowPop = true;
          Navigator.of(context).pushReplacementNamed(
            completionAction == GoalCompletionAction.viewGoal
                ? AppRoutes.goalDetails
                : AppRoutes.editGoal,
            arguments: goalId,
          );
          return;
        }
      }
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
          title: Text(
            AppStrings.choose('Discard transaction?', 'Bỏ giao dịch?'),
          ),
          content: Text(
            AppStrings.choose(
              'Your unsaved changes will be lost.',
              'Các thay đổi chưa lưu sẽ bị mất.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                AppStrings.choose('Keep editing', 'Tiếp tục chỉnh sửa'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppStrings.choose('Discard', 'Bỏ')),
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
    return AppStrings.isVietnamese
        ? '$day/$month/${value.year}'
        : '$month/$day/${value.year}';
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
      setState(() {
        _voiceState = _QuickAddVoiceState.error;
        _quickAddDraft = null;
        _quickAddErrorMessage =
            AppLanguage.instance.locale == AppLocale.vietnamese
            ? 'Vui lòng nói hoặc nhập nội dung giao dịch.'
            : 'Please say or type a transaction first.';
      });
      return;
    }
    final parseSession = ++_quickParseSession;
    setState(() {
      _isQuickAddParsing = true;
      _voiceState = _QuickAddVoiceState.parsing;
      _quickAddDraft = null;
      _quickAddErrorMessage = null;
    });
    try {
      final draft = await QuickAddService.instance.parse(text);
      if (!mounted || parseSession != _quickParseSession) return;
      setState(() {
        _isQuickAddParsing = false;
        _quickAddDraft = draft;
        _voiceState = _QuickAddVoiceState.success;
      });
    } on QuickAddException {
      if (!mounted || parseSession != _quickParseSession) return;
      setState(() {
        _voiceState = _QuickAddVoiceState.error;
        _quickAddErrorMessage =
            AppLanguage.instance.locale == AppLocale.vietnamese
            ? 'Không thể hiểu giao dịch. Hãy thử nói rõ hơn hoặc nhập thủ công.'
            : 'We couldn’t understand that. Try speaking clearly or type instead.';
      });
    } catch (_) {
      if (!mounted || parseSession != _quickParseSession) return;
      setState(() {
        _voiceState = _QuickAddVoiceState.error;
        _quickAddErrorMessage =
            AppLanguage.instance.locale == AppLocale.vietnamese
            ? 'Kết nối có thể chưa ổn định. Vui lòng thử lại.'
            : 'The connection may be weak. Please try again.';
      });
    } finally {
      if (mounted && parseSession == _quickParseSession && _isQuickAddParsing) {
        setState(() => _isQuickAddParsing = false);
      }
    }
  }

  Future<void> _reviewQuickAddDraft() async {
    var draft = _quickAddDraft;
    if (draft == null || _isQuickAddReviewOpen) return;
    final editedText = _quickAddController.text.trim();
    if (editedText != draft.originalText.trim()) {
      await _submitQuickAdd(editedText);
      if (!mounted || _voiceState != _QuickAddVoiceState.success) return;
      draft = _quickAddDraft;
      if (draft == null) return;
    }
    final reviewDraft = draft;
    setState(() => _isQuickAddReviewOpen = true);
    try {
      final action = await QuickAddReviewSheet.show(
        context,
        draft: reviewDraft,
        onConfirm: () => _confirmQuickAdd(reviewDraft),
      );
      if (!mounted) return;
      if (action == QuickAddReviewAction.confirmed) {
        _quickAddController.clear();
        final userId = ref.read(authServiceProvider).currentUser?.id;
        if (userId == null || !mounted) return;
        final saved = reviewDraft.toTransactionModel(
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
        _applyDraftToManual(reviewDraft);
      } else if (action == QuickAddReviewAction.retryVoice) {
        _retryQuickAdd();
      }
    } finally {
      if (mounted) setState(() => _isQuickAddReviewOpen = false);
    }
  }

  void _retryQuickAdd() {
    setState(() {
      _voiceState = _QuickAddVoiceState.idle;
      _quickAddDraft = null;
      _quickAddErrorMessage = null;
      _quickAddController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_handleVoiceTap());
    });
  }

  void _switchQuickAddToTyping() {
    setState(() {
      _voiceState = _QuickAddVoiceState.idle;
      _quickAddDraft = null;
      _quickAddErrorMessage = null;
    });
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
    setState(() {
      _voiceState = _QuickAddVoiceState.initializing;
      _voiceSoundLevel = 0;
    });
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
        onSoundLevel: (level) => _handleVoiceSoundLevel(session, level),
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

  void _handleVoiceSoundLevel(int session, double level) {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    if ((_voiceSoundLevel - level).abs() < .05) return;
    setState(() => _voiceSoundLevel = level);
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
    setState(() {
      _voiceState = _QuickAddVoiceState.parsing;
      _voiceSoundLevel = 0;
    });
    await _submitQuickAdd(transcript);
  }

  void _showVoiceErrorIfCurrent(int session, String code) {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    _voiceFinalHandled = true;
    _voiceTimeout?.cancel();
    setState(() {
      _voiceState = _QuickAddVoiceState.error;
      _voiceSoundLevel = 0;
      _quickAddDraft = null;
      _quickAddErrorMessage = _localizedVoiceError(code);
    });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: category.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          width: Responsive.w(context, 62),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: Responsive.w(context, 50),
                height: Responsive.w(context, 50),
                decoration: BoxDecoration(
                  color: outlined
                      ? Colors.transparent
                      : category.color.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                  border: outlined
                      ? Border.all(
                          color: isDark
                              ? _addTransactionDarkBorder
                              : const Color(0xFF8CB3A7),
                          width: 1.4,
                          style: BorderStyle.solid,
                        )
                      : null,
                  boxShadow: outlined || isDark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x10004736),
                            blurRadius: 9,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: category.buildIcon(
                  size: 21,
                  color: outlined
                      ? (isDark
                            ? const Color(0xFF66C0AA)
                            : const Color(0xFF006C53))
                      : category.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.categoryName(category.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? _addTransactionDarkSecondaryText
                      : const Color(0xFF586861),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Material(
        color: isDark ? _addTransactionDarkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const _SheetHandle(),
              _SheetHeader(
                title: AppStrings.choose('Select Category', 'Chọn danh mục'),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: _categories.length + 1,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: isDark
                        ? _addTransactionDarkBorder
                        : const Color(0xFFE4EAE7),
                  ),
                  itemBuilder: (context, index) {
                    if (index == _categories.length) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? _addTransactionDarkRaisedSurface
                                : const Color(0xFFE8F5EF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: isDark
                                ? const Color(0xFF82D7B8)
                                : const Color(0xFF006C46),
                          ),
                        ),
                        title: Text(
                          AppStrings.choose(
                            'Create custom category',
                            'Tạo danh mục tùy chỉnh',
                          ),
                          style: TextStyle(
                            color: isDark
                                ? _addTransactionDarkText
                                : const Color(0xFF1A1C1E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: selected && isDark
                            ? _addTransactionDarkRaisedSurface
                            : Colors.transparent,
                        onTap: () =>
                            setState(() => _selectedKey = category.key),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: category.color.withValues(
                              alpha: isDark ? 0.2 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: category.buildIcon(size: 19),
                        ),
                        title: Text(
                          AppStrings.categoryName(category.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isDark
                                ? _addTransactionDarkText
                                : const Color(0xFF1A1C1E),
                          ),
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle,
                                color: isDark
                                    ? const Color(0xFF38D6AC)
                                    : const Color(0xFF00D09E),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              _SheetApplyButton(
                label: AppStrings.choose('Apply Selection', 'Áp dụng lựa chọn'),
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
    name: 'Cash',
    logoAssetPath: 'assets/logos/ewallets/cash.png',
    brandColor: Color(0xFF4CAF50),
    type: WalletType.cash,
  );

  static const _transfer = WalletPreset(
    name: 'Transfer',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        color: isDark ? _addTransactionDarkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const _SheetHandle(),
              _SheetHeader(
                title: AppStrings.choose(
                  'Select Payment Method',
                  'Chọn phương thức thanh toán',
                ),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _section(
                      AppStrings.choose(
                        'PAYMENT METHOD',
                        'PHƯƠNG THỨC THANH TOÁN',
                      ),
                      const [_cash, _transfer],
                    ),
                  ],
                ),
              ),
              _SheetApplyButton(
                label: AppStrings.choose('Apply Selection', 'Áp dụng lựa chọn'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 7),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              letterSpacing: 0.8,
              color: isDark
                  ? _addTransactionDarkMutedText
                  : const Color(0xFF5F6368),
            ),
          ),
        ),
        ...presets.map(_sourceRow),
      ],
    );
  }

  Widget _sourceRow(WalletPreset preset) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              color: isDark
                  ? selected
                        ? _addTransactionDarkRaisedSurface
                        : _addTransactionDarkSurface
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? _addTransactionDarkBorder
                    : const Color(0xFFE0E4E2),
              ),
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
                        switch (preset.name) {
                          'Cash' => AppStrings.choose('Cash', 'Tiền mặt'),
                          'Transfer' => AppStrings.choose(
                            'Transfer',
                            'Chuyển khoản',
                          ),
                          _ => preset.name,
                        },
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? _addTransactionDarkText
                              : const Color(0xFF1A1C1E),
                        ),
                      ),
                      Text(
                        switch (preset.type) {
                          WalletType.cash => AppStrings.choose(
                            'Cash payment',
                            'Thanh toán tiền mặt',
                          ),
                          WalletType.transfer => AppStrings.choose(
                            'Cashless payment',
                            'Thanh toán không tiền mặt',
                          ),
                        },
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? _addTransactionDarkSecondaryText
                              : const Color(0xFF6D7B74),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected
                      ? (isDark
                            ? const Color(0xFF38D6AC)
                            : const Color(0xFF00D09E))
                      : (isDark
                            ? _addTransactionDarkMutedText
                            : const Color(0xFF1A1C1E)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: isDark
              ? _addTransactionDarkMutedText
              : const Color(0xFFD5DAD7),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? _addTransactionDarkText
                    : const Color(0xFF1A1C1E),
              ),
            ),
          ),
          IconButton(
            tooltip: AppStrings.choose('Close', 'Đóng'),
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: isDark
                  ? _addTransactionDarkSecondaryText
                  : const Color(0xFF43474E),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: isDark
                ? const Color(0xFF006C53)
                : AppColors.primaryGreen,
            foregroundColor: isDark ? Colors.white : const Color(0xFF002112),
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
      title: Text(AppStrings.choose('Custom Category', 'Danh mục tùy chỉnh')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLength: 24,
              decoration: InputDecoration(
                labelText: AppStrings.choose('Category name', 'Tên danh mục'),
              ),
            ),
            const SizedBox(height: 12),
            Text(AppStrings.choose('Icon', 'Biểu tượng')),
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
            Text(AppStrings.choose('Color', 'Màu sắc')),
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
          child: Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              CustomCategoryDef(name: name, iconData: _icon, color: _color),
            );
          },
          child: Text(AppStrings.choose('Save Category', 'Lưu danh mục')),
        ),
      ],
    );
  }
}
