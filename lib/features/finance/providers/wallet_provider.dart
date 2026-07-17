import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/wallet_service.dart';

final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService.instance;
});
