import 'package:flutter/material.dart';

/// Supported wallet types.
enum WalletType { bank, ewallet, cash }

/// A lightweight preset used in the onboarding picker.
class WalletPreset {
  const WalletPreset({
    required this.name,
    required this.shortName,
    required this.logoAssetPath,
    required this.brandColor,
    required this.type,
  });

  final String name;
  final String shortName;
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
    required this.shortName,
    required this.logoAssetPath,
    required this.brandColor,
    required this.type,
    required this.initialBalance,
    this.isActive = true,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      shortName: json['short_name'] as String,
      logoAssetPath: json['logo_asset_path'] as String,
      brandColor: Color(int.parse((json['brand_color'] as String).replaceFirst('#', ''), radix: 16)),
      type: _parseType(json['type'] as String),
      initialBalance: json['initial_balance'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'short_name': shortName,
        'logo_asset_path': logoAssetPath,
        'brand_color': '#${(brandColor.r * 255).round().toRadixString(16).padLeft(2, '0')}${(brandColor.g * 255).round().toRadixString(16).padLeft(2, '0')}${(brandColor.b * 255).round().toRadixString(16).padLeft(2, '0')}',
        'type': type.name,
        'initial_balance': initialBalance,
        'is_active': isActive,
      };

  final String id;
  final String userId;
  final String name;
  final String shortName;
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
}
