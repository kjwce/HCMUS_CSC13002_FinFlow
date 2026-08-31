import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_preferences.dart';

class NotificationPreferencesService extends ChangeNotifier {
  NotificationPreferencesService._();

  static final instance = NotificationPreferencesService._();
  static const _cachePrefix = 'finflow_notification_preferences_v2_';

  final SharedPreferencesAsync _local = SharedPreferencesAsync();
  NotificationPreferences _value = const NotificationPreferences();
  String? _userId;
  bool _loaded = false;
  bool _saving = false;

  NotificationPreferences get value => _value;
  bool get loaded => _loaded;
  bool get saving => _saving;

  Future<void> startForUser(String userId) async {
    if (_userId != userId) {
      _userId = userId;
      _value = const NotificationPreferences();
      _loaded = false;
      notifyListeners();
    }
    await _loadLocal(userId);
    try {
      final response = await Supabase.instance.client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (_userId != userId) return;
      if (response == null) {
        await Supabase.instance.client.from('notification_preferences').upsert({
          'user_id': userId,
          ..._value.toJson(),
        });
      } else {
        _value = NotificationPreferences.fromJson(response);
        await _saveLocal(userId, _value);
      }
    } catch (error) {
      debugPrint('notification preferences sync error: $error');
    } finally {
      if (_userId == userId) {
        _loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> update(NotificationPreferences next) async {
    final userId = _userId;
    _value = next;
    _loaded = true;
    notifyListeners();
    if (userId == null) return;
    await _saveLocal(userId, next);
    _saving = true;
    notifyListeners();
    try {
      await Supabase.instance.client.from('notification_preferences').upsert({
        'user_id': userId,
        ...next.toJson(),
      });
    } catch (error) {
      debugPrint('save notification preferences error: $error');
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void clear() {
    _userId = null;
    _value = const NotificationPreferences();
    _loaded = false;
    _saving = false;
    notifyListeners();
  }

  Future<void> _loadLocal(String userId) async {
    final raw = await _local.getString('$_cachePrefix$userId');
    if (raw == null || raw.isEmpty) return;
    try {
      final values = <String, dynamic>{};
      for (final part in raw.split('|')) {
        final separator = part.indexOf('=');
        if (separator <= 0) continue;
        final key = part.substring(0, separator);
        final value = part.substring(separator + 1);
        values[key] = value == 'true'
            ? true
            : value == 'false'
            ? false
            : int.tryParse(value) ?? value;
      }
      _value = NotificationPreferences.fromJson(values);
      _loaded = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveLocal(String userId, NotificationPreferences preferences) {
    final encoded = preferences
        .toJson()
        .entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('|');
    return _local.setString('$_cachePrefix$userId', encoded);
  }
}
