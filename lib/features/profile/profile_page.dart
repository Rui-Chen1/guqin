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

  /// 切到「我的」标签时由根容器调用，刷新收藏与进度。
  static void reload() => _ProfilePageState._reloader?.call();

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, int> _progress = {};
  List<GuqinPiece> _favorites = [];

  /// 供外部（切到「我的」标签时）触发刷新。
  static void Function()? _reloader;

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
    _reloader = _load;
    _load();
  }

  @override
  void dispose() {
    _reloader = null;
    super.dispose();
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

    // 琴人手账：9 枚印章，朱砂 / 泥金 / 石青 / 松烟四色轮替
    final badges = <(String, String, Color, bool)>[
      ('琴', '初临琴境', AppColors.cinnabar, (_progress['realm_views'] ?? 0) >= 1),
      ('拨', '拨弦成声', AppColors.gold, (_progress['model_views'] ?? 0) >= 1),
      ('谱', '识谱初探', AppColors.jade, (_progress['notation_views'] ?? 0) >= 1),
      ('曲', '琴曲开卷', AppColors.ink, (_progress['piece_views'] ?? 0) >= 1),
      (
        '指',
        '指法初成',
        AppColors.cinnabar,
        (_progress['fingering_views'] ?? 0) >= 1
      ),
      ('引', '琴引成', AppColors.gold, (_progress['realm_guide_done'] ?? 0) >= 1),
      ('境', '数字琴境', AppColors.jade, (_progress['realm_views'] ?? 0) >= 3),
      ('藏', '琴曲收藏', AppColors.ink, _favorites.isNotEmpty),
      ('友', '七弦老友', AppColors.cinnabar, totalViews >= 10),
    ];
    final unlockedCount = badges.where((b) => b.$4).length;

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
            SectionTitle(
                title: '琴人手账',
                subtitle: '$unlockedCount / ${badges.length} 枚印章'),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  for (final b in badges)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: b.$4 ? b.$3 : Colors.transparent,
                            border: Border.all(
                                color: b.$4 ? b.$3 : AppColors.line,
                                width: 1.4),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: b.$4
                                ? [
                                    BoxShadow(
                                        color: b.$3.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ]
                                : null,
                          ),
                          child: Text(b.$1,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      b.$4 ? Colors.white : AppColors.inkSoft)),
                        ),
                        const SizedBox(height: 6),
                        Text(b.$2,
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    b.$4 ? AppColors.ink : AppColors.inkSoft)),
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
