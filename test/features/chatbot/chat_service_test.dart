import 'package:finflow/features/chatbot/models/chat_model.dart';
import 'package:finflow/features/chatbot/services/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatService', () {
    test('parses a grounded reply and insight', () async {
      Map<String, dynamic>? capturedBody;
      final service = ChatService(
        invokeFunction: (body) async {
          capturedBody = body;
          return {
            'success': true,
            'data': {
              'reply': 'Bạn đã chi 2.500.000đ tuần này.',
              'insight': {
                'title': 'Tăng 15% so với tuần trước',
                'detail': 'Ăn uống là danh mục cao nhất.',
              },
              'chart': {
                'type': 'bar',
                'title': 'So sánh tuần',
                'labels': ['Tuần trước', 'Tuần này'],
                'values': [2000000, 2500000],
              },
            },
          };
        },
      );

      final result = await service.send(
        message: 'Chi tiêu tuần này?',
        history: const [],
        locale: 'vi-VN',
      );

      expect(result.message, 'Bạn đã chi 2.500.000đ tuần này.');
      expect(result.insight?.title, 'Tăng 15% so với tuần trước');
      expect(result.chart?.type, ChatChartType.bar);
      expect(result.chart?.values, [2000000, 2500000]);
      expect(capturedBody?['message'], 'Chi tiêu tuần này?');
      expect(capturedBody?['currentDate'], matches(r'^\d{4}-\d{2}-\d{2}$'));
    });

    test('sends at most the ten most recent history items', () async {
      late Map<String, dynamic> capturedBody;
      final service = ChatService(
        invokeFunction: (body) async {
          capturedBody = body;
          return {
            'success': true,
            'data': {'reply': 'OK', 'insight': null},
          };
        },
      );
      final history = List.generate(
        12,
        (index) => ChatModel(
          id: '$index',
          message: 'message $index',
          role: index.isEven ? ChatRole.user : ChatRole.assistant,
          createdAt: DateTime(2026),
        ),
      );

      await service.send(
        message: 'question',
        history: history,
        locale: 'en-US',
      );

      final sent = capturedBody['history'] as List;
      expect(sent, hasLength(10));
      expect((sent.first as Map)['message'], 'message 2');
      expect((sent.last as Map)['message'], 'message 11');
    });

    test('rejects empty messages before invoking the function', () async {
      var invoked = false;
      final service = ChatService(
        invokeFunction: (_) async {
          invoked = true;
          return null;
        },
      );

      expect(
        () => service.send(message: '  ', history: const [], locale: 'en-US'),
        throwsA(isA<ChatException>()),
      );
      expect(invoked, isFalse);
    });

    test('includes a stored image reference in the function request', () async {
      late Map<String, dynamic> capturedBody;
      final service = ChatService(
        invokeFunction: (body) async {
          capturedBody = body;
          return {
            'success': true,
            'data': {
              'reply': 'Nice receipt 👀',
              'insight': null,
              'chart': null,
            },
          };
        },
      );

      await service.send(
        message: 'Analyze this',
        history: const [],
        locale: 'en-US',
        image: const ChatImageAttachment(
          storagePath: 'user-id/photo.jpg',
          mimeType: 'image/jpeg',
        ),
      );

      expect(capturedBody['imagePath'], 'user-id/photo.jpg');
      expect(capturedBody['imageMimeType'], 'image/jpeg');
    });
  });
}
