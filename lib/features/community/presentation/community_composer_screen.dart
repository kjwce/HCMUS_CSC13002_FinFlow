import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../models/community_post_model.dart';
import '../providers/community_provider.dart';
import '../utils/community_topics.dart';
import '../utils/rich_text_formatter.dart';
import 'widgets/post_submitted_dialog.dart';

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
  final List<XFile> _selectedImages = [];

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
      _category = communityTopics.first;
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

  Future<void> _pickImages() async {
    final images = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (!mounted || images.isEmpty) return;
    final remaining = 10 - _selectedImages.length;
    if (remaining <= 0) {
      _showMessage(
        AppStrings.choose(
          'You can attach up to 10 images.',
          'Bạn có thể đính kèm tối đa 10 ảnh.',
        ),
      );
      return;
    }
    setState(() => _selectedImages.addAll(images.take(remaining)));
    if (images.length > remaining) {
      _showMessage(
        AppStrings.choose(
          'Only the first 10 images were attached.',
          'Chỉ 10 ảnh đầu tiên được đính kèm.',
        ),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  Future<void> _pickCategory() async {
    final colors = context.finFlowColors;
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: colors.bottomSheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
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
              AppStrings.choose('Choose a topic', 'Chọn chủ đề'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: Responsive.sp(context, 15),
                color: colors.primaryText,
              ),
            ),
            SizedBox(height: Responsive.h(context, 8)),
            for (var i = 0; i < communityTopics.length; i++) ...[
              ListTile(
                leading: Icon(
                  _categoryIcon(communityTopics[i]),
                  color: AppColors.accentTeal,
                ),
                title: Text(communityTopicLabel(communityTopics[i])),
                trailing: communityTopics[i] == _category
                    ? const Icon(Icons.check, color: AppColors.primaryGreen)
                    : null,
                onTap: () => Navigator.of(context).pop(communityTopics[i]),
              ),
              if (i != communityTopics.length - 1)
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
    if ((text.isEmpty && _selectedImages.isEmpty) || _isPosting) return;
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
        if (_selectedImages.isNotEmpty) {
          await service.addPostImages(postId: postId, images: _selectedImages);
        }
      }
      if (!mounted) return;
      if (_isEditing) {
        Navigator.of(context).pop(true);
        return;
      }
      final action = await showPostSubmittedDialog(context);
      if (!mounted) return;
      if (action == PostSubmittedAction.viewActivity) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.communityActivity);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              '${_isEditing ? AppStrings.choose("Could not edit", "Không thể chỉnh sửa") : AppStrings.choose("Could not post", "Không thể đăng bài")}: $e',
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
    final canPost =
        (_controller.text.trim().isNotEmpty || _selectedImages.isNotEmpty) &&
        !_isPosting;
    final displayName = _anonymous
        ? AppStrings.choose('Anonymous', 'Ẩn danh')
        : (user?.fullName ?? AppStrings.choose('You', 'Bạn'));

    return Scaffold(
      backgroundColor: isDark ? colors.pageBackground : colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(canPost),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(context, 20),
                  Responsive.h(context, 18),
                  Responsive.w(context, 20),
                  Responsive.h(context, 24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAuthorRow(displayName, user?.avatarUrl),
                    SizedBox(height: Responsive.h(context, 14)),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 7,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 16),
                        color: colors.primaryText,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: AppStrings.choose(
                          "What's on your mind?",
                          'Bạn đang nghĩ gì?',
                        ),
                        hintStyle: TextStyle(
                          color: colors.secondaryText,
                          fontSize: Responsive.sp(context, 17),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      SizedBox(height: Responsive.h(context, 14)),
                      _buildSelectedMedia(),
                    ],
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

  Widget _buildSelectedMedia() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _selectedImages.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _selectedImages.length == 1 ? 1 : 2,
        childAspectRatio: _selectedImages.length == 1 ? 1.8 : 1,
        crossAxisSpacing: Responsive.w(context, 4),
        mainAxisSpacing: Responsive.w(context, 4),
      ),
      itemBuilder: (_, index) => Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.w(context, 12)),
            child: Image.file(
              File(_selectedImages[index].path),
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: Responsive.w(context, 6),
            right: Responsive.w(context, 6),
            child: IconButton.filled(
              tooltip: AppStrings.choose('Remove image', 'Xóa ảnh'),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .66),
                foregroundColor: Colors.white,
                minimumSize: const Size(40, 40),
              ),
              onPressed: () => setState(() => _selectedImages.removeAt(index)),
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
        ],
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
            tooltip: AppStrings.choose('Close', 'Đóng'),
            icon: Icon(
              Icons.close,
              size: Responsive.w(context, 22),
              color: colors.primaryText,
            ),
          ),
          Expanded(
            child: Text(
              _isEditing
                  ? AppStrings.choose('Edit post', 'Chỉnh sửa bài viết')
                  : AppStrings.choose('New post', 'Bài viết mới'),
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
                fontSize: Responsive.sp(context, 22),
                color: isDark ? colors.primaryText : AppColors.deepEmerald,
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
                        _isEditing
                            ? AppStrings.save
                            : AppStrings.choose('Post', 'Đăng'),
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
                        communityTopicLabel(_category),
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
        horizontal: Responsive.w(context, 16),
        vertical: Responsive.h(context, 10),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
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
            tooltip: AppStrings.choose('Add images', 'Thêm ảnh'),
            accent: true,
            onTap: _pickImages,
          ),
          SizedBox(width: Responsive.w(context, 6)),
          _ToolbarIconButton(
            icon: _anonymous
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            tooltip: _anonymous
                ? AppStrings.choose('Post with your profile', 'Đăng bằng hồ sơ')
                : AppStrings.choose('Post anonymously', 'Đăng ẩn danh'),
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
