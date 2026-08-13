import 'package:flutter/material.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/utils/responsive.dart';
import '../models/quick_add_draft_model.dart';
import '../models/transaction_category.dart';
import '../services/wallet_service.dart';

enum QuickAddReviewAction { confirmed, editDetails, retryVoice }

class QuickAddReviewSheet extends StatefulWidget {
  const QuickAddReviewSheet({
    super.key,
    required this.draft,
    required this.onConfirm,
  });

  final QuickAddDraft draft;
  final Future<void> Function() onConfirm;

  static Future<QuickAddReviewAction?> show(
    BuildContext context, {
    required QuickAddDraft draft,
    required Future<void> Function() onConfirm,
  }) {
    return showModalBottomSheet<QuickAddReviewAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: QuickAddReviewSheet(draft: draft, onConfirm: onConfirm),
      ),
    );
  }

  @override
  State<QuickAddReviewSheet> createState() => _QuickAddReviewSheetState();
}

class _QuickAddReviewSheetState extends State<QuickAddReviewSheet> {
  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';
  static const _emerald = Color(0xFF006C53);
  static const _mintSurface = Color(0xFFDDF8EE);
  static const _expenseRed = Color(0xFFD83A45);
  static const _expenseSurface = Color(0xFFFFE9E8);
  static const _amberSurface = Color(0xFFFFF1C8);
  static const _amber = Color(0xFFFFA000);
  static const _ink = Color(0xFF10211C);
  static const _muted = Color(0xFF52615B);
  var _isConfirming = false;

  bool get _isVietnamese => AppLanguage.instance.locale == AppLocale.vietnamese;
  bool get _isComplete => widget.draft.canConfirm;
  bool get _isExpense => widget.draft.type == QuickAddTransactionType.expense;
  Color get _statusAccent => !_isComplete
      ? _amber
      : _isExpense
      ? _expenseRed
      : _emerald;
  Color get _statusSurface => !_isComplete
      ? _amberSurface
      : _isExpense
      ? _expenseSurface
      : _mintSurface;

  String _t(String english, String vietnamese) =>
      _isVietnamese ? vietnamese : english;

  String _localizedWalletName(String name) => switch (name) {
    'Cash' => _t('Cash', 'Tiền mặt'),
    'Transfer' => _t('Transfer', 'Chuyển khoản'),
    _ => name,
  };

  Future<void> _confirm() async {
    if (_isConfirming || !_isComplete) return;
    setState(() => _isConfirming = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.of(context).pop(QuickAddReviewAction.confirmed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Could not save the transaction. Please try again.',
              'Không thể lưu giao dịch. Vui lòng thử lại.',
            ),
          ),
        ),
      );
    }
  }

  void _closeWith(QuickAddReviewAction action) {
    if (!_isConfirming) Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isConfirming,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Responsive.w(context, 28)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26002219),
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: Responsive.h(context, 8)),
            Container(
              width: Responsive.w(context, 42),
              height: Responsive.h(context, 4),
              decoration: BoxDecoration(
                color: const Color(0xFFBEC8C3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(context, 16),
                  Responsive.h(context, 12),
                  Responsive.w(context, 16),
                  Responsive.h(context, 14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    SizedBox(height: Responsive.h(context, 14)),
                    _isComplete
                        ? _buildCompleteSummary()
                        : _buildIncompleteSummary(),
                    SizedBox(height: Responsive.h(context, 14)),
                    _buildDetectedDetails(),
                    SizedBox(height: Responsive.h(context, 12)),
                    if (_isComplete)
                      _buildOriginalInput()
                    else
                      _buildItemsToReview(),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          key: const Key('quick_add_header_icon'),
          width: Responsive.w(context, 42),
          height: Responsive.w(context, 42),
          decoration: BoxDecoration(
            color: _statusSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: _statusAccent,
            size: 22,
          ),
        ),
        SizedBox(width: Responsive.w(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Quick Add Result', 'Kết quả Quick Add'),
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 18),
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  height: 1.15,
                ),
              ),
              SizedBox(height: Responsive.h(context, 2)),
              Text(
                _t(
                  'Review what we detected before saving.',
                  'Kiểm tra thông tin trước khi lưu.',
                ),
                style: TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: Responsive.sp(context, 10),
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: _t('Close', 'Đóng'),
          onPressed: _isConfirming ? null : () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(backgroundColor: const Color(0xFFF2F5F3)),
          icon: const Icon(Icons.close_rounded, size: 20),
          color: _ink,
        ),
      ],
    );
  }

  Widget _buildCompleteSummary() {
    final draft = widget.draft;
    final isExpense = _isExpense;
    final signedAmount =
        '${isExpense ? '-' : '+'}${_formatVnd(draft.amount!)} VND';
    return Container(
      key: const Key('quick_add_summary'),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 18),
        vertical: Responsive.h(context, 16),
      ),
      decoration: BoxDecoration(
        color: _statusSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -8,
            top: -10,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 72,
              color: _statusAccent.withValues(alpha: .1),
            ),
          ),
          Column(
            children: [
              Container(
                key: const Key('quick_add_type_badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusAccent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  isExpense
                      ? _t('EXPENSE', 'CHI TIÊU')
                      : _t('INCOME', 'THU NHẬP'),
                  style: const TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: Responsive.h(context, 8)),
              Text(
                signedAmount,
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 24),
                  fontWeight: FontWeight.w700,
                  color: _statusAccent,
                ),
              ),
              SizedBox(height: Responsive.h(context, 3)),
              Text(
                draft.name!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: Responsive.sp(context, 13),
                  fontWeight: FontWeight.w500,
                  color: _ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncompleteSummary() {
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 14)),
      decoration: BoxDecoration(
        color: _amberSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: Responsive.w(context, 38),
            height: Responsive.w(context, 38),
            decoration: const BoxDecoration(
              color: Color(0xFFFFE4A1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 22,
              color: _amber,
            ),
          ),
          SizedBox(width: Responsive.w(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('NEEDS MORE INFORMATION', 'CẦN THÊM THÔNG TIN'),
                        style: const TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .4,
                          color: Color(0xFFB46600),
                        ),
                      ),
                    ),
                    _statusBadge(
                      _t('INCOMPLETE', 'CHƯA ĐỦ'),
                      background: _amber,
                      foreground: Colors.white,
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 4)),
                Text(
                  _incompleteHeadline,
                  style: TextStyle(
                    fontFamily: _headlineFont,
                    fontSize: Responsive.sp(context, 17),
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 2)),
                Text(
                  _t(
                    'Complete the missing details to continue.',
                    'Bổ sung thông tin còn thiếu để tiếp tục.',
                  ),
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 11),
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _incompleteHeadline {
    final missing = widget.draft.missingFields;
    if (missing.contains(QuickAddMissingField.amount)) {
      return _t('Amount not detected', 'Chưa nhận diện số tiền');
    }
    if (missing.contains(QuickAddMissingField.transactionType)) {
      return _t(
        'Transaction type not detected',
        'Chưa xác định loại giao dịch',
      );
    }
    return _t('Some details are missing', 'Một số thông tin còn thiếu');
  }

  Widget _buildDetectedDetails() {
    final draft = widget.draft;
    final wallet = WalletService.instance.byId(draft.walletId);
    final category = draft.categoryKey == null
        ? null
        : TransactionCategory.resolve(draft.categoryKey!);
    final walletValue = wallet != null && wallet.isActive
        ? _localizedWalletName(wallet.name)
        : draft.walletName == null
        ? _t('Missing', 'Còn thiếu')
        : _localizedWalletName(draft.walletName!);
    final details = <_DetectedDetail>[
      _DetectedDetail(
        label: _t('Name', 'Tên'),
        value: draft.name ?? _t('Missing', 'Còn thiếu'),
        icon: Icons.edit_note_rounded,
        iconColor: const Color(0xFF47645A),
        missing: draft.missingFields.contains(QuickAddMissingField.name),
      ),
      _DetectedDetail(
        label: _t('Category', 'Danh mục'),
        value: draft.categoryKey == null
            ? _t('Missing', 'Còn thiếu')
            : AppStrings.categoryName(category!.label),
        icon: category?.icon ?? Icons.category_outlined,
        iconColor: category?.color ?? _muted,
        category: category,
        missing: draft.missingFields.contains(QuickAddMissingField.category),
      ),
      _DetectedDetail(
        label: _t('Wallet', 'Ví'),
        value: walletValue,
        icon: Icons.account_balance_wallet_outlined,
        iconColor: const Color(0xFF277CC8),
        missing: draft.missingFields.contains(QuickAddMissingField.wallet),
      ),
      _DetectedDetail(
        label: _t('Date', 'Ngày'),
        value: _dateLabel(draft.date),
        icon: Icons.calendar_today_outlined,
        iconColor: const Color(0xFF4D5D56),
      ),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 14),
        Responsive.h(context, 12),
        Responsive.w(context, 14),
        Responsive.h(context, 8),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _t('Detected Details', 'Thông tin nhận diện'),
                  style: TextStyle(
                    fontFamily: _headlineFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              if (!_isComplete)
                const Icon(Icons.edit_square, size: 15, color: _muted),
            ],
          ),
          SizedBox(height: Responsive.h(context, 6)),
          ...details.map(
            (detail) => _isComplete
                ? _completeDetailRow(detail)
                : _incompleteDetailRow(detail),
          ),
        ],
      ),
    );
  }

  Widget _completeDetailRow(_DetectedDetail detail) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 6)),
      child: Row(
        children: [
          Container(
            width: Responsive.w(context, 30),
            height: Responsive.w(context, 30),
            decoration: BoxDecoration(
              color: detail.iconColor.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child:
                detail.category?.buildIcon(
                  size: 15,
                  widgetKey: const Key('quick_add_category_icon'),
                ) ??
                Icon(detail.icon, size: 15, color: detail.iconColor),
          ),
          SizedBox(width: Responsive.w(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.label,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 9),
                    color: _muted,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 1)),
                Text(
                  detail.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _incompleteDetailRow(_DetectedDetail detail) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 8)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9EEEB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              detail.label,
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 11),
                color: _muted,
              ),
            ),
          ),
          if (detail.missing)
            _statusBadge(
              _t('Missing', 'Còn thiếu'),
              background: const Color(0xFFFFF0C2),
              foreground: const Color(0xFFB46600),
              icon: Icons.warning_amber_rounded,
            )
          else ...[
            if (detail.label == _t('Wallet', 'Ví'))
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(detail.icon, size: 14, color: detail.iconColor),
              ),
            Flexible(
              child: Text(
                detail.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: Responsive.sp(context, 12),
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(
    String label, {
    required Color background,
    required Color foreground,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: .3,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalInput() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 12),
        ),
        childrenPadding: EdgeInsets.fromLTRB(
          Responsive.w(context, 12),
          0,
          Responsive.w(context, 12),
          Responsive.h(context, 12),
        ),
        backgroundColor: const Color(0xFFF3F5F4),
        collapsedBackgroundColor: const Color(0xFFF3F5F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: const Icon(Icons.history_rounded, size: 17, color: _muted),
        title: Text(
          _t('Original input', 'Nội dung ban đầu'),
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 11),
            color: _muted,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '“${widget.draft.originalText}”',
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 12),
                fontStyle: FontStyle.italic,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsToReview() {
    final items = _reviewItems;
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 14)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 17, color: _amber),
              SizedBox(width: Responsive.w(context, 7)),
              Expanded(
                child: Text(
                  _t('Items to review', 'Thông tin cần kiểm tra'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _headlineFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 7)),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 3)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: CircleAvatar(radius: 2, backgroundColor: _amber),
                  ),
                  SizedBox(width: Responsive.w(context, 8)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 11),
                        color: _muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _reviewItems {
    final missing = widget.draft.missingFields;
    final result = <String>[];
    if (missing.contains(QuickAddMissingField.amount)) {
      result.add(_t('Amount is missing', 'Còn thiếu số tiền'));
    }
    if (missing.contains(QuickAddMissingField.transactionType)) {
      result.add(_t('Choose Income or Expense', 'Chọn Thu nhập hoặc Chi tiêu'));
    }
    if (missing.contains(QuickAddMissingField.name)) {
      result.add(_t('Transaction name is missing', 'Còn thiếu tên giao dịch'));
    }
    if (missing.contains(QuickAddMissingField.category)) {
      result.add(_t('Choose a category', 'Chọn một danh mục'));
    }
    if (missing.contains(QuickAddMissingField.wallet)) {
      result.add(_t('Choose a wallet', 'Chọn một ví'));
    }
    for (final warning in widget.draft.warnings) {
      if (warning.toLowerCase().contains('transfer') &&
          !result.contains(warning)) {
        result.add(warning);
      }
    }
    if (result.isEmpty) {
      result.add(
        _t('Review the detected details', 'Kiểm tra thông tin nhận diện'),
      );
    }
    return result;
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          Responsive.w(context, 16),
          Responsive.h(context, 12),
          Responsive.w(context, 16),
          Responsive.h(context, 14),
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE6ECE9))),
        ),
        child: _isComplete
            ? _buildCompleteActions()
            : _buildIncompleteActions(),
      ),
    );
  }

  Widget _buildCompleteActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          key: const Key('quick_add_confirm'),
          onPressed: _isConfirming ? null : _confirm,
          style: _primaryStyle(),
          icon: _isConfirming
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(_t('Confirm & Save', 'Xác nhận và lưu')),
        ),
        SizedBox(height: Responsive.h(context, 8)),
        OutlinedButton.icon(
          key: const Key('quick_add_edit_details'),
          onPressed: _isConfirming
              ? null
              : () => _closeWith(QuickAddReviewAction.editDetails),
          style: _outlinedStyle(),
          icon: const Icon(Icons.edit_square, size: 17),
          label: Text(_t('Edit Details', 'Chỉnh sửa thông tin')),
        ),
      ],
    );
  }

  Widget _buildIncompleteActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          key: const Key('quick_add_edit_details'),
          onPressed: () => _closeWith(QuickAddReviewAction.editDetails),
          style: _primaryStyle(),
          icon: const Icon(Icons.edit_note_rounded, size: 19),
          label: Text(
            _t('Complete Missing Details', 'Bổ sung thông tin còn thiếu'),
          ),
        ),
        TextButton.icon(
          onPressed: () => _closeWith(QuickAddReviewAction.retryVoice),
          style: TextButton.styleFrom(foregroundColor: _muted),
          icon: const Icon(Icons.mic_none_rounded, size: 17),
          label: Text(_t('Try Voice Again', 'Thử lại bằng giọng nói')),
        ),
      ],
    );
  }

  ButtonStyle _primaryStyle() => ElevatedButton.styleFrom(
    minimumSize: Size.fromHeight(Responsive.h(context, 50)),
    elevation: 5,
    shadowColor: _statusAccent.withValues(alpha: .3),
    backgroundColor: _statusAccent,
    foregroundColor: Colors.white,
    disabledBackgroundColor: _statusAccent.withValues(alpha: .5),
    shape: const StadiumBorder(),
    textStyle: TextStyle(
      fontFamily: _headlineFont,
      fontSize: Responsive.sp(context, 13),
      fontWeight: FontWeight.w700,
    ),
  );

  ButtonStyle _outlinedStyle() => OutlinedButton.styleFrom(
    minimumSize: Size.fromHeight(Responsive.h(context, 48)),
    foregroundColor: _statusAccent,
    side: BorderSide(color: _statusAccent),
    shape: const StadiumBorder(),
    textStyle: TextStyle(
      fontFamily: _headlineFont,
      fontSize: Responsive.sp(context, 13),
      fontWeight: FontWeight.w700,
    ),
  );

  String _dateLabel(DateTime? date) {
    if (date == null) return _t('Today', 'Hôm nay');
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return _t('Today', 'Hôm nay');
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatVnd(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}

class _DetectedDetail {
  const _DetectedDetail({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.missing = false,
    this.category,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool missing;
  final TransactionCategory? category;
}
