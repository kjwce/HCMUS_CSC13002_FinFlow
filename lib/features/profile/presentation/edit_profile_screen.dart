import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../auth/services/auth_service.dart';

/// Edit Profile screen – shown when user taps "Edit Profile" from the profile tab.
///
/// Layout (from Figma node 1:671 "edit"):
///   - Cover image (top, from assets/edit_cover.png)
///   - Back arrow (left) + "Edit my Profile" title (center)
///   - Circle avatar (128x128) with camera-icon overlay (bottom-right),
///     rendered on top of the white card so it's never clipped
///   - Username and ID below avatar
///   - "account settings" section header
///   - Form fields (Username, phone, email, weekly budget) with light-green bg,
///     rounded 10px
///   - Toggle switches: "Turn dark Theme", "push notifications"
///   - "Update Profile" button (green, rounded 30px)
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _weeklyBudgetController;

  bool _darkTheme = false;
  bool _pushNotifications = true;
  bool _isSaving = false;
  bool _isPicking = false;
  bool _isFormattingWeeklyBudget = false;
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    final u = AuthService.instance.currentUser;
    _usernameController = TextEditingController(text: u?.fullName ?? '');
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    final weeklyBudget = AuthService.instance.weeklyBudget;
    _weeklyBudgetController = TextEditingController(
      text: weeklyBudget > 0 ? _formatMoneyInput(weeklyBudget.toString()) : '',
    );
    _weeklyBudgetController.addListener(_formatWeeklyBudgetInput);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _weeklyBudgetController.removeListener(_formatWeeklyBudgetInput);
    _weeklyBudgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.currentUser;
        final displayName = user?.fullName ?? AppStrings.noActiveUser;
        final userId = user?.id ?? '-';

        return Scaffold(
          backgroundColor: AppColors.dashboardBg,
          bottomNavigationBar: const AppBottomNavBar(selectedIndex: 4),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── 1. Cover image (phía sau) ──────────────────────────────
                  SizedBox(
                    height: Responsive.h(context, 206),
                    width: double.infinity,
                    child: Image.asset(
                      'assets/edit_cover.png',
                      fit: BoxFit.cover,
                    ),
                  ),

                  // ── Back arrow + title (trên cover) ────────────────────────
                  Positioned(
                    top: Responsive.h(context, 12),
                    left: Responsive.w(context, 20),
                    right: Responsive.w(context, 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.arrow_back,
                            color: _profileText,
                            size: Responsive.w(context, 24),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Edit my Profile',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: Responsive.sp(context, 20),
                            color: _profileText,
                          ),
                        ),
                        const Spacer(),
                        const NotificationBell(),
                      ],
                    ),
                  ),

                  // ── 2. White content card ──────────────────────────────────
                  Container(
                    margin: EdgeInsets.only(top: Responsive.h(context, 180)),
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
                        SizedBox(height: Responsive.h(context, 168)),
                        // Account settings header
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: Responsive.w(context, 38),
                            ),
                            child: Text(
                              AppStrings.accountSettings,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: Responsive.sp(context, 20),
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
                        SizedBox(height: Responsive.h(context, 20)),
                        _buildFormField(
                          label: 'Weekly Budget',
                          controller: _weeklyBudgetController,
                          hint: '500,000',
                          keyboardType: TextInputType.number,
                          suffixText: 'VND',
                        ),
                        SizedBox(height: Responsive.h(context, 24)),
                        // push notifications toggle
                        _buildToggleRow(
                          label: AppStrings.pushNotifications,
                          value: _pushNotifications,
                          onChanged: (v) =>
                              setState(() => _pushNotifications = v),
                        ),
                        SizedBox(height: Responsive.h(context, 37)),
                        // Turn dark Theme toggle
                        _buildToggleRow(
                          label: AppStrings.turnDarkTheme,
                          value: _darkTheme,
                          onChanged: (v) => setState(() => _darkTheme = v),
                        ),
                        SizedBox(height: Responsive.h(context, 48)),
                        // Update Profile button
                        _buildUpdateButton(),
                        SizedBox(height: Responsive.h(context, 40)),
                      ],
                    ),
                  ),

                  // ── 3. Avatar + name/ID (đè lên – không bị che) ──────────
                  Positioned(
                    top: Responsive.h(context, 130),
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
                        SizedBox(height: Responsive.h(context, 4)),
                        // ID
                        Text(
                          'ID: $userId',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: Responsive.sp(context, 13),
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
    TextInputType? keyboardType,
    String? suffixText,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 38)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: Responsive.sp(context, 15),
              color: _profileText,
            ),
          ),
          SizedBox(height: Responsive.h(context, 6)),
          Container(
            width: double.infinity,
            height: Responsive.h(context, 32),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w300,
                fontSize: Responsive.sp(context, 13),
                color: textColor ?? _profileText,
              ),
              decoration: InputDecoration(
                hintText: hint,
                suffixText: suffixText,
                suffixStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: Responsive.sp(context, 11),
                  color: AppColors.mutedGray,
                ),
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w300,
                  fontSize: Responsive.sp(context, 13),
                  color: Colors.grey,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 20),
                  vertical: Responsive.h(context, 6),
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 38)),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: Responsive.sp(context, 15),
              color: _profileText,
            ),
          ),
          const Spacer(),
          _CustomToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: Responsive.w(context, 169),
      height: Responsive.h(context, 36),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? SizedBox(
                width: Responsive.w(context, 18),
                height: Responsive.h(context, 18),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _profileText,
                ),
              )
            : Text(
                'Update Profile',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: Responsive.sp(context, 15),
                  color: _profileText,
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
        weeklyBudget: _parseMoneyInput(_weeklyBudgetController.text),
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

  void _formatWeeklyBudgetInput() {
    if (_isFormattingWeeklyBudget) return;
    _isFormattingWeeklyBudget = true;
    final digits = _weeklyBudgetController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _weeklyBudgetController.text = '';
    } else {
      final formatted = _formatMoneyInput(digits);
      _weeklyBudgetController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    _isFormattingWeeklyBudget = false;
  }

  static int _parseMoneyInput(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return int.tryParse(digits) ?? 0;
  }

  static String _formatMoneyInput(String digits) {
    return digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
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

// =============================================================================
// Custom toggle switch matching Figma: green rounded pill 31x15, white circle 12x12
// =============================================================================

class _CustomToggle extends StatelessWidget {
  const _CustomToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: Responsive.w(context, 31),
        height: Responsive.w(
          context,
          15,
        ), // using w() since this is a small value that should keep its aspect ratio
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7.5),
          color: value ? AppColors.primaryGreen : const Color(0xFFCCCCCC),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: Responsive.w(context, 12),
            height: Responsive.w(context, 12),
            margin: EdgeInsets.symmetric(horizontal: Responsive.w(context, 2)),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
