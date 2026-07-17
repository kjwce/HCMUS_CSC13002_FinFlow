import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/notification_bell.dart';

// =============================================================================
// AI SCREEN — enhanced from roadmap placeholder
// =============================================================================

class AiScreen extends ConsumerWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(Responsive.w(context, 20)),
        children: [
          // Header row: title + bell
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Assistant',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: Responsive.sp(context, 20),
                      color: const Color(0xFF093030),
                    ),
              ),
              const NotificationBell(),
            ],
          ),
          SizedBox(height: Responsive.h(context, 20)),
          _RoadmapItem(
            icon: Icons.auto_awesome,
            title: AppStrings.naturalInput,
            subtitle: AppStrings.naturalInputDesc,
          ),
          _RoadmapItem(
            icon: Icons.document_scanner,
            title: AppStrings.receiptScanning,
            subtitle: AppStrings.receiptScanningDesc,
          ),
          _RoadmapItem(
            icon: Icons.psychology,
            title: AppStrings.aiCoach,
            subtitle: AppStrings.aiCoachDesc,
          ),
          _RoadmapItem(
            icon: Icons.chat,
            title: AppStrings.chatAssistant,
            subtitle: AppStrings.chatAssistantDesc,
          ),
          SizedBox(height: Responsive.h(context, 20)),
          // Coming-soon note
          Container(
            padding: EdgeInsets.all(Responsive.w(context, 16)),
            decoration: BoxDecoration(
              color: const Color(0xFFD4F4E4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF44BF99),
                  size: 24,
                ),
                SizedBox(width: Responsive.w(context, 12)),
                Expanded(
                  child: Text(
                    'More features coming soon!',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: Responsive.sp(context, 14),
                      color: const Color(0xFF002117),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature item widget
// ---------------------------------------------------------------------------

class _RoadmapItem extends StatelessWidget {
  const _RoadmapItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: Responsive.h(context, 12)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.emerald),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
