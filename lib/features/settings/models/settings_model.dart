class SettingsModel {
  const SettingsModel({
    required this.userId,
    this.notificationsEnabled = true,
    this.darkMode = false,
    this.language = 'en',
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      userId: json['id'] as String,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      darkMode: json['dark_mode'] as bool? ?? false,
      language: json['language'] as String? ?? 'en',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': userId,
        'notifications_enabled': notificationsEnabled,
        'dark_mode': darkMode,
        'language': language,
      };

  final String userId;
  final bool notificationsEnabled;
  final bool darkMode;
  final String language;
}
