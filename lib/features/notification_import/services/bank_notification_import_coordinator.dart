import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../finance/presentation/add_transaction_sheet.dart';
import '../../finance/presentation/quick_add_review_sheet.dart';
import '../../finance/services/transaction_service.dart';
import 'bank_notification_configuration_migration.dart';
import 'bank_notification_import_service.dart';
import 'bank_notification_platform.dart';

class BankNotificationImportCoordinator with WidgetsBindingObserver {
  BankNotificationImportCoordinator._();

  static final instance = BankNotificationImportCoordinator._();

  final _platform = BankNotificationPlatform.instance;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _processing = false;
  DateTime _retryAfter = DateTime.fromMillisecondsSinceEpoch(0);

  void start(GlobalKey<NavigatorState> navigatorKey) {
    if (_navigatorKey != null) return;
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(processPending()),
    );
    unawaited(processPending());
  }

  Future<void> retryNow() {
    _retryAfter = DateTime.fromMillisecondsSinceEpoch(0);
    return processPending();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(processPending());
    }
  }

  Future<void> processPending() async {
    if (_processing ||
        DateTime.now().isBefore(_retryAfter) ||
        !_platform.isSupported ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    await BankNotificationConfigurationMigration.instance.run();
    final configuration = await _platform.configuration();
    if (!configuration.enabled ||
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }
    _processing = true;
    try {
      final pending = await _platform.pending();
      if (pending.isEmpty) return;
      final launchNotificationId = await _platform
          .consumeLaunchNotificationId();
      final notification =
          pending
              .where((item) => item.id == launchNotificationId)
              .firstOrNull ??
          pending.first;
      final result = await BankNotificationImportService.instance.parse(
        notification,
      );
      if (!result.isTransaction || result.draft == null) {
        await _platform.acknowledge(notification.id);
        return;
      }

      final draft = result.draft!;
      final context = _navigatorKey?.currentContext;
      if (context == null || !context.mounted) return;
      final action = await QuickAddReviewSheet.show(
        context,
        draft: draft,
        onConfirm: () async {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId == null) throw StateError('Not authenticated');
          await TransactionService.instance.add(
            draft.toTransactionModel(
              id: 't_${DateTime.now().microsecondsSinceEpoch}',
              userId: userId,
            ),
            isImported: true,
          );
        },
      );
      await _platform.acknowledge(notification.id);
      if (action == QuickAddReviewAction.editDetails && context.mounted) {
        await AddTransactionSheet.show(
          context,
          initialIsExpense: draft.type?.name == 'expense',
          initialAmount: draft.amount,
          initialName: draft.name,
          initialCategoryKey: draft.categoryKey,
          initialWalletId: draft.walletId,
          initialDate: draft.date,
        );
      }
    } on BankNotificationImportException catch (error) {
      debugPrint('Bank notification parser failed: ${error.code}');
      _retryAfter = DateTime.now().add(const Duration(minutes: 1));
    } catch (error) {
      debugPrint('Bank notification import failed: $error');
      _retryAfter = DateTime.now().add(const Duration(minutes: 1));
    } finally {
      _processing = false;
    }
  }
}
