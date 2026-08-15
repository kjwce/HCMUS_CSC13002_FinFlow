import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../finance/models/transaction_category.dart';
import '../../finance/providers/transaction_provider.dart';
import '../../finance/services/transaction_service.dart';
import '../../finance/presentation/widgets/goal_ui.dart';
import '../models/category_budget_model.dart';
import '../providers/category_budget_provider.dart';
import '../services/category_budget_service.dart';
import 'category_budget_dialog.dart';

class CategoryBudgetsScreen extends ConsumerStatefulWidget {
  const CategoryBudgetsScreen({super.key});

  @override
  ConsumerState<CategoryBudgetsScreen> createState() =>
      _CategoryBudgetsScreenState();
}

class _CategoryBudgetsScreenState extends ConsumerState<CategoryBudgetsScreen> {
  @override
  void initState() {
    super.initState();
    CategoryBudgetService.instance.addListener(_refresh);
    Future.microtask(
      () => ref.read(categoryBudgetServiceProvider).fetchCurrentMonth(),
    );
  }

  @override
  void dispose() {
    CategoryBudgetService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageColor = isDark ? const Color(0xFF081C18) : goalSurface;
    final primaryText = isDark ? const Color(0xFFF4FBF8) : goalText;
    final secondaryText = isDark ? const Color(0xFFA9C1B9) : goalMuted;
    final budgets = ref.watch(categoryBudgetServiceProvider).budgets;
    final transactions = ref.watch(transactionServiceProvider);
    final range = transactions.dateRangeForPeriod(ChartPeriod.month);
    final spent = transactions.expenseByCategoryBetween(range.start, range.end);
    final now = DateTime.now();
    final monthLabel = AppStrings.isVietnamese
        ? 'Tháng ${now.month}'
        : const [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ][now.month - 1];

    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF081C18)
            : const Color(0xFFE8F6F1),
        surfaceTintColor: Colors.transparent,
        foregroundColor: isDark ? const Color(0xFFF4FBF8) : goalPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF29483F) : const Color(0x1A006C53),
          ),
        ),
        title: Text(
          AppStrings.choose('Budget by Category', 'Ngân sách theo danh mục'),
          style: TextStyle(
            fontFamily: 'Manrope',
            color: isDark ? const Color(0xFFF4FBF8) : goalPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: budgets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: isDark
                          ? const Color(0xFF16352E)
                          : goalMint,
                      child: Icon(
                        Icons.pie_chart_outline_rounded,
                        size: 42,
                        color: isDark ? const Color(0xFF38D6AC) : goalPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.choose(
                        'Set your first category budget',
                        'Đặt ngân sách danh mục đầu tiên',
                      ),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.choose(
                        'Track spending limits for $monthLabel ${now.year}.',
                        'Theo dõi hạn mức chi tiêu cho $monthLabel năm ${now.year}.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondaryText),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: goalFilledButtonStyle(),
                      onPressed: () => _editBudget(),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        AppStrings.choose(
                          'Add Category Budget',
                          'Thêm ngân sách danh mục',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Text(
                  AppStrings.isVietnamese
                      ? '$monthLabel năm ${now.year}'
                      : '$monthLabel ${now.year}',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 14),
                ...budgets.map(
                  (budget) => _BudgetCard(
                    budget: budget,
                    spent: spent[_transactionKey(budget.category)] ?? 0,
                    onTap: () => _editBudget(
                      budget,
                      spent[_transactionKey(budget.category)] ?? 0,
                    ),
                    onDelete: () => ref
                        .read(categoryBudgetServiceProvider)
                        .delete(budget.id),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: budgets.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: pageColor,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0xFF29483F)
                          : const Color(0x14006C53),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton.icon(
                  style: goalFilledButtonStyle(),
                  onPressed: () => _editBudget(),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text(
                    AppStrings.choose(
                      'Add Category Budget',
                      'Thêm ngân sách danh mục',
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  static String _transactionKey(String category) =>
      switch (category.toLowerCase()) {
        'food & dining' => 'Food',
        'transportation' => 'Transport',
        _ => category,
      };

  Future<void> _editBudget([CategoryBudgetModel? budget, int spent = 0]) async {
    final result = await showCategoryBudgetDialog(
      context,
      budget: budget,
      currentSpent: spent,
    );
    if (result == null) return;
    final service = ref.read(categoryBudgetServiceProvider);
    if (result.action == CategoryBudgetDialogAction.delete && budget != null) {
      await service.delete(budget.id);
      return;
    }
    if (result.action == CategoryBudgetDialogAction.save) {
      await service.save(result.category, result.limitAmount);
      if (budget != null && result.category != budget.category) {
        await service.delete(budget.id);
      }
    }
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.onTap,
    required this.onDelete,
  });
  final CategoryBudgetModel budget;
  final int spent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = TransactionCategory.resolve(
      _CategoryBudgetsScreenState._transactionKey(budget.category),
    );
    final ratio = budget.limitAmount <= 0
        ? 0.0
        : (spent / budget.limitAmount).clamp(0.0, 1.0);
    final left = budget.limitAmount - spent;
    final color = ratio >= .9
        ? goalError
        : ratio >= .75
        ? const Color(0xFFF59E0B)
        : isDark
        ? const Color(0xFF38D6AC)
        : goalPrimary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF16352E) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF29483F) : const Color(0xFFE3E9E6),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: category.color.withValues(alpha: .12),
                    child: category.buildIcon(size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.categoryName(
                        _CategoryBudgetsScreenState._transactionKey(
                          budget.category,
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF4FBF8) : goalText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    AppStrings.choose(
                      '${formatVnd(left.abs())} ${left < 0 ? 'over' : 'left'}',
                      '${formatVnd(left.abs())} ${left < 0 ? 'vượt mức' : 'còn lại'}',
                    ),
                    style: TextStyle(
                      color: left < 0
                          ? (isDark ? const Color(0xFFFFB4AB) : goalError)
                          : (isDark ? const Color(0xFFA9C1B9) : goalText),
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  PopupMenuButton<String>(
                    iconColor: isDark ? const Color(0xFF708D84) : goalText,
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(AppStrings.choose('Delete', 'Xóa')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RoundedBudgetProgress(value: ratio, color: color),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _BudgetAmountCaption(
                      label: AppStrings.choose('Spent:', 'Đã chi:'),
                      amount: spent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BudgetAmountCaption(
                      label: AppStrings.choose('Budget:', 'Ngân sách:'),
                      amount: budget.limitAmount,
                      alignRight: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundedBudgetProgress extends StatelessWidget {
  const _RoundedBudgetProgress({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const height = 10.0;
    final progress = value.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rawWidth = constraints.maxWidth * progress;
          final fillWidth = progress <= 0
              ? 0.0
              : rawWidth.clamp(height, constraints.maxWidth);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF29483F) : goalSurfaceLow,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: fillWidth,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BudgetAmountCaption extends StatelessWidget {
  const _BudgetAmountCaption({
    required this.label,
    required this.amount,
    this.alignRight = false,
  });

  final String label;
  final int amount;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final captionColor = isDark
        ? const Color(0xFFA9C1B9)
        : const Color(0xFF52645F);
    final amountColor = isDark
        ? const Color(0xFFA9C1B9)
        : const Color(0xFF30433E);
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  color: captionColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: '${formatVnd(amount)} VND',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 12, height: 1.2),
        ),
      ),
    );
  }
}
