import 'package:flutter/material.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../models/quick_add_draft_model.dart';
import '../models/transaction_category.dart';
import '../services/wallet_service.dart';

enum QuickAddReviewAction { confirmed, editDetails }

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
      builder: (_) => QuickAddReviewSheet(draft: draft, onConfirm: onConfirm),
    );
  }

  @override
  State<QuickAddReviewSheet> createState() => _QuickAddReviewSheetState();
}

class _QuickAddReviewSheetState extends State<QuickAddReviewSheet> {
  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';
  var _isConfirming = false;

  bool get _isVietnamese => AppLanguage.instance.locale == AppLocale.vietnamese;

  Future<void> _confirm() async {
    if (_isConfirming || !widget.draft.canConfirm) return;
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
            _isVietnamese
                ? 'Không thể lưu giao dịch. Vui lòng thử lại.'
                : 'Could not save the transaction. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final themeColors = context.finFlowColors;
    final hasAttention =
        draft.missingFields.isNotEmpty || draft.confidence < 0.6;
    return PopScope(
      canPop: !_isConfirming,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: themeColors.bottomSheetBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Responsive.w(context, 28)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: Responsive.h(context, 8)),
            Container(
              width: Responsive.w(context, 42),
              height: Responsive.h(context, 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC8CECB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(context, 20),
                  Responsive.h(context, 14),
                  Responsive.w(context, 20),
                  Responsive.h(context, 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: Responsive.h(context, 4)),
                    Text(
                      _isVietnamese
                          ? 'Xem lại giao dịch đã nhận diện trước khi lưu.'
                          : 'Review the detected transaction before saving.',
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 13),
                        color: AppColors.mutedGray,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 20)),
                    _buildAmountSummary(hasAttention),
                    SizedBox(height: Responsive.h(context, 22)),
                    Text(
                      _isVietnamese
                          ? 'Các trường nhận diện'
                          : 'Detected Fields',
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 13),
                        color: AppColors.mutedGray,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 10)),
                    _buildDetectedFields(),
                    if (draft.warnings.isNotEmpty) ...[
                      SizedBox(height: Responsive.h(context, 14)),
                      _buildWarnings(),
                    ],
                    SizedBox(height: Responsive.h(context, 18)),
                    Text(
                      _isVietnamese ? 'Nội dung ban đầu' : 'Original text',
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 13),
                        color: AppColors.mutedGray,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 9)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(context, 14),
                        vertical: Responsive.h(context, 14),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F1F3),
                        borderRadius: BorderRadius.circular(
                          Responsive.w(context, 12),
                        ),
                      ),
                      child: Text(
                        '“${draft.originalText}”',
                        style: TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: Responsive.sp(context, 13),
                          fontStyle: FontStyle.italic,
                          color: AppColors.darkGray,
                        ),
                      ),
                    ),
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
        Icon(
          Icons.auto_awesome,
          size: Responsive.w(context, 20),
          color: AppColors.primaryGreen,
        ),
        SizedBox(width: Responsive.w(context, 7)),
        Expanded(
          child: Text(
            _isVietnamese ? 'Kết quả Quick Add' : 'Quick Add Result',
            style: TextStyle(
              fontFamily: _headlineFont,
              fontSize: Responsive.sp(context, 18),
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
        ),
        IconButton(
          tooltip: _isVietnamese ? 'Đóng' : 'Close',
          onPressed: _isConfirming ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          color: AppColors.darkText,
        ),
      ],
    );
  }

  Widget _buildAmountSummary(bool hasAttention) {
    final draft = widget.draft;
    final isExpense = draft.type == QuickAddTransactionType.expense;
    final amountColor = isExpense
        ? const Color(0xFFC90010)
        : AppColors.deepEmerald;
    final amount = draft.amount == null
        ? (_isVietnamese ? 'Thiếu số tiền' : 'Amount missing')
        : '${isExpense
                  ? '-'
                  : draft.type == QuickAddTransactionType.income
                  ? '+'
                  : ''}'
              '${_formatVnd(draft.amount!)} VND';
    final badge = switch (draft.type) {
      QuickAddTransactionType.income => 'INCOME',
      QuickAddTransactionType.expense => 'EXPENSE',
      null => _isVietnamese ? 'CHƯA XÁC ĐỊNH' : 'UNKNOWN',
    };
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 30)),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F1F4),
        borderRadius: BorderRadius.circular(Responsive.w(context, 16)),
        border: hasAttention
            ? Border.all(color: AppColors.amber.withValues(alpha: 0.65))
            : null,
      ),
      child: Column(
        children: [
          Text(
            amount,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _headlineFont,
              fontSize: Responsive.sp(context, 28),
              fontWeight: FontWeight.w600,
              color: draft.amount == null ? AppColors.coral : amountColor,
            ),
          ),
          SizedBox(height: Responsive.h(context, 8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 14),
              vertical: Responsive.h(context, 5),
            ),
            decoration: BoxDecoration(
              color: isExpense
                  ? const Color(0xFFFFDAD8)
                  : draft.type == QuickAddTransactionType.income
                  ? AppColors.lightGreen
                  : const Color(0xFFFFE8B8),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 11),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: isExpense
                    ? const Color(0xFF8C1D18)
                    : AppColors.deepEmerald,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedFields() {
    final draft = widget.draft;
    final wallet = WalletService.instance.byId(draft.walletId);
    final walletValue = wallet != null && wallet.isActive
        ? wallet.name
        : draft.walletName ?? (_isVietnamese ? 'Chưa chọn' : 'Not selected');
    final categoryValue = draft.categoryKey == null
        ? _missingLabel
        : TransactionCategory.fromKey(draft.categoryKey!).label;
    return Container(
      decoration: BoxDecoration(
        color: context.finFlowColors.surface,
        borderRadius: BorderRadius.circular(Responsive.w(context, 14)),
        border: Border.all(color: const Color(0xFFD8DEDB)),
      ),
      child: Column(
        children: [
          _fieldRow(
            icon: Icons.receipt_long_outlined,
            iconColor: const Color(0xFF5A8D2C),
            iconBackground: const Color(0xFFE4F3D9),
            label: _isVietnamese ? 'Tên' : 'Name',
            value: draft.name ?? _missingLabel,
            missing: draft.missingFields.contains(QuickAddMissingField.name),
          ),
          _divider(),
          _fieldRow(
            icon: Icons.format_list_bulleted_rounded,
            iconColor: AppColors.mediumGreen,
            iconBackground: const Color(0xFFD8F7EC),
            label: _isVietnamese ? 'Danh mục' : 'Category',
            value: categoryValue,
            missing: draft.missingFields.contains(
              QuickAddMissingField.category,
            ),
          ),
          _divider(),
          _fieldRow(
            icon: Icons.credit_card_rounded,
            iconColor: AppColors.blueAccent,
            iconBackground: const Color(0xFFE5EEFF),
            label: _isVietnamese ? 'Tài khoản' : 'Wallet',
            value: walletValue,
            missing: draft.missingFields.contains(QuickAddMissingField.wallet),
          ),
          _divider(),
          _fieldRow(
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.darkText,
            iconBackground: const Color(0xFFE9EFEC),
            label: _isVietnamese ? 'Ngày' : 'Date',
            value: _dateLabel(draft.date),
          ),
        ],
      ),
    );
  }

  Widget _fieldRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String label,
    required String value,
    bool missing = false,
  }) {
    return Container(
      color: missing ? const Color(0xFFFFF8E7) : Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 13),
        vertical: Responsive.h(context, 12),
      ),
      child: Row(
        children: [
          Container(
            width: Responsive.w(context, 32),
            height: Responsive.w(context, 32),
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: Responsive.w(context, 17),
              color: iconColor,
            ),
          ),
          SizedBox(width: Responsive.w(context, 12)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 13),
                color: AppColors.muted,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 13),
                fontWeight: missing ? FontWeight.w600 : FontWeight.w400,
                color: missing ? AppColors.coral : AppColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFE6EAE8));

  Widget _buildWarnings() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DB),
        borderRadius: BorderRadius.circular(Responsive.w(context, 12)),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: Responsive.w(context, 19),
            color: const Color(0xFF8A6100),
          ),
          SizedBox(width: Responsive.w(context, 9)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.draft.warnings
                  .map(
                    (warning) => Padding(
                      padding: EdgeInsets.only(
                        bottom: Responsive.h(context, 3),
                      ),
                      child: Text(
                        warning,
                        style: TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: Responsive.sp(context, 12),
                          color: const Color(0xFF604600),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        Responsive.h(context, 12),
        Responsive.w(context, 20),
        Responsive.h(context, 16),
      ),
      decoration: BoxDecoration(
        color: context.finFlowColors.bottomSheetBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('quick_add_edit_details'),
              onPressed: _isConfirming
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(QuickAddReviewAction.editDetails),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepEmerald,
                side: const BorderSide(color: AppColors.deepEmerald),
                minimumSize: Size(0, Responsive.h(context, 48)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: Text(_isVietnamese ? 'Chỉnh sửa' : 'Edit Details'),
            ),
          ),
          SizedBox(width: Responsive.w(context, 14)),
          Expanded(
            child: ElevatedButton(
              key: const Key('quick_add_confirm'),
              onPressed: widget.draft.canConfirm && !_isConfirming
                  ? _confirm
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepEmerald,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.mutedGray.withValues(
                  alpha: 0.35,
                ),
                minimumSize: Size(0, Responsive.h(context, 48)),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: _isConfirming
                  ? SizedBox(
                      width: Responsive.w(context, 20),
                      height: Responsive.w(context, 20),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isVietnamese ? 'Xác nhận' : 'Confirm'),
            ),
          ),
        ],
      ),
    );
  }

  String get _missingLabel => _isVietnamese ? 'Cần bổ sung' : 'Required';

  String _dateLabel(DateTime? date) {
    if (date == null) return _isVietnamese ? 'Hôm nay' : 'Today';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final value = DateTime(date.year, date.month, date.day);
    if (value == today) return _isVietnamese ? 'Hôm nay' : 'Today';
    if (value == today.subtract(const Duration(days: 1))) {
      return _isVietnamese ? 'Hôm qua' : 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatVnd(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}
