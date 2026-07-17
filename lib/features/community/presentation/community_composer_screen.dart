import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../models/community_post_model.dart';
import '../providers/community_provider.dart';
import '../utils/rich_text_formatter.dart';

const _kComposerCategories = [
  'Budgeting',
  'Saving',
  'Debt-free',
  'Investing',
  'General',
];

/// Full-screen "New post" composer — mirrors the Threads-style layout:
/// close button, author row with a community/category picker, a large
/// text field, and a bottom formatting toolbar (bold/italic/underline/
/// bullets/spoiler).
///
/// Pass [editPost] to enter edit mode for an existing post.
class CommunityComposerScreen extends ConsumerStatefulWidget {
  const CommunityComposerScreen({super.key, this.editPost});

  final CommunityPostModel? editPost;

  @override
  ConsumerState<CommunityComposerScreen> createState() =>
      _CommunityComposerScreenState();
}

class _CommunityComposerScreenState
    extends ConsumerState<CommunityComposerScreen> {
  final _controller = MarkdownEditingController();
  final _focusNode = FocusNode();
  XFile? _selectedImage;

  late String _category;
  bool _anonymous = false;
  bool _isPosting = false;

  bool get _isEditing => widget.editPost != null;

  @override
  void initState() {
    super.initState();
    final post = widget.editPost;
    if (post != null) {
      _category = post.category;
      _anonymous = post.isAnonymous;
      _controller.text = post.content;
    } else {
      _category = _kComposerCategories.first;
    }
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

  Set<String> get _activeFormats => _controller.activeFormatsAt(
    _controller.selection.isValid ? _controller.selection.start : 0,
  );

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (image != null && mounted) setState(() => _selectedImage = image);
  }

  Future<void> _pickCategory() async {
    final colors = context.finFlowColors;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.bottomSheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: Responsive.h(context, 12)),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(height: Responsive.h(context, 16)),
            Text(
              'Choose a topic',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: Responsive.sp(context, 15),
                color: colors.primaryText,
              ),
            ),
            SizedBox(height: Responsive.h(context, 8)),
            for (var i = 0; i < _kComposerCategories.length; i++) ...[
              ListTile(
                leading: Icon(
                  _categoryIcon(_kComposerCategories[i]),
                  color: AppColors.accentTeal,
                ),
                title: Text(_kComposerCategories[i]),
                trailing: _kComposerCategories[i] == _category
                    ? const Icon(Icons.check, color: AppColors.primaryGreen)
                    : null,
                onTap: () => Navigator.of(context).pop(_kComposerCategories[i]),
              ),
              if (i != _kComposerCategories.length - 1)
                Divider(height: 1, indent: 56, color: colors.divider),
            ],
            SizedBox(height: Responsive.h(context, 8)),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  IconData _categoryIcon(String category) => switch (category) {
    'Budgeting' => Icons.savings_outlined,
    'Saving' => Icons.account_balance_outlined,
    'Debt-free' => Icons.money_off_outlined,
    'Investing' => Icons.trending_up,
    _ => Icons.forum_outlined,
  };

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isPosting) return;
    setState(() => _isPosting = true);
    try {
      final service = ref.read(communityServiceProvider);
      if (_isEditing) {
        await service.editPost(
          postId: widget.editPost!.id,
          content: text,
          category: _category,
          isSpoiler: widget.editPost!.isSpoiler,
        );
      } else {
        final postId = await service.createPost(
          content: text,
          isAnonymous: _anonymous,
          category: _category,
        );
        if (_selectedImage != null) {
          await service.addPostImage(postId: postId, image: _selectedImage!);
        }
        await service.fetchPosts();
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              '${_isEditing ? "Could not edit" : "Could not post"}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPost = _controller.text.trim().isNotEmpty && !_isPosting;
    final displayName = _anonymous ? 'Anonymous' : (user?.fullName ?? 'You');

    return Scaffold(
      backgroundColor: isDark ? colors.pageBackground : AppColors.mintSoft,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : RadialGradient(
                  center: const Alignment(0.45, -0.72),
                  radius: 0.42,
                  colors: [
                    AppColors.primaryGreen.withValues(alpha: 0.42),
                    AppColors.dashboardHeaderBg.withValues(alpha: 0.9),
                    AppColors.mint,
                  ],
                  stops: const [0, 0.35, 1],
                ),
          color: isDark ? colors.pageBackground : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(canPost),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.w(context, 28),
                    Responsive.h(context, 18),
                    Responsive.w(context, 28),
                    Responsive.h(context, 14),
                  ),
                  child: Column(
                    children: [
                      _buildAuthorRow(displayName, user?.avatarUrl),
                      SizedBox(height: Responsive.h(context, 18)),
                      AspectRatio(
                        aspectRatio: 0.92,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).shadowColor.withValues(alpha: 0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 7),
                              ),
                              BoxShadow(
                                color: AppColors.accentTeal.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 30,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  expands: true,
                                  maxLines: null,
                                  minLines: null,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: TextStyle(
                                    fontSize: Responsive.sp(context, 15),
                                    color: colors.primaryText,
                                    height: 1.45,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    hintText: "What's on your mind?",
                                    hintStyle: TextStyle(
                                      color: colors.secondaryText,
                                      fontSize: Responsive.sp(context, 16),
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.all(
                                      Responsive.w(context, 20),
                                    ),
                                  ),
                                ),
                              ),
                              if (_selectedImage != null)
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(context, 14),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          File(_selectedImage!.path),
                                          height: Responsive.h(context, 120),
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      IconButton.filled(
                                        onPressed: () => setState(
                                          () => _selectedImage = null,
                                        ),
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(height: Responsive.h(context, 18)),
                      _buildToolbar(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool canPost) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surface : AppColors.dashboardHeaderBg,
        border: Border(bottom: BorderSide(color: colors.divider)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        vertical: Responsive.h(context, 14),
        horizontal: Responsive.w(context, 16),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
            icon: Icon(
              Icons.close,
              size: Responsive.w(context, 22),
              color: colors.primaryText,
            ),
          ),
          Expanded(
            child: Text(
              _isEditing ? 'Edit post' : 'New post',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: Responsive.sp(context, 16),
                color: colors.primaryText,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canPost ? _submit : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 16),
                  vertical: Responsive.h(context, 8),
                ),
                decoration: BoxDecoration(
                  color: canPost ? AppColors.deepEmerald : colors.disabled,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isPosting
                    ? SizedBox(
                        width: Responsive.w(context, 14),
                        height: Responsive.w(context, 14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Save' : 'Post',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.sp(context, 13),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorRow(String displayName, String? avatarUrl) {
    final colors = context.finFlowColors;
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: Responsive.w(context, 20),
          backgroundColor: _anonymous
              ? AppColors.mutedGray
              : AppColors.primaryGreen,
          backgroundImage: !_anonymous && avatarUrl?.isNotEmpty == true
              ? NetworkImage(avatarUrl!)
              : null,
          child: _anonymous
              ? const Icon(Icons.visibility_off, color: Colors.white)
              : avatarUrl?.isNotEmpty == true
              ? null
              : Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        SizedBox(width: Responsive.w(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.sp(context, 14),
                  color: colors.primaryText,
                ),
              ),
              SizedBox(height: Responsive.h(context, 2)),
              InkWell(
                onTap: _pickCategory,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(
                        _category,
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 12.5),
                          color: AppColors.mutedGray,
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        size: Responsive.w(context, 16),
                        color: AppColors.mutedGray,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final colors = context.finFlowColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 14),
        vertical: Responsive.h(context, 8),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _ToolbarButton(
            label: 'B',
            bold: true,
            active: _activeFormats.contains('bold'),
            onTap: () => _wrapSelection('**', '**'),
          ),
          _ToolbarButton(
            label: 'I',
            italic: true,
            active: _activeFormats.contains('italic'),
            onTap: () => _wrapSelection('*', '*'),
          ),
          _ToolbarButton(
            label: 'U',
            underline: true,
            active: _activeFormats.contains('underline'),
            onTap: () => _wrapSelection('~', '~'),
          ),
          Container(
            width: 1,
            height: Responsive.h(context, 24),
            margin: EdgeInsets.symmetric(horizontal: Responsive.w(context, 6)),
            color: colors.divider,
          ),
          _ToolbarIconButton(
            icon: Icons.format_list_bulleted,
            onTap: _insertBullet,
          ),
          _ToolbarIconButton(
            icon: Icons.image_outlined,
            tooltip: 'Add image',
            accent: true,
            onTap: _pickImage,
          ),
          SizedBox(width: Responsive.w(context, 6)),
          _ToolbarIconButton(
            icon: _anonymous
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            tooltip: _anonymous ? 'Post with your profile' : 'Post anonymously',
            accent: true,
            onTap: _isEditing
                ? () {}
                : () => setState(() => _anonymous = !_anonymous),
          ),
        ],
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
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      radius: 22,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 10),
          vertical: Responsive.h(context, 7),
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryGreen.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          bold
              ? Icons.format_bold
              : italic
              ? Icons.format_italic
              : Icons.format_underlined,
          size: Responsive.w(context, 23),
          semanticLabel: label,
          color: active
              ? AppColors.deepEmerald
              : context.finFlowColors.primaryText,
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
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final button = InkResponse(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      radius: 26,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: accent ? Responsive.w(context, 44) : Responsive.w(context, 38),
        height: Responsive.w(context, 44),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.primaryGreen.withValues(alpha: 0.13)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: Responsive.w(context, accent ? 23 : 22),
          color: accent
              ? AppColors.mediumGreen
              : context.finFlowColors.primaryText,
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
