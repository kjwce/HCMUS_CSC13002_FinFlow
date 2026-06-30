import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/goal_service.dart';

/// Bottom sheet / full dialog to create or view a saving goal.
class GoalSetupSheet extends ConsumerStatefulWidget {
  const GoalSetupSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const GoalSetupSheet(),
    );
  }

  @override
  ConsumerState<GoalSetupSheet> createState() => _GoalSetupSheetState();
}

class _GoalSetupSheetState extends ConsumerState<GoalSetupSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSaving = false;
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
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(goalServiceProvider);
    final goal = gs.activeGoal;
    final saved = goal != null ? gs.savedAmount(ref.read(transactionServiceProvider).transactions) : 0;
    final progress = goal != null ? gs.progressRatio(ref.read(transactionServiceProvider).transactions) : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal != null ? 'Saving Goal' : 'Set a Saving Goal',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF003829),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (goal != null) ...[
            // ── Active goal detail ──
            _buildProgressCircle(progress),
            const SizedBox(height: 12),
            Text(
              goal.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF052224)),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatMoney(saved)} / ${_formatMoney(goal.targetAmount)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF747875)),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 24),
            // Delete button
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Goal'),
                    content: Text('Delete "${goal.name}" and start fresh?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await gs.deleteGoal(goal.id);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Goal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
            const SizedBox(height: 8),
            // Replace with new goal
            TextButton(
              onPressed: () => _startNewGoal(context, gs),
              child: const Text('Set New Goal Instead',
                  style: TextStyle(color: Color(0xFF0068FF))),
            ),
          ] else ...[
            // ── No goal yet — create form ──
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Goal name',
                hintText: 'e.g. Buy a laptop',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target amount (VND)',
                hintText: '5,000,000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _saveGoal(gs),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: const Color(0xFF093030),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Start Saving',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProgressCircle(double progress) {
    return Center(
      child: SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              color: const Color(0xFF007AFF),
              backgroundColor: Colors.white30,
            ),
            const Icon(Icons.flag, color: Color(0xFF093030), size: 28),
          ],
        ),
      ),
    );
  }

  Future<void> _startNewGoal(BuildContext context, GoalService gs) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace Goal'),
        content: const Text('Your current goal will be deactivated. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace')),
        ],
      ),
    );
    if (confirm == true) {
      Navigator.of(context).pop(); // close current sheet
      GoalSetupSheet.show(context); // reopen fresh
    }
  }

  Future<void> _saveGoal(GoalService gs) async {
    final name = _nameController.text.trim();
    final raw = _amountController.text.trim().replaceAll(',', '');
    final amount = int.tryParse(raw);

    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name and a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      await gs.setGoal(GoalModel(
        id: 'g_${DateTime.now().millisecondsSinceEpoch}',
        userId: user!.id,
        name: name,
        targetAmount: amount,
        createdAt: DateTime.now(),
      ));
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  static String _formatMoney(int amount) {
    final text = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '$text VND';
  }
}

