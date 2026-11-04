import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../common/guqin_sound.dart';
import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../theme/app_theme.dart';
import '../model3d/model_page.dart';
import '../fingering/fingering_page.dart';
import 'notation_svg.dart';

/// 功能四：减字谱学习 —— SVG 矢量谱面，符号点击即释义；
/// 并提供「拼字练习」帮助理解减字的构字规律。
class NotationPage extends StatefulWidget {
  const NotationPage({super.key});

  @override
  State<NotationPage> createState() => _NotationPageState();
}

class _NotationPageState extends State<NotationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.bumpProgress('notation_views');
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkScaffold(
      appBar: AppBar(
        title: const Text('减字谱学习'),
        actions: [
          IconButton(
            tooltip: '玩法说明',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('减字谱拼字'),
                content: const Text('根据题目，将下方的减字部件拖入对应宫格。四个部件全部正确即可通关。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.cinnabar,
          unselectedLabelColor: AppColors.inkSoft,
          indicatorColor: AppColors.cinnabar,
          tabs: const [Tab(text: '识谱'), Tab(text: '拼字')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_ReadTab(), _ComposeTab()],
      ),
    );
  }
}

class _ReadTab extends StatefulWidget {
  const _ReadTab();

  @override
  State<_ReadTab> createState() => _ReadTabState();
}

class _ReadTabState extends State<_ReadTab> {
  static final _symbols = SeedData.symbols.take(8).toList();
  final Set<String> _recognized = {};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        PaperCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('减字认识',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  Text('${_recognized.length} / ${_symbols.length}',
                      style: const TextStyle(
                          color: AppColors.jade,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '何为减字',
                    onPressed: _showIntroduction,
                    icon: const Icon(Icons.help_outline,
                        size: 18, color: AppColors.inkSoft),
                  ),
                  const Text('何为减字',
                      style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _recognized.length / _symbols.length,
                  minHeight: 5,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.22),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.jade),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '点开一个减字，看它如何拆成四笔 —— 展开即算「已识」。',
                style: TextStyle(
                    fontSize: 11.5, height: 1.5, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle(title: '常用减字', subtitle: '点击拆解'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _symbols.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, i) {
            final symbol = _symbols[i];
            final cellWidth = (MediaQuery.sizeOf(context).width - 52) / 3;
            final glyphSize = math.min(80.0, cellWidth - 18);
            return _ReadGlyphTile(
              symbol: symbol,
              size: glyphSize,
              recognized: _recognized.contains(symbol.reading),
              onTap: () => _showMeaning(context, symbol),
            );
          },
        ),
      ],
    );
  }

  void _showIntroduction() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('何为减字'),
        content: const Text(
          '减字谱是古琴专用记谱法，将汉字笔画拆取组合成一个符号，记录左手指法、徽位、右手指法与弦序。点开下方减字，可逐项查看它的构成与琴面位置。',
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showMeaning(BuildContext context, NotationSymbol s) {
    setState(() => _recognized.add(s.reading));
    final hui = _numberFromChinese(s.hui);
    final stringNumber = _numberFromChinese(s.stringNum);
    final soundKind = s.meaning.contains('泛音')
        ? 'harm'
        : s.meaning.contains('散音')
            ? 'open'
            : 'press';
    final navigator = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.58,
        maxChildSize: 0.96,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('减字拆解',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('读作「${s.reading}」',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.inkSoft)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: NotationGlyph(
                  leftHand: s.leftHand,
                  leftTech: s.leftTech,
                  hui: s.hui,
                  rightHand: s.rightHand,
                  stringNum: s.stringNum,
                  size: math.min(152, MediaQuery.sizeOf(context).width - 80),
                  borderColor: AppColors.gold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TagChip('左手指法：${s.leftHand}${s.leftTech ?? ''}',
                      color: AppColors.jade),
                  TagChip('徽位：${s.hui}', color: AppColors.cinnabar),
                  TagChip('右手：${s.rightHand}', color: AppColors.jade),
                  TagChip('弦序：${s.stringNum}', color: AppColors.cinnabar),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.my_location, size: 18, color: AppColors.cinnabar),
                  SizedBox(width: 8),
                  Text('琴面位置',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  border: Border.all(color: AppColors.line),
                ),
                child: Guqin3DPreview(
                  hui: hui,
                  stringNum: stringNumber,
                  height: 150,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.meaning,
                style: const TextStyle(
                    fontSize: 13, height: 1.8, color: AppColors.ink),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final index = (stringNumber - 1).clamp(0, 6);
                        GuqinSound.instance
                            .play(GuqinSound.file(soundKind, index));
                      },
                      icon: const Icon(Icons.volume_up, size: 18),
                      label: const Text('试听按音'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        navigator.push(
                          MaterialPageRoute<void>(
                            builder: (_) => FingeringPage(initialSymbol: s),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('指法示范'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadGlyphTile extends StatelessWidget {
  const _ReadGlyphTile({
    required this.symbol,
    required this.size,
    required this.recognized,
    required this.onTap,
  });

  final NotationSymbol symbol;
  final double size;
  final bool recognized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            NotationGlyph(
              leftHand: symbol.leftHand,
              leftTech: symbol.leftTech,
              hui: symbol.hui,
              rightHand: symbol.rightHand,
              stringNum: symbol.stringNum,
              size: size,
              onTap: onTap,
              borderColor: recognized ? AppColors.jade : AppColors.line,
              fillColor: recognized
                  ? AppColors.jade.withValues(alpha: 0.82)
                  : AppColors.paperLight,
            ),
            if (recognized)
              Positioned(
                top: -5,
                right: -7,
                child: Transform.rotate(
                  angle: -0.12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.cinnabar,
                      border: Border.all(color: AppColors.paperLight, width: 1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      '已识',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          symbol.reading,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

int _numberFromChinese(String value) {
  const numerals = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
    '十',
    '十一',
    '十二',
    '十三',
  ];
  final index = numerals.indexOf(value);
  return index < 0 ? 0 : index + 1;
}

class _ComposeTab extends StatefulWidget {
  const _ComposeTab();

  @override
  State<_ComposeTab> createState() => _ComposeTabState();
}

class _ComposeTabState extends State<_ComposeTab> {
  static final _levels = SeedData.symbols
      .where((symbol) => symbol.leftTech == null)
      .take(4)
      .toList();
  static const _piecePool = [
    '大',
    '食',
    '中',
    '名',
    '跪',
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
    '十',
    '擘',
    '托',
    '抹',
    '挑',
    '勾',
    '剔',
    '打',
    '摘',
  ];

  final math.Random _random = math.Random();
  final Map<int, _PuzzlePiece> _placed = {};
  late List<_PuzzlePiece> _pieces;
  int _levelIndex = 0;
  bool _levelComplete = false;
  bool _completed = false;
  String? _feedback;

  NotationSymbol get _target => _levels[_levelIndex];
  List<String> get _answers => [
        _target.leftHand,
        _target.hui,
        _target.rightHand,
        _target.stringNum,
      ];

  @override
  void initState() {
    super.initState();
    _pieces = _createPieces();
  }

  List<_PuzzlePiece> _createPieces() {
    final answers = _answers;
    final distractors = _piecePool.toSet().difference(answers.toSet()).toList()
      ..shuffle(_random);
    final values = [...answers, ...distractors.take(2)]..shuffle(_random);
    return [
      for (var i = 0; i < values.length; i++)
        _PuzzlePiece(id: i, value: values[i]),
    ];
  }

  void _resetLevel() {
    setState(() {
      _placed.clear();
      _pieces = _createPieces();
      _feedback = null;
      _levelComplete = false;
      _completed = false;
    });
  }

  void _restart() {
    setState(() {
      _levelIndex = 0;
      _placed.clear();
      _pieces = _createPieces();
      _feedback = null;
      _levelComplete = false;
      _completed = false;
    });
  }

  void _acceptPiece(int quadrant, _PuzzlePiece piece) {
    if (_levelComplete || _completed || _placed.containsKey(quadrant)) return;
    if (piece.value != _answers[quadrant]) {
      setState(() => _feedback = '这个部件不属于该宫格，再试一次。');
      return;
    }

    setState(() {
      _placed[quadrant] = piece;
      _feedback = '正确，继续拼合。';
    });

    if (_placed.length != 4) return;
    setState(() {
      _levelComplete = true;
      _completed = _levelIndex == _levels.length - 1;
      _feedback = _completed ? '四关全部完成，减字拼合成功！' : '拼合成功，看看完整减字。';
    });
  }

  void _nextLevel() {
    if (_completed) {
      _restart();
      return;
    }
    setState(() {
      _levelIndex++;
      _placed.clear();
      _pieces = _createPieces();
      _feedback = null;
      _levelComplete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionTitle(
          title: '拼字练习',
          subtitle: _completed
              ? '四关完成'
              : '第 ${_levelIndex + 1} / ${_levels.length} 关 · 入门',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < _levels.length; i++) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == _levelIndex ? 24 : 30,
                      height: 4,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: i <= _levelIndex
                            ? AppColors.cinnabar
                            : AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: _resetLevel,
              child: const Text('重置'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: AppColors.gold, size: 20),
              const SizedBox(width: 10),
              Text(_completed ? '拼字练习已完成' : '拼出：${_target.reading}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: _PuzzleBoard(
            size: math.min(300, MediaQuery.sizeOf(context).width - 72),
            values: List.generate(4, (index) => _placed[index]?.value ?? ''),
            onAccept: _acceptPiece,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _completed ? '四宫合一，减字拼合完成' : '长按下方部件，拖入对应宫格',
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              _feedback!,
              style: TextStyle(
                fontSize: 12,
                color: _feedback!.startsWith('这个')
                    ? AppColors.cinnabar
                    : AppColors.jade,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final piece in _pieces)
              if (!_placed.values.any((placed) => placed.id == piece.id))
                _DraggablePiece(
                  piece: piece,
                  enabled: !_levelComplete && !_completed,
                ),
          ],
        ),
        if (_levelComplete) ...[
          const SizedBox(height: 20),
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('已拼成',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                NotationGlyph(
                  leftHand: _target.leftHand,
                  leftTech: _target.leftTech,
                  hui: _target.hui,
                  rightHand: _target.rightHand,
                  stringNum: _target.stringNum,
                  size: 96,
                  borderColor: AppColors.jade,
                ),
                const SizedBox(height: 8),
                Text(
                  '「${_target.reading}」',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2),
                ),
                const SizedBox(height: 6),
                Text(
                  _target.meaning,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, height: 1.7, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FingeringPage(),
                        ),
                      ),
                      icon: const Icon(Icons.touch_app_outlined, size: 17),
                      label: const Text('指法示范'),
                    ),
                    FilledButton(
                      onPressed: _nextLevel,
                      child: Text(_completed ? '再练一次' : '下一关'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PuzzlePiece {
  const _PuzzlePiece({required this.id, required this.value});

  final int id;
  final String value;
}

class _DraggablePiece extends StatelessWidget {
  const _DraggablePiece({required this.piece, required this.enabled});

  final _PuzzlePiece piece;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.paperLight,
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        piece.value,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
    );
    if (!enabled) return Opacity(opacity: 0.55, child: tile);

    return LongPressDraggable<_PuzzlePiece>(
      data: piece,
      feedback: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.paperLight,
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x332B2620),
                  blurRadius: 8,
                  offset: Offset(0, 3)),
            ],
          ),
          child: SizedBox(
            width: 58,
            height: 58,
            child: Center(
              child: Text(piece.value,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: tile),
      child: tile,
    );
  }
}

class _PuzzleBoard extends StatelessWidget {
  const _PuzzleBoard({
    required this.size,
    required this.values,
    required this.onAccept,
  });

  final double size;
  final List<String> values;
  final void Function(int quadrant, _PuzzlePiece piece) onAccept;

  @override
  Widget build(BuildContext context) {
    final height = size * 1.16;
    return SizedBox(
      width: size,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: NotationGlyph(
              leftHand: values[0],
              hui: values[1],
              rightHand: values[2],
              stringNum: values[3],
              size: size,
            ),
          ),
          for (var quadrant = 0; quadrant < 4; quadrant++)
            _dropTarget(quadrant, size, height),
        ],
      ),
    );
  }

  Widget _dropTarget(int quadrant, double width, double height) {
    final isTop = quadrant < 2;
    final isRight = quadrant.isOdd;
    return Positioned(
      left: isRight ? width / 2 : 0,
      top: isTop ? 0 : height / 2,
      width: width / 2,
      height: height / 2,
      child: DragTarget<_PuzzlePiece>(
        onWillAcceptWithDetails: (_) => values[quadrant].isEmpty,
        onAcceptWithDetails: (details) => onAccept(quadrant, details.data),
        builder: (context, candidates, rejected) {
          final hovering = candidates.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hovering
                  ? AppColors.gold.withValues(alpha: 0.16)
                  : Colors.transparent,
              border: hovering
                  ? Border.all(
                      color: AppColors.gold.withValues(alpha: 0.65), width: 1.5)
                  : null,
            ),
            child: values[quadrant].isEmpty
                ? Text(
                    kQuadrantNames[quadrant],
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  )
                : null,
          );
        },
      ),
    );
  }
}
