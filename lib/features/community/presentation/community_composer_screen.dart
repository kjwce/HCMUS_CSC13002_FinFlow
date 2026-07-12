import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../providers/community_provider.dart';

const _kComposerCategories = ['Budgeting', 'Saving', 'Debt-free', 'Investing', 'General'];

/// Full-screen "New post" composer — mirrors the Threads-style layout:
/// close button, author row with a community/category picker, a large
/// text field, and a bottom formatting toolbar (bold/italic/underline/
/// bullets/spoiler).
class CommunityComposerScreen extends ConsumerStatefulWidget {
  const CommunityComposerScreen({super.key});

  @override
  ConsumerState<CommunityComposerScreen> createState() =>
      _CommunityComposerScreenState();
}

class _CommunityComposerScreenState
    extends ConsumerState<CommunityComposerScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String _category = _kComposerCategories.first;
  bool _anonymous = false;
  bool _isPosting = false;

  static const _bgColor = Color(0xFFF9FBF8);
  static const _headerBg = Color(0xFFD4F4E4);
  static const _primaryGreen = Color(0xFF44BF99);
  static const _textDark = Color(0xFF002117);
  static const _textMuted = Color(0xFF8E918F);
  static const _white = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Formatting toolbar actions
  // ---------------------------------------------------------------------

  void _wrapSelection(String prefix, String suffix) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final selected = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$prefix$selected$suffix');
    final cursor = selected.isEmpty
        ? start + prefix.length
        : start + prefix.length + selected.length + suffix.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _focusNode.requestFocus();
  }

  void _insertBullet() {
    final text = _controller.text;
    final selection = _controller.selection;
    final offset = selection.start < 0 ? text.length : selection.start;
    final needsNewline = offset > 0 && text[offset - 1] != '\n';
    final insert = '${needsNewline ? '\n' : ''}• ';
    final newText = text.replaceRange(offset, offset, insert);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + insert.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: Responsive.h(context, 12)),
            Text(
              'Community or topic',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: Responsive.sp(context, 15),
                color: _textDark,
              ),
            ),
            SizedBox(height: Responsive.h(context, 8)),
            for (final category in _kComposerCategories)
              ListTile(
                title: Text(category),
                trailing: category == _category
                    ? const Icon(Icons.check, color: _primaryGreen)
                    : null,
                onTap: () => Navigator.of(context).pop(category),
              ),
            SizedBox(height: Responsive.h(context, 8)),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isPosting) return;
    setState(() => _isPosting = true);
    try {
      await ref.read(communityServiceProvider).createPost(
            content: text,
            isAnonymous: _anonymous,
            category: _category,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final canPost = _controller.text.trim().isNotEmpty && !_isPosting;
    final displayName = _anonymous ? 'Anonymous' : (user?.fullName ?? 'You');

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(canPost),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.w(context, 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAuthorRow(displayName),
                    SizedBox(height: Responsive.h(context, 12)),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 4,
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 15),
                        color: _textDark,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: "What's new?",
                        hintStyle: TextStyle(
                          color: _textMuted,
                          fontSize: Responsive.sp(context, 15),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool canPost) {
    return Container(
      color: _headerBg,
      padding: EdgeInsets.symmetric(
        vertical: Responsive.h(context, 14),
        horizontal: Responsive.w(context, 16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(Icons.close, size: Responsive.w(context, 22), color: _textDark),
          ),
          Expanded(
            child: Text(
              'New post',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: Responsive.sp(context, 16),
                color: _textDark,
              ),
            ),
          ),
          GestureDetector(
            onTap: canPost ? _submit : null,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 16),
                vertical: Responsive.h(context, 8),
              ),
              decoration: BoxDecoration(
                color: canPost ? _primaryGreen : _textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isPosting
                  ? SizedBox(
                      width: Responsive.w(context, 14),
                      height: Responsive.w(context, 14),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _white,
                      ),
                    )
                  : Text(
                      'Post',
                      style: TextStyle(
                        color: _white,
                        fontWeight: FontWeight.w700,
                        fontSize: Responsive.sp(context, 13),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorRow(String displayName) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _anonymous = !_anonymous),
          child: CircleAvatar(
            radius: Responsive.w(context, 20),
            backgroundColor: _anonymous ? _textMuted : _primaryGreen,
            child: Icon(
              _anonymous ? Icons.visibility_off : Icons.person,
              color: _white,
              size: Responsive.w(context, 18),
            ),
          ),
        ),
        SizedBox(width: Responsive.w(context, 10)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: Responsive.sp(context, 14),
                color: _textDark,
              ),
            ),
            SizedBox(height: Responsive.h(context, 2)),
            GestureDetector(
              onTap: _pickCategory,
              child: Row(
                children: [
                  Text(
                    _category,
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 12.5),
                      color: _textMuted,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: Responsive.w(context, 16), color: _textMuted),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 12),
          vertical: Responsive.h(context, 8),
        ),
        decoration: BoxDecoration(
          color: _white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _ToolbarButton(
              label: 'B',
              bold: true,
              onTap: () => _wrapSelection('**', '**'),
            ),
            _ToolbarButton(
              label: 'I',
              italic: true,
              onTap: () => _wrapSelection('_', '_'),
            ),
            _ToolbarButton(
              label: 'U',
              underline: true,
              onTap: () => _wrapSelection('~', '~'),
            ),
            _ToolbarIconButton(
              icon: Icons.format_list_bulleted,
              onTap: _insertBullet,
            ),
            const Spacer(),
            _ToolbarIconButton(
              icon: Icons.visibility_off_outlined,
              tooltip: 'Mark as spoiler',
              onTap: () => _wrapSelection('||', '||'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.onTap,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;
  final bool underline;

  static const _textDark = Color(0xFF002117);

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      radius: 22,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 10)),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Responsive.sp(context, 17),
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            decoration: underline ? TextDecoration.underline : null,
            color: _textDark,
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  static const _textDark = Color(0xFF002117);

  @override
  Widget build(BuildContext context) {
    final button = InkResponse(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      radius: 22,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 10)),
        child: Icon(icon, size: Responsive.w(context, 20), color: _textDark),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
