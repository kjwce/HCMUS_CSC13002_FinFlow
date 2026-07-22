import 'package:flutter/material.dart';

/// The two payment sources supported by FinFlow.
enum WalletType { cash, transfer }

/// A lightweight preset used in the onboarding picker.
class WalletPreset {
  const WalletPreset({
    required this.name,
    required this.logoAssetPath,
    required this.brandColor,
    required this.type,
  });

  final String name;
  final String logoAssetPath;
  final Color brandColor;
  final WalletType type;

  bool get isTransfer => type == WalletType.transfer;
}

/// Persistent wallet model stored in Supabase.
class WalletModel {
  const WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.logoAssetPath,
    required this.brandColor,
    required this.type,
    required this.initialBalance,
    this.isActive = true,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    final name = _stringValue(json['name'], fallback: 'Wallet');
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: name,
      logoAssetPath: _stringValue(json['logo_asset_path']),
      brandColor: _parseColor(json['brand_color']),
      type: _parseType(_stringValue(json['type'], fallback: 'transfer')),
      initialBalance: (json['initial_balance'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'logo_asset_path': logoAssetPath,
    'brand_color':
        '#${(brandColor.r * 255).round().toRadixString(16).padLeft(2, '0')}${(brandColor.g * 255).round().toRadixString(16).padLeft(2, '0')}${(brandColor.b * 255).round().toRadixString(16).padLeft(2, '0')}',
    'type': type.name,
    'initial_balance': initialBalance,
    'is_active': isActive,
  };

  final String id;
  final String userId;
  final String name;
  final String logoAssetPath;
  final Color brandColor;
  final WalletType type;
  final int initialBalance;
  final bool isActive;

  /// Stable id used for the two system wallets belonging to a user.
  static String systemId(String userId, WalletType type) {
    return 'wallet_${type.name}_${userId.replaceAll('-', '')}';
  }

  static WalletType _parseType(String s) {
    // Keep old databases readable before migration 019 is deployed.
    if (s == 'cash') return WalletType.cash;
    return WalletType.transfer;
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static Color _parseColor(dynamic value) {
    final hex = _stringValue(value, fallback: '#4285F4').replaceFirst('#', '');
    final parsed = int.tryParse(hex, radix: 16) ?? 0x4285F4;
    return Color(parsed | 0xFF000000);
  }
}
