import 'package:flutter/material.dart';

import 'wallet_model.dart';

/// 27 banks — matched to the actual logo PNGs in assets/logos/banks/.
const List<WalletPreset> bankPresets = [
  WalletPreset(
    name: 'Vietcombank',
    logoAssetPath: 'assets/logos/banks/vietcombank.png',
    brandColor: Color(0xFF007A3D),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'VietinBank',
    logoAssetPath: 'assets/logos/banks/vietinbank.png',
    brandColor: Color(0xFFCD2027),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'BIDV',
    logoAssetPath: 'assets/logos/banks/bidv.png',
    brandColor: Color(0xFF1A4F9F),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'Agribank',
    logoAssetPath: 'assets/logos/banks/agribank.png',
    brandColor: Color(0xFFED1C24),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'Techcombank',
    logoAssetPath: 'assets/logos/banks/techcombank.png',
    brandColor: Color(0xFFE31837),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'MB Bank',
    logoAssetPath: 'assets/logos/banks/mbbank.png',
    brandColor: Color(0xFF8B1A1A),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'VPBank',
    logoAssetPath: 'assets/logos/banks/vpbank.png',
    brandColor: Color(0xFF00613C),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'ACB',
    logoAssetPath: 'assets/logos/banks/acb.png',
    brandColor: Color(0xFF0066B3),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'Sacombank',
    logoAssetPath: 'assets/logos/banks/sacombank.png',
    brandColor: Color(0xFF0033A0),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'TPBank',
    logoAssetPath: 'assets/logos/banks/tpbank.png',
    brandColor: Color(0xFF5C0F8B),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'HDBank',
    logoAssetPath: 'assets/logos/banks/hdbank.png',
    brandColor: Color(0xFF003087),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'SHB',
    logoAssetPath: 'assets/logos/banks/shb.png',
    brandColor: Color(0xFFC8102E),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'OCB',
    logoAssetPath: 'assets/logos/banks/ocb.png',
    brandColor: Color(0xFFFF6600),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'SeABank',
    logoAssetPath: 'assets/logos/banks/seabank.png',
    brandColor: Color(0xFFE4002B),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'VIB',
    logoAssetPath: 'assets/logos/banks/vib.png',
    brandColor: Color(0xFF005BAA),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'MSB',
    logoAssetPath: 'assets/logos/banks/msb.png',
    brandColor: Color(0xFFE30613),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'Nam A Bank',
    logoAssetPath: 'assets/logos/banks/nama_bank.png',
    brandColor: Color(0xFFE30613),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'Eximbank',
    logoAssetPath: 'assets/logos/banks/eximbank.png',
    brandColor: Color(0xFF003087),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'SCB',
    logoAssetPath: 'assets/logos/banks/scb.png',
    brandColor: Color(0xFF003087),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'CB Bank',
    logoAssetPath: 'assets/logos/banks/cbbank.png',
    brandColor: Color(0xFF003D6B),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'Đông Á Bank',
    logoAssetPath: 'assets/logos/banks/dongabank.png',
    brandColor: Color(0xFF004B87),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'GPBank',
    logoAssetPath: 'assets/logos/banks/gpbank.png',
    brandColor: Color(0xFF1A5E2A),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'OceanBank',
    logoAssetPath: 'assets/logos/banks/oceanbank.png',
    brandColor: Color(0xFF006DAE),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'PGBank',
    logoAssetPath: 'assets/logos/banks/pgbank.png',
    brandColor: Color(0xFFE31837),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'PVcomBank',
    logoAssetPath: 'assets/logos/banks/pvcom.png',
    brandColor: Color(0xFF00843D),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'Saigonbank',
    logoAssetPath: 'assets/logos/banks/saigonbank.png',
    brandColor: Color(0xFF003D6B),
    type: WalletType.bank,
  ),
  WalletPreset(
    name: 'SHINHAN Bank',
    logoAssetPath: 'assets/logos/banks/shinhan.png',
    brandColor: Color(0xFF002D6B),
    type: WalletType.bank,
  ),
];
