import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../models/transaction_category.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
class EditTransactionScreen extends ConsumerStatefulWidget {
  const EditTransactionScreen({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  ConsumerState<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late String _selectedCategory;

  /// All category keys: built-in 14 + user custom ones.
  late List<String> _allCategoryKeys;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.transaction.title);
    _amountController = TextEditingController(
      text: widget.transaction.amount.abs().toString(),
    );

    // Build full list: built-in keys + any custom keys that exist in the store
    _allCategoryKeys = [
      ...TransactionCategory.all.map((c) => c.key),
      ...CustomCategoryStore.instance.items.map((c) => c.name),
    ].toSet().toList(); // deduplicate

    // Fallback to 'Other' if not found
    _selectedCategory = _allCategoryKeys.contains(widget.transaction.category)
        ? widget.transaction.category
        : 'Other';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  IconData _iconForCategory(String key) {
    // Check custom store first
    final custom = CustomCategoryStore.instance.findByKey(key);
    if (custom != null) return custom.iconData;
    return TransactionCategory.fromKey(key).icon;
  }

  Color _colorForCategory(String key) {
    final custom = CustomCategoryStore.instance.findByKey(key);
    if (custom != null) return custom.color;
    return TransactionCategory.fromKey(key).color;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.editTransaction),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.coral),
            onPressed: () async {
              await ref.read(transactionServiceProvider).delete(widget.transaction.id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Preview chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _colorForCategory(_selectedCategory).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconForCategory(_selectedCategory),
                      color: _colorForCategory(_selectedCategory), size: 20),
                  const SizedBox(width: 8),
                  Text(_selectedCategory,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _colorForCategory(_selectedCategory),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: AppStrings.title),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: AppStrings.amountVND),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(labelText: AppStrings.category),
              items: _allCategoryKeys.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(_iconForCategory(cat), size: 18, color: _colorForCategory(cat)),
                      const SizedBox(width: 10),
                      Text(cat),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCategory = v);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final amount = int.tryParse(
                  _amountController.text.replaceAll(',', ''),
                );
                if (amount == null || amount <= 0) return;
                final sign = widget.transaction.amount < 0 ? -1 : 1;
                await ref.read(transactionServiceProvider).update(TransactionModel(
                  id: widget.transaction.id,
                  userId: widget.transaction.userId,
                  title: _titleController.text.trim(),
                  category: _selectedCategory,
                  amount: amount * sign,
                  date: widget.transaction.date,
                ));
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }
}
