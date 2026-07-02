import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../models/bank_preset.dart';
import '../models/ewallet_preset.dart';
import '../models/wallet_model.dart';
import '../services/wallet_service.dart';


/// Onboarding screen shown after sign-up for the user to pick their wallets
/// and enter initial balances.
class WalletOnboardingScreen extends ConsumerStatefulWidget {
  const WalletOnboardingScreen({super.key});

  @override
  ConsumerState<WalletOnboardingScreen> createState() =>
      _WalletOnboardingScreenState();
}

class _WalletOnboardingScreenState
    extends ConsumerState<WalletOnboardingScreen> {
  int _step = 1; // 1 = pick wallets, 2 = enter balances

  // Selected wallet presets (step 1)
  final List<WalletPreset> _selectedBanks = [];
  WalletPreset? _selectedEwallet;
  bool _hasCash = true;

  // Balance controllers keyed by preset name (step 2)
  final Map<String, TextEditingController> _balanceControllers = {};
  bool _isSaving = false;

  List<WalletPreset> get _selectedPresets {
    final list = <WalletPreset>[..._selectedBanks];
    if (_selectedEwallet != null) list.add(_selectedEwallet!);
    if (_hasCash) {
      list.add(ewalletPresets.firstWhere((p) => p.type == WalletType.cash));
    }
    return list;
  }

  @override
  void dispose() {
    for (final c in _balanceControllers.values) {
      c.dispose();
    }
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
          onPressed: () {
            if (_step == 1) {
              Navigator.of(context).pop();
            } else {
              setState(() => _step = 1);
            }
          },
        ),
        title: Text(
          _step == 1
              ? 'Chọn tài khoản (${_selectedBanks.length + (_selectedEwallet != null ? 1 : 0)}/3)'
              : 'Nhập số dư',
          style: const TextStyle(
            color: Color(0xFF093030),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: _step == 1 ? _buildStep1() : _buildStep2(),
    );
  }

  // =========================================================================
  // STEP 1 — Pick wallets
  // =========================================================================
  Widget _buildStep1() {
    // Groups: banks, ewallets, cash
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 20),
              vertical: Responsive.h(context, 12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Ngân hàng (tối đa 2)'),
                SizedBox(height: Responsive.h(context, 8)),
                _buildPresetGrid(
                  presets: bankPresets,
                  maxSelect: 2,
                  selectedList: _selectedBanks,
                  onToggle: (p) {
                    setState(() {
                      final idx = _selectedBanks.indexOf(p);
                      if (idx >= 0) {
                        _selectedBanks.removeAt(idx);
                      } else if (_selectedBanks.length < 2) {
                        _selectedBanks.add(p);
                      }
                    });
                  },
                ),
                SizedBox(height: Responsive.h(context, 24)),
                _buildSectionHeader('Ví điện tử (tối đa 1)'),
                SizedBox(height: Responsive.h(context, 8)),
                _buildPresetGrid(
                  presets: ewalletPresets
                      .where((p) => p.type == WalletType.ewallet)
                      .toList(),
                  maxSelect: 1,
                  selectedList: _selectedEwallet != null
                      ? [_selectedEwallet!]
                      : [],
                  onToggle: (p) {
                    setState(() {
                      if (_selectedEwallet == p) {
                        _selectedEwallet = null;
                      } else {
                        _selectedEwallet = p;
                      }
                    });
                  },
                ),
                SizedBox(height: Responsive.h(context, 24)),
                _buildSectionHeader('Tiền mặt'),
                SizedBox(height: Responsive.h(context, 8)),
                _buildCashToggle(),
              ],
            ),
          ),
        ),
        _buildStep1BottomBar(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: Color(0xFF093030),
      ),
    );
  }

  Widget _buildPresetGrid({
    required List<WalletPreset> presets,
    required int maxSelect,
    required List<WalletPreset> selectedList,
    required void Function(WalletPreset) onToggle,
  }) {
    return Wrap(
      spacing: Responsive.w(context, 10),
      runSpacing: Responsive.h(context, 10),
      children: presets.map((p) {
        final isSelected = selectedList.contains(p);
        final isDisabled = !isSelected && selectedList.length >= maxSelect;
        return GestureDetector(
          onTap: isDisabled ? null : () => onToggle(p),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isDisabled ? 0.35 : 1.0,
            child: Container(
              width: Responsive.w(context, 76),
              padding: EdgeInsets.symmetric(
                vertical: Responsive.h(context, 8),
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? p.brandColor.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? p.brandColor
                      : const Color(0xFFE0E0E0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    p.logoAssetPath,
                    width: Responsive.w(context, 32),
                    height: Responsive.w(context, 32),
                    errorBuilder: (_, __, ___) => Container(
                      width: Responsive.w(context, 32),
                      height: Responsive.w(context, 32),
                      decoration: BoxDecoration(
                        color: p.brandColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          p.shortName.substring(0, 1),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Responsive.sp(context, 14),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 4)),
                  Text(
                    p.shortName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: Responsive.sp(context, 10),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF052224),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCashToggle() {
    return GestureDetector(
      onTap: () => setState(() => _hasCash = !_hasCash),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 16),
          vertical: Responsive.h(context, 12),
        ),
        decoration: BoxDecoration(
          color: _hasCash
              ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasCash ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0),
            width: _hasCash ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logos/ewallets/cash.png',
              width: 32,
              height: 32,
              errorBuilder: (_, __, ___) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.money, color: Colors.white, size: 18),
              ),
            ),
            SizedBox(width: Responsive.w(context, 12)),
            const Text(
              'Tiền mặt',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF052224),
              ),
            ),
            const Spacer(),
            Icon(
              _hasCash ? Icons.check_circle : Icons.radio_button_unchecked,
              color: _hasCash ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1BottomBar() {
    final canProceed = _selectedBanks.isNotEmpty || _selectedEwallet != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(context, 20)),
        child: SizedBox(
          width: double.infinity,
          height: Responsive.h(context, 48),
          child: ElevatedButton(
            onPressed: canProceed ? _goToStep2 : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Tiếp theo',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: Responsive.sp(context, 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goToStep2() {
    // Create controllers for each selected wallet
    for (final p in _selectedPresets) {
      if (!_balanceControllers.containsKey(p.name)) {
        _balanceControllers[p.name] = TextEditingController();
      }
    }
    setState(() => _step = 2);
  }

  // =========================================================================
  // STEP 2 — Enter balances
  // =========================================================================
  Widget _buildStep2() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 24),
              vertical: Responsive.h(context, 16),
            ),
            child: Column(
              children: _selectedPresets.map((p) {
                final ctrl = _balanceControllers[p.name]!;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: Responsive.h(context, 16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            p.logoAssetPath,
                            width: 28,
                            height: 28,
                            errorBuilder: (_, __, ___) => Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: p.brandColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  p.shortName.substring(0, 1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: Responsive.w(context, 10)),
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: Color(0xFF052224),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(context, 8)),
                      TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: 'VNĐ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(context, 16),
                            vertical: Responsive.h(context, 12),
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        _buildStep2BottomBar(),
      ],
    );
  }

  Widget _buildStep2BottomBar() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(context, 20)),
        child: SizedBox(
          width: double.infinity,
          height: Responsive.h(context, 48),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveWallets,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Hoàn tất',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: Responsive.sp(context, 16),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveWallets() async {
    setState(() => _isSaving = true);
    try {
      final userId = AuthService.instance.currentUser!.id;
      final wallets = _selectedPresets.map((p) {
        final raw = _balanceControllers[p.name]?.text.trim() ?? '';
        final balance = int.tryParse(raw.replaceAll(',', '')) ?? 0;
        return WalletModel(
          id: 'w_${DateTime.now().millisecondsSinceEpoch}_${p.shortName}',
          userId: userId,
          name: p.name,
          shortName: p.shortName,
          logoAssetPath: p.logoAssetPath,
          brandColor: p.brandColor,
          type: p.type,
          initialBalance: balance,
        );
      }).toList();

      await WalletService.instance.insertWallets(wallets);
      if (!mounted) return;
      // Navigate to budget setup
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.budgetSetup,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
}
