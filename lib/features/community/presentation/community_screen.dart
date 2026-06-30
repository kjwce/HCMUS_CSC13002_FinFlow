import 'package:flutter/material.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            AppStrings.community,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          const _PostCard(
            title: 'Anonymous student',
            body:
                'I saved 500k this week by cooking at home. Any simple meal plans?',
            reaction: 'Support',
          ),
          const _PostCard(
            title: 'Young professional',
            body: 'How do you track subscriptions before they renew?',
            reaction: 'Encourage',
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.title,
    required this.body,
    required this.reaction,
  });

  final String title;
  final String body;
  final String reaction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 12),
            Chip(
              avatar: const Icon(Icons.volunteer_activism, size: 18),
              label: Text(reaction),
              backgroundColor: AppColors.mint,
              side: BorderSide.none,
            ),
          ],
        ),
      ),
    );
  }
}
