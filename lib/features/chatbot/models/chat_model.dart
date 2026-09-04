import 'dart:typed_data';

enum ChatRole { user, assistant }

enum ChatChartType { bar, donut }

class ChatChart {
  const ChatChart({
    required this.type,
    required this.title,
    required this.labels,
    required this.values,
  });

  factory ChatChart.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final rawLabels = json['labels'];
    final rawValues = json['values'];
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Invalid chart title');
    }
    if (rawLabels is! List || rawValues is! List || rawLabels.isEmpty) {
      throw const FormatException('Invalid chart data');
    }
    final labels = rawLabels.map((item) => item.toString()).toList();
    final values = rawValues.map((item) {
      if (item is! num || !item.isFinite || item < 0) {
        throw const FormatException('Invalid chart value');
      }
      return item.toDouble();
    }).toList();
    if (labels.length != values.length || labels.length > 8) {
      throw const FormatException('Mismatched chart data');
    }
    return ChatChart(
      type: json['type'] == 'donut' ? ChatChartType.donut : ChatChartType.bar,
      title: title.trim(),
      labels: labels,
      values: values,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    'labels': labels,
    'values': values,
  };

  final ChatChartType type;
  final String title;
  final List<String> labels;
  final List<double> values;
}

class ChatInsight {
  const ChatInsight({required this.title, required this.detail});

  factory ChatInsight.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final detail = json['detail'];
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Invalid insight title');
    }
    if (detail is! String || detail.trim().isEmpty) {
      throw const FormatException('Invalid insight detail');
    }
    return ChatInsight(title: title.trim(), detail: detail.trim());
  }

  final String title;
  final String detail;
}

class ChatImageAttachment {
  const ChatImageAttachment({
    required this.mimeType,
    this.storagePath,
    this.signedUrl,
    this.bytes,
  });

  final String mimeType;
  final String? storagePath;
  final String? signedUrl;
  final Uint8List? bytes;
}

class PendingChatImage {
  const PendingChatImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class ChatModel {
  const ChatModel({
    required this.id,
    required this.message,
    required this.role,
    required this.createdAt,
    this.insight,
    this.chart,
    this.image,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    return ChatModel(
      id: json['id'] as String,
      message: json['message'] as String,
      role: role == 'assistant' ? ChatRole.assistant : ChatRole.user,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      insight: json['insight'] is Map
          ? ChatInsight.fromJson(
              Map<String, dynamic>.from(json['insight'] as Map),
            )
          : null,
      chart: json['chart'] is Map
          ? ChatChart.fromJson(Map<String, dynamic>.from(json['chart'] as Map))
          : null,
      image: json['image_path'] is String
          ? ChatImageAttachment(
              storagePath: json['image_path'] as String,
              mimeType: json['image_mime_type'] as String? ?? 'image/jpeg',
              signedUrl: json['image_url'] as String?,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    'role': role.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (insight != null)
      'insight': {'title': insight!.title, 'detail': insight!.detail},
    if (chart != null) 'chart': chart!.toJson(),
    if (image?.storagePath != null) 'image_path': image!.storagePath,
    if (image?.storagePath != null) 'image_mime_type': image!.mimeType,
  };

  Map<String, String> toPromptJson() => {'role': role.name, 'message': message};

  final String id;
  final String message;
  final ChatRole role;
  final DateTime createdAt;
  final ChatInsight? insight;
  final ChatChart? chart;
  final ChatImageAttachment? image;

  bool get isUser => role == ChatRole.user;

  ChatModel copyWithImage(ChatImageAttachment attachment) => ChatModel(
    id: id,
    message: message,
    role: role,
    createdAt: createdAt,
    insight: insight,
    chart: chart,
    image: attachment,
  );
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New conversation',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
}
