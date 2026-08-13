import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class QuickAddSpeechLocale {
  const QuickAddSpeechLocale(this.id, this.name);

  final String id;
  final String name;
}

class QuickAddSpeechResult {
  const QuickAddSpeechResult({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;
}

class QuickAddSpeechException implements Exception {
  const QuickAddSpeechException(
    this.code,
    this.message, {
    this.isPermanent = false,
  });

  final String code;
  final String message;
  final bool isPermanent;

  @override
  String toString() => 'QuickAddSpeechException($code): $message';
}

abstract class QuickAddSpeechDriver {
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<QuickAddSpeechException> onError,
  });

  Future<bool> hasPermission();
  Future<List<QuickAddSpeechLocale>> locales();
  Future<QuickAddSpeechLocale?> systemLocale();
  Future<void> listen({
    required ValueChanged<QuickAddSpeechResult> onResult,
    ValueChanged<double>? onSoundLevel,
    String? localeId,
  });
  Future<void> stop();
  Future<void> cancel();
  bool get isListening;
}

/// Device speech recognition for Quick Add.
///
/// This service only owns the platform recognizer lifecycle. It never parses,
/// saves, navigates, or creates a QuickAddDraft.
class QuickAddSpeechRecognitionService {
  QuickAddSpeechRecognitionService._({QuickAddSpeechDriver? driver})
    : _driver = driver ?? _SpeechToTextDriver();

  static final QuickAddSpeechRecognitionService instance =
      QuickAddSpeechRecognitionService._();

  factory QuickAddSpeechRecognitionService.forTesting({
    required QuickAddSpeechDriver driver,
  }) => QuickAddSpeechRecognitionService._(driver: driver);

  final QuickAddSpeechDriver _driver;
  Future<bool>? _initialization;
  bool _available = false;
  String? _selectedLocaleId;
  bool _usesVietnameseLocale = false;
  ValueChanged<String>? _statusListener;
  ValueChanged<QuickAddSpeechException>? _errorListener;

  bool get isListening => _driver.isListening;
  bool get isAvailable => _available;
  String? get selectedLocaleId => _selectedLocaleId;
  bool get usesVietnameseLocale => _usesVietnameseLocale;

  Future<bool> initialize({
    ValueChanged<String>? onStatus,
    ValueChanged<QuickAddSpeechException>? onError,
  }) {
    _statusListener = onStatus;
    _errorListener = onError;
    return _initialization ??= _initializeOnce();
  }

  Future<bool> _initializeOnce() async {
    try {
      _available = await _driver.initialize(
        onStatus: (status) => _statusListener?.call(status),
        onError: (error) => _errorListener?.call(error),
      );
      if (!_available) return false;
      await _selectLocale();
      return true;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  Future<void> _selectLocale() async {
    final locales = await _driver.locales();
    QuickAddSpeechLocale? selected;

    for (final expected in const ['vi_VN', 'vi-VN']) {
      for (final locale in locales) {
        if (locale.id == expected) {
          selected = locale;
          break;
        }
      }
      if (selected != null) break;
    }

    selected ??= _firstVietnameseLocale(locales);
    _usesVietnameseLocale = selected != null;
    selected ??= await _driver.systemLocale();
    _selectedLocaleId = selected?.id;

    if (kDebugMode) {
      debugPrint('Quick Add speech locale: ${_selectedLocaleId ?? 'system'}');
    }
  }

  QuickAddSpeechLocale? _firstVietnameseLocale(
    List<QuickAddSpeechLocale> locales,
  ) {
    for (final locale in locales) {
      final normalized = locale.id.toLowerCase().replaceAll('_', '-');
      if (normalized == 'vi' || normalized.startsWith('vi-')) return locale;
    }
    return null;
  }

  Future<void> startListening({
    required ValueChanged<QuickAddSpeechResult> onResult,
    ValueChanged<double>? onSoundLevel,
  }) async {
    if (!_available) {
      throw const QuickAddSpeechException(
        'RECOGNIZER_UNAVAILABLE',
        'Speech recognition is unavailable.',
      );
    }
    if (_driver.isListening) {
      throw const QuickAddSpeechException(
        'VOICE_BUSY',
        'A speech recognition session is already active.',
      );
    }
    final permitted = await _driver.hasPermission();
    if (!permitted) {
      throw const QuickAddSpeechException(
        'MICROPHONE_PERMISSION_DENIED',
        'Microphone permission was denied.',
      );
    }
    await _driver.listen(
      onResult: onResult,
      onSoundLevel: onSoundLevel,
      localeId: _selectedLocaleId,
    );
  }

  Future<void> stopListening() => _driver.stop();

  Future<void> cancelListening() => _driver.cancel();
}

class _SpeechToTextDriver implements QuickAddSpeechDriver {
  final SpeechToText _speech = SpeechToText();

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<QuickAddSpeechException> onError,
  }) {
    return _speech.initialize(
      onStatus: onStatus,
      onError: (SpeechRecognitionError error) {
        onError(
          QuickAddSpeechException(
            error.errorMsg,
            'Speech recognition failed.',
            isPermanent: error.permanent,
          ),
        );
      },
    );
  }

  @override
  Future<bool> hasPermission() => _speech.hasPermission;

  @override
  Future<List<QuickAddSpeechLocale>> locales() async {
    final values = await _speech.locales();
    return values
        .map((locale) => QuickAddSpeechLocale(locale.localeId, locale.name))
        .toList(growable: false);
  }

  @override
  Future<QuickAddSpeechLocale?> systemLocale() async {
    final locale = await _speech.systemLocale();
    if (locale == null) return null;
    return QuickAddSpeechLocale(locale.localeId, locale.name);
  }

  @override
  Future<void> listen({
    required ValueChanged<QuickAddSpeechResult> onResult,
    ValueChanged<double>? onSoundLevel,
    String? localeId,
  }) {
    return _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(
          QuickAddSpeechResult(
            text: result.recognizedWords,
            isFinal: result.finalResult,
          ),
        );
      },
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
