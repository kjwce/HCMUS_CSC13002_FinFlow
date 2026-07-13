import 'dart:typed_data';

import 'package:finflow/features/finance/services/quick_add_voice_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeRecorder recorder;
  late _FakeFiles files;

  QuickAddVoiceService service({
    dynamic response = const {
      'success': true,
      'version': 1,
      'data': {'transcript': 'Ăn phở 60k bằng MoMo.'},
    },
    Object? invokeError,
  }) {
    return QuickAddVoiceService.forTesting(
      recorder: recorder,
      files: files,
      invoker: (_) async {
        if (invokeError != null) throw invokeError;
        return response;
      },
    );
  }

  setUp(() {
    recorder = _FakeRecorder();
    files = _FakeFiles();
  });

  test('permission granted starts one recording', () async {
    final voice = service();
    await voice.startRecording();
    expect(recorder.permissionChecks, 1);
    expect(recorder.startCount, 1);
    expect(voice.isRecording, isTrue);
  });

  test('permission denied does not start recording', () async {
    recorder.permissionGranted = false;
    final voice = service();
    await expectLater(
      voice.startRecording(),
      throwsA(
        isA<QuickAddVoiceException>().having(
          (error) => error.code,
          'code',
          'MICROPHONE_PERMISSION_DENIED',
        ),
      ),
    );
    expect(recorder.startCount, 0);
  });

  test('duplicate recording start is prevented', () async {
    final voice = service();
    await voice.startRecording();
    await expectLater(
      voice.startRecording(),
      throwsA(
        isA<QuickAddVoiceException>().having(
          (error) => error.code,
          'code',
          'VOICE_BUSY',
        ),
      ),
    );
    expect(recorder.startCount, 1);
  });

  test('recording stops and Deepgram transcript is returned', () async {
    final voice = service();
    await voice.startRecording();
    final transcript = await voice.stopAndTranscribe();
    expect(recorder.stopCount, 1);
    expect(transcript, 'Ăn phở 60k bằng MoMo.');
    expect(voice.isRecording, isFalse);
  });

  test('empty recording is rejected and temporary file is deleted', () async {
    files.bytes = Uint8List(0);
    final voice = service();
    await voice.startRecording();
    await expectLater(
      voice.stopAndTranscribe(),
      throwsA(
        isA<QuickAddVoiceException>().having(
          (error) => error.code,
          'code',
          'EMPTY_AUDIO',
        ),
      ),
    );
    expect(files.deletedPaths, contains(files.path));
  });

  test('upload failure is sanitized and temporary file is deleted', () async {
    final voice = service(invokeError: Exception('raw provider response'));
    await voice.startRecording();
    await expectLater(
      voice.stopAndTranscribe(),
      throwsA(
        isA<QuickAddVoiceException>()
            .having((error) => error.code, 'code', 'SPEECH_TO_TEXT_UNAVAILABLE')
            .having(
              (error) => error.message,
              'message',
              isNot(contains('raw provider response')),
            ),
      ),
    );
    expect(files.deletedPaths, contains(files.path));
  });

  test('empty transcript is rejected', () async {
    final voice = service(
      response: const {
        'success': true,
        'version': 1,
        'data': {'transcript': '   '},
      },
    );
    await voice.startRecording();
    await expectLater(
      voice.stopAndTranscribe(),
      throwsA(
        isA<QuickAddVoiceException>().having(
          (error) => error.code,
          'code',
          'EMPTY_TRANSCRIPT',
        ),
      ),
    );
  });

  test('unsupported response version is rejected', () async {
    final voice = service(
      response: const {
        'success': true,
        'version': 2,
        'data': {'transcript': 'Lunch'},
      },
    );
    await voice.startRecording();
    await expectLater(
      voice.stopAndTranscribe(),
      throwsA(
        isA<QuickAddVoiceException>().having(
          (error) => error.code,
          'code',
          'UNSUPPORTED_SPEECH_VERSION',
        ),
      ),
    );
  });

  test('recording cancellation removes temporary audio', () async {
    final voice = service();
    await voice.startRecording();
    await voice.cancelRecording();
    expect(recorder.cancelCount, 1);
    expect(files.deletedPaths, contains(files.path));
    expect(voice.isRecording, isFalse);
  });

  test('stop without recording is rejected', () async {
    final voice = service();
    await expectLater(
      voice.stopAndTranscribe(),
      throwsA(
        isA<QuickAddVoiceException>().having(
          (error) => error.code,
          'code',
          'VOICE_NOT_RECORDING',
        ),
      ),
    );
  });
}

class _FakeRecorder implements QuickAddRecorderDriver {
  bool permissionGranted = true;
  int permissionChecks = 0;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? path;

  @override
  Future<bool> hasPermission() async {
    permissionChecks++;
    return permissionGranted;
  }

  @override
  Future<void> start(String path) async {
    startCount++;
    this.path = path;
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    return path;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}

class _FakeFiles implements QuickAddVoiceFileStore {
  final String path = 'temporary-voice.m4a';
  Uint8List bytes = Uint8List.fromList([1, 2, 3]);
  final List<String> deletedPaths = [];

  @override
  String createTemporaryPath() => path;

  @override
  Future<void> delete(String path) async {
    deletedPaths.add(path);
  }

  @override
  Future<Uint8List> read(String path) async => bytes;
}
