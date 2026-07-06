import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../models/transaction_category.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  const EditTransactionScreen({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late String _selectedCategory;
  String? _selectedWalletId;
  var _isFormatting = false;

  /// All category keys: built-in 14 + user custom ones.
  late List<String> _allCategoryKeys;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.transaction.name);
    _amountController = TextEditingController(
      text: _addCommas(widget.transaction.amount.abs().toString()),
    );
    _amountController.addListener(_formatAmount);
    _selectedWalletId = widget.transaction.walletId;
    Future.microtask(() {
      ref
          .read(walletServiceProvider)
          .fetchWallets()
          .catchError((e) => debugPrint('fetchWallets error: $e'));
    });

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

  void _formatAmount() {
    if (_isFormatting) return;
    _isFormatting = true;
    final text = _amountController.text.replaceAll(',', '');
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _amountController.text = '';
    } else {
      final formatted = _addCommas(digits);
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
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

  IconData _iconForWalletType(WalletType type) {
    return switch (type) {
      WalletType.bank => Icons.account_balance,
      WalletType.ewallet => Icons.wallet,
      WalletType.cash => Icons.money,
    };
  }

  String _walletLabel(WalletModel wallet) {
    return wallet.name;
  }

  WalletModel? _selectedWallet(List<WalletModel> wallets) {
    final id = _selectedWalletId;
    if (id == null) return null;
    for (final wallet in wallets) {
      if (wallet.id == id) return wallet;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletServiceProvider).currentUserWallets;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.editTransaction),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.coral),
            onPressed: () async {
              await ref
                  .read(transactionServiceProvider)
                  .delete(widget.transaction.id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(Responsive.w(context, 24)),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Preview chip
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 16),
                  vertical: Responsive.h(context, 10),
                ),
                decoration: BoxDecoration(
                  color: _colorForCategory(
                    _selectedCategory,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForCategory(_selectedCategory),
                      color: _colorForCategory(_selectedCategory),
                      size: Responsive.w(context, 20),
                    ),
                    SizedBox(width: Responsive.w(context, 8)),
                    Text(
                      _selectedCategory,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _colorForCategory(_selectedCategory),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Responsive.h(context, 20)),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              SizedBox(height: Responsive.h(context, 12)),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: AppStrings.amountVND),
              ),
              SizedBox(height: Responsive.h(context, 12)),
              _buildWalletSelector(wallets),
              SizedBox(height: Responsive.h(context, 12)),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(labelText: AppStrings.category),
                items: _allCategoryKeys.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Icon(
                          _iconForCategory(cat),
                          size: Responsive.w(context, 18),
                          color: _colorForCategory(cat),
                        ),
                        SizedBox(width: Responsive.w(context, 10)),
                        Text(cat),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
              ),
              SizedBox(height: Responsive.h(context, 24)),
              ElevatedButton(
                onPressed: () async {
                  final amount = int.tryParse(
                    _amountController.text.replaceAll(',', ''),
                  );
                  if (amount == null || amount <= 0) return;
                  final sign = widget.transaction.amount < 0 ? -1 : 1;
                  await ref
                      .read(transactionServiceProvider)
                      .update(
                        TransactionModel(
                          id: widget.transaction.id,
                          userId: widget.transaction.userId,
                          name: _titleController.text.trim(),
                          category: _selectedCategory,
                          amount: amount * sign,
                          date: widget.transaction.date,
                          walletId: _selectedWalletId,
                        ),
                      );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: Text(AppStrings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletSelector(List<WalletModel> wallets) {
    final wallet = _selectedWallet(wallets);
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: wallets.isEmpty ? null : () => _showWalletPicker(wallets),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'From account'),
        child: Row(
          children: [
            Icon(
              wallet == null
                  ? Icons.account_balance_wallet_outlined
                  : _iconForWalletType(wallet.type),
              size: Responsive.w(context, 18),
              color: wallet?.brandColor ?? AppColors.mutedGray,
            ),
            SizedBox(width: Responsive.w(context, 10)),
            Expanded(
              child: Text(
                wallet == null ? 'Select account' : _walletLabel(wallet),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: wallet == null ? AppColors.mutedGray : null,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: Responsive.w(context, 20),
              color: AppColors.mutedGray,
            ),
          ],
        ),
      ),
    );
  }

  void _showWalletPicker(List<WalletModel> wallets) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final groupedWallets = <WalletType, List<WalletModel>>{
          WalletType.bank: wallets
              .where((wallet) => wallet.type == WalletType.bank)
              .toList(),
          WalletType.ewallet: wallets
              .where((wallet) => wallet.type == WalletType.ewallet)
              .toList(),
          WalletType.cash: wallets
              .where((wallet) => wallet.type == WalletType.cash)
              .toList(),
        };

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(Responsive.w(context, 16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: groupedWallets.entries.expand((entry) {
                  final groupWallets = entry.value;
                  if (groupWallets.isEmpty) return const <Widget>[];
                  return [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        Responsive.w(context, 16),
                        Responsive.h(context, 12),
                        Responsive.w(context, 16),
                        Responsive.h(context, 4),
                      ),
                      child: Text(
                        _walletTypeLabel(entry.key),
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 13),
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedGray,
                        ),
                      ),
                    ),
                    ...groupWallets.map((wallet) {
                      return ListTile(
                        leading: Icon(
                          _iconForWalletType(wallet.type),
                          color: wallet.brandColor,
                        ),
                        title: Text(
                          _walletLabel(wallet),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: wallet.id == _selectedWalletId
                            ? const Icon(
                                Icons.check,
                                color: AppColors.primaryGreen,
                              )
                            : null,
                        onTap: () {
                          setState(() => _selectedWalletId = wallet.id);
                          Navigator.of(context).pop();
                        },
                      );
                    }),
                  ];
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  String _walletTypeLabel(WalletType type) {
    return switch (type) {
      WalletType.bank => 'Bank',
      WalletType.ewallet => 'E-Wallet',
      WalletType.cash => 'Cash',
    };
  }
}
