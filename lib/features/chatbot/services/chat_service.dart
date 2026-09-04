import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../models/chat_model.dart';

typedef ChatFunctionInvoker =
    Future<dynamic> Function(Map<String, dynamic> body);
typedef ChatFunctionStreamer =
    Stream<Map<String, dynamic>> Function(Map<String, dynamic> body);

class ChatReply {
  const ChatReply({required this.message, this.insight, this.chart});

  final String message;
  final ChatInsight? insight;
  final ChatChart? chart;
}

class ChatStreamUpdate {
  const ChatStreamUpdate.delta(this.delta) : reply = null;

  const ChatStreamUpdate.done(this.reply) : delta = '';

  final String delta;
  final ChatReply? reply;
}

class ChatException implements Exception {
  const ChatException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class ChatService {
  ChatService({
    ChatFunctionInvoker? invokeFunction,
    ChatFunctionStreamer? streamFunction,
    SupabaseClient? client,
    bool? persistenceEnabled,
  }) : _invokeFunction = invokeFunction ?? _invokeSupabaseFunction,
       _streamFunction =
           streamFunction ??
           (invokeFunction == null ? _streamSupabaseFunction : null),
       _client = client,
       _persistenceEnabled =
           persistenceEnabled ?? (invokeFunction == null || client != null);

  static final instance = ChatService();

  final ChatFunctionInvoker _invokeFunction;
  final ChatFunctionStreamer? _streamFunction;
  final SupabaseClient? _client;
  final bool _persistenceEnabled;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<List<ChatConversation>> fetchConversations() async {
    if (!_persistenceEnabled) return const [];
    final userId = _requireUserId();
    final response = await _supabase
        .from('chat_conversations')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (response as List)
        .map(
          (item) =>
              ChatConversation.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<ChatConversation?> createConversation(String title) async {
    if (!_persistenceEnabled) return null;
    final userId = _requireUserId();
    final response = await _supabase
        .from('chat_conversations')
        .insert({'user_id': userId, 'title': _conversationTitle(title)})
        .select()
        .single();
    return ChatConversation.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> renameConversation(String id, String title) async {
    if (!_persistenceEnabled) return;
    final userId = _requireUserId();
    await _supabase
        .from('chat_conversations')
        .update({'title': _conversationTitle(title)})
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> deleteConversation(String id) async {
    if (!_persistenceEnabled) return;
    final userId = _requireUserId();
    final imageRows = await _supabase
        .from('chat_messages')
        .select('image_path')
        .eq('conversation_id', id)
        .eq('user_id', userId)
        .not('image_path', 'is', null);
    final paths = (imageRows as List)
        .map((row) => (row as Map)['image_path'])
        .whereType<String>()
        .toList(growable: false);
    if (paths.isNotEmpty) {
      await _supabase.storage.from('chat-images').remove(paths);
    }
    await _supabase
        .from('chat_conversations')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<List<ChatModel>> fetchMessages(String conversationId) async {
    if (!_persistenceEnabled) return const [];
    final userId = _requireUserId();
    final response = await _supabase
        .from('chat_messages')
        .select()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId)
        .order('sequence_number', ascending: true);
    final orderedRows = sortChatMessageRows(response as List);
    return Future.wait(
      orderedRows.map((json) async {
        final path = json['image_path'];
        if (path is String && path.isNotEmpty) {
          json['image_url'] = await _supabase.storage
              .from('chat-images')
              .createSignedUrl(path, 3600);
        }
        return ChatModel.fromJson(json);
      }),
    );
  }

  Future<void> saveMessage(String conversationId, ChatModel message) async {
    if (!_persistenceEnabled) return;
    final userId = _requireUserId();
    await _supabase.from('chat_messages').insert({
      'conversation_id': conversationId,
      'user_id': userId,
      'role': message.role.name,
      'message': message.message,
      'created_at': message.createdAt.toUtc().toIso8601String(),
      if (message.insight != null)
        'insight': {
          'title': message.insight!.title,
          'detail': message.insight!.detail,
        },
      if (message.chart != null) 'chart': message.chart!.toJson(),
      if (message.image?.storagePath != null)
        'image_path': message.image!.storagePath,
      if (message.image?.storagePath != null)
        'image_mime_type': message.image!.mimeType,
    });
  }

  Future<ChatImageAttachment?> uploadImage(PendingChatImage image) async {
    if (!_persistenceEnabled) {
      return ChatImageAttachment(mimeType: image.mimeType, bytes: image.bytes);
    }
    if (image.bytes.length > 6 * 1024 * 1024) {
      throw const ChatException(
        'IMAGE_TOO_LARGE',
        'Ảnh không được vượt quá 6 MB.',
      );
    }
    final userId = _requireUserId();
    final extension = switch (image.mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _supabase.storage
        .from('chat-images')
        .uploadBinary(
          path,
          Uint8List.fromList(image.bytes),
          fileOptions: FileOptions(contentType: image.mimeType),
        );
    final signedUrl = await _supabase.storage
        .from('chat-images')
        .createSignedUrl(path, 3600);
    return ChatImageAttachment(
      storagePath: path,
      signedUrl: signedUrl,
      mimeType: image.mimeType,
      bytes: image.bytes,
    );
  }

  Future<ChatReply> send({
    required String message,
    required List<ChatModel> history,
    required String locale,
    ChatImageAttachment? image,
  }) async {
    final response = await _invokeFunction(
      _buildRequestBody(
        message: message,
        history: history,
        locale: locale,
        image: image,
      ),
    );

    if (response is! Map || response['success'] != true) {
      throw ChatException(
        'INVALID_RESPONSE',
        locale == 'vi-VN'
            ? 'Phản hồi của trợ lý không hợp lệ.'
            : 'The assistant returned an invalid response.',
      );
    }
    return _parseReply(response['data']);
  }

  Stream<ChatStreamUpdate> sendStream({
    required String message,
    required List<ChatModel> history,
    required String locale,
    ChatImageAttachment? image,
  }) async* {
    final streamFunction = _streamFunction;
    if (streamFunction == null) {
      yield ChatStreamUpdate.done(
        await send(
          message: message,
          history: history,
          locale: locale,
          image: image,
        ),
      );
      return;
    }

    final body = _buildRequestBody(
      message: message,
      history: history,
      locale: locale,
      image: image,
    );
    var completed = false;
    await for (final event in streamFunction(body)) {
      switch (event['type']) {
        case 'delta':
          final delta = event['delta'];
          if (delta is String && delta.isNotEmpty) {
            yield ChatStreamUpdate.delta(delta);
          }
        case 'done':
          completed = true;
          yield ChatStreamUpdate.done(_parseReply(event['data']));
        case 'error':
          final rawError = event['error'];
          final error = rawError is Map
              ? Map<String, dynamic>.from(rawError)
              : const <String, dynamic>{};
          throw ChatException(
            error['code'] as String? ?? 'CHATBOT_UNAVAILABLE',
            error['message'] as String? ??
                'Unable to reach the financial assistant.',
          );
      }
    }
    if (!completed) {
      throw const ChatException(
        'STREAM_INTERRUPTED',
        'The assistant response was interrupted.',
      );
    }
  }

  static Map<String, dynamic> _buildRequestBody({
    required String message,
    required List<ChatModel> history,
    required String locale,
    ChatImageAttachment? image,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ChatException(
        'EMPTY_MESSAGE',
        locale == 'vi-VN'
            ? 'Tin nhắn không được để trống.'
            : 'Message cannot be empty.',
      );
    }
    if (trimmed.length > 1000) {
      throw ChatException(
        'MESSAGE_TOO_LONG',
        locale == 'vi-VN'
            ? 'Tin nhắn không được vượt quá 1000 ký tự.'
            : 'Message cannot exceed 1000 characters.',
      );
    }

    final promptHistory = history
        .where((item) => item.message.trim().isNotEmpty)
        .toList(growable: false)
        .reversed
        .take(10)
        .toList(growable: false)
        .reversed
        .toList(growable: true);
    // Gemini conversations should begin with a user turn. The local welcome
    // bubble is presentation-only and must not become a leading model turn.
    while (promptHistory.isNotEmpty && !promptHistory.first.isUser) {
      promptHistory.removeAt(0);
    }

    return {
      'message': trimmed,
      'locale': locale,
      'timezone': DateTime.now().timeZoneName,
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      'currentDate': _localDate(DateTime.now()),
      'history': promptHistory
          .map((item) => item.toPromptJson())
          .toList(growable: false),
      if (image?.storagePath != null) 'imagePath': image!.storagePath,
      if (image?.storagePath != null) 'imageMimeType': image!.mimeType,
    };
  }

  static ChatReply _parseReply(dynamic rawData) {
    if (rawData is! Map) {
      throw const ChatException(
        'INVALID_RESPONSE',
        'Invalid chatbot response.',
      );
    }
    final data = Map<String, dynamic>.from(rawData);
    final reply = data['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const ChatException(
        'INVALID_RESPONSE',
        'Invalid chatbot response.',
      );
    }

    ChatInsight? insight;
    if (data['insight'] is Map) {
      insight = ChatInsight.fromJson(
        Map<String, dynamic>.from(data['insight'] as Map),
      );
    }
    ChatChart? chart;
    if (data['chart'] is Map) {
      chart = ChatChart.fromJson(
        Map<String, dynamic>.from(data['chart'] as Map),
      );
    }
    return ChatReply(message: reply.trim(), insight: insight, chart: chart);
  }

  String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const ChatException(
        'UNAUTHORIZED',
        'Please sign in to use chat history.',
      );
    }
    return userId;
  }

  static String _conversationTitle(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return 'New conversation';
    return compact.length <= 60 ? compact : '${compact.substring(0, 57)}...';
  }

  static String _localDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Stream<Map<String, dynamic>> _streamSupabaseFunction(
    Map<String, dynamic> body,
  ) async* {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw const ChatException(
        'UNAUTHORIZED',
        'Please sign in to use the assistant.',
      );
    }

    final client = http.Client();
    try {
      final request =
          http.Request(
              'POST',
              Uri.parse(
                '${SupabaseConstants.url}/functions/v1/finance-chatbot',
              ),
            )
            ..headers.addAll({
              'Authorization': 'Bearer ${session.accessToken}',
              'apikey': SupabaseConstants.anonKey,
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            })
            ..body = jsonEncode(body);
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final responseBody = await response.stream.bytesToString();
        try {
          final decoded = jsonDecode(responseBody);
          final rawError = decoded is Map ? decoded['error'] : null;
          if (rawError is Map) {
            throw ChatException(
              rawError['code'] as String? ?? 'CHATBOT_UNAVAILABLE',
              rawError['message'] as String? ??
                  'Unable to reach the financial assistant.',
            );
          }
        } on ChatException {
          rethrow;
        } catch (_) {
          // Fall through to the status-based error below.
        }
        throw ChatException(
          'CHATBOT_UNAVAILABLE',
          'The assistant returned HTTP ${response.statusCode}.',
        );
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trimLeft();
        if (data.isEmpty || data == '[DONE]') continue;
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          yield Map<String, dynamic>.from(decoded);
        }
      }
    } on ChatException {
      rethrow;
    } catch (_) {
      throw const ChatException(
        'CHATBOT_UNAVAILABLE',
        'Unable to stream the assistant response.',
      );
    } finally {
      client.close();
    }
  }

  static Future<dynamic> _invokeSupabaseFunction(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'finance-chatbot',
        body: body,
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final rawError = details is Map ? details['error'] : null;
      final code = rawError is Map && rawError['code'] is String
          ? rawError['code'] as String
          : 'CHATBOT_UNAVAILABLE';
      final message = rawError is Map && rawError['message'] is String
          ? rawError['message'] as String
          : 'Unable to reach the financial assistant.';
      throw ChatException(code, message);
    } catch (_) {
      throw const ChatException(
        'CHATBOT_UNAVAILABLE',
        'Unable to reach the financial assistant.',
      );
    }
  }
}

List<Map<String, dynamic>> sortChatMessageRows(List<dynamic> items) {
  final rows = items
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList(growable: false);
  rows.sort((left, right) {
    final leftSequence = left['sequence_number'];
    final rightSequence = right['sequence_number'];
    if (leftSequence is num && rightSequence is num) {
      return leftSequence.compareTo(rightSequence);
    }

    final leftDate = DateTime.tryParse(left['created_at']?.toString() ?? '');
    final rightDate = DateTime.tryParse(right['created_at']?.toString() ?? '');
    if (leftDate != null && rightDate != null) {
      final dateOrder = leftDate.compareTo(rightDate);
      if (dateOrder != 0) return dateOrder;
    }

    if (left['role'] == right['role']) return 0;
    return left['role'] == 'user' ? -1 : 1;
  });
  return rows;
}
