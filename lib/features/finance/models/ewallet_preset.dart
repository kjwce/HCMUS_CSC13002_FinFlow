import 'package:flutter/material.dart';

import 'wallet_model.dart';

/// 9 e-wallets + Cash + Other.
const List<WalletPreset> ewalletPresets = [
  WalletPreset(
    name: 'MoMo',
    logoAssetPath: 'assets/logos/ewallets/momo.png',
    brandColor: Color(0xFFAF006D),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'ZaloPay',
    logoAssetPath: 'assets/logos/ewallets/zalopay.png',
    brandColor: Color(0xFF0068FF),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'VNPay',
    logoAssetPath: 'assets/logos/ewallets/vnpay.png',
    brandColor: Color(0xFFE31837),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'ShopeePay',
    logoAssetPath: 'assets/logos/ewallets/shopeepay.png',
    brandColor: Color(0xFFEE4D2D),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'Viettel Money',
    logoAssetPath: 'assets/logos/ewallets/viettelmoney.png',
    brandColor: Color(0xFFEE0033),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'GrabPay',
    logoAssetPath: 'assets/logos/ewallets/grabpay.png',
    brandColor: Color(0xFF00B14F),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'OnePay',
    logoAssetPath: 'assets/logos/ewallets/onepay.png',
    brandColor: Color(0xFF003087),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'PayPal',
    logoAssetPath: 'assets/logos/ewallets/paypal.png',
    brandColor: Color(0xFF003087),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'Apple Pay',
    logoAssetPath: 'assets/logos/ewallets/apple_pay.png',
    brandColor: Color(0xFF000000),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'Tiền mặt',
    logoAssetPath: 'assets/logos/ewallets/cash.png',
    brandColor: Color(0xFF4CAF50),
    type: WalletType.cash,
  ),
  WalletPreset(
    name: 'Khác',
    logoAssetPath: 'assets/logos/ewallets/other.png',
    brandColor: Color(0xFF9E9E9E),
    type: WalletType.cash,
  ),
];
