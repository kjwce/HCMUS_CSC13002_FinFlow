import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/recurring_service.dart';

final recurringServiceProvider = Provider<RecurringService>((ref) {
  return RecurringService.instance;
});

final recurringServiceRevisionProvider =
    ChangeNotifierProvider<_RecurringServiceRevision>((ref) {
      return _RecurringServiceRevision(RecurringService.instance);
    });

class _RecurringServiceRevision extends ChangeNotifier {
  _RecurringServiceRevision(this._service) {
    _service.addListener(_forwardChange);
  }

  final RecurringService _service;

  void _forwardChange() => notifyListeners();

  @override
  void dispose() {
    _service.removeListener(_forwardChange);
    super.dispose();
  }
}
