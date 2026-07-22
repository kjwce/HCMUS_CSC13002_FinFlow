import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../services/wallet_service.dart';

/// Collects the opening balances for FinFlow's two system payment sources.
class WalletOnboardingScreen extends StatefulWidget {
  const WalletOnboardingScreen({super.key});

  @override
  State<WalletOnboardingScreen> createState() => _WalletOnboardingScreenState();
}

class _WalletOnboardingScreenState extends State<WalletOnboardingScreen> {
  final _cashController = TextEditingController();
  final _transferController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _cashController.dispose();
    _transferController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF093030)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Thiết lập nguồn tiền',
          style: TextStyle(
            color: Color(0xFF093030),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.w(context, 20),
            Responsive.h(context, 16),
            Responsive.w(context, 20),
            Responsive.h(context, 20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nhập số dư hiện tại',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF052224),
                ),
              ),
              SizedBox(height: Responsive.h(context, 6)),
              const Text(
                'FinFlow sử dụng hai nguồn tiền chung. Bạn có thể nhập 0 và cập nhật lại sau.',
                style: TextStyle(color: Color(0xFF5F6F6B), height: 1.45),
              ),
              SizedBox(height: Responsive.h(context, 24)),
              _BalanceCard(
                controller: _cashController,
                title: 'Tiền mặt',
                description: 'Tiền bạn đang giữ và chi tiêu trực tiếp',
                icon: Icons.payments_outlined,
                color: const Color(0xFF4CAF50),
              ),
              SizedBox(height: Responsive.h(context, 14)),
              _BalanceCard(
                controller: _transferController,
                title: 'Chuyển khoản',
                description: 'Các khoản thanh toán không dùng tiền mặt',
                icon: Icons.swap_horiz_rounded,
                color: const Color(0xFF2878D0),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: const Color(0xFF002112),
                  minimumSize: Size.fromHeight(Responsive.h(context, 52)),
                  shape: const StadiumBorder(),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Tiếp tục',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await WalletService.instance.saveSystemWallets(
        cashInitialBalance: _parseBalance(_cashController.text),
        transferInitialBalance: _parseBalance(_transferController.text),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.budgetSetup, (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lưu: $error')));
    }
  }

  static int _parseBalance(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'\D'), '')) ?? 0;
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.controller,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final TextEditingController controller;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF6D7B74),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Số dư ban đầu',
              hintText: '0',
              suffixText: 'VND',
              filled: true,
              fillColor: const Color(0xFFF6FAF8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
