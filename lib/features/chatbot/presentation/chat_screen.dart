import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// CHAT SCREEN — matches Figma node 1:1353
// =============================================================================

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();

  // Sample messages matching the Figma layout
  static const _sampleMessages = <_ChatMessage>[
    _ChatMessage(
      text: 'How can I save more money this month?',
      isUser: true,
    ),
    _ChatMessage(
      text: 'Great question! Let me analyze your spending patterns...',
      isUser: false,
    ),
    _ChatMessage(
      text: 'You could save by reducing dining out and subscriptions.',
      isUser: false,
    ),
    _ChatMessage(
      text: 'Try setting a weekly budget for meals and track it daily.',
      isUser: false,
    ),
    _ChatMessage(
      text:
          'Would you like me to create a personalized budget plan for you? '
          "Here's what I recommend based on your spending patterns over the "
          'last 3 months. You have been spending about 30% on dining, 20% '
          'on subscriptions, and 15% on transport. I suggest reallocating '
          '10% from dining to savings.',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(Responsive.w(context, 16)),
              itemCount: _sampleMessages.length,
              itemBuilder: (_, index) {
                final msg = _sampleMessages[index];
                return msg.isUser ? _userBubble(msg.text) : _botBubble(msg.text);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'AI Chatbot',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: Responsive.sp(context, 20),
          color: const Color(0xFF093030),
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/icon_notification.svg',
            width: Responsive.w(context, 24),
            height: Responsive.h(context, 24),
            colorFilter: const ColorFilter.mode(Color(0xFF093030), BlendMode.srcIn),
          ),
          onPressed: () {},
        ),
      ],
      backgroundColor: Colors.white,
      elevation: 0,
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: AppStrings.chatHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 16),
                    vertical: Responsive.h(context, 12),
                  ),
                ),
              ),
            ),
            SizedBox(width: Responsive.w(context, 8)),
            CircleAvatar(
              backgroundColor: const Color(0xFF44BF99),
              child:
                  const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: Responsive.h(context, 12)),
        constraints: BoxConstraints(maxWidth: Responsive.w(context, 320)),
        padding: EdgeInsets.all(Responsive.w(context, 14)),
        decoration: BoxDecoration(
          color: const Color(0xFFDFF7E2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFF093030)),
        ),
      ),
    );
  }

  Widget _botBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: Responsive.h(context, 12)),
        constraints: BoxConstraints(maxWidth: Responsive.w(context, 320)),
        padding: EdgeInsets.all(Responsive.w(context, 14)),
        decoration: BoxDecoration(
          color: const Color(0xFFDFF7E2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFF093030)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
