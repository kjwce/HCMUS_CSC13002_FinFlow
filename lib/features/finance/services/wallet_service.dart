import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet_model.dart';

/// Service handling wallet CRUD via Supabase.
class WalletService extends ChangeNotifier {
  WalletService._();

  static final WalletService instance = WalletService._();

  List<WalletModel> _wallets = [];

  List<WalletModel> get wallets => List.unmodifiable(_wallets);

  /// Return only the wallets that belong to the currently signed-in user.
  List<WalletModel> get currentUserWallets {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const [];
    return _wallets.where((w) => w.userId == userId).toList(growable: false);
  }

  /// Sum of `initialBalance` across all of the current user's wallets.
  int get totalInitialBalance {
    return currentUserWallets.fold(0, (sum, w) => sum + w.initialBalance);
  }

  /// Look up a wallet by id (null-safe).
  WalletModel? byId(String? id) {
    if (id == null) return null;
    return _wallets.where((w) => w.id == id).firstOrNull;
  }

  Future<void> fetchWallets() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _wallets = [];
      notifyListeners();
      return;
    }
    final res = await Supabase.instance.client
        .from('wallets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    _wallets = (res as List)
        .map((w) => WalletModel.fromJson(w as Map<String, dynamic>))
        .toList(growable: false);
    notifyListeners();
  }

  /// Insert a list of wallets (used during onboarding).
  Future<void> insertWallets(List<WalletModel> wallets) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final payload = wallets.map((w) => w.toJson()).toList();
    await Supabase.instance.client
        .from('wallets')
        .upsert(payload, onConflict: 'id');
    await fetchWallets();
  }

  /// Creates or updates the user's two canonical payment sources.
  Future<void> saveSystemWallets({
    required int cashInitialBalance,
    required int transferInitialBalance,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await insertWallets([
      WalletModel(
        id: WalletModel.systemId(userId, WalletType.cash),
        userId: userId,
        name: 'Tiền mặt',
        logoAssetPath: 'assets/logos/ewallets/cash.png',
        brandColor: const Color(0xFF4CAF50),
        type: WalletType.cash,
        initialBalance: cashInitialBalance,
      ),
      WalletModel(
        id: WalletModel.systemId(userId, WalletType.transfer),
        userId: userId,
        name: 'Chuyển khoản',
        logoAssetPath: 'assets/logos/ewallets/other.png',
        brandColor: const Color(0xFF2878D0),
        type: WalletType.transfer,
        initialBalance: transferInitialBalance,
      ),
    ]);
  }
}
