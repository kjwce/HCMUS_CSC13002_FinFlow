import 'package:flutter/material.dart';

/// Supported languages
enum AppLocale {
  english('English', 'en'),
  vietnamese('Tiếng Việt', 'vi');

  const AppLocale(this.label, this.code);

  final String label;
  final String code;
}

/// Simple singleton-based locale manager with ChangeNotifier support.
class AppLanguage extends ChangeNotifier {
  AppLanguage._();

  static final AppLanguage instance = AppLanguage._();

  AppLocale _locale = AppLocale.english;
  AppLocale get locale => _locale;

  void setLocale(AppLocale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void toggle() {
    _locale =
        _locale == AppLocale.english ? AppLocale.vietnamese : AppLocale.english;
    notifyListeners();
  }
}

/// ============================================================
/// STRINGS — add new keys here and provide both translations.
/// ============================================================
class AppStrings {
  AppStrings._();

  // Helpers
  static String get _l => AppLanguage.instance.locale.code;
  static bool get _isEn => _l == 'en';

  // -- General --
  static String get appName => 'FinFlow';
  static String get appTagline => _isEn
      ? 'Your personal finance assistant'
      : 'Trợ lý tài chính cá nhân';

  // -- Auth screens --
  static String get signIn => _isEn ? 'Sign In' : 'Đăng nhập';
  static String get signUp => _isEn ? 'Sign Up' : 'Đăng ký';
  static String get signingIn => _isEn ? 'Signing In...' : 'Đang đăng nhập...';
  static String get creating => _isEn ? 'Creating...' : 'Đang tạo...';
  static String get forgotPassword => _isEn ? 'Forgot password?' : 'Quên mật khẩu?';
  static String get resetPassword =>
      _isEn ? 'Reset password' : 'Đặt lại mật khẩu';
  static String get backToSignIn =>
      _isEn ? 'Back to Sign In' : 'Quay lại đăng nhập';
  static String get newToFinflowSignUp =>
      _isEn ? 'New to FinFlow? Sign Up' : 'Chưa có tài khoản? Đăng ký';
  static String get alreadyHaveAccount =>
      _isEn ? 'Already have an account? Sign In' : 'Đã có tài khoản? Đăng nhập';
  static String get email => _isEn ? 'Email' : 'Email';
  static String get password => _isEn ? 'Password' : 'Mật khẩu';
  static String get confirmPassword =>
      _isEn ? 'Confirm password' : 'Xác nhận mật khẩu';
  static String get fullName => _isEn ? 'Full name' : 'Họ và tên';
  static String get orContinueWith =>
      _isEn ? 'or continue with' : 'hoặc tiếp tục bằng';
  static String get invalidEmailOrPassword =>
      _isEn ? 'Invalid email or password' : 'Email hoặc mật khẩu không đúng';
  static String get emailAlreadyRegistered =>
      _isEn ? 'Email already registered' : 'Email đã được đăng ký';
  static String get emailNotFound =>
      _isEn ? 'Email not found' : 'Email không tồn tại';
  static String get passwordTooShort =>
      _isEn ? 'Password must be at least 6 characters'
          : 'Mật khẩu phải có ít nhất 6 ký tự';
  static String get passwordsDoNotMatch =>
      _isEn ? 'Passwords do not match' : 'Mật khẩu không khớp';
  static String get registrationFailed =>
      _isEn ? 'Registration failed' : 'Đăng ký thất bại';
  static String get createAccount =>
      _isEn ? 'Create account' : 'Tạo tài khoản';
  static String get checkEmailConfirmation =>
      _isEn ? 'Please check your email to confirm your account'
          : 'Vui lòng kiểm tra email để xác nhận tài khoản';
  static String get signOut =>
      _isEn ? 'Sign Out' : 'Đăng xuất';

  // -- Forgot password screen --
  static String get forgotPasswordTitle =>
      _isEn ? 'Forgot password' : 'Quên mật khẩu';
  static String get enterEmailToReset =>
      _isEn ? 'Enter your email to reset your password'
          : 'Nhập email để đặt lại mật khẩu';

  // -- Home --
  static String get monthlyBalance =>
      _isEn ? 'Monthly balance' : 'Số dư tháng này';
  static String get totalBalance =>
      _isEn ? 'Total Balance' : 'Tổng số dư';
  static String get totalExpenseLabel =>
      _isEn ? 'Total Expense' : 'Tổng chi tiêu';
  static String get income => _isEn ? 'Income' : 'Thu nhập';
  static String get expense => _isEn ? 'Expense' : 'Chi tiêu';
  static String get recentTransactions =>
      _isEn ? 'Recent transactions' : 'Giao dịch gần đây';
  static String get add => _isEn ? 'Add' : 'Thêm';
  static String get noTransactionsYet => _isEn
      ? 'No transactions yet.\nTap "Add" to record your first one.'
      : 'Chưa có giao dịch nào.\nNhấn "Thêm" để ghi lại giao dịch đầu tiên.';
  static String get welcomeBack => _isEn ? 'Hi, Welcome Back' : 'Chào mừng trở lại';
  static String get greetingMorning => _isEn ? 'Good Morning' : 'Chào buổi sáng';
  static String get greetingAfternoon => _isEn ? 'Good Afternoon' : 'Chào buổi chiều';
  static String get greetingEvening => _isEn ? 'Good Evening' : 'Chào buổi tối';
  static String get savingsOnGoals => _isEn ? 'Savings\nOn Goals' : 'Tiết kiệm\nMục tiêu';
  static String get revenueLastWeek => _isEn ? 'Revenue Last Week' : 'Thu nhập tuần trước';
  static String get foodLastWeek => _isEn ? 'Food Last Week' : 'Ăn uống tuần trước';
  static String get daily => _isEn ? 'Daily' : 'Hàng ngày';
  static String get weekly => _isEn ? 'Weekly' : 'Hàng tuần';
  static String get monthly => _isEn ? 'Monthly' : 'Hàng tháng';
  static String get expenseLooksGood => _isEn
      ? '✅ %s Of Your Expenses, Looks Good.'
      : '✅ %s Chi tiêu của bạn, ổn đấy.';
  static String get overBudget => _isEn
      ? 'Over budget — consider adjusting your spending!'
      : 'Đã vượt ngân sách — hãy cân nhắc điều chỉnh chi tiêu!';
  static String get budget => _isEn ? 'Budget' : 'Ngân sách';

  // -- Add Transaction sheet --
  static String get addTransaction =>
      _isEn ? 'Add Transaction' : 'Thêm giao dịch';
  static String get title => _isEn ? 'Title' : 'Tiêu đề';
  static String get titleHint => _isEn ? 'e.g. Pho, Gas, Salary'
      : 'VD: Ăn phở, Đổ xăng, Lương';
  static String get amountVND => _isEn ? 'Amount (VND)' : 'Số tiền (VND)';
  static String get amountHint => _isEn ? 'e.g. 50000' : 'VD: 50000';
  static String get category => _isEn ? 'Category' : 'Danh mục';
  static String get addExpense =>
      _isEn ? 'Add Expense' : 'Thêm chi tiêu';
  static String get addIncome => _isEn ? 'Add Income' : 'Thêm thu nhập';
  static String get pleaseEnterTitle =>
      _isEn ? 'Please enter a title' : 'Vui lòng nhập tiêu đề';
  static String get pleaseEnterValidAmount =>
      _isEn ? 'Please enter a valid amount'
          : 'Vui lòng nhập số tiền hợp lệ';
  static String get pleaseSignInFirst =>
      _isEn ? 'Please sign in first to add a transaction'
          : 'Vui lòng đăng nhập trước để thêm giao dịch';

  // -- Bottom nav --
  static String get navHome => _isEn ? 'Home' : 'Trang chủ';
  static String get navAI => _isEn ? 'AI' : 'AI';
  static String get navCommunity => _isEn ? 'Community' : 'Cộng đồng';
  static String get navProfile => _isEn ? 'Profile' : 'Hồ sơ';

  // -- Profile --
  static String get profileTitle => _isEn ? 'Profile' : 'Hồ sơ';
  static String get noActiveUser =>
      _isEn ? 'No active user' : 'Chưa có người dùng';
  static String get signInToSetUser =>
      _isEn ? 'Sign in to set current user' : 'Đăng nhập để chọn người dùng';
  static String get userId => _isEn ? 'User ID' : 'Mã người dùng';
  static String get created => _isEn ? 'Created' : 'Ngày tạo';
  static String get viewDatabase =>
      _isEn ? 'View SQLite database' : 'Xem cơ sở dữ liệu';
  static String get clearAllData =>
      _isEn ? 'Clear all data' : 'Xoá toàn bộ dữ liệu';

  // -- Profile tab menu --
  static String get editProfileMenuItem =>
      _isEn ? 'Edit Profile' : 'Chỉnh sửa hồ sơ';
  static String get security => _isEn ? 'Security' : 'Bảo mật';
  static String get settingMenu => _isEn ? 'Setting' : 'Cài đặt';
  static String get help => _isEn ? 'Help' : 'Trợ giúp';
  static String get logout => _isEn ? 'Logout' : 'Đăng xuất';

  // -- Edit profile screen --
  static String get editProfile =>
      _isEn ? 'Edit my Profile' : 'Chỉnh sửa hồ sơ';
  static String get accountSettings =>
      _isEn ? 'Account settings' : 'Cài đặt tài khoản';
  static String get username => _isEn ? 'Username' : 'Tên người dùng';
  static String get phone => _isEn ? 'Phone' : 'Số điện thoại';
  static String get emailAddress =>
      _isEn ? 'Email address' : 'Địa chỉ email';
  static String get turnDarkTheme =>
      _isEn ? 'Turn dark Theme' : 'Chế độ tối';
  static String get pushNotifications =>
      _isEn ? 'Push notifications' : 'thông báo đẩy';
  static String get updateProfile =>
      _isEn ? 'Update Profile' : 'Cập nhật hồ sơ';

  // -- AI screen --
  static String get aiTitle => _isEn ? 'AI assistant' : 'Trợ lý AI';
  static String get naturalInput =>
      _isEn ? 'Natural language input' : 'Nhập bằng ngôn ngữ tự nhiên';
  static String get naturalInputDesc => _isEn
      ? 'Parse spending text into transactions.'
      : 'Phân tích văn bản chi tiêu thành giao dịch.';
  static String get receiptScanning =>
      _isEn ? 'Receipt scanning' : 'Quét hoá đơn';
  static String get receiptScanningDesc => _isEn
      ? 'OCR bills and categorize items.'
      : 'OCR hoá đơn và phân loại.';
  static String get aiCoach => _isEn ? 'AI coach' : 'Huấn luyện viên AI';
  static String get aiCoachDesc => _isEn
      ? 'Budget warnings and spending suggestions.'
      : 'Cảnh báo ngân sách và gợi ý chi tiêu.';
  static String get chatAssistant =>
      _isEn ? 'Chat assistant' : 'Trợ lý trò chuyện';
  static String get chatAssistantDesc => _isEn
      ? 'Ask questions about your money.'
      : 'Hỏi về tài chính của bạn.';

  // -- Community --
  static String get community => _isEn ? 'Community' : 'Cộng đồng';
  static String get joinCommunity => _isEn
      ? 'Join our community to share tips and learn from others!'
      : 'Tham gia cộng đồng để chia sẻ mẹo và học hỏi!';
  static String get comingSoon => _isEn ? 'Coming soon' : 'Sắp ra mắt';

  // -- Database viewer --
  static String get databaseTitle =>
      _isEn ? 'SQLite Database' : 'Cơ sở dữ liệu';
  static String get exportDB => _isEn ? 'Export database' : 'Xuất dữ liệu';
  static String get confirmClearTitle =>
      _isEn ? 'Clear all data?' : 'Xoá toàn bộ dữ liệu?';
  static String get confirmClearMsg => _isEn
      ? 'This will delete all users and transactions.'
      : 'Thao tác này sẽ xoá tất cả người dùng và giao dịch.';
  static String get cancel => _isEn ? 'Cancel' : 'Huỷ';
  static String get clear => _isEn ? 'Clear' : 'Xoá';
  static String get dataCleared =>
      _isEn ? 'All data cleared!' : 'Đã xoá toàn bộ dữ liệu!';
  static String get exportedTo =>
      _isEn ? 'Exported to:' : 'Đã xuất ra:';
  static String get exportFailed =>
      _isEn ? 'Export failed:' : 'Xuất thất bại:';
  static String get records => _isEn ? 'records' : 'bản ghi';

  // -- Verification screen --
  static String get verifyEmail =>
      _isEn ? 'Verify Email' : 'Xác thực Email';
  static String get verifyEmailDesc => _isEn
      ? 'Please enter the 4-digit code sent to your email'
      : 'Vui lòng nhập mã 4 chữ số đã gửi đến email của bạn';
  static String get verify => _isEn ? 'Verify' : 'Xác thực';
  static String get resendCode =>
      _isEn ? 'Resend code' : 'Gửi lại mã';
  static String get otpSent =>
      _isEn ? 'OTP code sent to your email!' : 'Mã OTP đã gửi đến email của bạn!';
  static String get otpVerified =>
      _isEn ? 'Email verified successfully!' : 'Xác thực email thành công!';
  static String get invalidOtp =>
      _isEn ? 'Invalid verification code' : 'Mã xác thực không đúng';

  // -- New password screen --
  static String get newPassword =>
      _isEn ? 'New Password' : 'Mật khẩu mới';
  static String get newPasswordDesc => _isEn
      ? 'Enter your new password'
      : 'Nhập mật khẩu mới của bạn';
  static String get newPasswordLabel =>
      _isEn ? 'New Password' : 'Mật khẩu mới';
  static String get confirmNewPasswordLabel =>
      _isEn ? 'Confirm Password' : 'Xác nhận mật khẩu';
  static String get reset => _isEn ? 'Reset' : 'Đặt lại';
  static String get passwordResetSuccess =>
      _isEn ? 'Password has been reset successfully!' : 'Mật khẩu đã được đặt lại thành công!';
  static String get checkEmailToReset =>
      _isEn ? 'Check your email for the password reset link'
          : 'Kiểm tra email để nhận link đặt lại mật khẩu';

  // -- Edit transaction --
  static String get editTransaction =>
      _isEn ? 'Edit Transaction' : 'Sửa giao dịch';
  static String get save => _isEn ? 'Save' : 'Lưu';

  // -- Settings --
  static String get settings => _isEn ? 'Settings' : 'Cài đặt';
  static String get budgetLimit =>
      _isEn ? 'Budget Limit' : 'Hạn mức ngân sách';
  static String get language => _isEn ? 'Language' : 'Ngôn ngữ';
  static String get about => _isEn ? 'About' : 'Thông tin';
  static String get saved => _isEn ? 'Saved!' : 'Đã lưu!';

  // -- Chat --
  static String get chatHint =>
      _isEn ? 'Ask me about your finances...' : 'Hỏi về tài chính của bạn...';
  static String get chatWelcome => _isEn
      ? 'Hello! I\'m your AI assistant. How can I help you today?'
      : 'Xin chào! Tôi là trợ lý AI. Tôi có thể giúp gì cho bạn?';

  // -- Scan --
  static String get scanReceipt =>
      _isEn ? 'Scan Receipt' : 'Quét hoá đơn';
  static String get scanDesc => _isEn
      ? 'Take a photo of your receipt to automatically add it as a transaction.'
      : 'Chụp ảnh hoá đơn để tự động thêm giao dịch.';
  static String get openCamera =>
      _isEn ? 'Open Camera' : 'Mở Camera';

  // -- Category names --
  static String categoryName(String cat) {
    if (_isEn) return cat;
    return _viCategory[cat] ?? cat;
  }

  static const _viCategory = {
    'Food': 'Ăn uống',
    'Transport': 'Di chuyển',
    'Subscription': 'Đăng ký',
    'Shopping': 'Mua sắm',
    'Entertainment': 'Giải trí',
    'Health': 'Sức khoẻ',
    'Bills': 'Hoá đơn',
    'Salary': 'Lương',
    'Other': 'Khác',
  };
}

/// Helper extensions for context-based string access.
extension BuildContextStrings on BuildContext {
  AppLocale get locale => AppLanguage.instance.locale;

  void setLocale(AppLocale l) => AppLanguage.instance.setLocale(l);

  void toggleLanguage() => AppLanguage.instance.toggle();
}
