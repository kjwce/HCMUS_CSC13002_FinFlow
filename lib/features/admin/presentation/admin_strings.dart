import '../../../core/i18n/app_language.dart';

class AdminStrings {
  AdminStrings._();

  static String t(String english, String vietnamese) =>
      AppStrings.choose(english, vietnamese);

  static String get moderation => t('Post moderation', 'Kiểm duyệt bài viết');
  static String get reportedPosts => t('Reported posts', 'Bài bị báo cáo');
  static String get members => t('Members', 'Thành viên');
  static String get refresh => t('Refresh', 'Làm mới');
  static String get signOut => t('Sign out', 'Đăng xuất');
  static String get cancel => t('Cancel', 'Hủy');
  static String get retry => t('Try again', 'Thử lại');
  static String get approve => t('Approve', 'Duyệt bài');
  static String get reject => t('Reject', 'Từ chối');
  static String get removePost => t('Remove post', 'Gỡ bài');
  static String get pending => t('Pending', 'Chờ duyệt');
  static String get approved => t('Approved', 'Đã duyệt');
  static String get rejected => t('Rejected', 'Từ chối');
  static String get removed => t('Removed', 'Đã gỡ');
  static String get all => t('All', 'Tất cả');
  static String get reports => t('Reports', 'Lượt báo cáo');
  static String get noDescription =>
      t('No additional details', 'Không có mô tả thêm');
  static String get member => t('Member', 'Thành viên');
  static String get noEmail => t('Email unavailable', 'Không hiển thị email');

  static String reportReason(String value) => switch (value) {
    'unsafe_illegal' => t('Unsafe or illegal content', 'Nội dung nguy hiểm'),
    'scam_fraud' => t('Scam or fraud', 'Lừa đảo'),
    'spam' => t('Spam', 'Spam'),
    'harassment' => t('Harassment', 'Quấy rối'),
    'misinformation' => t('Misinformation', 'Thông tin sai lệch'),
    _ => value,
  };
}
