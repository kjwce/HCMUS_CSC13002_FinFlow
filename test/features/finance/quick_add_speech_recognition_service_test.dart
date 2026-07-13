import 'package:finflow/features/finance/services/quick_add_speech_recognition_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeSpeechDriver driver;

  QuickAddSpeechRecognitionService service() =>
      QuickAddSpeechRecognitionService.forTesting(driver: driver);

  setUp(() => driver = _FakeSpeechDriver());

  test('initialization succeeds and is performed only once', () async {
    final speech = service();
    expect(await speech.initialize(), isTrue);
    expect(await speech.initialize(), isTrue);
    expect(driver.initializeCount, 1);
    expect(speech.isAvailable, isTrue);
  });

  test('initialization failure reports recognizer unavailable', () async {
    driver.available = false;
    final speech = service();
    expect(await speech.initialize(), isFalse);
    await expectLater(
      speech.startListening(onResult: (_) {}),
      throwsA(
        isA<QuickAddSpeechException>().having(
          (error) => error.code,
          'code',
          'RECOGNIZER_UNAVAILABLE',
        ),
      ),
    );
  });

  test('vi_VN is preferred over other Vietnamese locales', () async {
    driver.availableLocales = const [
      QuickAddSpeechLocale('vi', 'Vietnamese'),
      QuickAddSpeechLocale('vi_VN', 'Vietnamese (Vietnam)'),
      QuickAddSpeechLocale('en_US', 'English'),
    ];
    final speech = service();
    await speech.initialize();
    expect(speech.selectedLocaleId, 'vi_VN');
    expect(speech.usesVietnameseLocale, isTrue);
  });

  test('another vi language locale is selected before system locale', () async {
    driver.availableLocales = const [
      QuickAddSpeechLocale('en_US', 'English'),
      QuickAddSpeechLocale('vi', 'Vietnamese'),
    ];
    final speech = service();
    await speech.initialize();
    expect(speech.selectedLocaleId, 'vi');
  });

  test('system locale is the safe fallback', () async {
    driver.availableLocales = const [
      QuickAddSpeechLocale('en_GB', 'English'),
    ];
    driver.deviceLocale = const QuickAddSpeechLocale(
      'en_US',
      'English (United States)',
    );
    final speech = service();
    await speech.initialize();
    expect(speech.selectedLocaleId, 'en_US');
    expect(speech.usesVietnameseLocale, isFalse);
  });

  test('permission denied prevents listening', () async {
    driver.permissionGranted = false;
    final speech = service();
    await speech.initialize();
    await expectLater(
      speech.startListening(onResult: (_) {}),
      throwsA(
        isA<QuickAddSpeechException>().having(
          (error) => error.code,
          'code',
          'MICROPHONE_PERMISSION_DENIED',
        ),
      ),
    );
    expect(driver.listenCount, 0);
  });

  test('listening forwards partial and final transcripts', () async {
    final received = <QuickAddSpeechResult>[];
    final speech = service();
    await speech.initialize();
    await speech.startListening(onResult: received.add);

    driver.emit('Ăn trưa', isFinal: false);
    driver.emit('Ăn trưa 50k', isFinal: true);

    expect(driver.listenCount, 1);
    expect(driver.listenLocale, 'vi_VN');
    expect(received, hasLength(2));
    expect(received.first.text, 'Ăn trưa');
    expect(received.first.isFinal, isFalse);
    expect(received.last.text, 'Ăn trưa 50k');
    expect(received.last.isFinal, isTrue);
  });

  test('duplicate listening start is rejected', () async {
    final speech = service();
    await speech.initialize();
    await speech.startListening(onResult: (_) {});
    await expectLater(
      speech.startListening(onResult: (_) {}),
      throwsA(
        isA<QuickAddSpeechException>().having(
          (error) => error.code,
          'code',
          'VOICE_BUSY',
        ),
      ),
    );
  });

  test('manual stop and cancel reach the platform boundary', () async {
    final speech = service();
    await speech.initialize();
    await speech.startListening(onResult: (_) {});
    await speech.stopListening();
    await speech.cancelListening();
    expect(driver.stopCount, 1);
    expect(driver.cancelCount, 1);
  });

  test('safe platform error is forwarded without a stack trace', () async {
    QuickAddSpeechException? received;
    final speech = service();
    await speech.initialize(onError: (error) => received = error);
    driver.raiseError(
      const QuickAddSpeechException(
        'error_permission',
        'Speech recognition failed.',
        isPermanent: true,
      ),
    );
    expect(received?.code, 'error_permission');
    expect(received?.isPermanent, isTrue);
  });
}

class _FakeSpeechDriver implements QuickAddSpeechDriver {
  bool available = true;
  bool permissionGranted = true;
  bool listening = false;
  int initializeCount = 0;
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? listenLocale;
  List<QuickAddSpeechLocale> availableLocales = const [
    QuickAddSpeechLocale('vi_VN', 'Vietnamese (Vietnam)'),
  ];
  QuickAddSpeechLocale? deviceLocale = const QuickAddSpeechLocale(
    'en_US',
    'English (United States)',
  );
  ValueChanged<QuickAddSpeechResult>? resultListener;
  ValueChanged<QuickAddSpeechException>? errorListener;

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<QuickAddSpeechException> onError,
  }) async {
    initializeCount++;
    errorListener = onError;
    return available;
  }

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<List<QuickAddSpeechLocale>> locales() async => availableLocales;

  @override
  Future<QuickAddSpeechLocale?> systemLocale() async => deviceLocale;

  @override
  Future<void> listen({
    required ValueChanged<QuickAddSpeechResult> onResult,
    String? localeId,
  }) async {
    listenCount++;
    listening = true;
    listenLocale = localeId;
    resultListener = onResult;
  }

  void emit(String text, {required bool isFinal}) {
    resultListener?.call(QuickAddSpeechResult(text: text, isFinal: isFinal));
  }

  void raiseError(QuickAddSpeechException error) => errorListener?.call(error);

  @override
  Future<void> stop() async {
    stopCount++;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    listening = false;
  }
}
