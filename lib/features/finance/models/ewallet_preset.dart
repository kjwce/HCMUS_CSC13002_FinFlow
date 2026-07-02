import 'package:flutter/material.dart';

import 'wallet_model.dart';

/// 9 e-wallets + Cash + Other.
const List<WalletPreset> ewalletPresets = [
  WalletPreset(
    name: 'MoMo',
    shortName: 'MOMO',
    logoAssetPath: 'assets/logos/ewallets/momo.png',
    brandColor: Color(0xFFAF006D),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'ZaloPay',
    shortName: 'ZLP',
    logoAssetPath: 'assets/logos/ewallets/zalopay.png',
    brandColor: Color(0xFF0068FF),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'VNPay',
    shortName: 'VNP',
    logoAssetPath: 'assets/logos/ewallets/vnpay.png',
    brandColor: Color(0xFFE31837),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'ShopeePay',
    shortName: 'SPAY',
    logoAssetPath: 'assets/logos/ewallets/shopeepay.png',
    brandColor: Color(0xFFEE4D2D),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'Viettel Money',
    shortName: 'VTM',
    logoAssetPath: 'assets/logos/ewallets/viettel_money.png',
    brandColor: Color(0xFFEE0033),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'GrabPay',
    shortName: 'GRAB',
    logoAssetPath: 'assets/logos/ewallets/grabpay.png',
    brandColor: Color(0xFF00B14F),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'OnePay',
    shortName: 'ONEP',
    logoAssetPath: 'assets/logos/ewallets/onepay.png',
    brandColor: Color(0xFF003087),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'PayPal',
    shortName: 'PAL',
    logoAssetPath: 'assets/logos/ewallets/paypal.png',
    brandColor: Color(0xFF003087),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'Apple Pay',
    shortName: 'APAY',
    logoAssetPath: 'assets/logos/ewallets/apple_pay.png',
    brandColor: Color(0xFF000000),
    type: WalletType.ewallet,
  ),
  WalletPreset(
    name: 'Tiền mặt',
    shortName: 'CASH',
    logoAssetPath: 'assets/logos/ewallets/cash.png',
    brandColor: Color(0xFF4CAF50),
    type: WalletType.cash,
  ),
  WalletPreset(
    name: 'Khác',
    shortName: 'OTHER',
    logoAssetPath: 'assets/logos/ewallets/other.png',
    brandColor: Color(0xFF9E9E9E),
    type: WalletType.cash,
  ),
];
