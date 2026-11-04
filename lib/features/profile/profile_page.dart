import 'package:flutter/material.dart';

import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../theme/app_theme.dart';
import '../pieces/piece_detail_page.dart';

/// 我的：学习进度、收藏与项目说明。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, int> _progress = {};
  List<GuqinPiece> _favorites = [];

  /// 进度维度定义：键 → 展示名
  static const _dimensions = <String, String>{
    'piece_views': '琴曲研读',
    'notation_views': '减字谱',
    'fingering_views': '指法动画',
    'model_views': '三维展示',
    'assist_views': '演奏辅助',
    'visualize_views': '琴音可视化',
    'realm_views': '数字琴境',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await AppDatabase.instance.allProgress();
    final ids = await AppDatabase.instance.favoriteIds('piece');
    final favs = <GuqinPiece>[];
    for (final id in ids) {
      final piece = await AppDatabase.instance.findPiece(id);
      if (piece != null) favs.add(piece);
    }
    if (mounted) {
      setState(() {
        _progress = p;
        _favorites = favs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalViews = _progress.values.fold<int>(0, (a, b) => a + b);
    final maxDim = _dimensions.keys
        .map((k) => _progress[k] ?? 0)
        .fold<int>(1, (a, b) => b > a ? b : a);

    // 减字识认：以前缀 sym_ 记下的已识减字。
    final symTotal = SeedData.symbols.length;
    final symLearned = _progress.keys
        .where((k) => k.startsWith('sym_') && (_progress[k] ?? 0) > 0)
        .length;

    return InkScaffold(
      backgroundImageAsset: 'assets/images/qin_hero_mist.jpg',
      appBar: AppBar(title: const Text('我的')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.cinnabar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // 头部
            PaperCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Seal('琴', size: 52),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('弦上知音 · 习琴者',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      Text('累计学习轨迹 $totalViews 次',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionTitle(title: '学习进度', subtitle: '各功能使用轨迹'),
            PaperCard(
              child: Column(
                children: _dimensions.entries.map((e) {
                  final v = _progress[e.key] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(e.value,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.inkSoft)),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: v / maxDim,
                            minHeight: 6,
                            backgroundColor: AppColors.line,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.cinnabar),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 30,
                          child: Text('$v',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            // 减字识认：与识谱页进度条同一数据源（键前缀 sym_）
            PaperCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 84,
                    child: Text('减字识认',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.inkSoft)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: symTotal == 0 ? 0 : symLearned / symTotal,
                      minHeight: 6,
                      backgroundColor: AppColors.line,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.jade),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    child: Text('$symLearned',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionTitle(title: '我的收藏', subtitle: '${_favorites.length} 首琴曲'),
            if (_favorites.isEmpty)
              const PaperCard(
                child: Text('暂无收藏。在「琴曲资料库」中点击书签图标即可收藏。',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              )
            else
              ..._favorites.map(
                (p) => PaperCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PieceDetailPage(pieceId: p.id!)),
                    );
                    _load();
                  },
                  child: Row(
                    children: [
                      Text(p.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                      const SizedBox(width: 10),
                      TagChip(p.difficulty),
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.inkSoft),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
