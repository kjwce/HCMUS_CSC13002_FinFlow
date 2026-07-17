import 'package:flutter/foundation.dart';

/// Notifies listeners once Supabase + auth state is fully initialised.
/// LaunchScreen waits for this before checking the current session.
final authInitNotifier = ValueNotifier<bool>(false);
