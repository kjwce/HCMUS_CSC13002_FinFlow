import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _isSaving = false;
  bool _isPicking = false;
  File? _avatarFile;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageColor => _isDark ? _darkBackground : _mintBackground;
  Color get _surfaceColor => _isDark ? _darkSurface : Colors.white;
  Color get _primaryTextColor => _isDark ? _darkText : _onSurface;
  Color get _secondaryTextColor =>
      _isDark ? _darkSecondaryText : const Color(0xFF52655E);
  Color get _mutedTextColor =>
      _isDark ? _darkMutedText : const Color(0xFF52655E);
  Color get _borderColor => _isDark ? _darkBorder : Colors.transparent;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.currentUser;
        final displayName = _nameController.text.trim().isEmpty
            ? (user?.fullName ?? AppStrings.noActiveUser)
            : _nameController.text.trim();

        return Scaffold(
          backgroundColor: _pageColor,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      Responsive.w(context, 20),
                      Responsive.h(context, 8),
                      Responsive.w(context, 20),
                      Responsive.h(context, 32),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPhotoCard(user, displayName),
                        SizedBox(height: Responsive.h(context, 24)),
                        Padding(
                          padding: EdgeInsets.only(
                            left: Responsive.w(context, 4),
                            bottom: Responsive.h(context, 8),
                          ),
                          child: Text(
                            AppStrings.choose(
                              'PERSONAL DETAILS',
                              'THÔNG TIN CÁ NHÂN',
                            ),
                            style: TextStyle(
                              fontFamily: 'Hanken Grotesk',
                              fontSize: Responsive.sp(context, 13),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: _isDark
                                  ? _darkSecondaryText
                                  : const Color(0xFF3E5650),
                            ),
                          ),
                        ),
                        _buildDetailsCard(),
                        SizedBox(height: Responsive.h(context, 32)),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      height: Responsive.h(context, 64),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _isDark ? _darkBorder : Colors.transparent),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 8)),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back_rounded,
                size: Responsive.w(context, 24),
                color: _primaryTextColor,
              ),
            ),
            Expanded(
              child: Text(
                AppStrings.choose('Edit Profile', 'Chỉnh sửa hồ sơ'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: Responsive.sp(context, 22),
                  fontWeight: FontWeight.w700,
                  color: _isDark ? _primaryTextColor : AppColors.deepEmerald,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(dynamic user, String displayName) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 24),
        vertical: Responsive.h(context, 22),
      ),
      decoration: _cardDecoration(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: Responsive.h(context, -42),
            left: Responsive.w(context, -46),
            child: _decorativeCircle(
              82,
              _isDark ? const Color(0x3329483F) : const Color(0x0D00513E),
            ),
          ),
          Positioned(
            bottom: Responsive.h(context, -58),
            right: Responsive.w(context, -58),
            child: _decorativeCircle(
              116,
              _isDark ? const Color(0x3329483F) : const Color(0x0D00C49A),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: Responsive.w(context, 92),
                    height: Responsive.w(context, 92),
                    padding: EdgeInsets.all(Responsive.w(context, 4)),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      shape: BoxShape.circle,
                      boxShadow: _isDark
                          ? const []
                          : const [
                              BoxShadow(
                                color: Color(0x2400513E),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFFE2EAE7),
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : (user?.avatarUrl != null
                                ? NetworkImage(user!.avatarUrl!)
                                : null),
                      child: _avatarFile == null && user?.avatarUrl == null
                          ? Text(
                              _firstLetter(displayName),
                              style: TextStyle(
                                color: _isDark ? _darkPrimary : _primary,
                                fontSize: Responsive.sp(context, 30),
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: Responsive.w(context, -2),
                    bottom: Responsive.h(context, -2),
                    child: Material(
                      color: _isDark ? _darkPrimary : _primary,
                      shape: CircleBorder(
                        side: BorderSide(color: _surfaceColor, width: 2),
                      ),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isPicking ? null : _pickAvatar,
                        child: SizedBox(
                          width: Responsive.w(context, 32),
                          height: Responsive.w(context, 32),
                          child: _isPicking
                              ? Padding(
                                  padding: EdgeInsets.all(
                                    Responsive.w(context, 8),
                                  ),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _isDark
                                        ? _darkBackground
                                        : Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.photo_camera_rounded,
                                  color: _isDark
                                      ? _darkBackground
                                      : Colors.white,
                                  size: Responsive.w(context, 18),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: Responsive.h(context, 14)),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: Responsive.sp(context, 20),
                  fontWeight: FontWeight.w700,
                  color: _isDark ? _darkPrimary : _primary,
                ),
              ),
              SizedBox(height: Responsive.h(context, 4)),
              Text(
                AppStrings.choose(
                  'Tap the camera icon to change photo',
                  'Chạm biểu tượng máy ảnh để đổi ảnh',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 13),
                  fontWeight: FontWeight.w600,
                  color: _secondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _decorativeCircle(double size, Color color) {
    return Container(
      width: Responsive.w(context, size),
      height: Responsive.w(context, size),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      decoration: _cardDecoration(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildDetailRow(
            label: AppStrings.choose('FULL NAME', 'HỌ VÀ TÊN'),
            controller: _nameController,
            focusNode: _nameFocus,
            icon: Icons.person_rounded,
            iconColor: _isDark
                ? const Color(0xFF6EAEFF)
                : const Color(0xFF1478D4),
            iconBackground: _isDark
                ? const Color(0xFF173F54)
                : const Color(0xFFE8F2FF),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: _isDark ? _darkBorder : const Color(0xFFF0F2F1),
          ),
          _buildDetailRow(
            label: AppStrings.choose('PHONE NUMBER', 'SỐ ĐIỆN THOẠI'),
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            icon: Icons.call_rounded,
            iconColor: _isDark
                ? const Color(0xFFA6D568)
                : const Color(0xFF78B925),
            iconBackground: _isDark
                ? const Color(0xFF2C4525)
                : const Color(0xFFF1F8E8),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: _isDark ? _darkBorder : const Color(0xFFF0F2F1),
          ),
          _buildDetailRow(
            label: AppStrings.choose('EMAIL ADDRESS', 'ĐỊA CHỈ EMAIL'),
            controller: _emailController,
            icon: Icons.mail_rounded,
            iconColor: _isDark
                ? const Color(0xFFC69CFF)
                : const Color(0xFF8A35E8),
            iconBackground: _isDark
                ? const Color(0xFF3B2E52)
                : const Color(0xFFF2E8FF),
            readOnly: true,
            helperText: AppStrings.choose(
              'Email cannot be changed',
              'Không thể thay đổi email',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    bool readOnly = false,
    String? helperText,
  }) {
    return Container(
      height: Responsive.h(context, 84),
      color: readOnly
          ? (_isDark
                ? _darkBackground.withValues(alpha: 0.3)
                : const Color(0x4DF3F3F6))
          : _surfaceColor,
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
      child: Row(
        children: [
          Container(
            width: Responsive.w(context, 40),
            height: Responsive.w(context, 40),
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: Responsive.w(context, 21),
            ),
          ),
          SizedBox(width: Responsive.w(context, 16)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 12),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.75,
                        color: _isDark
                            ? _darkSecondaryText
                            : const Color(0xFF52645F),
                      ),
                    ),
                    if (readOnly) ...[
                      SizedBox(width: Responsive.w(context, 4)),
                      Icon(
                        Icons.lock_rounded,
                        size: Responsive.w(context, 13),
                        color: _isDark
                            ? _darkMutedText
                            : const Color(0xFF7D918A),
                      ),
                    ],
                  ],
                ),
                SizedBox(
                  height: Responsive.h(context, helperText == null ? 30 : 25),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: readOnly,
                    keyboardType: keyboardType,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: Responsive.sp(context, 17),
                      fontWeight: FontWeight.w500,
                      color: readOnly
                          ? (_isDark ? _darkMutedText : const Color(0xFF5D6865))
                          : _primaryTextColor,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (helperText != null)
                  Text(
                    helperText,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 12.5),
                      fontWeight: FontWeight.w600,
                      color: _mutedTextColor,
                    ),
                  ),
              ],
            ),
          ),
          if (!readOnly)
            IconButton(
              onPressed: () => focusNode?.requestFocus(),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.edit_rounded,
                size: Responsive.w(context, 21),
                color: _isDark ? _darkMutedText : const Color(0xFF829B93),
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _borderColor),
      boxShadow: _isDark
          ? const []
          : const [
              BoxShadow(
                color: Color(0x24006C53),
                blurRadius: 25,
                offset: Offset(0, 10),
                spreadRadius: -5,
              ),
            ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: Responsive.h(context, 56),
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isDark ? _darkButton : _primary,
          disabledBackgroundColor: (_isDark ? _darkButton : _primary)
              .withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          elevation: _isDark ? 0 : 7,
          shadowColor: _isDark ? Colors.transparent : const Color(0x33006C53),
          shape: const StadiumBorder(),
        ),
        icon: _isSaving
            ? SizedBox(
                width: Responsive.w(context, 19),
                height: Responsive.w(context, 19),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.check_circle_outline_rounded,
                size: Responsive.w(context, 21),
              ),
        label: Text(
          _isSaving
              ? AppStrings.choose('Saving...', 'Đang lưu...')
              : AppStrings.choose('Save Changes', 'Lưu thay đổi'),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: Responsive.sp(context, 18),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Full name cannot be empty',
              'Họ và tên không được để trống',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await AuthService.instance.uploadAvatar(_avatarFile!);
      }

      await AuthService.instance.updateProfile(
        fullName: name,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.saved)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Failed to save: $error',
              'Không thể lưu: $error',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _pickAvatar() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null && mounted) {
        setState(() => _avatarFile = File(picked.path));
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  static String _firstLetter(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }
}

const _mintBackground = Color(0xFFEDF7F3);
const _primary = Color(0xFF00513E);
const _onSurface = Color(0xFF1A1C1E);
const _darkBackground = Color(0xFF081C18);
const _darkSurface = Color(0xFF16352E);
const _darkBorder = Color(0xFF29483F);
const _darkText = Color(0xFFF4FBF8);
const _darkSecondaryText = Color(0xFFA9C1B9);
const _darkMutedText = Color(0xFF708D84);
const _darkPrimary = Color(0xFF38D6AC);
const _darkButton = Color(0xFF006C53);
