import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../services/chat_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  PendingChatImage? _pendingImage;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImage == null) return;
    final pendingImage = _pendingImage;
    _controller.clear();
    setState(() => _pendingImage = null);
    _focusNode.requestFocus();
    _scrollToBottom();
    await ref
        .read(chatControllerProvider)
        .send(text, pendingImage: pendingImage);
    _scrollToBottom();
  }

  Future<void> _sendSuggestion(String text) async {
    _controller.text = text;
    await _send();
  }

  Future<void> _showHistory() async {
    _focusNode.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ChatHistorySheet(),
    );
  }

  Future<void> _showImagePicker() async {
    _focusNode.unfocus();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 6 * 1024 * 1024) {
        throw const ChatException(
          'IMAGE_TOO_LARGE',
          'Ảnh không được vượt quá 6 MB.',
        );
      }
      final mimeType = picked.mimeType ?? _mimeTypeFromName(picked.name);
      if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
        throw const ChatException(
          'INVALID_IMAGE',
          'Chỉ hỗ trợ ảnh JPG, PNG hoặc WebP.',
        );
      }
      setState(() {
        _pendingImage = PendingChatImage(bytes: bytes, mimeType: mimeType);
      });
    } on ChatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể chọn ảnh. Vui lòng thử lại.')),
      );
    }
  }

  static String _mimeTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    ref.listen(chatControllerProvider, (_, _) => _scrollToBottom());

    return Scaffold(
      backgroundColor: context.finFlowColors.pageBackground,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              key: const Key('chat-message-list'),
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                Responsive.w(context, 20),
                Responsive.h(context, 12),
                Responsive.w(context, 20),
                Responsive.h(context, 20),
              ),
              itemCount: state.messages.length + (state.isSending ? 1 : 0),
              separatorBuilder: (_, _) =>
                  SizedBox(height: Responsive.h(context, 20)),
              itemBuilder: (context, index) {
                if (index == state.messages.length) {
                  return const _TypingBubble();
                }
                return _MessageBubble(message: state.messages[index]);
              },
            ),
          ),
          if (!state.messages.any((message) => message.isUser))
            _QuickPrompts(
              enabled: !state.isSending,
              onSelected: _sendSuggestion,
            ),
          if (state.errorMessage != null)
            _ErrorBanner(
              message: state.errorMessage!,
              onDismiss: state.clearError,
            ),
          if (_pendingImage != null)
            _PendingImagePreview(
              bytes: _pendingImage!.bytes,
              onRemove: () => setState(() => _pendingImage = null),
            ),
          _ChatInput(
            controller: _controller,
            focusNode: _focusNode,
            isSending: state.isSending,
            onSend: _send,
            onImageTap: _showImagePicker,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final colors = context.finFlowColors;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: Responsive.h(context, 68),
      titleSpacing: Responsive.w(context, widget.showBackButton ? 4 : 20),
      leading: widget.showBackButton
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      title: Row(
        children: [
          Flexible(
            child: Text(
              'AI Assistant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: Responsive.sp(context, 22),
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('chat-history-button'),
          tooltip: AppLanguage.instance.locale == AppLocale.vietnamese
              ? 'Lịch sử trò chuyện'
              : 'Chat history',
          onPressed: _showHistory,
          icon: const Icon(Icons.history_rounded),
        ),
        const NotificationBell(),
        const SizedBox(width: 10),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatModel message;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) return _buildUserMessage(context);
    return _buildAssistantMessage(context);
  }

  Widget _buildUserMessage(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.w(context, 310)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: EdgeInsets.all(Responsive.w(context, 16)),
              decoration: const BoxDecoration(
                color: Color(0xFF064E3B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.image != null) ...[
                    _ChatImage(image: message.image!),
                    SizedBox(height: Responsive.h(context, 10)),
                  ],
                  Text(
                    message.message,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: Responsive.sp(context, 15),
                      height: 1.45,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.h(context, 3)),
            Text(
              AppLanguage.instance.locale == AppLocale.vietnamese
                  ? 'Đã gửi'
                  : 'Sent',
              style: TextStyle(
                fontSize: Responsive.sp(context, 10),
                color: context.finFlowColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantMessage(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.w(context, 330)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _AssistantAvatar(),
            SizedBox(width: Responsive.w(context, 8)),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(Responsive.w(context, 16)),
                    decoration: BoxDecoration(
                      color: context.finFlowColors.surface,
                      border: Border.all(
                        color: const Color(0xFFC3ECD7).withValues(alpha: 0.8),
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        bottomLeft: Radius.circular(3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF064E3B,
                          ).withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      message.message,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: Responsive.sp(context, 15),
                        height: 1.5,
                        color: context.finFlowColors.primaryText,
                      ),
                    ),
                  ),
                  if (message.insight != null) ...[
                    SizedBox(height: Responsive.h(context, 10)),
                    _InsightCard(insight: message.insight!),
                  ],
                  if (message.chart != null) ...[
                    SizedBox(height: Responsive.h(context, 10)),
                    _ChatChartCard(chart: message.chart!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Responsive.w(context, 32),
      height: Responsive.w(context, 32),
      decoration: const BoxDecoration(
        color: Color(0xFFC3ECD7),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.smart_toy_rounded,
        color: Color(0xFF064E3B),
        size: 18,
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final ChatInsight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: const Color(0xFFC3ECD7).withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC3ECD7).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.trending_up_rounded, color: Color(0xFF064E3B)),
          SizedBox(width: Responsive.w(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 13),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF064E3B),
                  ),
                ),
                SizedBox(height: Responsive.h(context, 3)),
                Text(
                  insight.detail,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 11),
                    height: 1.35,
                    color: const Color(0xFF416656),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isVietnamese = AppLanguage.instance.locale == AppLocale.vietnamese;
    final prompts = isVietnamese
        ? const [
            'Chi tiêu tuần này của tôi?',
            'Danh mục nào tốn nhiều nhất tháng này?',
            'Tôi còn bao nhiêu ngân sách?',
            'So sánh tuần này với tuần trước',
          ]
        : const [
            'How much did I spend this week?',
            'What is my top spending category this month?',
            'How much budget do I have left?',
            'Compare this week with last week',
          ];
    return SizedBox(
      key: const Key('chat-quick-prompts'),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
        itemCount: prompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          label: Text(prompts[index]),
          onPressed: enabled ? () => onSelected(prompts[index]) : null,
          backgroundColor: context.finFlowColors.surface,
          side: const BorderSide(color: Color(0xFFC3ECD7)),
          labelStyle: const TextStyle(
            color: Color(0xFF064E3B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChatChartCard extends StatelessWidget {
  const _ChatChartCard({required this.chart});

  final ChatChart chart;
  static const _colors = [
    Color(0xFF064E3B),
    Color(0xFF10B981),
    Color(0xFF44BF99),
    Color(0xFF7ADBB7),
    Color(0xFFE5B54B),
    Color(0xFFE86B5D),
    Color(0xFF3799D2),
    Color(0xFF8E928F),
  ];

  @override
  Widget build(BuildContext context) {
    if (chart.values.every((value) => value == 0)) return const SizedBox();
    return Container(
      key: const Key('chat-chart-card'),
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(context, 14)),
      decoration: BoxDecoration(
        color: context.finFlowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC3ECD7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chart.title,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 14),
              fontWeight: FontWeight.w700,
              color: context.finFlowColors.primaryText,
            ),
          ),
          SizedBox(height: Responsive.h(context, 14)),
          if (chart.type == ChatChartType.donut)
            _donut(context)
          else
            _bars(context),
          SizedBox(height: Responsive.h(context, 10)),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: List.generate(
              chart.labels.length,
              (index) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colors[index % _colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${chart.labels[index]}: ${_compactVnd(chart.values[index])}',
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 10),
                      color: context.finFlowColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _donut(BuildContext context) {
    return SizedBox(
      height: Responsive.h(context, 150),
      child: PieChart(
        PieChartData(
          centerSpaceRadius: Responsive.w(context, 34),
          sectionsSpace: 2,
          sections: List.generate(
            chart.values.length,
            (index) => PieChartSectionData(
              value: chart.values[index],
              color: _colors[index % _colors.length],
              radius: Responsive.w(context, 38),
              showTitle: false,
            ),
          ),
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      ),
    );
  }

  Widget _bars(BuildContext context) {
    final maxValue = chart.values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: Responsive.h(context, 150),
      child: BarChart(
        BarChartData(
          maxY: maxValue * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= chart.labels.length) {
                    return const SizedBox();
                  }
                  final label = chart.labels[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label.length > 8 ? '${label.substring(0, 7)}…' : label,
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 9),
                        color: context.finFlowColors.secondaryText,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(
            chart.values.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: chart.values[index],
                  width: Responsive.w(context, 18),
                  color: _colors[index % _colors.length],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      ),
    );
  }

  static String _compactVnd(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}Bđ';
    }
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}Mđ';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}Kđ';
    return '${value.toStringAsFixed(0)}đ';
  }
}

class _ChatHistorySheet extends ConsumerWidget {
  const _ChatHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(chatControllerProvider);
    final isVietnamese = AppLanguage.instance.locale == AppLocale.vietnamese;
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isVietnamese ? 'Lịch sử trò chuyện' : 'Chat history',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('new-chat-button'),
                  onPressed: () async {
                    await controller.newConversation();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add_comment_rounded, size: 18),
                  label: Text(isVietnamese ? 'Chat mới' : 'New chat'),
                ),
              ],
            ),
          ),
          if (controller.isLoadingHistory)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: controller.conversations.isEmpty
                ? Center(
                    child: Text(
                      isVietnamese
                          ? 'Chưa có cuộc trò chuyện đã lưu.'
                          : 'No saved conversations yet.',
                    ),
                  )
                : ListView.builder(
                    itemCount: controller.conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = controller.conversations[index];
                      final isActive =
                          conversation.id == controller.activeConversationId;
                      return ListTile(
                        selected: isActive,
                        leading: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: isActive ? const Color(0xFF064E3B) : null,
                        ),
                        title: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_dateLabel(conversation.updatedAt)),
                        onTap: () async {
                          await controller.openConversation(conversation.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'rename') {
                              await _rename(context, controller, conversation);
                            } else if (action == 'delete') {
                              await controller.deleteConversation(
                                conversation.id,
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(isVietnamese ? 'Đổi tên' : 'Rename'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(isVietnamese ? 'Xóa' : 'Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static Future<void> _rename(
    BuildContext context,
    ChatController controller,
    ChatConversation conversation,
  ) async {
    final textController = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 60,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (title != null) {
      await controller.renameConversation(conversation.id, title);
    }
  }

  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [_AssistantAvatar(), SizedBox(width: 8), _TypingDots()],
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chat-typing-indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.finFlowColors.surface,
        border: Border.all(color: const Color(0xFFC3ECD7)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(3),
        ),
      ),
      child: const Text('•••', style: TextStyle(color: Color(0xFF416656))),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.image});

  final ChatImageAttachment image;

  @override
  Widget build(BuildContext context) {
    final bytes = image.bytes;
    final signedUrl = image.signedUrl;
    final imageWidget = bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover)
        : signedUrl != null
        ? Image.network(
            signedUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white70),
            ),
          )
        : const Center(
            child: Icon(Icons.image_outlined, color: Colors.white70),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        key: const Key('chat-message-image'),
        width: Responsive.w(context, 230),
        height: Responsive.h(context, 170),
        child: imageWidget,
      ),
    );
  }
}

class _PendingImagePreview extends StatelessWidget {
  const _PendingImagePreview({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.w(context, 20),
          Responsive.h(context, 6),
          Responsive.w(context, 20),
          0,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                key: const Key('chat-pending-image'),
                width: Responsive.w(context, 92),
                height: Responsive.h(context, 72),
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: -8,
              top: -8,
              child: IconButton.filled(
                key: const Key('remove-chat-image'),
                onPressed: onRemove,
                style: IconButton.styleFrom(
                  minimumSize: const Size(28, 28),
                  maximumSize: const Size(28, 28),
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFF064E3B),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.onImageTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onImageTap;

  @override
  Widget build(BuildContext context) {
    final isVietnamese = AppLanguage.instance.locale == AppLocale.vietnamese;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        Responsive.h(context, 8),
        Responsive.w(context, 20),
        Responsive.h(context, 12),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.finFlowColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFC3ECD7).withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF064E3B).withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('chat-image-button'),
              tooltip: isVietnamese ? 'Gửi ảnh' : 'Send image',
              onPressed: isSending ? null : onImageTap,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFC3ECD7).withValues(alpha: 0.5),
                foregroundColor: const Color(0xFF064E3B),
                minimumSize: const Size(42, 42),
              ),
              icon: const Icon(Icons.image_outlined),
            ),
            Expanded(
              child: TextField(
                key: const Key('chat-input'),
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textInputAction: TextInputAction.send,
                onSubmitted: isSending ? null : (_) => onSend(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: isVietnamese
                      ? 'Nhập tin nhắn...'
                      : 'Type a message...',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            IconButton.filled(
              key: const Key('chat-send-button'),
              tooltip: isVietnamese ? 'Gửi' : 'Send',
              onPressed: isSending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF064E3B),
                disabledBackgroundColor: context.finFlowColors.disabled,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
