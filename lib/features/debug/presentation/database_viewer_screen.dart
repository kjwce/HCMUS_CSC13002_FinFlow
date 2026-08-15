import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../finance/providers/transaction_provider.dart';

class DatabaseViewerScreen extends ConsumerStatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  ConsumerState<DatabaseViewerScreen> createState() =>
      _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends ConsumerState<DatabaseViewerScreen> {
  var _isExporting = false;
  var _isClearing = false;

  Future<void> _exportDatabase() async {
    setState(() => _isExporting = true);
    // Supabase is cloud-based — no local export needed
    if (!mounted) return;
    setState(() => _isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.choose(
            'Data is stored in Supabase cloud',
            'Dữ liệu được lưu trên đám mây Supabase',
          ),
        ),
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.confirmClearTitle),
        content: Text(AppStrings.confirmClearMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppStrings.clear,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isClearing = true);
    try {
      await ref.read(transactionServiceProvider).clearAll();
      if (!mounted) return;
      setState(() => _isClearing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.dataCleared)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isClearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Failed to clear: $e',
              'Không thể xóa dữ liệu: $e',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final ts = ref.watch(transactionServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.databaseTitle),
        backgroundColor: AppColors.mintSoft,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _isClearing ? null : _clearAllData,
              icon: _isClearing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_sweep),
              tooltip: AppStrings.clearAllData,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _isExporting ? null : _exportDatabase,
              icon: _isExporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              tooltip: AppStrings.exportDB,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: AppStrings.choose('Current user', 'Người dùng hiện tại'),
            subtitle: auth.currentUser != null
                ? AppStrings.choose('1 record', '1 bản ghi')
                : AppStrings.choose('0 records', '0 bản ghi'),
          ),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.emerald,
                child: Text(
                  auth.currentUser?.fullName.isNotEmpty == true
                      ? auth.currentUser!.fullName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                auth.currentUser?.fullName ??
                    AppStrings.choose('Not signed in', 'Chưa đăng nhập'),
              ),
              subtitle: Text(auth.currentUser?.email ?? ''),
            ),
          ),
          const SizedBox(height: 18),
          _SectionHeader(
            title: AppStrings.choose('Transactions', 'Giao dịch'),
            subtitle: '${ts.transactions.length} ${AppStrings.records}',
          ),
          for (final transaction in ts.transactions)
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(transaction.name),
                subtitle: Text(
                  '${transaction.id} | user=${transaction.userId} | ${transaction.category}',
                ),
                trailing: Text(
                  '${transaction.amount} VND',
                  style: TextStyle(
                    color: transaction.amount < 0
                        ? AppColors.coral
                        : AppColors.emerald,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
