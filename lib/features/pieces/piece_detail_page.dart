import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../theme/app_theme.dart';
import '../fingering/fingering_page.dart';
import '../model3d/model_page.dart';
import '../notation/notation_page.dart';
import '../notation/notation_svg.dart';
import '../visualize/visualize_page.dart';

/// 琴曲详情：元数据 + 背景典故 + 谱面示意 + 试听示意。
class PieceDetailPage extends StatefulWidget {
  final int pieceId;
  const PieceDetailPage({super.key, required this.pieceId});

  @override
  State<PieceDetailPage> createState() => _PieceDetailPageState();
}

class _PieceDetailPageState extends State<PieceDetailPage> {
  GuqinPiece? _piece;

  @override
  void initState() {
    super.initState();
    _load();
    AppDatabase.instance.bumpProgress('piece_views');
  }

  Future<void> _load() async {
    final p = await AppDatabase.instance.findPiece(widget.pieceId);
    if (mounted) setState(() => _piece = p);
  }

  @override
  Widget build(BuildContext context) {
    final p = _piece;
    if (p == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final width = MediaQuery.of(context).size.width;
    final isWide = width > 800;

    if (isWide) {
      return InkScaffold(
        appBar: AppBar(title: Text(p.title)),
        body: Row(
          children: [
            // 左侧：主要信息与试听
            Expanded(
              flex: 5,
              child: _IntroTab(piece: p),
            ),
            const VerticalDivider(width: 1, color: AppColors.line),
            // 右侧：背景与谱面
            Expanded(
              flex: 4,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: AppColors.cinnabar,
                      unselectedLabelColor: AppColors.inkSoft,
                      indicatorColor: AppColors.cinnabar,
                      tabs: [
                        Tab(text: '背景典故'),
                        Tab(text: '谱面示意'),
                        Tab(text: '配套学习')
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _BackgroundTab(piece: p),
                          const _NotationTab(),
                          const _RelatedTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.title),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.cinnabar,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.cinnabar,
            tabs: [
              Tab(text: '简介'),
              Tab(text: '背景典故'),
              Tab(text: '谱面示意'),
              Tab(text: '相关')
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _IntroTab(piece: p),
            _BackgroundTab(piece: p),
            const _NotationTab(),
            const _RelatedTab(),
          ],
        ),
      ),
    );
  }
}

class _IntroTab extends StatelessWidget {
  final GuqinPiece piece;
  const _IntroTab({required this.piece});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        GuqinImage(asset: piece.imageAsset, height: 150),
        const SizedBox(height: 16),
        _PlayerBar(piece: piece),
        const SizedBox(height: 18),
        const SectionTitle(title: '曲目信息'),
        PaperCard(
          child: Column(
            children: [
              _row('朝代', piece.dynasty),
              _divider(),
              _row('传谱 / 作者', piece.author),
              _divider(),
              _row('宫调 / 定弦', piece.mode),
              _divider(),
              _row('难度', piece.difficulty),
              _divider(),
              _row('参考时长', _fmt(piece.durationSec)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle(title: '曲意简介'),
        Text(piece.intro,
            style: const TextStyle(
                fontSize: 13.5, height: 1.9, color: AppColors.ink)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              piece.tags.map((t) => TagChip(t, color: AppColors.gold)).toList(),
        ),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.inkSoft)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _divider() => const Divider(height: 1, color: AppColors.line);

  static String _fmt(int sec) =>
      '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
}

class _BackgroundTab extends StatelessWidget {
  final GuqinPiece piece;
  const _BackgroundTab({required this.piece});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const SectionTitle(title: '典故与背景', subtitle: '知其然，更知其所以然'),
        PaperCard(
          child: Text(piece.background,
              style: const TextStyle(
                  fontSize: 14, height: 2.0, color: AppColors.ink)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.jade.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: AppColors.jade),
              SizedBox(width: 8),
              Expanded(
                child: Text('听琴小贴士：先了解曲目背景，再对照减字谱聆听，更容易把握曲情与气韵。',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.8, color: AppColors.inkSoft)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotationTab extends StatelessWidget {
  const _NotationTab();

  @override
  Widget build(BuildContext context) {
    final sample = SeedData.symbols.take(6).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const SectionTitle(title: '开篇谱面示意', subtitle: '减字谱 SVG 矢量渲染'),
        const Text('下图为该曲开篇常用减字（示意片段）。点击任一符号即可拆解四要素。',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: sample.map((s) {
            return Column(
              children: [
                NotationGlyph(
                  leftHand: s.leftHand,
                  leftTech: s.leftTech,
                  hui: s.hui,
                  rightHand: s.rightHand,
                  stringNum: s.stringNum,
                  size: 72,
                  onTap: () => _showNotationMeaning(context, s),
                ),
                const SizedBox(height: 6),
                Text(s.reading, style: const TextStyle(fontSize: 11)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showNotationMeaning(BuildContext context, NotationSymbol symbol) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NotationGlyph(
                  leftHand: symbol.leftHand,
                  leftTech: symbol.leftTech,
                  hui: symbol.hui,
                  rightHand: symbol.rightHand,
                  stringNum: symbol.stringNum,
                  size: 88,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('读作「${symbol.reading}」',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    TagChip('左手指法：${symbol.leftHand}'),
                    const SizedBox(height: 6),
                    TagChip('徽位：${symbol.hui}', color: AppColors.cinnabar),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text('符号拆解',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TagChip('上左 · 左手指法「${symbol.leftHand}」'),
                TagChip('上右 · 徽位「${symbol.hui}」', color: AppColors.cinnabar),
                TagChip('下左 · 右手指法「${symbol.rightHand}」',
                    color: AppColors.jade),
                TagChip('下右 · 弦序「${symbol.stringNum}」',
                    color: AppColors.cinnabar),
              ],
            ),
            const SizedBox(height: 16),
            const Text('释义',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(symbol.meaning,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.8, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

class _RelatedTab extends StatelessWidget {
  const _RelatedTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const SectionTitle(title: '配套学习', subtitle: '建议按顺序体验'),
        _link(context, Icons.grid_on_outlined, '减字谱学习', '识读本曲谱面符号',
            AppColors.gold, (_) => const NotationPage()),
        const SizedBox(height: 10),
        _link(context, Icons.pan_tool_alt_outlined, '指法动画教学', '练习曲中所用指法',
            const Color(0xFF7A6BA8), (_) => const FingeringPage()),
        const SizedBox(height: 10),
        _link(context, Icons.view_in_ar_outlined, '古琴三维展示', '多角度观察琴身结构',
            AppColors.jade, (_) => const ModelPage()),
        const SizedBox(height: 10),
        _link(context, Icons.graphic_eq_outlined, '琴音可视化', '观察散 / 按 / 泛音波形',
            const Color(0xFF3C7EA8), (_) => const VisualizePage()),
      ],
    );
  }

  Widget _link(BuildContext context, IconData icon, String title, String sub,
      Color color, WidgetBuilder builder) {
    return PaperCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: builder)),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(icon, color: color.withValues(alpha: 0.75), size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 20),
        ],
      ),
    );
  }
}

/// 试听条：播放本地琴曲音频（离线资源）。
class _PlayerBar extends StatefulWidget {
  final GuqinPiece piece;
  const _PlayerBar({required this.piece});

  @override
  State<_PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<_PlayerBar> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  /// 音源预加载进度：播放前必须等它完成，否则 resume 会因播放器尚无音源而无声。
  late final Future<void> _prepare;

  Duration _total = Duration.zero;
  Duration _pos = Duration.zero;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _prepare = _init();
  }

  Future<void> _init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      _subs.add(_player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _total = d);
      }));
      _subs.add(_player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _pos = p);
      }));
      _subs.add(_player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _playing = s == PlayerState.playing);
      }));

      // 显式指定从 assets 加载
      final source = AssetSource(widget.piece.audioSource);
      await _player.setSource(source);
    } catch (e) {
      debugPrint('Audio Init Error: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_failed) return;
    await _prepare; // 等音源就绪，避免"看似在播放但没有声音"
    if (!mounted || _failed) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _seekTo(double ratio) async {
    if (_failed || _total.inMilliseconds == 0) return;
    final target = _total * ratio.clamp(0.0, 1.0);
    await _player.seek(target);
    if (mounted) setState(() => _pos = target);
  }

  @override
  Widget build(BuildContext context) {
    final totalSec =
        _total.inSeconds > 0 ? _total.inSeconds : widget.piece.durationSec;
    final progress = _total.inMilliseconds > 0
        ? (_pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PaperCard(
          child: Row(
            children: [
              IconButton.filled(
                onPressed: _failed ? null : _toggle,
                style:
                    IconButton.styleFrom(backgroundColor: AppColors.cinnabar),
                icon: Icon(
                    _failed
                        ? Icons.volume_off_outlined
                        : (_playing ? Icons.pause : Icons.play_arrow),
                    color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _seekTo(box.maxWidth == 0
                            ? 0
                            : d.localPosition.dx / box.maxWidth),
                        child: SizedBox(
                          height: 34,
                          child: CustomPaint(
                            painter: _WavePainter(progress: progress),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(_fmt(_pos.inSeconds),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.inkSoft)),
                        const Spacer(),
                        Text(_failed ? '音频资源缺失' : '真人演奏',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.inkSoft)),
                        const Spacer(),
                        Text(_fmt(totalSec),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.inkSoft)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.piece.audioCredit,
          style: const TextStyle(
              fontSize: 10, color: AppColors.inkSoft, height: 1.4),
        ),
      ],
    );
  }

  static String _fmt(int sec) =>
      '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
}

class _WavePainter extends CustomPainter {
  final double progress;
  _WavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final playedX = size.width * progress;
    for (double x = 0; x < size.width; x += 2.5) {
      final n = x / size.width;
      final amp = (math.sin(n * 34) * 0.5 +
          math.sin(n * 91) * 0.3 +
          math.sin(n * 7) * 0.2);
      final hh = (size.height * 0.42) * amp.abs();
      final paint = Paint()
        ..color = x <= playedX
            ? AppColors.cinnabar
            : AppColors.inkSoft.withValues(alpha: 0.3)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, mid - hh), Offset(x, mid + hh), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.progress != progress;
}
