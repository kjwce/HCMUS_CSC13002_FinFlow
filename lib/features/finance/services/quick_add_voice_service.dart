import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class QuickAddRecorderDriver {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> cancel();
}

abstract class QuickAddVoiceFileStore {
  String createTemporaryPath();
  Future<Uint8List> read(String path);
  Future<void> delete(String path);
}

typedef SpeechToTextInvoker = Future<dynamic> Function(Uint8List audioBytes);

class QuickAddVoiceException implements Exception {
  const QuickAddVoiceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'QuickAddVoiceException($code): $message';
}

/// Records one temporary M4A clip and returns only its validated transcript.
///
/// Audio is sent directly to the authenticated `speech-to-text` Edge Function
/// and deleted locally after success, cancellation, or failure.
class QuickAddVoiceService {
  QuickAddVoiceService._({
    QuickAddRecorderDriver? recorder,
    QuickAddVoiceFileStore? files,
    SpeechToTextInvoker? invoker,
  }) : _recorder = recorder ?? _RecordRecorderDriver(),
       _files = files ?? _DeviceVoiceFileStore(),
       _invoker = invoker ?? _invokeSpeechToText;

  static final QuickAddVoiceService instance = QuickAddVoiceService._();

  factory QuickAddVoiceService.forTesting({
    required QuickAddRecorderDriver recorder,
    required QuickAddVoiceFileStore files,
    required SpeechToTextInvoker invoker,
  }) {
    return QuickAddVoiceService._(
      recorder: recorder,
      files: files,
      invoker: invoker,
    );
  }

  static const _supportedVersion = 1;
  final QuickAddRecorderDriver _recorder;
  final QuickAddVoiceFileStore _files;
  final SpeechToTextInvoker _invoker;

  String? _recordingPath;
  bool _isStarting = false;
  bool _isTranscribing = false;

  bool get isRecording => _recordingPath != null;
  bool get isBusy => _isStarting || _isTranscribing;

  Future<void> startRecording() async {
    if (isRecording || isBusy) {
      throw const QuickAddVoiceException(
        'VOICE_BUSY',
        'A voice operation is already in progress.',
      );
    }

    _isStarting = true;
    String? path;
    try {
      final permitted = await _recorder.hasPermission();
      if (!permitted) {
        throw const QuickAddVoiceException(
          'MICROPHONE_PERMISSION_DENIED',
          'Microphone permission was denied.',
        );
      }
      path = _files.createTemporaryPath();
      await _recorder.start(path);
      _recordingPath = path;
    } on QuickAddVoiceException {
      rethrow;
    } catch (_) {
      if (path != null) await _deleteSafely(path);
      throw const QuickAddVoiceException(
        'RECORDING_START_FAILED',
        'Could not start voice recording.',
      );
    } finally {
      _isStarting = false;
    }
  }

  Future<String> stopAndTranscribe() async {
    final originalPath = _recordingPath;
    if (originalPath == null || _isTranscribing) {
      throw const QuickAddVoiceException(
        'VOICE_NOT_RECORDING',
        'No voice recording is active.',
      );
    }

    _isTranscribing = true;
    _recordingPath = null;
    String? stoppedPath;
    try {
      stoppedPath = await _recorder.stop();
      final path = stoppedPath ?? originalPath;
      final audio = await _files.read(path);
      if (audio.isEmpty) {
        throw const QuickAddVoiceException(
          'EMPTY_AUDIO',
          'No voice was recorded.',
        );
      }

      dynamic response;
      try {
        response = await _invoker(audio);
      } on QuickAddVoiceException {
        rethrow;
      } catch (_) {
        throw const QuickAddVoiceException(
          'SPEECH_TO_TEXT_UNAVAILABLE',
          'Speech recognition is currently unavailable.',
        );
      }
      return _parseTranscript(response);
    } on QuickAddVoiceException {
      rethrow;
    } catch (_) {
      throw const QuickAddVoiceException(
        'RECORDING_READ_FAILED',
        'Could not process the voice recording.',
      );
    } finally {
      await _deleteSafely(originalPath);
      if (stoppedPath != null && stoppedPath != originalPath) {
        await _deleteSafely(stoppedPath);
      }
      _isTranscribing = false;
    }
  }

  Future<void> cancelRecording() async {
    final path = _recordingPath;
    _recordingPath = null;
    try {
      await _recorder.cancel();
    } catch (_) {
      // Cancellation is best effort; file cleanup still runs below.
    } finally {
      if (path != null) await _deleteSafely(path);
    }
  }

  String _parseTranscript(dynamic response) {
    if (response is! Map || response['success'] != true) {
      throw const QuickAddVoiceException(
        'INVALID_SPEECH_RESPONSE',
        'Speech recognition returned an invalid result.',
      );
    }
    if (response['version'] != _supportedVersion) {
      throw const QuickAddVoiceException(
        'UNSUPPORTED_SPEECH_VERSION',
        'The speech response version is not supported.',
      );
    }
    final data = response['data'];
    if (data is! Map || data['transcript'] is! String) {
      throw const QuickAddVoiceException(
        'INVALID_SPEECH_RESPONSE',
        'Speech recognition returned an invalid result.',
      );
    }
    final transcript = (data['transcript'] as String).trim();
    if (transcript.isEmpty) {
      throw const QuickAddVoiceException(
        'EMPTY_TRANSCRIPT',
        'No speech could be recognized.',
      );
    }
    return transcript;
  }

  Future<void> _deleteSafely(String path) async {
    try {
      await _files.delete(path);
    } catch (_) {
      // Temporary cleanup must not replace the useful operation error.
    }
  }

  static Future<dynamic> _invokeSpeechToText(Uint8List audioBytes) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'speech-to-text',
        headers: const {'Content-Type': 'audio/wav'},
        body: audioBytes,
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map && details['error'] is Map
          ? (details['error'] as Map)['code']?.toString()
          : null;
      throw QuickAddVoiceException(
        code ?? 'SPEECH_TO_TEXT_UNAVAILABLE',
        'Speech recognition is currently unavailable.',
      );
    }
  }
}

class _RecordRecorderDriver implements QuickAddRecorderDriver {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) {
    return _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        androidConfig: const AndroidRecordConfig(
          audioSource: AndroidAudioSource.mic,
          audioManagerMode: AudioManagerMode.modeInCommunication,
        ),
      ),
      path: path,
    );
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();
}

class _DeviceVoiceFileStore implements QuickAddVoiceFileStore {
  @override
  String createTemporaryPath() {
    return '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'finflow_quick_add_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  @override
  Future<Uint8List> read(String path) => File(path).readAsBytes();

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
