import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/responsive.dart';
import '../models/transaction_category.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

const _accounts = ['ING', 'BRD', 'Cash'];

/// Available icons for custom categories.
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
  Icons.wine_bar,
  Icons.sports_esports,
  Icons.work,
  Icons.family_restroom,
  Icons.construction,
  Icons.train,
  Icons.local_gas_station,
];

/// Available colors for custom categories.
const _customColors = <Color>[
  Color(0xFFE53935),
  Color(0xFFD81B60),
  Color(0xFF8E24AA),
  Color(0xFF5E35B1),
  Color(0xFF3949AB),
  Color(0xFF1E88E5),
  Color(0xFF039BE5),
  Color(0xFF00ACC1),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFF7CB342),
  Color(0xFFC0CA33),
  Color(0xFFFDD835),
  Color(0xFFFFB300),
  Color(0xFFFB8C00),
  Color(0xFFF4511E),
  Color(0xFF6D4C41),
  Color(0xFF757575),
];

// =============================================================================
//  ADD TRANSACTION SHEET
// =============================================================================

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddTransactionSheet(),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  var _isExpense = true;
  var _selectedAccount = 'ING';
  var _selectedCategory = 'Food';
  var _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_formatAmount);
  }

  void _formatAmount() {
    if (_isFormatting) return;
    _isFormatting = true;
    final text = _amountController.text.replaceAll(',', '');
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _amountController.text = '';
    } else {
      final formatted = _addCommas(digits);
      final pos = formatted.length;
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: pos),
      );
    }
    _isFormatting = false;
  }

  static String _addCommas(String digits) {
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  void dispose() {
    _amountController.removeListener(_formatAmount);
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Responsive.w(context, 24),
        right: Responsive.w(context, 24),
        top: Responsive.h(context, 24),
        bottom: MediaQuery.of(context).viewInsets.bottom + Responsive.h(context, 24),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add transaction',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: Responsive.sp(context, 18),
                    color: const Color(0xFF003829),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(context, 12)),

            // ── Segmented tabs ──
            Container(
              height: Responsive.h(context, 36),
              decoration: BoxDecoration(
                color: AppColors.lightGreen.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _SegmentTab(
                    label: 'New income',
                    isSelected: !_isExpense,
                    onTap: () => setState(() => _isExpense = false),
                  ),
                  _SegmentTab(
                    label: 'New expense',
                    isSelected: _isExpense,
                    onTap: () => setState(() => _isExpense = true),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.h(context, 24)),

            // ── Amount input ──
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 20),
                vertical: Responsive.h(context, 16),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    _isExpense ? '-' : '+',
                    style: TextStyle(
                      fontWeight: FontWeight.w100,
                      fontSize: Responsive.sp(context, 74),
                      color: const Color(0xFF7D968B),
                    ),
                  ),
                  SizedBox(width: Responsive.w(context, 12)),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 40),
                        color: const Color(0xFF444745),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontSize: Responsive.sp(context, 40),
                          color: const Color(0xFF444745).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.w(context, 8)),
                  Text(
                    'VND',
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 24),
                      color: const Color(0xFF0076E3),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.h(context, 20)),

            // ── From account ──
            Text('From account',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: Responsive.sp(context, 16),
                  color: const Color(0xFF747875),
                )),
            SizedBox(height: Responsive.h(context, 8)),
            Row(
              children: _accounts.map((account) {
                final isSelected = _selectedAccount == account;
                return Padding(
                  padding: EdgeInsets.only(right: Responsive.w(context, 8)),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedAccount = account),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(context, 20),
                        vertical: Responsive.h(context, 8),
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1CA380) : Colors.white,
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1CA380) : const Color(0xFFBFC9C3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            Padding(
                              padding: EdgeInsets.only(right: Responsive.w(context, 6)),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          Text(account,
                              style: TextStyle(
                                fontSize: Responsive.sp(context, 14),
                                color: isSelected ? Colors.white : const Color(0xFF707974),
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: Responsive.h(context, 20)),

            // ── Category grid ──
            Text('From category',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: Responsive.sp(context, 16),
                  color: const Color(0xFF707974),
                )),
            SizedBox(height: Responsive.h(context, 8)),
            _buildCategoryGrid(),

            SizedBox(height: Responsive.h(context, 24)),

            // ── Confirm button ──
            ElevatedButton(
              onPressed: () async {
                final amountText = _amountController.text.trim();
                final amount = int.tryParse(amountText.replaceAll(',', ''));
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.pleaseEnterValidAmount)),
                  );
                  return;
                }
                if (ref.read(authServiceProvider).currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.pleaseSignInFirst)),
                  );
                  return;
                }

                try {
                  final sign = _isExpense ? -1 : 1;
                  await ref.read(transactionServiceProvider).add(
                    TransactionModel(
                      id: 't_${DateTime.now().millisecondsSinceEpoch}',
                      userId: ref.read(authServiceProvider).currentUser!.id,
                      title: _selectedCategory,
                      category: _selectedCategory,
                      amount: amount * sign,
                      date: DateTime.now(),
                    ),
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1CA380),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, Responsive.h(context, 50)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Confirm',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: Responsive.sp(context, 16))),
            ),
            SizedBox(height: Responsive.h(context, 12)),
          ],
        ),
      ),
    );
  }

  // ── Category grid: popular + selected extended + custom + "More" ──
  Widget _buildCategoryGrid() {
    final store = CustomCategoryStore.instance;
    final popularKeys = TransactionCategory.popular.map((c) => c.key).toSet();
    final customKeys = store.items.map((c) => c.name).toSet();
    final shownKeys = {...popularKeys, ...customKeys};

    // Collect visible items: popular + custom
    final items = <TransactionCategory>[
      ...TransactionCategory.popular,
      ...store.items.map((c) => TransactionCategory(
            key: c.name,
            label: c.name,
            icon: c.iconData,
            color: c.color,
          )),
    ];

    // If the selected category is an extended built-in not yet shown, add it
    if (_selectedCategory.isNotEmpty &&
        !shownKeys.contains(_selectedCategory)) {
      final ext = TransactionCategory.fromKey(_selectedCategory);
      items.add(ext);
      shownKeys.add(_selectedCategory);
    }

    return Wrap(
      spacing: Responsive.w(context, 12),
      runSpacing: Responsive.h(context, 12),
      children: [
        ...items.map((cat) => _buildCategoryCircle(cat.key, cat.icon, cat.color, cat.label)),
        // "More" button
        _buildMoreButton(),
      ],
    );
  }

  Widget _buildCategoryCircle(String key, IconData icon, Color color, String label) {
    final isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: Responsive.w(context, 50),
            height: Responsive.w(context, 50),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.5),
                width: isSelected ? 3 : 2,
              ),
              color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF5F5F5),
            ),
            child: Icon(icon,
                color: isSelected ? color : color.withValues(alpha: 0.7), size: Responsive.w(context, 22)),
          ),
          SizedBox(height: Responsive.h(context, 4)),
          SizedBox(
            width: Responsive.w(context, 56),
            child: Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: Responsive.sp(context, 10),
                    color: AppColors.darkText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreButton() {
    return GestureDetector(
      onTap: () => _showMoreSheet(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: Responsive.w(context, 50),
            height: Responsive.w(context, 50),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFBFC9C3), width: 2),
              color: Colors.white,
            ),
            child: Icon(Icons.add, color: const Color(0xFF707974), size: Responsive.w(context, 22)),
          ),
          SizedBox(height: Responsive.h(context, 4)),
          Text('More',
              style: TextStyle(
                fontSize: Responsive.sp(context, 10),
                color: const Color(0xFF707974),
              )),
        ],
      ),
    );
  }

  Future<void> _showMoreSheet(BuildContext context) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _MoreCategorySheet(),
    );
    if (result != null && mounted) {
      setState(() => _selectedCategory = result);
    }
  }
}

// =============================================================================
// "MORE" BOTTOM SHEET
// =============================================================================

class _MoreCategorySheet extends ConsumerStatefulWidget {
  const _MoreCategorySheet();

  @override
  ConsumerState<_MoreCategorySheet> createState() => _MoreCategorySheetState();
}

class _MoreCategorySheetState extends ConsumerState<_MoreCategorySheet> {
  // ── Custom category form state ──
  final _customNameController = TextEditingController();
  var _customIcon = Icons.school;
  var _customColor = const Color(0xFF1E88E5);

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Responsive.w(context, 24),
        right: Responsive.w(context, 24),
        top: Responsive.h(context, 24),
        bottom: MediaQuery.of(context).viewInsets.bottom + Responsive.h(context, 24),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('More Categories',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.sp(context, 18),
                  color: const Color(0xFF003829),
                )),
          SizedBox(height: Responsive.h(context, 16)),

          // ── Built-in extended categories ──
          Text('Built-in',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: Responsive.sp(context, 14),
                color: const Color(0xFF747875),
              )),
          SizedBox(height: Responsive.h(context, 8)),
          Wrap(
            spacing: Responsive.w(context, 12),
            runSpacing: Responsive.h(context, 12),
            children: TransactionCategory.extended.map((cat) {
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(cat.key),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: Responsive.w(context, 50),
                      height: Responsive.w(context, 50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cat.color.withValues(alpha: 0.5), width: 2),
                        color: cat.color.withValues(alpha: 0.1),
                      ),
                      child: Icon(cat.icon, color: cat.color, size: Responsive.w(context, 22)),
                    ),
                    SizedBox(height: Responsive.h(context, 4)),
                    Text(cat.label,
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 10),
                          color: AppColors.darkText,
                        )),
                  ],
                ),
              );
            }).toList(),
          ),

          SizedBox(height: Responsive.h(context, 24)),
          const Divider(),
          SizedBox(height: Responsive.h(context, 12)),

          // ── Custom category ──
          Text('Custom Category',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: Responsive.sp(context, 14),
                color: const Color(0xFF747875),
              )),
          SizedBox(height: Responsive.h(context, 8)),
          TextField(
            controller: _customNameController,
            decoration: InputDecoration(
              hintText: 'e.g. Tuition, Repair...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 16),
                vertical: Responsive.h(context, 12),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 12)),

          // ── Icon picker ──
          Text('Pick icon',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: Responsive.sp(context, 13),
                color: const Color(0xFF747875),
              )),
          SizedBox(height: Responsive.h(context, 6)),
          SizedBox(
            height: Responsive.h(context, 36),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _customIcons.map((icn) {
                final isSelected = icn == _customIcon;
                return GestureDetector(
                  onTap: () => setState(() => _customIcon = icn),
                  child: Container(
                    width: Responsive.w(context, 36),
                    height: Responsive.w(context, 36),
                    margin: EdgeInsets.only(right: Responsive.w(context, 6)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? _customColor.withValues(alpha: 0.2) : const Color(0xFFF5F5F5),
                      border: Border.all(
                        color: isSelected ? _customColor : const Color(0xFFBFC9C3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      icn,
                      size: Responsive.w(context, 18),
                      color: isSelected ? _customColor : const Color(0xFF707974),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: Responsive.h(context, 12)),

          // ── Color picker ──
          Text('Pick color',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: Responsive.sp(context, 13),
                color: const Color(0xFF747875),
              )),
          SizedBox(height: Responsive.h(context, 6)),
          Wrap(
            spacing: Responsive.w(context, 6),
            runSpacing: Responsive.h(context, 6),
            children: _customColors.map((clr) {
              final isSelected = clr == _customColor;
              return GestureDetector(
                onTap: () => setState(() => _customColor = clr),
                child: Container(
                  width: Responsive.w(context, 28),
                  height: Responsive.w(context, 28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: clr,
                    border: isSelected
                        ? Border.all(color: Colors.black, width: 2.5)
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: Responsive.w(context, 16), color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          SizedBox(height: Responsive.h(context, 16)),

          // ── Save custom category ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final name = _customNameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a category name')),
                  );
                  return;
                }
                // Store custom category
                CustomCategoryStore.instance.add(
                  CustomCategoryDef(name: name, iconData: _customIcon, color: _customColor),
                );
                Navigator.of(context).pop(name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1CA380),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Save Category',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: Responsive.sp(context, 15))),
            ),
          ),
          SizedBox(height: Responsive.h(context, 8)),
        ],
      ),
      ),
    );
  }
}

// =============================================================================
//  Segment tab widget
// =============================================================================

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 8)),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF006C52) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                fontSize: Responsive.sp(context, 16),
                color: isSelected ? Colors.white : const Color(0xFF008768),
              )),
        ),
      ),
    );
  }
}
