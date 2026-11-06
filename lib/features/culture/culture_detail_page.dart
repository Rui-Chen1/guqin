import 'package:flutter/material.dart';

import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';

/// 文化资料详情页。
class CultureDetailPage extends StatelessWidget {
  final CultureArticle article;
  const CultureDetailPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return InkScaffold(
      appBar: AppBar(title: const Text('文化资料')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GuqinImage(
              asset: article.imageAsset,
              height: 180,
              icon: Icons.auto_stories_outlined),
          const SizedBox(height: 16),
          Row(children: [TagChip(article.category, color: AppColors.cinnabar)]),
          const SizedBox(height: 10),
          Text(article.title,
              style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              border: const Border(
                  left: BorderSide(color: AppColors.gold, width: 3)),
            ),
            child: Text(article.summary,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.9, color: AppColors.inkSoft)),
          ),
          const SizedBox(height: 16),
          Text(article.content,
              style: const TextStyle(
                  fontSize: 14, height: 2.0, color: AppColors.ink)),
          const SizedBox(height: 24),
          const Center(
            child: Text('— 弦上知音 · 古琴文化资料库 —',
                style: TextStyle(
                    fontSize: 11, color: AppColors.inkSoft, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}
