import 'package:flutter/material.dart';

/// Supported wallet types.
enum WalletType { bank, ewallet, cash }

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

  /// Whether this preset acts as a "bank-like" wallet for limit purposes.
  bool get isBankLike => type == WalletType.bank;
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
      type: _parseType(_stringValue(json['type'], fallback: 'bank')),
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

  static WalletType _parseType(String s) {
    return WalletType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => WalletType.bank,
    );
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
