import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/bank_preset.dart';
import '../models/ewallet_preset.dart';
import '../models/quick_add_draft_model.dart';
import '../models/transaction_category.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/transaction_provider.dart';
import '../services/quick_add_service.dart';
import '../services/quick_add_speech_recognition_service.dart';
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

enum _AccountCategory { bank, ewallet, cash }

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
  var _mode = _AddMode.manual;
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

  bool get _isVoiceRecording => _voiceState == _QuickAddVoiceState.listening;
  bool get _isVoiceProcessing =>
      _voiceState == _QuickAddVoiceState.initializing ||
      _voiceState == _QuickAddVoiceState.processingFinal;

  @override
  void initState() {
    super.initState();
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
    if (_voiceState != _QuickAddVoiceState.idle) {
      unawaited(QuickAddSpeechRecognitionService.instance.cancelListening());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFCFF),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    Responsive.w(context, 16),
                    Responsive.h(context, 24),
                    Responsive.w(context, 16),
                    MediaQuery.viewInsetsOf(context).bottom +
                        Responsive.h(context, 24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildModeSelector(),
                      SizedBox(height: Responsive.h(context, 24)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        child: switch (_mode) {
                          _AddMode.manual => _buildManualMode(),
                          _AddMode.quick => _buildQuickMode(),
                          _AddMode.scan => _buildScanPlaceholder(),
                        },
                      ),
                    ],
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
    return Container(
      height: Responsive.h(context, 64),
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 12)),
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
              onPressed: _requestClose,
              tooltip: 'Back',
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 22,
                color: Color(0xFF43474E),
              ),
            ),
          ),
          Text(
            'Add Transaction',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: Responsive.sp(context, 18),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1C1E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return _StitchSegmentedControl<_AddMode>(
      entries: const [
        (_AddMode.manual, 'MANUAL'),
        (_AddMode.quick, 'QUICK'),
        (_AddMode.scan, 'SCAN'),
      ],
      selected: _mode,
      selectedColor: const Color(0xFF006C46),
      onSelected: (value) => setState(() => _mode = value),
    );
  }

  Widget _buildManualMode() {
    final accent = _isExpense
        ? const Color(0xFFBA1A1A)
        : const Color(0xFF006C46);
    final category = _categoryForKey(_selectedCategory);
    final wallet = WalletService.instance.byId(_selectedWalletId);
    final date = _transactionDate ?? DateTime.now();

    return Column(
      key: const ValueKey(_AddMode.manual),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StitchSegmentedControl<bool>(
          entries: const [(false, 'NEW INCOME'), (true, 'NEW EXPENSE')],
          selected: _isExpense,
          selectedColor: accent,
          onSelected: (value) => setState(() => _isExpense = value),
        ),
        SizedBox(height: Responsive.h(context, 22)),
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
                cursorColor: accent,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: Responsive.sp(context, 44),
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: accent.withValues(alpha: 0.28)),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFC3C7CF), width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent, width: 2),
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
        SizedBox(height: Responsive.h(context, 18)),
        _buildSelectionField(
          fieldKey: const Key('manual_category_field'),
          label: 'CATEGORY',
          value: category.label,
          leading: Icon(category.icon, color: accent, size: 22),
          onTap: _showCategorySelection,
          accent: accent,
          highlighted: true,
        ),
        SizedBox(height: Responsive.h(context, 12)),
        _buildSelectionField(
          fieldKey: const Key('manual_source_field'),
          label: 'SOURCE',
          value: _sourceDisplayName(wallet?.name ?? _selectedWalletName),
          leading: wallet == null
              ? Icon(Icons.account_balance_rounded, color: accent, size: 22)
              : _walletLogo(wallet.logoAssetPath, wallet.brandColor),
          onTap: _showSourceSelection,
          accent: accent,
        ),
        SizedBox(height: Responsive.h(context, 12)),
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
          color: _isExpense ? const Color(0xFFBA1A1A) : AppColors.primaryGreen,
          foregroundColor: _isExpense ? Colors.white : const Color(0xFF002112),
          isLoading: _isSavingTransaction,
          onPressed: _saveManualTransaction,
        ),
      ],
    );
  }

  String _sourceDisplayName(String? name) {
    if (name == null || name.isEmpty) return 'Select Source';
    return name == 'Tiền mặt' ? 'Cash' : name;
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

  Widget _buildScanPlaceholder() {
    return Container(
      key: const ValueKey(_AddMode.scan),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 24),
        vertical: Responsive.h(context, 52),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC3C7CF)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 48,
            color: Color(0xFF006C46),
          ),
          SizedBox(height: 16),
          Text(
            'Scan mode is coming soon',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Receipt OCR will be connected here in a later update.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF5F6368)),
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
    return Container(
      constraints: BoxConstraints(minHeight: Responsive.h(context, 70)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 14),
        vertical: Responsive.h(context, 7),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC3C7CF)),
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
          Icon(Icons.edit_note_rounded, color: accent, size: 25),
          SizedBox(width: Responsive.w(context, 12)),
          Expanded(
            child: TextField(
              key: const Key('manual_name_field'),
              controller: _nameController,
              textInputAction: TextInputAction.done,
              cursorColor: accent,
              decoration: InputDecoration(
                labelText: 'TRANSACTION NAME',
                labelStyle: _labelStyle.copyWith(fontSize: 10),
                hintText: 'Enter transaction name...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
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
      _showMessage('Please select an account');
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
      WalletType.bank => _AccountCategory.bank,
      WalletType.ewallet => _AccountCategory.ewallet,
      WalletType.cash => _AccountCategory.cash,
    };
  }

  Widget _walletLogo(String path, Color fallbackColor) {
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(Icons.account_balance_rounded, color: fallbackColor, size: 24),
      ),
    );
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

class _StitchSegmentedControl<T> extends StatelessWidget {
  const _StitchSegmentedControl({
    required this.entries,
    required this.selected,
    required this.selectedColor,
    required this.onSelected,
  });

  final List<(T, String)> entries;
  final T selected;
  final Color selectedColor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Responsive.h(context, 44),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC3C7CF)),
      ),
      child: Row(
        children: entries.map((entry) {
          final active = entry.$1 == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: active,
              label: entry.$2,
              child: InkWell(
                onTap: () => onSelected(entry.$1),
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: active
                        ? const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    entry.$2,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: Responsive.sp(context, 10),
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : const Color(0xFF43474E),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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

  static const _availableEwalletAssetPaths = {
    'assets/logos/ewallets/momo.png',
    'assets/logos/ewallets/zalopay.png',
    'assets/logos/ewallets/vnpay.png',
    'assets/logos/ewallets/viettelmoney.png',
    'assets/logos/ewallets/grabpay.png',
    'assets/logos/ewallets/onepay.png',
    'assets/logos/ewallets/paypal.png',
  };

  static const _cash = WalletPreset(
    name: 'Tiền mặt',
    logoAssetPath: 'assets/logos/ewallets/cash.png',
    brandColor: Color(0xFF4CAF50),
    type: WalletType.cash,
  );

  @override
  void initState() {
    super.initState();
    final all = [_cash, ...bankPresets, ..._ewallets];
    for (final preset in all) {
      if (preset.name == widget.selectedName &&
          _AddTransactionSheetState._accountCategoryFor(preset.type) ==
              widget.selectedType) {
        _selected = preset;
        break;
      }
    }
  }

  static List<WalletPreset> get _ewallets => ewalletPresets
      .where(
        (preset) =>
            preset.type == WalletType.ewallet &&
            _availableEwalletAssetPaths.contains(preset.logoAssetPath),
      )
      .toList(growable: false);

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
                title: 'Select Source',
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _section('CASH', const [_cash]),
                    _section('BANK', bankPresets),
                    _section('E-WALLET', _ewallets),
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
                          : preset.type == WalletType.ewallet
                          ? Icons.account_balance_wallet_outlined
                          : Icons.account_balance_outlined,
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
                        preset.name == 'Tiền mặt' ? 'Cash' : preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        switch (preset.type) {
                          WalletType.bank => 'Bank account',
                          WalletType.ewallet => 'E-wallet',
                          WalletType.cash => 'Manual tracking',
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
