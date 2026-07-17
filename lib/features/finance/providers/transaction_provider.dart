import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/transaction_service.dart';

/// Expose the TransactionService singleton as a Riverpod provider.
final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService.instance;
});
