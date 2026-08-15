import 'dart:async';

import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/features/chatbot/models/chat_model.dart';
import 'package:finflow/features/chatbot/presentation/chat_screen.dart';
import 'package:finflow/features/chatbot/providers/chat_provider.dart';
import 'package:finflow/features/chatbot/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Stitch chatbot layout and sends a message', (
    tester,
  ) async {
    final response = Completer<dynamic>();
    final service = ChatService(invokeFunction: (_) => response.future);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatScreen(showBackButton: false),
        ),
      ),
    );

    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
    expect(find.byKey(const Key('chat-user-avatar')), findsOneWidget);
    expect(find.byKey(const Key('chat-quick-prompts')), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.byKey(const Key('chat-image-button')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('chat-input')),
      'Show my weekly spending',
    );
    await tester.tap(find.byKey(const Key('chat-send-button')));
    await tester.pump();

    expect(find.text('Show my weekly spending'), findsOneWidget);
    expect(find.byKey(const Key('chat-typing-indicator')), findsOneWidget);

    response.complete({
      'success': true,
      'data': {
        'reply': 'You spent 2,500,000 VND this week.',
        'insight': {
          'title': '15% higher than last week',
          'detail': 'Food was your largest category.',
        },
        'chart': {
          'type': 'bar',
          'title': 'Weekly spending comparison',
          'labels': ['Last week', 'This week'],
          'values': [2000000, 2500000],
        },
      },
    });
    await tester.pumpAndSettle();

    expect(find.text('You spent 2,500,000 VND this week.'), findsOneWidget);
    expect(find.text('15% higher than last week'), findsOneWidget);
    expect(find.byKey(const Key('chat-chart-card')), findsOneWidget);
    expect(find.byKey(const Key('chat-quick-prompts')), findsNothing);
    expect(find.byKey(const Key('chat-typing-indicator')), findsNothing);
  });

  testWidgets('opens the saved conversation sheet', (tester) async {
    final service = ChatService(
      invokeFunction: (_) async => {
        'success': true,
        'data': {'reply': 'OK', 'insight': null, 'chart': null},
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatScreen(showBackButton: false),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('chat-history-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('new-chat-button')), findsOneWidget);
    expect(find.text('No saved conversations yet.'), findsOneWidget);
  });

  testWidgets('replaces typing dots with streamed assistant text', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>();
    final service = ChatService(
      invokeFunction: (_) async => throw UnimplementedError(),
      streamFunction: (_) => events.stream,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatScreen(showBackButton: false),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('chat-input')), 'Hú');
    await tester.tap(find.byKey(const Key('chat-send-button')));
    await tester.pump();
    expect(find.byKey(const Key('chat-typing-indicator')), findsOneWidget);

    events.add({'type': 'delta', 'delta': 'Có mình '});
    await tester.pump();
    expect(find.text('Có mình '), findsOneWidget);
    expect(find.byKey(const Key('chat-typing-indicator')), findsNothing);

    events.add({'type': 'delta', 'delta': 'đây!'});
    await tester.pump();
    expect(find.text('Có mình đây!'), findsOneWidget);

    events.add({
      'type': 'done',
      'data': {'reply': 'Có mình đây!', 'insight': null, 'chart': null},
    });
    await events.close();
    await tester.pumpAndSettle();

    expect(find.text('Có mình đây!'), findsOneWidget);
    expect(find.byKey(const Key('chat-typing-indicator')), findsNothing);
  });

  testWidgets('renames a conversation without a disposed controller error', (
    tester,
  ) async {
    final service = _HistoryChatService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatScreen(showBackButton: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat-history-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Updated chat');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.renamedTitle, 'Updated chat');
    expect(tester.takeException(), isNull);
  });
}

class _HistoryChatService extends ChatService {
  _HistoryChatService()
    : super(
        invokeFunction: (_) async => throw UnimplementedError(),
        persistenceEnabled: false,
      );

  String? renamedTitle;

  @override
  Future<List<ChatConversation>> fetchConversations() async => [
    ChatConversation(
      id: 'conversation-1',
      title: 'Original chat',
      createdAt: DateTime(2026, 7, 18),
      updatedAt: DateTime(2026, 7, 18),
    ),
  ];

  @override
  Future<List<ChatModel>> fetchMessages(String conversationId) async => [];

  @override
  Future<void> renameConversation(String id, String title) async {
    renamedTitle = title;
  }
}
