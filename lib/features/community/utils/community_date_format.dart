/// Formats a [DateTime] the way the Figma community screens show it,
/// e.g. "6th May". No `intl` dependency required.
String formatCommunityDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day = date.day;
  final suffix = _daySuffix(day);
  return '$day$suffix ${months[date.month - 1]}';
}

String _daySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}
