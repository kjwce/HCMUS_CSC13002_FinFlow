import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_model.dart';

typedef ChatFunctionInvoker =
    Future<dynamic> Function(Map<String, dynamic> body);

class ChatReply {
  const ChatReply({required this.message, this.insight, this.chart});

  final String message;
  final ChatInsight? insight;
  final ChatChart? chart;
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
    SupabaseClient? client,
    bool? persistenceEnabled,
  }) : _invokeFunction = invokeFunction ?? _invokeSupabaseFunction,
       _client = client,
       _persistenceEnabled =
           persistenceEnabled ?? (invokeFunction == null || client != null);

  static final instance = ChatService();

  final ChatFunctionInvoker _invokeFunction;
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
        .order('created_at');
    return Future.wait(
      (response as List).map((item) async {
        final json = Map<String, dynamic>.from(item as Map);
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

    final response = await _invokeFunction({
      'message': trimmed,
      'locale': locale,
      'timezone': DateTime.now().timeZoneName,
      'currentDate': _localDate(DateTime.now()),
      'history': promptHistory
          .map((item) => item.toPromptJson())
          .toList(growable: false),
      if (image?.storagePath != null) 'imagePath': image!.storagePath,
      if (image?.storagePath != null) 'imageMimeType': image!.mimeType,
    });

    if (response is! Map || response['success'] != true) {
      throw ChatException(
        'INVALID_RESPONSE',
        locale == 'vi-VN'
            ? 'Phản hồi của trợ lý không hợp lệ.'
            : 'The assistant returned an invalid response.',
      );
    }
    final rawData = response['data'];
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
