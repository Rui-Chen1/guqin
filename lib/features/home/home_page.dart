import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../common/features.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../pieces/piece_detail_page.dart';

/// 首页：以水墨山水图为底，配山水轮播、功能列表与每日一曲。
///
/// 背景图固定在页面后方，令人在展卷临琴之境中浏览。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();
  final PageController _heroPage = PageController();
  int _heroIndex = 0;
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _startHeroRotation();
  }

  void _startHeroRotation() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_heroPage.hasClients) return;
      final next = (_heroPage.page?.round() ?? _heroIndex) + 1;
      _heroPage.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onHeroPageChanged(int index) {
    setState(() => _heroIndex = index);
    _startHeroRotation();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _scroll.dispose();
    _heroPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.32,
                child: Image.asset(
                  'assets/images/qin_hero_mist.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            // 书卷气：正文统一走宋体/楷体一系（缺失时回退系统衬线）
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontFamily: 'Songti SC',
                fontFamilyFallback: [
                  'STSong',
                  'Kaiti SC',
                  'Noto Serif CJK SC',
                  'Noto Serif SC',
                  'serif',
                ],
                color: AppColors.ink,
              ),
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    alignment: Alignment.topCenter,
                    child: _ScrollHero(
                      controller: _heroPage,
                      index: _heroIndex,
                      onPageChanged: _onHeroPageChanged,
                    ),
                  ),
                  const _HomeIntroduction(),
                  const SizedBox(height: 24),
                  const _FeatureSection(
                    title: '琴道',
                    subtitle: '入门次第',
                    features: kLearningFeatures,
                    numerals: ['壹', '贰', '叁', '肆'],
                  ),
                  const SizedBox(height: 24),
                  const _FeatureSection(
                    title: '琴境',
                    subtitle: '沉浸体验',
                    features: kExperienceFeatures,
                    numerals: ['伍', '陆', '柒', '捌'],
                  ),
                  const SizedBox(height: 24),
                  const _ChapterTitle(title: '每日一曲', subtitle: '弦上知音'),
                  const SizedBox(height: 14),
                  const _FeaturedPiece(),
                  const SizedBox(height: 30),
                  const _HomeFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 题画诗字体：楷体，最见笔意。
const TextStyle _poemStyle = TextStyle(
  fontFamily: 'Kaiti SC',
  fontFamilyFallback: ['STKaiti', 'Kaiti TC', 'Noto Serif CJK SC', 'serif'],
  color: Color(0xFFF7F0DE),
  fontSize: 15,
  height: 1.15,
  shadows: [
    Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1))
  ],
);

// ---------------------------------------------------------------- 题签

/// 顶部题签：朱砂印 + 竖排短句。
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Seal('琴', size: 46),
        _VerticalMotto('山居听泉'),
      ],
    );
  }
}

/// 朱砂印：方框双线，字居中（多字则竖排）。
class _Seal extends StatelessWidget {
  const _Seal(this.text, {this.size = 44});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    final inner = chars.length > 1 ? size * 0.32 : size * 0.44;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cinnabar,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
              color: AppColors.cinnabar.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in chars)
                Text(c,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: inner,
                        height: 1.05,
                        fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 竖排签条，用于右上角落款。
class _VerticalMotto extends StatelessWidget {
  const _VerticalMotto(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in text.split(''))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Text(c,
                  style: const TextStyle(
                      fontSize: 10, height: 1.0, color: AppColors.jade)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 画卷

/// 首页山水轮播。
class _ScrollHero extends StatelessWidget {
  const _ScrollHero({
    required this.controller,
    required this.index,
    required this.onPageChanged,
  });

  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;

  static const _slides = [
    ('assets/images/qin_hero_guqin.jpg', ['一弦一世界', '高山流水间'], 0.75),
    ('assets/images/ink_qin_pavilion.jpg', ['竹深留客处', '琴静见初心'], 0.563),
    ('assets/images/ink_waterfall_autumn.jpg', ['空山新雨后', '天气晚来秋'], 0.753),
    ('assets/images/ink_moon_river.jpg', ['春江潮水连海平', '海上明月共潮生'], 0.753),
    ('assets/images/ink_river_distant.jpg', ['山色有无中', '烟波浩渺间'], 2.0),
    ('assets/images/ink_river_forest.jpg', ['青山隐隐水迢迢', '秋尽江南草未凋'], 2.0),
    ('assets/images/ink_river_island.jpg', ['山随平野尽', '江入大荒流'], 2.0),
    ('assets/images/ink_bamboo_pavilion.jpg', ['竹深留客处', '荷净纳凉时'], 0.751),
    ('assets/images/ink_cliff_waterfall.jpg', ['飞流直下三千尺', '疑是银河落九天'], 0.574),
    ('assets/images/ink_plum_moon.jpg', ['疏影横斜水清浅', '暗香浮动月黄昏'], 0.753),
    ('assets/images/ink_river_village.jpg', ['白云生远岫', '流水绕孤村'], 2.0),
    ('assets/images/qin_hero_scroll.jpg', ['展卷临琴', '静听松风寒'], 0.75),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width - 16;
    final height = math.min(width * 1.4, size.height * 0.64);
    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: controller,
        onPageChanged: (page) => onPageChanged(page % _slides.length),
        itemBuilder: (context, index) {
          final slide = _slides[index % _slides.length];
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppColors.paper,
                child: Image.asset(
                  slide.$1,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const _PaperFallback(),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 44,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: AppColors.paperLight.withValues(alpha: 0.84),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PoemColumn(lines: slide.$2),
                      const SizedBox(width: 14),
                      const _Seal('知音', size: 28),
                    ],
                  ),
                ),
              ),
              _HeroPager(index: index % _slides.length),
            ],
          );
        },
      ),
    );
  }
}

class _HeroPager extends StatelessWidget {
  const _HeroPager({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 14,
      child: Row(
        children: [
          for (var i = 0; i < _ScrollHero._slides.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: i == index ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: i == index
                    ? AppColors.cinnabar
                    : AppColors.inkSoft.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          const Spacer(),
          const Text(
            '展卷临琴',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.inkSoft,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeIntroduction extends StatelessWidget {
  const _HomeIntroduction();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('弦上知音',
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8)),
                SizedBox(height: 4),
                Text('一弦一世界 · 高山流水',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                        letterSpacing: 2)),
              ],
            ),
          ),
          _VerticalMotto('非遗'),
        ],
      ),
    );
  }
}

/// 竖排诗句：右起为第一句。
class _PoemColumn extends StatelessWidget {
  const _PoemColumn({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = lines.length - 1; i >= 0; i--) ...[
          _line(lines[i]),
          if (i > 0) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _line(String line) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in line.split(''))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(c, style: _poemStyle),
          ),
      ],
    );
  }
}

/// 缺图回退：水墨渐变。
class _PaperFallback extends StatelessWidget {
  const _PaperFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFE6D4), Color(0xFFDDCEB3), Color(0xFFC8B694)],
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note,
            size: 28, color: AppColors.inkSoft.withValues(alpha: 0.4)),
      ),
    );
  }
}

// ---------------------------------------------------------------- 章节

/// 章节题头：朱砂点 + 标题 + 细金线 + 小注。
class _ChapterTitle extends StatelessWidget {
  const _ChapterTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 6, height: 6, color: AppColors.cinnabar),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3)),
          const SizedBox(width: 12),
          Expanded(
              child: Container(
                  height: 1, color: AppColors.gold.withValues(alpha: 0.35))),
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.inkSoft,
                    letterSpacing: 1.5)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 功能

class _FeatureSection extends StatelessWidget {
  const _FeatureSection({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.numerals,
  });

  final String title;
  final String subtitle;
  final List<AppFeature> features;
  final List<String> numerals;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChapterTitle(title: title, subtitle: subtitle),
        for (var i = 0; i < features.length; i++)
          _FeatureRow(
            feature: features[i],
            numeral: i < numerals.length ? numerals[i] : '${i + 1}',
          ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature, required this.numeral});

  final AppFeature feature;
  final String numeral;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: feature.builder)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: AppColors.gold.withValues(alpha: 0.18))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(numeral,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                        letterSpacing: 2)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(feature.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2)),
                    const SizedBox(height: 5),
                    Text(feature.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                            letterSpacing: 0.7)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward,
                  size: 18, color: AppColors.cinnabarSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通用册页面板：方角双线框，替代圆角卡片。
class _ScrollPanel extends StatelessWidget {
  const _ScrollPanel({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paperLight.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
              color: Color(0x142B2620), blurRadius: 14, offset: Offset(0, 6))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _SealTag extends StatelessWidget {
  const _SealTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.jade.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10, color: AppColors.jade, letterSpacing: 1)),
    );
  }
}

class _DotDivider extends StatelessWidget {
  const _DotDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 9,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: AppColors.gold.withValues(alpha: 0.6),
      );
}

String _fmtDuration(int sec) =>
    '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

// ---------------------------------------------------------------- 今日一曲

class _FeaturedPiece extends StatelessWidget {
  const _FeaturedPiece();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GuqinPiece>>(
      future: AppDatabase.instance.queryPieces(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const _ScrollPanel(child: Text('资料库加载中…'));
        }
        // 「今日」取当日序号对应曲目，保证每日不同。
        final list = snap.data!;
        final piece = list[DateTime.now().day % list.length];
        return _ScrollPanel(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PieceDetailPage(pieceId: piece.id!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _Seal('曲', size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(piece.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3)),
                  ),
                  _SealTag(piece.difficulty),
                ],
              ),
              const SizedBox(height: 11),
              Text(piece.intro,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, height: 1.75, color: AppColors.inkSoft)),
              const SizedBox(height: 11),
              Container(height: 1, color: AppColors.line),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text(piece.dynasty,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.inkSoft,
                          letterSpacing: 1)),
                  const _DotDivider(),
                  Text('时长 ${_fmtDuration(piece.durationSec)}',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.inkSoft)),
                  const _DotDivider(),
                  Expanded(
                    child: Text(piece.mode,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.inkSoft)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 1, color: AppColors.gold.withValues(alpha: 0.45)),
        const SizedBox(height: 22),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Seal('知音', size: 30),
            SizedBox(width: 14),
            Text('高山流水 · 一弦一世界',
                style: TextStyle(
                    fontSize: 13, color: AppColors.inkSoft, letterSpacing: 2)),
          ],
        ),
      ],
    );
  }
}
