import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/features/chatbot/providers/chat_provider.dart';
import 'package:finflow/features/chatbot/services/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppLanguage.instance.setLocale(AppLocale.english);
  });

  test('changing the app language preserves existing chat messages', () async {
    AppLanguage.instance.setLocale(AppLocale.english);
    final controller = ChatController(
      service: ChatService(
        invokeFunction: (_) async => {
          'success': true,
          'data': {
            'reply': 'This reply must remain unchanged.',
            'insight': null,
            'chart': null,
          },
        },
      ),
    );

    await controller.send('Keep my original message.');
    final messagesBeforeSwitch = controller.messages
        .map((message) => message.message)
        .toList(growable: false);

    AppLanguage.instance.setLocale(AppLocale.vietnamese);

    expect(
      controller.messages.map((message) => message.message),
      messagesBeforeSwitch,
    );
  });
}
