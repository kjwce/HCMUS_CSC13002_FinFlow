import '../../../core/i18n/app_language.dart';

const communityTopics = [
  'Budgeting',
  'Saving',
  'Debt-free',
  'Investing',
  'General',
];

const communityFeedTopics = ['All', ...communityTopics];

String communityTopicLabel(String topic) => switch (topic) {
  'All' => AppStrings.choose('All', 'Tất cả'),
  'Budgeting' => AppStrings.choose('Budgeting', 'Lập ngân sách'),
  'Saving' => AppStrings.choose('Saving', 'Tiết kiệm'),
  'Debt-free' => AppStrings.choose('Debt-free', 'Thoát nợ'),
  'Investing' => AppStrings.choose('Investing', 'Đầu tư'),
  'General' => AppStrings.choose('General', 'Chung'),
  _ => topic,
};
