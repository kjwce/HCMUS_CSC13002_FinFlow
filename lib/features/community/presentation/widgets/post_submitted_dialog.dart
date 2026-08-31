import 'package:flutter/material.dart';

import '../../../../core/i18n/app_language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

enum PostSubmittedAction { dismiss, viewActivity }

Future<PostSubmittedAction> showPostSubmittedDialog(
  BuildContext context,
) async {
  return await showDialog<PostSubmittedAction>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PostSubmittedDialog(),
      ) ??
      PostSubmittedAction.dismiss;
}

class _PostSubmittedDialog extends StatelessWidget {
  const _PostSubmittedDialog();

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: colors.dialogBackground,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 22),
          vertical: Responsive.h(context, 24),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.divider),
        ),
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: isDark ? .38 : .16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 390,
            maxHeight: MediaQuery.sizeOf(context).height * .86,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              Responsive.w(context, 20),
              Responsive.h(context, 22),
              Responsive.w(context, 20),
              Responsive.h(context, 16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: Responsive.w(context, 54),
                  height: Responsive.w(context, 54),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF214A40)
                        : const Color(0xFFDDF5ED),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    size: Responsive.w(context, 28),
                    color: AppColors.deepEmerald,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 15)),
                Text(
                  AppStrings.choose(
                    'Post submitted for review',
                    'Bài viết đã gửi thành công',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 20),
                    fontWeight: FontWeight.w800,
                    color: colors.primaryText,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 7)),
                Text(
                  AppStrings.choose(
                    'Your post has been submitted successfully. Our Community team will review it before it becomes visible to everyone.',
                    'Bài viết của bạn đã được gửi thành công. Đội ngũ Community sẽ kiểm duyệt trước khi bài viết được hiển thị với mọi người.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 14),
                    fontWeight: FontWeight.w500,
                    height: 1.42,
                    color: colors.secondaryText,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 16)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 13),
                    vertical: Responsive.h(context, 11),
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A4037)
                        : const Color(0xFFE8F7F2),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: Responsive.w(context, 17),
                        color: AppColors.deepEmerald,
                      ),
                      SizedBox(width: Responsive.w(context, 8)),
                      Expanded(
                        child: Text(
                          AppStrings.choose(
                            'Most posts are reviewed shortly. You’ll receive a notification when your post is approved or rejected.',
                            'Hầu hết bài viết sẽ được kiểm duyệt trong thời gian ngắn. Bạn sẽ nhận được thông báo khi bài viết được duyệt hoặc từ chối.',
                          ),
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontSize: Responsive.sp(context, 12.5),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: colors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.h(context, 18)),
                SizedBox(
                  width: double.infinity,
                  height: Responsive.h(context, 48),
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(PostSubmittedAction.dismiss),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.deepEmerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: Text(
                      AppStrings.choose('Got it', 'Đã hiểu'),
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.h(context, 4)),
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(PostSubmittedAction.viewActivity),
                  child: Text(
                    AppStrings.choose(
                      'View my activity',
                      'Xem hoạt động của tôi',
                    ),
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 13.5),
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepEmerald,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
