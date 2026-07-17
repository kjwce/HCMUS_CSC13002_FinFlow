import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService.instance,
);

final chatControllerProvider = ChangeNotifierProvider<ChatController>((ref) {
  return ChatController(service: ref.read(chatServiceProvider));
});

class ChatController extends ChangeNotifier {
  ChatController({required this._service}) {
    _messages.add(_welcomeMessage());
    unawaited(_initialize());
  }

  final ChatService _service;
  final List<ChatModel> _messages = [];
  List<ChatConversation> _conversations = [];
  String? _activeConversationId;
  bool _isSending = false;
  bool _isReceivingText = false;
  bool _isLoadingHistory = false;
  String? _errorMessage;
  int _idCounter = 0;

  List<ChatModel> get messages => List.unmodifiable(_messages);
  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  String? get activeConversationId => _activeConversationId;
  bool get isSending => _isSending;
  bool get isReceivingText => _isReceivingText;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get errorMessage => _errorMessage;

  Future<void> _initialize() async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      _conversations = await _service.fetchConversations();
      if (_conversations.isNotEmpty) {
        await _loadConversation(_conversations.first.id);
      }
    } catch (_) {
      // Chat remains usable when history is temporarily unavailable.
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> newConversation() async {
    if (_isSending) return;
    _activeConversationId = null;
    _errorMessage = null;
    _messages
      ..clear()
      ..add(_welcomeMessage());
    notifyListeners();
  }

  Future<void> openConversation(String id) async {
    if (_isSending || id == _activeConversationId) return;
    _isLoadingHistory = true;
    notifyListeners();
    try {
      await _loadConversation(id);
      _errorMessage = null;
    } on ChatException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = _historyError;
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> _loadConversation(String id) async {
    final storedMessages = await _service.fetchMessages(id);
    _activeConversationId = id;
    _messages
      ..clear()
      ..add(_welcomeMessage())
      ..addAll(storedMessages);
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _service.deleteConversation(id);
      _conversations = _conversations
          .where((conversation) => conversation.id != id)
          .toList(growable: false);
      if (_activeConversationId == id) await newConversation();
      notifyListeners();
    } catch (_) {
      _errorMessage = _historyError;
      notifyListeners();
    }
  }

  Future<void> renameConversation(String id, String title) async {
    if (title.trim().isEmpty) return;
    try {
      await _service.renameConversation(id, title);
      await _refreshConversations();
    } catch (_) {
      _errorMessage = _historyError;
      notifyListeners();
    }
  }

  Future<bool> send(String text, {PendingChatImage? pendingImage}) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && pendingImage == null) || _isSending) return false;

    final displayText = trimmed.isNotEmpty
        ? trimmed
        : (_localeCode == 'vi-VN'
              ? 'Xem giúp mình ảnh này nha'
              : 'Please take a look at this image');

    _errorMessage = null;
    var userMessage = ChatModel(
      id: _nextId(),
      message: displayText,
      role: ChatRole.user,
      createdAt: DateTime.now(),
      image: pendingImage == null
          ? null
          : ChatImageAttachment(
              mimeType: pendingImage.mimeType,
              bytes: pendingImage.bytes,
            ),
    );
    _messages.add(userMessage);
    _isSending = true;
    _isReceivingText = false;
    notifyListeners();

    int? assistantIndex;
    try {
      await _ensureConversation(displayText);
      if (pendingImage != null) {
        final uploaded = await _service.uploadImage(pendingImage);
        if (uploaded == null) {
          throw const ChatException(
            'IMAGE_UPLOAD_FAILED',
            'Unable to upload image.',
          );
        }
        userMessage = userMessage.copyWithImage(uploaded);
        _messages[_messages.indexWhere((item) => item.id == userMessage.id)] =
            userMessage;
        notifyListeners();
      }
      await _saveMessageSafely(userMessage);
      final promptHistory = _messages.sublist(0, _messages.length - 1);
      var streamedText = '';
      ChatReply? finalReply;
      await for (final update in _service.sendStream(
        message: displayText,
        history: promptHistory,
        locale: _localeCode,
        image: userMessage.image,
      )) {
        if (update.delta.isNotEmpty) {
          streamedText += update.delta;
          assistantIndex ??= _messages.length;
          final draft = ChatModel(
            id: assistantIndex == _messages.length
                ? _nextId()
                : _messages[assistantIndex].id,
            message: streamedText,
            role: ChatRole.assistant,
            createdAt: assistantIndex == _messages.length
                ? DateTime.now()
                : _messages[assistantIndex].createdAt,
          );
          if (assistantIndex == _messages.length) {
            _messages.add(draft);
          } else {
            _messages[assistantIndex] = draft;
          }
          _isReceivingText = true;
          notifyListeners();
        }
        if (update.reply != null) finalReply = update.reply;
      }
      final reply = finalReply;
      if (reply == null) {
        throw const ChatException(
          'STREAM_INTERRUPTED',
          'The assistant response was interrupted.',
        );
      }
      final completedMessage = ChatModel(
        id: assistantIndex == null ? _nextId() : _messages[assistantIndex].id,
        message: reply.message,
        role: ChatRole.assistant,
        createdAt: assistantIndex == null
            ? DateTime.now()
            : _messages[assistantIndex].createdAt,
        insight: reply.insight,
        chart: reply.chart,
      );
      if (assistantIndex == null) {
        _messages.add(completedMessage);
      } else {
        _messages[assistantIndex] = completedMessage;
      }
      await _saveMessageSafely(completedMessage);
      await _refreshConversations();
      return true;
    } on ChatException catch (error) {
      if (assistantIndex != null && assistantIndex < _messages.length) {
        _messages.removeAt(assistantIndex);
      }
      _errorMessage = error.message;
      return false;
    } catch (_) {
      if (assistantIndex != null && assistantIndex < _messages.length) {
        _messages.removeAt(assistantIndex);
      }
      _errorMessage = _localeCode == 'vi-VN'
          ? 'Không thể kết nối với trợ lý. Vui lòng thử lại.'
          : 'Unable to connect to the assistant. Please try again.';
      return false;
    } finally {
      _isSending = false;
      _isReceivingText = false;
      notifyListeners();
    }
  }

  Future<void> _ensureConversation(String firstMessage) async {
    if (_activeConversationId != null) return;
    try {
      final conversation = await _service.createConversation(firstMessage);
      if (conversation == null) return;
      _activeConversationId = conversation.id;
      _conversations = [
        conversation,
        ..._conversations.where((item) => item.id != conversation.id),
      ];
    } catch (_) {
      // The assistant can still answer without persisted history.
    }
  }

  Future<void> _saveMessageSafely(ChatModel message) async {
    final conversationId = _activeConversationId;
    if (conversationId == null) return;
    try {
      await _service.saveMessage(conversationId, message);
    } catch (_) {
      // A history write must not prevent the assistant from answering.
    }
  }

  Future<void> _refreshConversations() async {
    try {
      _conversations = await _service.fetchConversations();
      notifyListeners();
    } catch (_) {
      // Keep the last local list when refresh fails.
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  String get _localeCode =>
      AppLanguage.instance.locale == AppLocale.vietnamese ? 'vi-VN' : 'en-US';

  String get _historyError => _localeCode == 'vi-VN'
      ? 'Không thể tải lịch sử trò chuyện.'
      : 'Unable to load chat history.';

  ChatModel _welcomeMessage() => ChatModel(
    id: _nextId(),
    message: _localeCode == 'vi-VN'
        ? 'Chào bạn! Tôi có thể giúp gì cho tình hình tài chính của bạn hôm nay?'
        : 'Hi! How can I help with your finances today?',
    role: ChatRole.assistant,
    createdAt: DateTime.now(),
  );
}
