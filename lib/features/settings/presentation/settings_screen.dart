import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_manager.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/home_header_controls.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../finance/models/wallet_model.dart';
import '../../finance/services/transaction_service.dart';
import '../../finance/services/wallet_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_loadMoneySources());
  }

  Future<void> _loadMoneySources() async {
    try {
      await Future.wait([
        WalletService.instance.fetchWallets(),
        TransactionService.instance.fetchTransactions(),
      ]);
    } catch (_) {}
  }

  Future<void> _chooseLanguage() => showFinFlowLanguageDialog(context);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppThemeManager.instance,
        AppLanguage.instance,
        WalletService.instance,
        TransactionService.instance,
      ]),
      builder: (context, _) {
        final colors = context.finFlowColors;
        final wallets = WalletService.instance;
        final transactions = TransactionService.instance;
        final cash = _walletOfType(wallets, WalletType.cash);
        final transfer = _walletOfType(wallets, WalletType.transfer);

        return Scaffold(
          backgroundColor: colors.pageBackground,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            backgroundColor: colors.pageBackground,
            foregroundColor: colors.primaryText,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: Text(AppStrings.choose('App Settings', 'Cài đặt ứng dụng')),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 14),
                child: NotificationBell(),
              ),
            ],
          ),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              Responsive.w(context, 16),
              Responsive.h(context, 8),
              Responsive.w(context, 16),
              Responsive.h(context, 32),
            ),
            children: [
              _SectionLabel(
                AppStrings.choose('FINANCIAL MANAGEMENT', 'QUẢN LÝ TÀI CHÍNH'),
              ),
              SizedBox(height: Responsive.h(context, 8)),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: AppStrings.budgetLimit,
                    subtitle: AppStrings.choose(
                      'Daily, weekly & monthly limits',
                      'Hạn mức ngày, tuần và tháng',
                    ),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.budgetLimits),
                  ),
                  _SettingsRow(
                    key: const Key('money-sources-settings-row'),
                    icon: Icons.payments_outlined,
                    title: AppStrings.choose('Money Sources', 'Nguồn tiền'),
                    subtitle: AppStrings.choose(
                      'Cash and bank transfer balances',
                      'Số dư tiền mặt và chuyển khoản',
                    ),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.moneySources),
                    detail: Padding(
                      padding: EdgeInsets.only(top: Responsive.h(context, 8)),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SourceSummary(
                              label: AppStrings.choose('Cash', 'Tiền mặt'),
                              amount: cash == null
                                  ? 0
                                  : transactions.balanceByWallet(cash.id),
                              color: const Color(0xFF00A77D),
                            ),
                          ),
                          Expanded(
                            child: _SourceSummary(
                              label: AppStrings.choose(
                                'Transfer',
                                'Chuyển khoản',
                              ),
                              amount: transfer == null
                                  ? 0
                                  : transactions.balanceByWallet(transfer.id),
                              color: const Color(0xFF2878D0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: Responsive.h(context, 28)),
              _SectionLabel(AppStrings.choose('PREFERENCES', 'TÙY CHỌN')),
              SizedBox(height: Responsive.h(context, 8)),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    key: const Key('notification-preferences-settings-row'),
                    icon: Icons.notifications_none_rounded,
                    title: AppStrings.choose(
                      'Notification Preferences',
                      'Tùy chọn thông báo',
                    ),
                    subtitle: AppStrings.choose(
                      'Budgets, recurring and community',
                      'Ngân sách, định kỳ và cộng đồng',
                    ),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.notificationPreferences),
                  ),
                  _SettingsRow(
                    icon: Icons.dark_mode_rounded,
                    iconColor: const Color(0xFF8E35C7),
                    iconBackground: const Color(0xFFF3E6F8),
                    title: AppStrings.darkMode,
                    subtitle: AppStrings.choose(
                      'Change app appearance',
                      'Thay đổi giao diện ứng dụng',
                    ),
                    switchValue: AppThemeManager.instance.isDark,
                    onSwitchChanged: (value) => AppThemeManager.instance
                        .setMode(value ? ThemeMode.dark : ThemeMode.light),
                  ),
                  _SettingsRow(
                    icon: Icons.language_rounded,
                    iconColor: const Color(0xFF2878D0),
                    iconBackground: const Color(0xFFE7F1FB),
                    title: AppStrings.language,
                    subtitle: AppLanguage.instance.locale == AppLocale.english
                        ? 'English'
                        : 'Tiếng Việt',
                    onTap: _chooseLanguage,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

WalletModel? _walletOfType(WalletService service, WalletType type) {
  for (final wallet in service.currentUserWallets) {
    if (wallet.type == type) return wallet;
  }
  return null;
}

String _formatVnd(int amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$sign${buffer.toString()} VND';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 5),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Hanken Grotesk',
        fontSize: Responsive.sp(context, 12),
        fontWeight: FontWeight.w700,
        letterSpacing: .45,
        color: context.finFlowColors.secondaryText,
      ),
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D00513E),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              Divider(height: 1, color: colors.divider),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = const Color(0xFF00A77D),
    this.iconBackground = const Color(0xFFE5F7F2),
    this.onTap,
    this.switchValue,
    this.onSwitchChanged,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 13)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: Responsive.w(context, 38),
              height: Responsive.w(context, 38),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? colors.elevatedSurface
                    : iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: Responsive.w(context, 20),
                color: iconColor,
              ),
            ),
            SizedBox(width: Responsive.w(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 15.5),
                      fontWeight: FontWeight.w700,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 12.5),
                      height: 1.3,
                      color: colors.secondaryText,
                    ),
                  ),
                  ?detail,
                ],
              ),
            ),
            SizedBox(width: Responsive.w(context, 8)),
            if (switchValue != null)
              SizedBox(
                height: Responsive.h(context, 36),
                child: Switch.adaptive(
                  value: switchValue!,
                  onChanged: onSwitchChanged,
                  activeTrackColor: const Color(0xFF00A77D),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(top: Responsive.h(context, 8)),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: Responsive.w(context, 22),
                  color: colors.secondaryText.withValues(alpha: .55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceSummary extends StatelessWidget {
  const _SourceSummary({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: Responsive.sp(context, 12),
          color: context.finFlowColors.secondaryText,
        ),
      ),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          _formatVnd(amount),
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: Responsive.sp(context, 13.5),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ],
  );
}
