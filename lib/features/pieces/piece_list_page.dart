import 'package:flutter/material.dart';

import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import 'piece_detail_page.dart';

/// 功能三：琴曲资料库 —— 结构化琴曲元数据检索。
class PieceListPage extends StatefulWidget {
  const PieceListPage({super.key});

  @override
  State<PieceListPage> createState() => _PieceListPageState();
}

class _PieceListPageState extends State<PieceListPage> {
  static const _difficulties = ['全部', '入门', '进阶', '精研'];

  String _difficulty = '全部';
  String _keyword = '';
  Set<int> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await AppDatabase.instance.favoriteIds('piece');
    if (mounted) setState(() => _favorites = favs);
  }

  Future<void> _toggleFav(int id) async {
    final now = await AppDatabase.instance.toggleFavorite('piece', id);
    if (!mounted) return;
    setState(() {
      if (now) {
        _favorites = {..._favorites, id};
      } else {
        _favorites = {..._favorites}..remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkScaffold(
      appBar: AppBar(title: const Text('琴曲资料库')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _keyword = v),
              decoration: InputDecoration(
                hintText: '检索曲名、传谱、标签…',
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
              itemCount: _difficulties.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = _difficulties[i];
                final selected = d == _difficulty;
                return ChoiceChip(
                  label: Text(d),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _difficulty = d),
                  labelStyle: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : AppColors.inkSoft),
                  selectedColor: AppColors.cinnabar,
                  backgroundColor: AppColors.paperLight,
                  side: const BorderSide(color: AppColors.line),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FutureBuilder<List<GuqinPiece>>(
              future: AppDatabase.instance
                  .queryPieces(keyword: _keyword, difficulty: _difficulty),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return const Center(
                    child: Text('未找到相关曲目',
                        style: TextStyle(color: AppColors.inkSoft)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    final fav = _favorites.contains(p.id);
                    return PaperCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PieceDetailPage(pieceId: p.id!)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 88,
                            child: GuqinImage(
                              asset: p.imageAsset,
                              height: 88,
                              icon: Icons.music_note_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(p.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2)),
                                    ),
                                    const SizedBox(width: 8),
                                    TagChip(p.difficulty),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _toggleFav(p.id!),
                                      child: Icon(
                                        fav
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        size: 20,
                                        color: fav
                                            ? AppColors.cinnabar
                                            : AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(p.intro,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.7,
                                        color: AppColors.inkSoft)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text('${p.dynasty} · ${p.author}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.inkSoft)),
                                    ),
                                    const SizedBox(width: 8),
                                    ...p.tags.take(2).map((t) => Padding(
                                          padding:
                                              const EdgeInsets.only(left: 6),
                                          child:
                                              TagChip(t, color: AppColors.gold),
                                        )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
