import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../../finance/presentation/add_transaction_sheet.dart';

/// Edit Profile screen – shown when user taps "Edit Profile" from the profile tab.
///
/// Layout (from Figma node 1:671 "edit"):
///   - Cover image (top, from assets/edit_cover.png)
///   - Back arrow (left) + "Edit my Profile" title (center)
///   - Circle avatar (128x128) with camera-icon overlay (bottom-right),
///     rendered on top of the white card so it's never clipped
///   - Username and ID below avatar
///   - "account settings" section header
///   - Form fields (Username, phone, email) with light-green bg,
///     rounded 10px
///   - Full-width "Update Profile" button
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  bool _isSaving = false;
  bool _isPicking = false;
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    final u = AuthService.instance.currentUser;
    _usernameController = TextEditingController(text: u?.fullName ?? '');
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.currentUser;
        final displayName = user?.fullName ?? AppStrings.noActiveUser;

        return Scaffold(
          backgroundColor: AppColors.dashboardBg,
          bottomNavigationBar: AppBottomNavBar(
            selectedIndex: 4,
            onAddTap: () => AddTransactionSheet.show(context),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── 1. Cover image (phía sau) ──────────────────────────────
                  Container(
                    margin: EdgeInsets.only(top: Responsive.h(context, 56)),
                    height: Responsive.h(context, 206),
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(40),
                      ),
                    ),
                    child: Image.asset(
                      'assets/edit_cover.png',
                      fit: BoxFit.cover,
                    ),
                  ),

                  // ── Back arrow + title (trên cover) ────────────────────────
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: Responsive.h(context, 56),
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(context, 12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: Responsive.w(context, 44),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: const Color(0xFF006C53),
                                size: Responsive.w(context, 22),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Edit my Profile',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.sp(context, 18),
                              color: const Color(0xFF006C53),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(width: Responsive.w(context, 44)),
                        ],
                      ),
                    ),
                  ),

                  // ── 2. White content card ──────────────────────────────────
                  Container(
                    margin: EdgeInsets.only(top: Responsive.h(context, 190)),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Khoảng trống để avatar + tên không bị che
                        SizedBox(height: Responsive.h(context, 140)),
                        // Account settings header
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: Responsive.w(context, 16),
                            ),
                            child: Text(
                              AppStrings.accountSettings,
                              style: TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                fontWeight: FontWeight.w500,
                                fontSize: Responsive.sp(context, 18),
                                color: _profileText,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: Responsive.h(context, 16)),
                        // Username field
                        _buildFormField(
                          label: AppStrings.username,
                          controller: _usernameController,
                          hint: 'John Smith',
                        ),
                        SizedBox(height: Responsive.h(context, 20)),
                        // Phone field
                        _buildFormField(
                          label: AppStrings.phone,
                          controller: _phoneController,
                          hint: '+44 555 5555 55',
                          textColor: const Color(0xFF0E3E3E),
                        ),
                        SizedBox(height: Responsive.h(context, 20)),
                        // Email field
                        _buildFormField(
                          label: AppStrings.emailAddress,
                          controller: _emailController,
                          hint: 'example@example.com',
                        ),
                        SizedBox(height: Responsive.h(context, 48)),
                        // Update Profile button
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(context, 16),
                          ),
                          child: _buildUpdateButton(),
                        ),
                        SizedBox(height: Responsive.h(context, 40)),
                      ],
                    ),
                  ),

                  // ── 3. Avatar + name/ID (đè lên – không bị che) ──────────
                  Positioned(
                    top: Responsive.h(context, 140),
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        // Avatar with camera badge
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: Responsive.w(context, 64),
                                backgroundColor: AppColors.lightGreen,
                                backgroundImage: _avatarFile != null
                                    ? FileImage(_avatarFile!)
                                    : (user?.avatarUrl != null
                                          ? NetworkImage(user!.avatarUrl!)
                                          : null),
                                child:
                                    _avatarFile == null &&
                                        user?.avatarUrl == null
                                    ? Text(
                                        _firstLetter(displayName),
                                        style: TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontSize: Responsive.sp(context, 40),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      )
                                    : null,
                              ),
                              // Camera icon overlay (bottom-right)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: Responsive.w(context, 32),
                                  height: Responsive.w(context, 32),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: Responsive.w(context, 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: Responsive.h(context, 12)),
                        // Username
                        Text(
                          displayName,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: Responsive.sp(context, 20),
                            color: _profileText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    Color? textColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontWeight: FontWeight.w500,
              fontSize: Responsive.sp(context, 12),
              color: _profileText,
            ),
          ),
          SizedBox(height: Responsive.h(context, 6)),
          Container(
            width: double.infinity,
            height: Responsive.h(context, 48),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x33006C53)),
            ),
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontWeight: FontWeight.w400,
                fontSize: Responsive.sp(context, 14),
                color: textColor ?? _profileText,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontWeight: FontWeight.w400,
                  fontSize: Responsive.sp(context, 14),
                  color: Colors.grey,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 20),
                  vertical: Responsive.h(context, 13),
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: Responsive.h(context, 48),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF08C99A),
          foregroundColor: const Color(0xFF00382C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? SizedBox(
                width: Responsive.w(context, 18),
                height: Responsive.h(context, 18),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00382C),
                ),
              )
            : Text(
                'Update Profile',
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.sp(context, 14),
                ),
              ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _usernameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Username cannot be empty')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? avatarUrl;

      // Upload avatar nếu có ảnh mới chọn
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  static String _firstLetter(String name) {
    final t = name.trim();
    return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
  }

  Future<void> _pickAvatar() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
    setState(() => _isPicking = false);
  }
}

// =============================================================================
// Constants
// =============================================================================

const _profileText = Color(0xFF093030);
