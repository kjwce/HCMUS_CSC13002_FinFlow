import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_language.dart';
import '../../finance/models/transaction_category.dart';
import '../../finance/presentation/widgets/goal_ui.dart';
import '../models/category_budget_model.dart';

enum CategoryBudgetDialogAction { save, delete }

class CategoryBudgetDialogResult {
  const CategoryBudgetDialogResult.save({
    required this.category,
    required this.limitAmount,
  }) : action = CategoryBudgetDialogAction.save;

  const CategoryBudgetDialogResult.delete()
    : action = CategoryBudgetDialogAction.delete,
      category = '',
      limitAmount = 0;

  final CategoryBudgetDialogAction action;
  final String category;
  final int limitAmount;
}

Future<CategoryBudgetDialogResult?> showCategoryBudgetDialog(
  BuildContext context, {
  CategoryBudgetModel? budget,
  int currentSpent = 0,
}) {
  final darkDialog = Theme.of(context).brightness == Brightness.dark;
  return showDialog<CategoryBudgetDialogResult>(
    context: context,
    barrierColor: darkDialog
        ? const Color(0xB3000000)
        : const Color(0x990B1612),
    builder: (_) =>
        _CategoryBudgetDialog(budget: budget, currentSpent: currentSpent),
  );
}

class _CategoryBudgetDialog extends StatefulWidget {
  const _CategoryBudgetDialog({
    required this.budget,
    required this.currentSpent,
  });

  final CategoryBudgetModel? budget;
  final int currentSpent;

  @override
  State<_CategoryBudgetDialog> createState() => _CategoryBudgetDialogState();
}

class _CategoryBudgetDialogState extends State<_CategoryBudgetDialog> {
  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';
  static const _darkModal = Color(0xFF16352E);
  static const _darkBorder = Color(0xFF29483F);
  static const _darkText = Color(0xFFF4FBF8);
  static const _darkSecondary = Color(0xFFA9C1B9);
  static const _darkMuted = Color(0xFF708D84);
  static const _darkInput = Color(0xFF0A241F);
  static const _darkPanel = Color(0xFF112622);
  static const _darkAccent = Color(0xFF38D6AC);
  static const _darkRemove = Color(0xFFFF6B70);

  late String _category = widget.budget?.category ?? 'Food';
  late final TextEditingController _controller = TextEditingController(
    text: widget.budget == null ? '0' : formatVnd(widget.budget!.limitAmount),
  );
  String? _amountError;

  bool get _isEditing => widget.budget != null;
  bool get _isDarkEdit => Theme.of(context).brightness == Brightness.dark;
  int get _amount => int.tryParse(_controller.text.replaceAll(',', '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleAmountChanged)
      ..dispose();
    super.dispose();
  }

  void _handleAmountChanged() {
    if (_amountError != null || mounted) setState(() => _amountError = null);
  }

  void _save() {
    if (_amount <= 0) {
      setState(
        () => _amountError = AppStrings.choose(
          'Enter a monthly limit greater than 0.',
          'Nhập hạn mức tháng lớn hơn 0.',
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      CategoryBudgetDialogResult.save(
        category: _category,
        limitAmount: _amount,
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: Text(AppStrings.choose('Remove budget?', 'Xóa ngân sách?')),
        content: Text(
          AppStrings.choose(
            'The monthly limit for ${_categoryLabel(_category)} will be removed. Your transactions will not be affected.',
            'Hạn mức tháng của ${AppStrings.categoryName(_categoryLabel(_category))} sẽ bị xóa. Các giao dịch của bạn không bị ảnh hưởng.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmContext).pop(false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: goalError),
            onPressed: () => Navigator.of(confirmContext).pop(true),
            child: Text(AppStrings.choose('Remove', 'Xóa')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const CategoryBudgetDialogResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _amount <= 0
        ? 0.0
        : (widget.currentSpent / _amount).clamp(0.0, 1.0);
    final usedPercent = _amount <= 0
        ? 0
        : ((widget.currentSpent / _amount) * 100).round();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: _isDarkEdit ? _darkModal : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: _isDarkEdit ? 0 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: _isDarkEdit
            ? const BorderSide(color: _darkBorder)
            : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, _isEditing ? 14 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isDarkEdit
                          ? _darkAccent.withValues(alpha: .18)
                          : goalMint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: _isDarkEdit ? _darkAccent : goalPrimary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing
                              ? AppStrings.choose(
                                  'Edit Category Budget',
                                  'Sửa ngân sách danh mục',
                                )
                              : AppStrings.choose(
                                  'Add Category Budget',
                                  'Thêm ngân sách danh mục',
                                ),
                          style: TextStyle(
                            fontFamily: _headlineFont,
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: _isDarkEdit ? _darkText : goalText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isEditing
                              ? AppStrings.choose(
                                  'Update the monthly spending limit for this category.',
                                  'Cập nhật hạn mức chi tiêu tháng cho danh mục này.',
                                )
                              : AppStrings.choose(
                                  'Set a monthly spending limit for a category.',
                                  'Đặt hạn mức chi tiêu tháng cho một danh mục.',
                                ),
                          style: TextStyle(
                            fontFamily: _bodyFont,
                            fontSize: 12.5,
                            height: 1.35,
                            color: _isDarkEdit ? _darkSecondary : goalMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isEditing)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: AppStrings.choose('Close', 'Đóng'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: _isDarkEdit ? _darkMuted : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _FieldLabel(AppStrings.category, dark: _isDarkEdit),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _isDarkEdit ? _darkMuted : null,
                ),
                borderRadius: BorderRadius.circular(14),
                decoration: _inputDecoration(dark: _isDarkEdit),
                items: [
                  if (!TransactionCategory.all.any(
                    (category) => category.key == _category,
                  ))
                    DropdownMenuItem(
                      value: _category,
                      child: _CategoryOption(
                        categoryKey: _category,
                        dark: _isDarkEdit,
                      ),
                    ),
                  ...TransactionCategory.all
                      .where((category) => category.key != 'Salary')
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.key,
                          child: _CategoryOption(
                            categoryKey: category.key,
                            dark: _isDarkEdit,
                          ),
                        ),
                      ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 16),
              _FieldLabel(
                AppStrings.choose('Monthly Limit', 'Hạn mức tháng'),
                dark: _isDarkEdit,
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _controller,
                autofocus: false,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _BudgetAmountFormatter(),
                ],
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: _isDarkEdit ? _darkText : goalText,
                ),
                decoration: _inputDecoration(
                  dark: _isDarkEdit,
                  errorText: _amountError,
                  suffix: Text(
                    'VND',
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: 13,
                      color: _isDarkEdit ? _darkAccent : goalText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _isEditing
                    ? AppStrings.choose(
                        'Current monthly spending: ${formatVnd(widget.currentSpent)} VND',
                        'Chi tiêu tháng hiện tại: ${formatVnd(widget.currentSpent)} VND',
                      )
                    : AppStrings.choose(
                        'You can change this limit at any time.',
                        'Bạn có thể thay đổi hạn mức này bất cứ lúc nào.',
                      ),
                style: TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: _isDarkEdit ? _darkMuted : goalMuted,
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 17),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isDarkEdit ? _darkPanel : const Color(0xFFE5F8F1),
                    borderRadius: BorderRadius.circular(12),
                    border: _isDarkEdit ? Border.all(color: _darkBorder) : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${AppStrings.categoryName(_categoryLabel(_category))} ${AppStrings.choose('budget usage', 'mức sử dụng ngân sách')}',
                            style: TextStyle(
                              fontFamily: _bodyFont,
                              fontSize: 12,
                              color: _isDarkEdit ? _darkAccent : goalMuted,
                            ),
                          ),
                          Text(
                            AppStrings.choose(
                              '${usedPercent.clamp(0, 100)}% used',
                              'Đã dùng ${usedPercent.clamp(0, 100)}%',
                            ),
                            style: TextStyle(
                              fontFamily: _bodyFont,
                              fontSize: 12,
                              color: _isDarkEdit ? _darkSecondary : goalMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          color: _isDarkEdit ? _darkAccent : goalPrimary,
                          backgroundColor: _isDarkEdit
                              ? _darkBorder
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${formatVnd(widget.currentSpent)} / ${formatVnd(_amount)} VND',
                          style: TextStyle(
                            fontFamily: _bodyFont,
                            fontSize: 11,
                            color: _isDarkEdit ? _darkMuted : goalMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: _isEditing ? 24 : 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: goalPrimary,
                    disabledBackgroundColor: _isDarkEdit
                        ? _darkBorder
                        : const Color(0xFFA8CEC3),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _amount > 0 ? _save : null,
                  child: Text(
                    _isEditing
                        ? AppStrings.choose('Save Changes', 'Lưu thay đổi')
                        : AppStrings.choose('Save Budget', 'Lưu ngân sách'),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: _isDarkEdit ? _darkSecondary : goalText,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    AppStrings.cancel,
                    style: const TextStyle(fontFamily: _bodyFont, fontSize: 13),
                  ),
                ),
              ),
              if (_isEditing) ...[
                Divider(
                  height: 14,
                  color: _isDarkEdit ? _darkBorder : const Color(0x1F3E4944),
                ),
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: _isDarkEdit ? _darkRemove : goalError,
                    ),
                    onPressed: _delete,
                    child: Text(
                      AppStrings.choose('Remove Budget', 'Xóa ngân sách'),
                      style: const TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static InputDecoration _inputDecoration({
    required bool dark,
    Widget? suffix,
    String? errorText,
  }) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: dark ? _darkInput : const Color(0xFFF9FAFA),
    hintStyle: TextStyle(color: dark ? _darkMuted : null),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    suffix: suffix,
    errorText: errorText,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: dark ? _darkBorder : goalOutline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: dark ? _darkAccent : goalPrimary,
        width: 1.4,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: goalError),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: goalError, width: 1.4),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.dark = false});
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily: 'Hanken Grotesk',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: dark ? _CategoryBudgetDialogState._darkSecondary : goalText,
    ),
  );
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({required this.categoryKey, this.dark = false});
  final String categoryKey;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final category = TransactionCategory.resolve(_transactionKey(categoryKey));
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: category.buildIcon(size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          AppStrings.categoryName(_categoryLabel(categoryKey)),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 15,
            color: dark ? _CategoryBudgetDialogState._darkText : goalText,
          ),
        ),
      ],
    );
  }
}

String _transactionKey(String category) => switch (category.toLowerCase()) {
  'food & dining' => 'Food',
  'transportation' => 'Transport',
  _ => category,
};

String _categoryLabel(String category) => switch (category.toLowerCase()) {
  'food & dining' || 'food' => 'Food',
  'transportation' || 'transport' => 'Transportation',
  _ => TransactionCategory.resolve(_transactionKey(category)).label,
};

class _BudgetAmountFormatter extends TextInputFormatter {
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
