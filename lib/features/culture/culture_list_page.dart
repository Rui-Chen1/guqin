import 'package:flutter/material.dart';

import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import 'culture_detail_page.dart';
import 'daily_card.dart';

/// 功能一：古琴文化资料库 —— 分类浏览与检索。
class CultureListPage extends StatefulWidget {
  const CultureListPage({super.key});

  @override
  State<CultureListPage> createState() => _CultureListPageState();
}

class _CultureListPageState extends State<CultureListPage> {
  String _category = '全部';
  String _keyword = '';
  List<String> _categories = const ['全部'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await AppDatabase.instance.articleCategories();
    if (mounted) setState(() => _categories = ['全部', ...cats]);
  }

  @override
  Widget build(BuildContext context) {
    return InkScaffold(
      appBar: AppBar(title: const Text('古琴文化资料库')),
      body: Column(
        children: [
          const DailySignCard(),
          const ColdFactCapsule(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _keyword = v),
              decoration: InputDecoration(
                hintText: '检索历史、形制、琴派、工艺…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: AppColors.paperLight,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(3),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(3),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = _categories[i];
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : AppColors.inkSoft,
                  ),
                  selectedColor: AppColors.cinnabar,
                  backgroundColor: AppColors.paperLight,
                  side: const BorderSide(color: AppColors.line),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<CultureArticle>>(
              future: AppDatabase.instance
                  .queryArticles(category: _category, keyword: _keyword),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return const Center(
                    child: Text('未找到相关资料',
                        style: TextStyle(color: AppColors.inkSoft)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ArticleCard(article: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final CultureArticle article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CultureDetailPage(article: article)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: GuqinImage(
                asset: article.imageAsset,
                height: 92,
                icon: Icons.auto_stories_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TagChip(article.category, color: AppColors.cinnabar),
                  ],
                ),
                const SizedBox(height: 6),
                Text(article.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(article.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, height: 1.6, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
