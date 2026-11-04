import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../common/guqin_sound.dart';
import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/practice_data.dart' show kOpenStrings, noteName;
import '../../data/seed_data.dart';
import '../../theme/app_theme.dart';

/// 功能五：指法动画教学。
/// 用轻量自绘动画演示「散音 / 泛音 / 按音」及左右手指法的动作要领，
/// 支持暂停、慢镜、定格、逐帧、进度拖拽与逐指法切换（可作为 Rive 矢量动画的降级实现）。
class FingeringPage extends StatefulWidget {
  /// 进入时直接定位的分类（如「右手指法」）。
  final String? initialCategory;

  /// 进入时直接定位的指法名（如「勾」）。
  final String? initialLabel;

  /// 直接定位减字（双手演示）。
  final NotationSymbol? initialSymbol;

  const FingeringPage({
    super.key,
    this.initialCategory,
    this.initialLabel,
    this.initialSymbol,
  });

  @override
  State<FingeringPage> createState() => _FingeringPageState();
}

class _FingeringPageState extends State<FingeringPage>
    with SingleTickerProviderStateMixin {
  static const _categories = ['基本音色', '右手指法', '左手指法', '组合连弹'];

  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));

  String _category = '基本音色';
  int _selected = 0;
  int _comboIndex = 0;
  int _targetString = 3; // 目标弦（0 起）
  double _speed = 1.0;
  bool _playing = true;
  bool _sideView = true; // 侧视画中画
  int _notationHandIndex = 0;

  double _lastAnimValue = 0;
  bool _mute = false; // 拖拽进度 / 逐帧时不发声
  List<String> _sounds = const [];

  List<Fingering> get _list =>
      SeedData.fingerings.where((f) => f.category == _category).toList();

  bool get _isCombo => _category == '组合连弹';

  /// 连弹组合：一式之内依次施行数法，用于演示同弦的往复与「入出成对」之理。
  static const _combos = <_ComboDef>[
    _ComboDef('勾挑', '中指勾入、食指挑出，一入一出而音音分明，为同弦连弹之常法。', ['勾', '挑']),
    _ComboDef('抹挑', '食指抹入、挑出，最见轻灵，宜匀宜轻，勿使一重一轻。', ['抹', '挑']),
    _ComboDef('托擘', '大指向内为托、向外为擘，成对而用，音取深厚沉雄。', ['托', '擘']),
    _ComboDef('打摘', '无名指打入、摘出，专用于急促交替，出音须干净利落。', ['打', '摘']),
    _ComboDef('按吟', '先按弦取声、再就本位吟猱，按为骨、吟为韵，一声之中见起伏。', ['按音', '吟']),
  ];

  /// 当前演示的步骤序列：单式一步，连弹数步。
  List<_Step> get _steps {
    if (widget.initialSymbol != null) {
      final s = widget.initialSymbol!;
      final lMotion =
          _motionOf(s.leftTech ?? (_notationKind(s) == 'harm' ? '泛音' : '按音'));
      final rMotion = _motionOf(s.rightHand);
      final strIdx = (_kCnNumeral[s.stringNum] ?? 1) - 1;
      return switch (_notationHandIndex) {
        1 => [
            _Step(
              label: s.leftHand + (s.leftTech ?? ''),
              leftLabel: s.leftHand + (s.leftTech ?? ''),
              leftMotion: lMotion,
              string: strIdx,
              hui: s.hui,
            ),
          ],
        2 => [
            _Step(
              label: s.rightHand,
              rightLabel: s.rightHand,
              rightMotion: rMotion,
              string: strIdx,
              hui: s.hui,
            ),
          ],
        _ => [
            _Step(
              label: s.reading,
              leftLabel: s.leftHand + (s.leftTech ?? ''),
              leftMotion: lMotion,
              rightLabel: s.rightHand,
              rightMotion: rMotion,
              string: strIdx,
              hui: s.hui,
            ),
          ],
      };
    }

    if (_isCombo) {
      final combo = _combos[_comboIndex.clamp(0, _combos.length - 1)];
      final out = <_Step>[];
      for (final name in combo.steps) {
        final f = SeedData.fingerings.firstWhere((e) => e.name == name);
        final isLeft =
            f.category == '左手指法' || (f.category == '基本音色' && f.name != '散音');
        out.add(_Step(
          label: f.name,
          leftLabel: isLeft ? f.name : null,
          leftMotion: isLeft ? f.motion : null,
          rightLabel: isLeft ? null : f.name,
          rightMotion: isLeft ? null : f.motion,
          string: _targetString,
          hui: isLeft ? (f.name == '泛音' ? '七' : '九') : null,
        ));
      }
      if (out.isNotEmpty) return out;
    }

    final list = _list;
    final f = list.isEmpty ? null : list[_selected.clamp(0, list.length - 1)];
    if (f == null) return const [];

    final isLeft =
        f.category == '左手指法' || (f.category == '基本音色' && f.name != '散音');
    return [
      _Step(
        label: f.name,
        leftLabel: isLeft ? f.name : null,
        leftMotion: isLeft ? f.motion : null,
        rightLabel: isLeft ? null : f.name,
        rightMotion: isLeft ? null : f.motion,
        string: _targetString,
        hui: isLeft ? (f.name == '泛音' ? '七' : '九') : null,
      ),
    ];
  }

  String? _motionOf(String name) {
    try {
      return SeedData.fingerings.firstWhere((f) => f.name == name).motion;
    } catch (_) {
      return 'pluck_down';
    }
  }

  String _notationKind(NotationSymbol symbol) {
    if (symbol.meaning.contains('泛音')) return 'harm';
    if (symbol.meaning.contains('散音')) return 'open';
    return 'press';
  }

  /// 指法 → 音色标识（对应 assets/audio/sfx 下的文件前缀）。
  /// 右手八法因手指触弦的肉甲比例与出弦方向不同，音色厚薄明亮各异；
  /// 左手吟猱为不同速率的音波，绰注为不同方向的滑音。
  static const _kindByName = <String, String>{
    '散音': 'open',
    '泛音': 'harm',
    '按音': 'press',
    '擘': 'bai',
    '托': 'tuo',
    '抹': 'mo',
    '挑': 'tiao',
    '勾': 'gou',
    '剔': 'ti',
    '打': 'da',
    '摘': 'zhai',
    '吟': 'yin',
    '猱': 'nao',
    '绰': 'chuo',
    '注': 'zhu',
  };

  @override
  void initState() {
    super.initState();
    _applyDeepLink();
    _controller.repeat();
    _controller.addListener(_animationListener);
    AppDatabase.instance.bumpProgress('fingering_views');
    _warmUp();
  }

  /// 由外部（减字拆解、琴曲学习）深链进入时，直接定位到对应指法。
  void _applyDeepLink() {
    final label = widget.initialLabel;
    if (label != null) {
      final f = SeedData.fingerings.where((e) => e.name == label);
      if (f.isNotEmpty) {
        _category = f.first.category;
        final list =
            SeedData.fingerings.where((e) => e.category == _category).toList();
        final i = list.indexWhere((e) => e.name == label);
        _selected = i < 0 ? 0 : i;
        return;
      }
    }
    final c = widget.initialCategory;
    if (c != null && _categories.contains(c)) {
      _category = c;
      _selected = 0;
    }
  }

  void _animationListener() {
    final value = _controller.value;
    if (_mute) {
      _lastAnimValue = value;
      return;
    }
    // 每一步的触弦点（该步中点）处发声，与画布上的弦振严格同步。
    final n = _sounds.length;
    for (var i = 0; i < n; i++) {
      final c = (i + 0.5) / n;
      if (_lastAnimValue < c && value >= c) {
        GuqinSound.instance.play(_sounds[i], volume: 0.85);
        break;
      }
    }
    _lastAnimValue = value;
  }

  /// 切换指法、弦序或组合后立即预热新的音效，避免下一次演示时才载入。
  void _warmUp() {
    final files = [
      for (final s in _steps)
        GuqinSound.file(
          widget.initialSymbol == null
              ? _kindByName[s.label] ?? 'open'
              : _kindByName[widget.initialSymbol!.rightHand] ??
                  _notationKind(widget.initialSymbol!),
          s.string,
        ),
    ];
    _sounds = files;
    unawaited(GuqinSound.instance.preload(files));
  }

  @override
  void dispose() {
    _controller.removeListener(_animationListener);
    _controller.dispose();
    // 离开教学页即停止余响
    unawaited(GuqinSound.instance.stopAll());
    super.dispose();
  }

  void _selectCategory(String c) {
    setState(() {
      _category = c;
      _selected = 0;
    });
    _warmUp();
  }

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    });
  }

  void _setSpeed(double s) {
    setState(() {
      _speed = s;
      _controller.duration = Duration(milliseconds: (2600 / s).round());
      if (_playing) _controller.repeat();
    });
  }

  /// 定格：停在当前式的触弦瞬间，并奏出该音——正是一声将发未发之处。
  void _freeze() {
    final n = _steps.length;
    final idx = (_controller.value * n).floor().clamp(0, n - 1);
    setState(() {
      _playing = false;
      _controller.stop();
      _controller.value = (idx + 0.5) / n;
    });
    _lastAnimValue = _controller.value;
  }

  /// 逐帧步进：一步之内分六十帧，便于细看指节的屈伸。
  void _stepFrame(int dir) {
    final n = _steps.length;
    final mid = 1.0 / (n * 60);
    _mute = true;
    _controller.stop();
    _controller.value = (_controller.value + dir * mid).clamp(0.0, 1.0);
    _lastAnimValue = _controller.value;
    _mute = false;
    setState(() => _playing = false);
  }

  /// 进度拖拽：可停在任意一帧，亦兼作「逐式」——慢拖可见每一步的起落。
  void _scrub(double v) {
    _mute = true;
    if (_playing) {
      _playing = false;
      _controller.stop();
    }
    _controller.value = v.clamp(0.0, 1.0);
    _lastAnimValue = _controller.value;
    _mute = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final index = _selected.clamp(0, math.max(0, list.length - 1)).toInt();
    final fingering = list.isEmpty ? null : list[index];
    final steps = _steps;
    final combo =
        _isCombo ? _combos[_comboIndex.clamp(0, _combos.length - 1)] : null;

    return InkScaffold(
      appBar: AppBar(
        title: Text(widget.initialSymbol == null ? '指法动画教学' : '指法示范'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (widget.initialSymbol == null)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = _categories[i];
                  final selected = c == _category;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => _selectCategory(c),
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
          if (widget.initialSymbol == null) const SizedBox(height: 14),
          // 动画画布
          PaperCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: _FingeringPainter(
                          t: _controller.value,
                          steps: steps,
                          sideView: _sideView,
                          showSupportHand: widget.initialSymbol == null ||
                              _notationHandIndex == 0,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _transportRow(),
                _speedRow(),
                _progressRow(),
                if (widget.initialSymbol == null) ...[
                  const Divider(height: 18),
                  Row(
                    children: [
                      const Text('弦序',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.inkSoft)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          value: _targetString.toDouble(),
                          min: 0,
                          max: 6,
                          divisions: 6,
                          label: '第${_kStringNames[_targetString]}弦',
                          activeColor: AppColors.cinnabar,
                          onChanged: (v) {
                            setState(() => _targetString = v.round());
                            _warmUp();
                          },
                        ),
                      ),
                      Text('第${_kStringNames[_targetString]}弦',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (widget.initialSymbol != null) ...[
            const SectionTitle(title: '选择手别', subtitle: '点击单看一手或双手联动'),
            SizedBox(
              height: 74,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _pickTile(
                    title: '双手',
                    subtitle: '联动',
                    on: _notationHandIndex == 0,
                    onTap: () => _selectNotationHand(0),
                  ),
                  const SizedBox(width: 10),
                  _pickTile(
                    title: widget.initialSymbol!.leftHand,
                    subtitle: '左手',
                    on: _notationHandIndex == 1,
                    onTap: () => _selectNotationHand(1),
                  ),
                  const SizedBox(width: 10),
                  _pickTile(
                    title: widget.initialSymbol!.rightHand,
                    subtitle: '右手',
                    on: _notationHandIndex == 2,
                    onTap: () => _selectNotationHand(2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _NotationDemoInfoCard(
              symbol: widget.initialSymbol!,
              selectedHand: _notationHandIndex,
            ),
          ] else ...[
            // 指法 / 连弹选择
            SectionTitle(
                title: _isCombo ? '选择连弹' : '选择指法',
                subtitle: _isCombo ? '一式之内数法相续' : '点击切换动画'),
            SizedBox(
              height: 74,
              child: _isCombo ? _comboList() : _fingeringList(list, index),
            ),
            const SizedBox(height: 18),
          ],
          if (widget.initialSymbol == null && combo != null)
            _ComboCard(combo: combo)
          else if (widget.initialSymbol == null && fingering != null)
            _InfoCard(fingering: fingering),
        ],
      ),
    );
  }

  void _selectNotationHand(int index) {
    setState(() {
      _notationHandIndex = index;
      _playing = true;
      _controller.repeat();
    });
    _warmUp();
  }

  Widget _transportRow() {
    return Row(
      children: [
        IconButton.filled(
          onPressed: _togglePlay,
          style: IconButton.styleFrom(backgroundColor: AppColors.cinnabar),
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow,
              color: Colors.white),
          tooltip: '播放 / 暂停',
        ),
        _mini(Icons.replay, '重播', () => _controller.forward(from: 0)),
        _mini(Icons.center_focus_strong, '定格触弦瞬间', _freeze),
        _mini(Icons.chevron_left, '上一帧', () => _stepFrame(-1)),
        _mini(Icons.chevron_right, '下一帧', () => _stepFrame(1)),
        const Spacer(),
        _mini(_sideView ? Icons.crop_16_9 : Icons.crop_16_9_outlined, '侧视画中画',
            () => setState(() => _sideView = !_sideView),
            active: _sideView),
      ],
    );
  }

  Widget _mini(IconData icon, String tip, VoidCallback onTap,
      {bool active = false}) {
    return IconButton(
      onPressed: onTap,
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon,
          size: 20, color: active ? AppColors.jade : AppColors.inkSoft),
    );
  }

  Widget _speedRow() {
    return Row(
      children: [
        const Text('速度',
            style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
        const Spacer(),
        ...[0.25, 0.5, 1.0, 1.5].map((s) {
          final on = _speed == s;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () => _setSpeed(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: on ? AppColors.jade : AppColors.paper,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: on ? AppColors.jade : AppColors.line),
                ),
                child: Text('${s}x',
                    style: TextStyle(
                        fontSize: 11,
                        color: on ? Colors.white : AppColors.inkSoft)),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _progressRow() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        children: [
          const Text('进度',
              style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
          Expanded(
            child: Slider(
              value: _controller.value.clamp(0.0, 1.0),
              activeColor: AppColors.jade,
              onChanged: _scrub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fingeringList(List<Fingering> list, int index) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final f = list[i];
        final on = i == index;
        return _pickTile(
          title: f.name,
          subtitle: f.pinyin,
          on: on,
          onTap: () {
            setState(() => _selected = i);
            _warmUp();
          },
        );
      },
    );
  }

  Widget _comboList() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _combos.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final c = _combos[i];
        final on = i == _comboIndex;
        return _pickTile(
          title: c.name,
          subtitle: c.steps.join('·'),
          on: on,
          onTap: () {
            setState(() => _comboIndex = i);
            _warmUp();
          },
        );
      },
    );
  }

  Widget _pickTile({
    required String title,
    required String subtitle,
    required bool on,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        decoration: BoxDecoration(
          color: on
              ? AppColors.cinnabar.withValues(alpha: 0.10)
              : AppColors.paperLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: on ? AppColors.cinnabar : AppColors.line,
              width: on ? 1.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.cinnabar : AppColors.ink)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

const _kStringNames = ['一', '二', '三', '四', '五', '六', '七'];

class _InfoCard extends StatelessWidget {
  final Fingering fingering;
  const _InfoCard({required this.fingering});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(fingering.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(fingering.pinyin,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              const Spacer(),
              TagChip(fingering.category),
            ],
          ),
          const SizedBox(height: 10),
          Text(fingering.desc,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.8, color: AppColors.ink)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              border: const Border(
                  left: BorderSide(color: AppColors.gold, width: 3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('要领：${fingering.tip}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.8,
                          color: AppColors.inkSoft)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotationDemoInfoCard extends StatelessWidget {
  const _NotationDemoInfoCard({
    required this.symbol,
    required this.selectedHand,
  });

  final NotationSymbol symbol;
  final int selectedHand;

  @override
  Widget build(BuildContext context) {
    final handNotes = [
      (
        '左手',
        '${symbol.leftHand}${symbol.leftTech ?? ''} 按第${symbol.stringNum}弦${symbol.hui}徽'
      ),
      ('右手', '${symbol.rightHand}第${symbol.stringNum}弦'),
    ];
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(symbol.reading,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              const TagChip('减字示范', color: AppColors.jade),
              const Spacer(),
              Text('${symbol.stringNum}弦 · ${symbol.hui}徽',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            symbol.meaning,
            style: const TextStyle(fontSize: 13, height: 1.8),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < handNotes.length; i++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (selectedHand == 0 || selectedHand == i + 1)
                    ? (i == 0 ? AppColors.jade : AppColors.cinnabar)
                        .withValues(alpha: 0.08)
                    : AppColors.paper,
                border: Border(
                  left: BorderSide(
                    color: i == 0 ? AppColors.jade : AppColors.cinnabar,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      handNotes[i].$1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? AppColors.jade : AppColors.cinnabar,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      handNotes[i].$2,
                      style: const TextStyle(fontSize: 12, height: 1.5),
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

class _ComboCard extends StatelessWidget {
  final _ComboDef combo;
  const _ComboCard({required this.combo});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(combo.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(combo.steps.join(' · '),
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              const Spacer(),
              const TagChip('连弹'),
            ],
          ),
          const SizedBox(height: 10),
          Text(combo.hint,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.8, color: AppColors.ink)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              border: const Border(
                  left: BorderSide(color: AppColors.gold, width: 3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    size: 16, color: AppColors.gold),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                      '要领：连弹贵在「匀」与「分」——每一步的起落皆清楚可数，而拍子不失。'
                      '可先以 0.25x 慢看，再逐帧停在触弦处听其音色之别。',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.8,
                          color: AppColors.inkSoft)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 一个演示步骤：减字号、动作类型、类别与目标弦。
class _Step {
  final String label;
  final String? leftMotion;
  final String? leftLabel;
  final String? rightMotion;
  final String? rightLabel;
  final int string;
  final String? hui;

  const _Step({
    required this.label,
    this.leftMotion,
    this.leftLabel,
    this.rightMotion,
    this.rightLabel,
    required this.string,
    this.hui,
  });

  /// 判定此步是否有左手动作。
  bool get hasLeft => leftMotion != null;

  /// 判定此步是否有右手动作。
  bool get hasRight => rightMotion != null;

  String get motion => leftMotion ?? rightMotion ?? 'pluck_down';
}

/// 一组「连弹」指法。
class _ComboDef {
  final String name;
  final String hint;
  final List<String> steps;
  const _ComboDef(this.name, this.hint, this.steps);
}

/// 指法动作动画画笔。
///
/// 俯视琴面的第一视角：七弦横贯画面上方，岳山在右。左手自左下伸入按弦走弦，
/// 右手自右下伸入往靠岳山一侧弹弦。双手始终一并绘出——主手（本指法所属的
/// 那一只手）高亮并带动指节屈伸，辅手淡示其配合之势，如师在侧、双手并示。
/// 另以指尖残影、虚线轨迹、触弦涟漪与弦振相辅，示其来路与去向。
///
/// 连弹时 [steps] 不止一步，时间轴按步均分，逐步演示并逐步发声；左下另设
/// 侧视画中画，剖面示按弦之深浅、指节之屈伸与弦受拨之形变。
class _FingeringPainter extends CustomPainter {
  final double t; // 0..1 循环进度
  final List<_Step> steps;
  final bool sideView;
  final bool showSupportHand;

  _FingeringPainter({
    required this.t,
    required this.steps,
    required this.sideView,
    this.showSupportHand = true,
  });

  /// 每一步的触弦出音点（该步中点）：声音即在此刻触发（见页面动画监听）。
  static const double _contact = 0.5;

  /// 手的自适应尺度：由画布高度推出，小屏不越界、大屏不觉局促。
  double _k = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 弦区：上方留出注记的位置，下方整片留给双手
    final top = h * 0.16;
    final bottom = h * 0.46;
    final spacing = (bottom - top) / 6;
    _k = (h / 380).clamp(0.42, 1.15);

    // 连弹时按步均分时间轴；单式即一步
    final n = steps.length;
    final idx = (t * n).floor().clamp(0, n - 1);
    final localT = (t * n - idx).clamp(0.0, 1.0);
    final cur = steps[idx];
    final targetY = top + cur.string * spacing;

    _drawDeck(canvas, w, h, top, bottom, cur, localT);

    // 双手联动：根据 _Step 是否持有左右手动作决定是否激活
    final left = _leftPose(cur, w, targetY, cur.hasLeft, localT);
    final right = _rightPose(cur, w, targetY, cur.hasRight, localT);

    // 主手逻辑：若为双手，则以左手为轨迹主导；若为单手，则以动者为主
    final mainIsLeft = cur.hasLeft;
    final main = mainIsLeft ? left : right;
    final support = mainIsLeft ? right : left;

    _HandPose at(double tt) => mainIsLeft
        ? _leftPose(cur, w, targetY, true, tt)
        : _rightPose(cur, w, targetY, true, tt);

    // 辅手先落笔、主手后落笔，主次分明
    if (showSupportHand) _drawHand(canvas, support, 0.60);
    _drawTrail(canvas, main, at, localT);
    _drawHand(canvas, main, 1.0);

    // 右手取声处荡开涟漪，右手指法另作出弦／入弦的方向提示
    _drawRipple(canvas, right, localT);
    if (cur.rightMotion == 'pluck_up' || cur.rightMotion == 'pluck_down') {
      _drawPluckHint(canvas, right, targetY, cur);
    }

    // 本式所得之音：标于触弦之侧
    _drawPitchTag(canvas, main.contact, _pitchTag(cur));

    // 名称水印
    if (n == 1) {
      final tp = TextPainter(
        text: TextSpan(
          text: cur.label,
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.10),
            letterSpacing: 4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w - tp.width - 16, h - tp.height - 6));
    }

    // 双手动作注记：指明此刻左右手各该怎么做
    _drawCaptions(canvas, w, left, right, mainIsLeft);

    // 连弹的步骤时序
    if (n > 1) _drawTimeline(canvas, w, h, steps, idx);

    // 侧视画中画
    if (sideView) _drawSideView(canvas, w, h, cur, localT);
  }

  /// 判定此步的主导动作是否为左手。
  bool _isLeftAction(_Step s) => s.hasLeft;

  /// 琴面：木纹底色、岳山、十三徽与七弦。
  void _drawDeck(Canvas canvas, double w, double h, double top, double bottom,
      _Step cur, double localT) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B4A2F), Color(0xFF8A6240), Color(0xFF5C3E27)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 岳山（琴头）在右侧：右手的弹弦点即在其附近
    canvas.drawRect(
      Rect.fromLTWH(w * 0.88, 0, w * 0.12, h),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // 徽位（垂直于弦的横线）：一徽近岳山（右），七徽居中，十三徽近琴尾（左）
    final huiPaint = Paint()
      ..color = const Color(0xFFF3E6CE).withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 0; i < 13; i++) {
      final x = w * (1 - (i + 1) / 14);
      canvas.drawLine(Offset(x, top - 8), Offset(x, bottom + 8), huiPaint);
      canvas.drawCircle(
          Offset(x, top - 13),
          i == 6 ? 3 : 2,
          Paint()
            ..color =
                i == 6 ? const Color(0xFFE9C97A) : const Color(0xFFD9C9A8));
    }

    // 七弦
    final spacing = (bottom - top) / 6;
    for (var i = 0; i < 7; i++) {
      final y = top + i * spacing;
      final isTarget = i == cur.string;
      final paint = Paint()
        ..color = isTarget
            ? const Color(0xFFF5EBD6)
            : const Color(0xFFD8CBAF).withValues(alpha: 0.7)
        ..strokeWidth = isTarget ? 2.4 : 1.2;
      if (isTarget) {
        _drawVibratingString(canvas, w, y, paint, cur, localT);
      } else {
        canvas.drawLine(Offset(10, y), Offset(w - 10, y), paint);
      }
    }
  }

  void _drawVibratingString(Canvas canvas, double w, double y, Paint paint,
      _Step cur, double localT) {
    final (amp, u) = _stringState(cur, localT);
    if (amp <= 0.05) {
      canvas.drawLine(Offset(10, y), Offset(w - 10, y), paint);
      return;
    }
    final waves = cur.motion == 'harmonic'
        ? 5.0
        : (cur.motion == 'slide' && cur.label == '猱' ? 3.2 : 2.2);
    // 相位汇聚速度：吟的弦振细而密，猱的弦振缓而长。
    final swing =
        cur.motion == 'slide' ? (cur.label == '猱' ? 26.0 : 96.0) : 138.0;
    final path = Path()..moveTo(10, y);
    for (double x = 10; x <= w - 10; x += 3) {
      final norm = (x - 10) / (w - 20);
      // 两端固定，中部振幅最大
      final envelope = math.sin(norm * math.pi);
      final dy =
          amp * envelope * math.sin(norm * math.pi * 2 * waves - u * swing);
      path.lineTo(x, y + dy);
    }
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  /// 返回当前弦振的幅度与进度（0..1）。
  (double, double) _stringState(_Step cur, double localT) {
    const start = 0.5;
    if (localT < start) return (0, 0);
    final u = (localT - start) / (1 - start);
    final decay = math.exp(-4.5 * u);
    double base;
    if (cur.motion == 'harmonic') {
      base = 7.0;
    } else if (cur.motion == 'press') {
      base = 12.0;
    } else if (cur.motion == 'slide') {
      base = cur.label == '猱' ? 16.0 : 9.0; // 猱振大而长，吟振细而密
    } else {
      base = 15.0;
    }
    return (base * decay, u);
  }

  // ------------------------------------------------------------ 双手姿态

  /// 左手：自左下伸入，落于徽位按弦、走弦。
  /// 主手时依指法走弦；辅手（示范右手取声之曲）则虚置于徽间候按，示其配合之势。
  _HandPose _leftPose(
      _Step s, double w, double targetY, bool active, double t) {
    final rise = (1 - _ease(0.18, 0.46, t)) * 44; // 起手自画面下方抬起

    if (!active) {
      // 犹未落指：虚置于弦下
      return _HandPose(
        tip: Offset(w * 0.29, targetY + 40 + rise * 0.30),
        contact: Offset(w * 0.29, targetY),
        finger: 3,
        curl: 0.70,
        tilt: 0.22,
        mirror: false,
        glow: 0,
        nail: 1.0,
        caption: '左手·虚置候弦',
      );
    }

    final motion = s.leftMotion ?? 'press';
    // 根据徽位计算坐标
    final x = s.hui != null
        ? w * (1 - (_kCnNumeral[s.hui] ?? 7) / 14)
        : (motion == 'harmonic' ? w * 0.50 : w * 0.355);
    final finger = motion == 'harmonic' ? 1 : 3;

    var tipX = x;
    var tipY = targetY + rise;
    var curl = 0.5;
    var glow = 0.0;
    final lp = _ease(0.50, 0.92, t);

    switch (motion) {
      case 'harmonic':
        final lift = _ease(0.54, 0.72, t);
        tipY = targetY + rise + lift * 30;
        curl = 0.28 + lift * 0.5;
        glow = t > 0.43 && t < 0.64 ? (1 - (t - 0.43) / 0.21) * 0.95 : 0.0;
        break;
      case 'slide':
        final slow = s.leftLabel?.contains('猱') ?? false;
        final cycles = slow ? 3.0 : 12.0;
        tipX = x + (slow ? 26.0 : 12.0) * math.sin(lp * math.pi * cycles);
        tipY = targetY + (slow ? 6.0 * math.sin(lp * math.pi * cycles) : 0);
        glow = slow ? 0.55 : 0.4;
        break;
      case 'slide_up':
        tipX = x - 46 + lp * 46;
        glow = 0.45;
        break;
      case 'slide_down':
        tipX = x + 46 - lp * 46;
        glow = 0.45;
        break;
      default:
        glow = t > 0.44 ? 0.5 : 0.0;
        break;
    }

    return _HandPose(
      tip: Offset(tipX, tipY),
      contact: Offset(tipX, targetY),
      finger: finger,
      curl: curl,
      tilt: 0.22,
      mirror: false,
      glow: glow,
      nail: 1.0,
      caption: _leftCaption(s, finger, x, w),
    );
  }

  _HandPose _rightPose(
      _Step s, double w, double targetY, bool active, double t) {
    const xr = 0.72;
    final label = s.rightLabel ?? '抹';
    final motion = s.rightMotion ?? 'pluck_down';
    final tech = _kRightTech[label] ?? _kRightTechDefault;
    final finger = active ? _rightFinger(label) : 1;
    final outward = motion == 'pluck_up';
    final rise = (1 - _ease(0.14, 0.38, t)) * (22 + 26 * tech.lift);
    final travel = (((t - 0.38) / 0.24).clamp(0.0, 1.0) - 0.5) * 2;
    final relax = _ease(0.62, 0.88, t);
    final tipY = targetY + rise + (outward ? -1 : 1) * travel * 22 - relax * 6;
    final curl =
        (0.20 + 0.42 * _ease(0.38, 0.62, t) - relax * 0.16).clamp(0.0, 1.0);
    final glow = t > 0.42 && t < 0.70 ? (1 - (t - 0.42) / 0.28) * 0.9 : 0.0;

    return _HandPose(
      tip: Offset(w * xr, tipY),
      contact: Offset(w * xr, targetY),
      finger: finger,
      curl: curl,
      tilt: -0.24 + tech.wrist,
      mirror: true,
      glow: glow,
      nail: tech.nail,
      caption: active
          ? '右手·${_kFingerNames[finger]} $label（${tech.part}·${outward ? '向外' : '向身'}）'
          : '右手·食指 候弦',
    );
  }

  int _rightFinger(String label) => switch (label) {
        '擘' || '托' => 0,
        '抹' || '挑' => 1,
        '勾' || '剔' => 2,
        '打' || '摘' => 3,
        _ => 1,
      };

  // ------------------------------------------------------------ 落笔

  /// 绘出一只完整的琴人之手：腕、掌、五指（含指节与指甲）。
  /// 活动指的指尖恰落在 [pose] 的 tip 上，故手掌位置由该指的屈伸反推。
  void _drawHand(Canvas canvas, _HandPose pose, double alpha,
      {bool ghost = false}) {
    final skin = pose.mirror ? _kSkinRight : _kSkinLeft;
    final g = _kFingers[pose.finger];
    final tipLocal = _fingerTip(g, pose.curl);
    final local = Offset(g.root.dx + tipLocal.dx, g.root.dy + tipLocal.dy) * _k;
    final origin = pose.tip - _rotate(local, pose.tilt, pose.mirror);

    // 触弦高光
    if (pose.glow > 0) {
      canvas.drawCircle(
        pose.contact,
        10 + 18 * pose.glow,
        Paint()
          ..color = const Color(0xFFE9C97A)
              .withValues(alpha: 0.42 * pose.glow * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(pose.tilt);
    if (pose.mirror) canvas.scale(-1, 1);
    canvas.scale(_k);
    _paintArm(canvas, skin, alpha);
    _paintPalm(canvas, skin, alpha);
    // 余指收拢，不与弦争
    for (var i = 0; i < _kFingers.length; i++) {
      if (i == pose.finger) continue;
      _paintFinger(canvas, _kFingers[i], 0.95, alpha * 0.88, false, skin);
    }
    _paintFinger(canvas, g, pose.curl, alpha, !ghost, skin, pose.nail);
    canvas.restore();

    if (!ghost) _paintBadge(canvas, pose, alpha, origin);
  }

  /// 主手的动作残影与指尖轨迹：把「来路与去向」一并画出，如师以指点示。
  void _drawTrail(Canvas canvas, _HandPose now, _HandPose Function(double) at,
      double localT) {
    if (localT < 0.14) return;
    final moved = (now.tip - at(localT - 0.12).tip).distance;
    if (moved < 2.5) return; // 静势不留残影
    final cap = math.min(1.0, moved / 12.0);

    _drawHand(canvas, at(localT - 0.06), 0.20 * cap, ghost: true);
    _drawHand(canvas, at(localT - 0.12), 0.10 * cap, ghost: true);

    final pts = <Offset>[
      for (var i = 0; i <= 14; i++) at(localT - 0.16 + 0.02 * i).tip,
    ];
    _dashedPolyline(
      canvas,
      pts,
      Paint()
        ..color = const Color(0xFFE9C97A).withValues(alpha: 0.30)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
      4,
      5,
    );
  }

  /// 触弦涟漪：弦振初起时自取声处荡开一圈。
  void _drawRipple(Canvas canvas, _HandPose right, double localT) {
    if (localT < _contact || localT > _contact + 0.26) return;
    final u = (localT - _contact) / 0.26;
    canvas.drawCircle(
      right.contact,
      8 + 30 * u,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * (1 - u)
        ..color = const Color(0xFFE9C97A).withValues(alpha: 0.45 * (1 - u)),
    );
  }

  /// 弹弦方向提示：向外为「出弦」，向身为「入弦」。
  void _drawPluckHint(
      Canvas canvas, _HandPose right, double targetY, _Step cur) {
    final outward = cur.motion == 'pluck_up';
    final x = right.tip.dx - 40;
    final yTop = targetY - 27;
    final yBottom = targetY - 5;
    final paint = Paint()
      ..color = const Color(0xFFE9C97A)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final tail = outward ? Offset(x, yBottom) : Offset(x, yTop);
    final head = outward ? Offset(x, yTop) : Offset(x, yBottom);
    canvas.drawLine(tail, head, paint);
    final dir = (head.dy - tail.dy).sign;
    canvas.drawPath(
      Path()
        ..moveTo(head.dx, head.dy)
        ..lineTo(head.dx - 5, head.dy - dir * 7)
        ..lineTo(head.dx + 5, head.dy - dir * 7)
        ..close(),
      paint..style = PaintingStyle.fill,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: outward ? '出弦' : '入弦',
        style: const TextStyle(
          fontSize: 9,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE9C97A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(x - tp.width - 6, (yTop + yBottom) / 2 - tp.height / 2));
  }

  /// 本式所得之音的音高签：使音名与徽位互相印证。
  void _drawPitchTag(Canvas canvas, Offset at, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 9.5,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2B2620),
          fontFamily: AppTheme.serifFamily,
          fontFamilyFallback: AppTheme.serifFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(at.dx - tp.width / 2 - 7, at.dy - tp.height - 20,
        tp.width + 14, tp.height + 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = const Color(0xFFE9C97A).withValues(alpha: 0.92),
    );
    tp.paint(canvas, Offset(rect.left + 7, rect.top + 4));
  }

  /// 双手动作注记：左上一行示左手，右上一行示右手，主手一行以金色标出。
  void _drawCaptions(Canvas canvas, double w, _HandPose left, _HandPose right,
      bool activeIsLeft) {
    _caption(canvas, left.caption, 10, activeIsLeft);
    _caption(canvas, right.caption, w - 10, !activeIsLeft, rightAligned: true);
  }

  void _caption(Canvas canvas, String text, double x, bool bright,
      {bool rightAligned = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9.5,
          height: 1.0,
          letterSpacing: 0.6,
          fontWeight: bright ? FontWeight.w700 : FontWeight.w400,
          color: bright
              ? const Color(0xFFE9C97A)
              : Colors.white.withValues(alpha: 0.42),
          fontFamily: AppTheme.serifFamily,
          fontFamilyFallback: AppTheme.serifFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rightAligned ? x - tp.width : x, 6));
  }

  /// 连弹的步骤时序：逐步平列，当前一步以金色标出。
  void _drawTimeline(
      Canvas canvas, double w, double h, List<_Step> steps, int idx) {
    final dim = TextStyle(
      fontSize: 10,
      height: 1.0,
      color: Colors.white.withValues(alpha: 0.42),
      fontFamily: AppTheme.serifFamily,
      fontFamilyFallback: AppTheme.serifFallback,
    );
    const hot = TextStyle(
      fontSize: 11.5,
      height: 1.0,
      fontWeight: FontWeight.w700,
      color: Color(0xFFE9C97A),
      fontFamily: AppTheme.serifFamily,
      fontFamilyFallback: AppTheme.serifFallback,
    );
    final spans = <InlineSpan>[
      TextSpan(text: '连弹  ', style: dim),
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0) TextSpan(text: '  ·  ', style: dim),
        TextSpan(text: steps[i].label, style: i == idx ? hot : dim),
      ],
    ];
    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h - tp.height - 8));
  }

  /// 左手注记：指、徽位与所行之法，并附本式音名。
  String _leftCaption(_Step s, int finger, double x, double w) {
    final f = _kFingerNames[finger];
    final hui = _huiAt(x, w);
    final note = _pitchNote(s);
    return switch (s.motion) {
      'harmonic' => '左手·$f 点$hui（泛音 $note）',
      'slide' =>
        s.label == '猱' ? '左手·$f $hui 猱（大而缓·$note）' : '左手·$f $hui 吟（小而匀·$note）',
      'slide_up' => '左手·$f $hui 绰（由低就高·$note）',
      'slide_down' => '左手·$f $hui 注（由高就低·$note）',
      _ => '左手·$f 按$hui（$note）',
    };
  }

  /// 本式所得之音的音名（正调，按音取九徽、泛音取七徽）。
  String _pitchNote(_Step s) {
    final base = kOpenStrings[s.string.clamp(0, 6)];
    final add = s.motion == 'harmonic'
        ? 12
        : (s.motion == 'press' || s.motion.startsWith('slide') ? 7 : 0);
    return noteName(base + add);
  }

  String _pitchTag(_Step s) {
    final base = kOpenStrings[s.string.clamp(0, 6)];
    if (s.motion == 'harmonic') return '${noteName(base + 12)} · 七徽泛音';
    if (s.motion == 'press' || s.motion.startsWith('slide')) {
      return '${noteName(base + 7)} · 九徽按音';
    }
    return '${noteName(base)} · 空弦';
  }

  /// 由横坐标反推徽位号（一徽近岳山、七徽居中、十三徽近琴尾）。
  String _huiAt(double x, double w) {
    const names = [
      '',
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
    final n = (14 * (1 - x / w)).round().clamp(1, 13);
    return '${names[n]}徽';
  }

  // ------------------------------------------------------------ 侧视画中画

  /// 左下角侧视剖面：横为琴面、纵为弦之起伏。
  ///
  /// 左手按弦见其入木之深浅，右手指拨见其离面之形变；指之屈伸在侧视中
  /// 一目了然（与俯视的「变短」互为表里），弦受指之处则凹／凸成弧。
  void _drawSideView(
      Canvas canvas, double w, double h, _Step cur, double localT) {
    final pw = math.min(w * 0.34, 136.0);
    const ph = 96.0;
    final rect = Rect.fromLTWH(10, h - ph - 10, pw, ph);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(
        rrect, Paint()..color = Colors.black.withValues(alpha: 0.50));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE9C97A).withValues(alpha: 0.45),
    );

    final x0 = rect.left + 9; // 雁足（琴尾侧）
    final x1 = rect.right - 9; // 岳山（琴头侧）
    final restY = rect.top + 44; // 弦之静止高度
    final boardY = rect.bottom - 14; // 琴面
    final maxDip = boardY - restY; // 弦离琴面之距，亦按弦之行程

    // 琴面：木色带厚度
    canvas.drawRect(
      Rect.fromLTWH(rect.left, boardY, rect.width, rect.bottom - boardY),
      Paint()..color = const Color(0xFF6E4E33),
    );
    canvas.drawLine(
      Offset(rect.left, boardY),
      Offset(rect.right, boardY),
      Paint()
        ..color = const Color(0xFFB98A5C)
        ..strokeWidth = 2,
    );

    // 弦之所系：左端雁足、右端岳山
    for (final x in [x0, x1]) {
      canvas.drawRect(
        Rect.fromLTWH(x - 2.5, restY - 1, 5, boardY - restY + 1),
        Paint()..color = const Color(0xFF8A6240),
      );
    }

    // 弦的静止位置（虚线）：与琴面之距即按弦行程
    _dashedPolyline(
      canvas,
      [Offset(x0, restY), Offset(x1, restY)],
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..strokeWidth = 1,
      3,
      3,
    );

    // 触弦之处与俯视一致：左手偏琴尾，右手近岳山；
    // 吟猱之时按弦之处沿线往复，绰注则自本位两侧滑入，
    // 侧视中即弦之凹陷点一进一退、一滑一就。
    final leftAction = _isLeftAction(cur);
    final depth = _pressDepth(cur, localT);
    final lp = _ease(0.50, 0.92, localT); // 右手取声之后，左手方走弦
    final homeX = leftAction ? rect.left + pw * 0.34 : rect.left + pw * 0.70;
    var px = homeX;
    if (cur.motion == 'slide') {
      final slow = cur.label == '猱';
      px += (slow ? 6.0 : 2.5) * math.sin(localT * math.pi * (slow ? 7 : 20));
    } else if (cur.motion == 'slide_up') {
      px -= 15.0 * (1 - lp); // 绰：自琴尾侧（音低）滑就本位
    } else if (cur.motion == 'slide_down') {
      px += 15.0 * (1 - lp); // 注：自岳山侧（音高）滑就本位
    }

    // 弦在触弦点的垂直位移：按弦则下陷入木，拨弦则离面而起或向身而压；
    // 左手取声之后弦亦自往复（吟猱尤显），故与俯视之弦振同出一理。
    final double dy;
    if (leftAction) {
      dy = (depth * maxDip + _sideVib(cur, localT) * maxDip)
          .clamp(-maxDip * 0.5, maxDip * 0.92);
    } else {
      final outward = cur.motion == 'pluck_up';
      dy = (outward ? -1.0 : 1.0) * _pluckAmp(cur, localT) * maxDip * 0.62;
    }

    // 二次贝塞尔曲线中点的位移只有控制点之半，故控制点取两倍，
    // 指尖方能与弦严丝合缝地贴在一处。
    canvas.drawPath(
      Path()
        ..moveTo(x0, restY)
        ..quadraticBezierTo(px, restY + dy * 2, x1, restY),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFF5EBD6),
    );
    final touch = Offset(px, restY + dy);

    if (leftAction) {
      // 左手按弦：指自上方垂下。未触弦时悬于弦外，按实后方贴弦；
      // 泛音则点罢即离，正是「蜻蜓点水」之态。
      final double gap;
      if (cur.motion == 'harmonic') {
        gap = 26 * (1 - _ease(0.24, 0.42, localT)) +
            26 * _ease(0.56, 0.74, localT);
      } else if (cur.motion == 'slide_up' || cur.motion == 'slide_down') {
        gap = 0; // 绰注自始至终按实
      } else {
        gap = 26 * (1 - _ease(0.24, 0.42, localT));
      }
      final pts = _sideFingerJoints(touch, 0.42 + depth * 0.30, 1.34, gap: gap);
      final paint = Paint()
        ..color = _kSkinLeft.base
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i + 1 < pts.length; i++) {
        paint.strokeWidth = 9.0 - i * 1.6;
        canvas.drawLine(pts[i], pts[i + 1], paint);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: pts.last - const Offset(0, 1.5), width: 8, height: 7),
          const Radius.circular(3),
        ),
        Paint()..color = _kSkinLeft.nail,
      );
      // 绰注之滑：以一短箭标其来路，使「由低而就高／由高而就低」一望可辨
      if (cur.motion == 'slide_up' || cur.motion == 'slide_down') {
        final up = cur.motion == 'slide_up';
        final sgn = up ? 1.0 : -1.0;
        const yA = -20.0;
        final arrowPaint = Paint()
          ..color = const Color(0xFFE9C97A).withValues(alpha: 0.8)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(homeX - sgn * 15, restY + yA),
            Offset(homeX, restY + yA), arrowPaint);
        canvas.drawPath(
          Path()
            ..moveTo(homeX, restY + yA)
            ..lineTo(homeX - sgn * 5.5, restY + yA - 3.2)
            ..lineTo(homeX - sgn * 5.5, restY + yA + 3.2)
            ..close(),
          Paint()..color = const Color(0xFFE9C97A).withValues(alpha: 0.8),
        );
      }
    } else {
      // 右手弹弦：手自琴外侧伸来，甲背勾弦。
      // 指尖所指随出弦／入弦而异——入弦（向身）指向左下就弦而压，
      // 出弦（向外）指向左上挑弦而起，故两手之势一望可辨。
      final outward = cur.motion == 'pluck_up';
      // 起手时悬于弦外，触弦后方带上弦；拨罢即离，弦自振而去。
      final gap =
          24 * (1 - _ease(0.22, 0.36, localT)) + 22 * _ease(0.54, 0.94, localT);
      final pts = _sideFingerJoints(
          touch, 0.85, (math.pi - 0.35) * (outward ? -1 : 1),
          gap: gap);
      final paint = Paint()
        ..color = _kSkinRight.base
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i + 1 < pts.length; i++) {
        paint.strokeWidth = 9.0 - i * 1.6;
        canvas.drawLine(pts[i], pts[i + 1], paint);
      }
      // 指甲：甲背勾着弦
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: pts.last + const Offset(0, 1.5), width: 9, height: 8),
          const Radius.circular(3),
        ),
        Paint()..color = _kSkinRight.nail,
      );
      // 出弦（离面而起） / 入弦（向身而压）
      final a0 = Offset(px - 18, restY + dy * 0.5);
      final a1 = Offset(px - 18, restY + (outward ? -15 : 15));
      canvas.drawLine(
        a0,
        a1,
        Paint()
          ..color = const Color(0xFFE9C97A)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      final s = (a1.dy - a0.dy).sign;
      canvas.drawPath(
        Path()
          ..moveTo(a1.dx, a1.dy)
          ..lineTo(a1.dx - 4, a1.dy - s * 5.5)
          ..lineTo(a1.dx + 4, a1.dy - s * 5.5)
          ..close(),
        Paint()..color = const Color(0xFFE9C97A),
      );
    }

    _sideText(canvas, '侧视', Offset(rect.left + 7, rect.top + 5), 8.5,
        Colors.white.withValues(alpha: 0.5), false);
    // 手别：左手青玉、右手朱砂，与俯视中的手色相应
    _sideText(
      canvas,
      leftAction ? '左手' : '右手',
      Offset(rect.left + 34, rect.top + 5),
      9.5,
      leftAction ? const Color(0xFF8FD3B4) : const Color(0xFFE8A18C),
      true,
    );
    _sideText(canvas, _sideHint(cur), Offset(rect.right - 7, rect.top + 5), 8.5,
        const Color(0xFFE9C97A), true,
        rightAlign: true);
  }

  /// 侧视中的按弦深浅（0 不触弦，1 按至琴面）。
  double _pressDepth(_Step s, double localT) {
    switch (s.motion) {
      case 'press':
        return _ease(0.44, 0.72, localT) * 0.85;
      case 'harmonic':
        return _ease(0.44, 0.54, localT) *
            (1 - _ease(0.58, 0.72, localT)) *
            0.24;
      case 'slide':
        return _ease(0.44, 0.54, localT) * 0.80;
      case 'slide_up':
      case 'slide_down':
        return _ease(0.20, 0.40, localT) * 0.55 +
            _ease(0.50, 0.90, localT) * 0.25;
      default:
        return 0.0;
    }
  }

  /// 侧视中的拨弦形变：触弦前拉起至满，触弦后往复衰减。
  double _pluckAmp(_Step s, double localT) {
    if (localT < 0.36) return 0;
    if (localT < _contact) return (localT - 0.36) / (_contact - 0.36);
    final u = (localT - _contact) / (1 - _contact);
    return math.cos(u * math.pi * 4) * math.exp(-3.2 * u);
  }

  /// 侧视中弦之振动（以 maxDip 为单位）：左手取声之后弦自往复。
  /// 吟细密而不衰、猱深缓、按音泛音则渐止，与俯视之弦振同源。
  double _sideVib(_Step s, double localT) {
    if (localT < _contact) return 0;
    final u = (localT - _contact) / (1 - _contact);
    double base;
    var swing = 138.0;
    final double env;
    switch (s.motion) {
      case 'harmonic':
        base = 0.10;
        env = math.exp(-5.0 * u);
        break;
      case 'press':
        base = 0.14;
        env = math.exp(-4.0 * u);
        break;
      case 'slide':
        base = s.label == '猱' ? 0.22 : 0.11;
        swing = s.label == '猱' ? 26.0 : 96.0;
        env = 1.0 - u * 0.25; // 吟猱为持续之韵，仅略减
        break;
      default:
        base = 0.15;
        env = math.exp(-4.5 * u);
        break;
    }
    return base * env * math.sin(u * swing);
  }

  /// 侧视中一指的诸节：真角度累加，故屈伸成弧（区别于俯视的投影缩短）。
  ///
  /// [startAng] 为第一节的指向（屏幕坐标，+y 向下）；[curl] 越大则逐节折得越急。
  /// [gap] 为指尖离弦之距：整指沿其来路缩回，故未触弦时手自弦外而来。
  List<Offset> _sideFingerJoints(Offset tip, double curl, double startAng,
      {double gap = 0}) {
    const segs = [15.0, 12.0, 9.0];
    var ang = startAng;
    var p = Offset.zero;
    final pts = <Offset>[p];
    for (var i = 0; i < segs.length; i++) {
      p += Offset(math.cos(ang), math.sin(ang)) * segs[i];
      pts.add(p);
      ang -= curl * 0.22;
    }
    final span = pts.last - pts.first;
    final u = span.distance < 0.01 ? Offset.zero : span / span.distance;
    final off = tip - pts.last - u * gap;
    return [for (final q in pts) q + off];
  }

  String _sideHint(_Step s) => switch (s.motion) {
        'harmonic' => '轻点即离',
        'press' => '按弦入木',
        'slide' => '按实吟猱',
        'slide_up' => '绰·自低滑就',
        'slide_down' => '注·自高滑就',
        _ => _isLeftAction(s) ? '按弦' : '拨弦离面',
      };

  void _sideText(Canvas canvas, String text, Offset at, double size,
      Color color, bool bold,
      {bool rightAlign = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          height: 1.0,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color,
          fontFamily: AppTheme.serifFamily,
          fontFamilyFallback: AppTheme.serifFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rightAlign ? Offset(at.dx - tp.width, at.dy) : at);
  }

  // ------------------------------------------------------------ 基本量

  /// 平滑过渡（smoothstep）。
  double _ease(double a, double b, double t) {
    final u = ((t - a) / (b - a)).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  /// 某指诸节的位置（局部坐标，自指根至指尖）。
  ///
  /// 俯视琴面时看不见指节的侧面弯曲，屈起的指节只表现为「变短」并微微
  /// 向腕侧收拢，故此处以投影长度示屈伸：[curl] 越大，可见之指越短。
  List<Offset> _fingerJoints(_FingerGeom g, double curl) {
    final dir = Offset(math.sin(g.base), -math.cos(g.base));
    var p = g.root;
    var fold = 0.0;
    final pts = <Offset>[p];
    for (var i = 0; i < g.segs.length; i++) {
      final cosFold = math.cos(fold).clamp(0.12, 1.0);
      final len = g.segs[i];
      p += dir * (len * cosFold) + Offset(0, len * (1 - cosFold) * 0.55);
      pts.add(p);
      fold += curl * _kFlex[i];
    }
    return pts;
  }

  /// 某指的指尖（相对指根的偏移）。
  Offset _fingerTip(_FingerGeom g, double curl) =>
      _fingerJoints(g, curl).last - g.root;

  /// 某指全屈时的累计弯折量（弧度）。
  double _foldOf(_FingerGeom g, double curl) {
    var fold = 0.0;
    for (var i = 0; i < g.segs.length; i++) {
      fold += curl * _kFlex[i];
    }
    return fold;
  }

  /// 局部坐标 → 相对掌心的偏移（含镜像与腕部倾角）。
  Offset _rotate(Offset local, double tilt, bool mirror) {
    final lx = mirror ? -local.dx : local.dx;
    final c = math.cos(tilt);
    final s = math.sin(tilt);
    return Offset(lx * c - local.dy * s, lx * s + local.dy * c);
  }

  /// 虚线折线：用于指示指尖的动作轨迹。
  void _dashedPolyline(
      Canvas canvas, List<Offset> pts, Paint paint, double dash, double gap) {
    var carry = 0.0;
    var on = true;
    for (var i = 0; i + 1 < pts.length; i++) {
      var a = pts[i];
      final b = pts[i + 1];
      var len = (b - a).distance;
      if (len <= 0.01) continue;
      final dir = (b - a) / len;
      while (len > 0) {
        final step = math.min(len, (on ? dash : gap) - carry);
        final next = a + dir * step;
        if (on) canvas.drawLine(a, next, paint);
        a = next;
        len -= step;
        carry += step;
        if (carry >= (on ? dash : gap)) {
          carry = 0;
          on = !on;
        }
      }
    }
  }

  // ------------------------------------------------------------ 手的部件

  /// 小臂与腕（袖口束带一道）。
  void _paintArm(Canvas canvas, _Skin skin, double alpha) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(_kArmRect, const Radius.circular(15)),
      Paint()..color = skin.deep.withValues(alpha: alpha),
    );
    // 袖口：束带一道，标明腕之所在
    canvas.drawRect(
      const Rect.fromLTRB(-17, 40, 17, 56),
      Paint()..color = const Color(0xFF2A231C).withValues(alpha: 0.55 * alpha),
    );
    canvas.drawLine(
      const Offset(-17, 40),
      const Offset(17, 40),
      Paint()
        ..color = const Color(0xFFE9C97A).withValues(alpha: 0.35 * alpha)
        ..strokeWidth = 1.2,
    );
  }

  /// 手掌：掌身、拇指球与掌缘。
  void _paintPalm(Canvas canvas, _Skin skin, double alpha) {
    final rrect =
        RRect.fromRectAndRadius(_kPalmRect, const Radius.circular(18));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            skin.base.withValues(alpha: alpha),
            skin.deep.withValues(alpha: alpha),
          ],
        ).createShader(_kPalmRect),
    );
    canvas.drawCircle(
      Offset(_kPalmRect.right - 8, _kPalmRect.top + 22),
      14,
      Paint()..color = skin.base.withValues(alpha: alpha),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = skin.line.withValues(alpha: 0.5 * alpha),
    );
  }

  /// 一指：指身分节，屈伸以投影示之（俯视时屈起则显短），指端覆以指甲。
  /// [active] 时点出指节，见其屈伸之所在；[nail] 为该指触弦的甲肉比例
  /// （1 全用甲背，0 全用指肉），据此调整甲之长短明晦并补出指肉之厚。
  void _paintFinger(Canvas canvas, _FingerGeom g, double curl, double alpha,
      bool active, _Skin skin,
      [double nail = 1.0]) {
    final pts = _fingerJoints(g, curl);
    // 屈起则指端渐离视线：指甲随之变短、渐隐
    final cosFold = math.cos(_foldOf(g, curl) * 0.55).clamp(0.0, 1.0);

    // 轮廓
    final outline = Paint()
      ..color = skin.line.withValues(alpha: 0.5 * alpha)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i + 1 < pts.length; i++) {
      outline.strokeWidth = g.width * (1 - 0.13 * i) + 2.6;
      canvas.drawLine(pts[i], pts[i + 1], outline);
    }

    // 指身
    final body = Paint()
      ..color = (active ? skin.base : skin.deep).withValues(alpha: alpha)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i + 1 < pts.length; i++) {
      body.strokeWidth = g.width * (1 - 0.13 * i);
      canvas.drawLine(pts[i], pts[i + 1], body);
    }

    // 指甲（覆于指端背面）：用甲多则显，用肉多则隐而现指肉之厚
    if (cosFold > 0.12) {
      canvas.save();
      canvas.translate(pts.last.dx, pts.last.dy);
      canvas.rotate(g.base);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: const Offset(0, -5),
            width: 9,
            height: (11 * cosFold + 3) * (0.5 + 0.5 * nail),
          ),
          const Radius.circular(4),
        ),
        Paint()
          ..color = skin.nail.withValues(
              alpha: alpha * (0.35 + 0.65 * cosFold) * (0.35 + 0.65 * nail)),
      );
      canvas.restore();
    }
    if (active && nail < 0.55) {
      canvas.drawCircle(
        pts.last,
        g.width * 0.46,
        Paint()..color = skin.base.withValues(alpha: alpha),
      );
    }

    // 主手：点出指节，见其屈伸之所在
    if (active) {
      final mark = Paint()
        ..color = const Color(0xFFE9C97A).withValues(alpha: 0.7 * alpha);
      for (var i = 1; i < pts.length; i++) {
        canvas.drawCircle(pts[i], 2.2, mark);
      }
    }
  }

  /// 腕侧徽标：青玉为左手、朱砂为右手。绘于掌的靠外侧，一眼可辨。
  void _paintBadge(Canvas canvas, _HandPose pose, double alpha, Offset origin) {
    // 徽标贴在掌外侧的腕上，既不越出画布，也不与弦、指相扰
    final p =
        origin + _rotate(Offset(-46 * _k, 18 * _k), pose.tilt, pose.mirror);
    final isLeft = !pose.mirror;
    final r = 9.0 + 4.0 * _k;
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..color = (isLeft ? AppColors.jade : AppColors.cinnabar)
            .withValues(alpha: alpha),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.85 * alpha),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: isLeft ? '左' : '右',
        style: TextStyle(
          fontSize: r * 1.05,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: alpha),
          fontFamily: AppTheme.serifFamily,
          fontFamilyFallback: AppTheme.serifFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FingeringPainter old) =>
      old.t != t ||
      old.sideView != sideView ||
      old.showSupportHand != showSupportHand ||
      !_sameSteps(old.steps, steps);

  bool _sameSteps(List<_Step> a, List<_Step> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label ||
          a[i].leftMotion != b[i].leftMotion ||
          a[i].leftLabel != b[i].leftLabel ||
          a[i].rightMotion != b[i].rightMotion ||
          a[i].rightLabel != b[i].rightLabel ||
          a[i].hui != b[i].hui ||
          a[i].string != b[i].string) {
        return false;
      }
    }
    return true;
  }
}

/// 右手六法之别：抬手高低、腕转、甲肉比例与触弦部位。
///
/// 八法之异，不在「弹弦」一事，而在用指之肉甲、出弦之方向与腕臂之助：
/// 甲背者（挑、剔、摘）出音清越而亮，须抬指略高；指肉者（擘、托、勾、打）
/// 出音浑厚而温，宜贴弦而发。
class _RightTech {
  final double lift; // 抬手高低（0 贴弦，1 高抬）
  final double wrist; // 腕转（叠加于腕的倾角，弧度）
  final double nail; // 甲肉比例：1 全甲背，0 全指肉
  final String part; // 触弦部位之注记
  const _RightTech(this.lift, this.wrist, this.nail, this.part);
}

const _kRightTechDefault = _RightTech(0.55, 0.0, 0.55, '甲肉相半');

const _kRightTech = <String, _RightTech>{
  '散音': _RightTech(0.65, 0.02, 0.60, '指肉弹弦'),
  '擘': _RightTech(0.50, 0.10, 0.20, '指肉侧锋'),
  '托': _RightTech(0.40, -0.06, 0.35, '指腹'),
  '抹': _RightTech(0.38, -0.05, 0.55, '甲肉相半'),
  '挑': _RightTech(0.85, 0.12, 0.90, '甲背'),
  '勾': _RightTech(0.32, -0.04, 0.25, '指肉'),
  '剔': _RightTech(0.80, 0.10, 0.92, '甲背'),
  '打': _RightTech(0.55, 0.04, 0.30, '指肉借腕'),
  '摘': _RightTech(0.90, 0.14, 0.88, '甲背'),
};

/// 一只手的姿态快照。
///
/// [tip] 为活动指的指尖（画布坐标），[contact] 为触弦点，[finger] 为活动指的
/// 序号（对应 [_kFingers]：0 大指、1 食指、2 中指、3 名指、4 小指），[curl] 为
/// 该指的屈伸量（0 伸直、1 屈曲），[tilt] 为腕的倾角，[mirror] 为真即右手
/// （与左手互为镜像），[glow] 为触弦高光强度，[nail] 为活动指的甲肉比例，
/// [caption] 为该手的动作注记。
class _HandPose {
  final Offset tip;
  final Offset contact;
  final int finger;
  final double curl;
  final double tilt;
  final bool mirror;
  final double glow;
  final double nail;
  final String caption;
  const _HandPose({
    required this.tip,
    required this.contact,
    required this.finger,
    required this.curl,
    required this.tilt,
    required this.mirror,
    required this.glow,
    required this.nail,
    required this.caption,
  });
}

/// 琴人肤色：右手暖白、左手略深，与腕侧徽标（右朱砂、左青玉）相呼应。
class _Skin {
  final Color base;
  final Color deep;
  final Color line;
  final Color nail;
  const _Skin(this.base, this.deep, this.line, this.nail);
}

const _kSkinRight = _Skin(
  Color(0xFFF5DCBA),
  Color(0xFFDCB88E),
  Color(0xFFB08A63),
  Color(0xFFFBF1E2),
);

const _kSkinLeft = _Skin(
  Color(0xFFE4C6A4),
  Color(0xFFC6A078),
  Color(0xFF9C7A55),
  Color(0xFFF6E9D8),
);

/// 一指的几何（局部坐标：原点在掌心，-y 指向指尖）。
///
/// [root] 为指根，[base] 为指根的朝向（弧度，0 即竖直向上），[segs] 为各指节
/// 的长度，[width] 为指根的粗细。
class _FingerGeom {
  final Offset root;
  final double base;
  final List<double> segs;
  final double width;
  const _FingerGeom(this.root, this.base, this.segs, this.width);
}

/// 五指几何，下标与 [_HandPose.finger] 一致。
///
/// 局部坐标为掌心俯视（手背朝外）：+y 沿小臂而下，-y 指向指尖，+x 为拇指一侧。
/// 故本表所绘即左手——拇指在掌的内侧（朝画面中央）、小指在外侧；右手取其镜像。
const _kFingers = <_FingerGeom>[
  // 大指：自掌侧斜出，短而壮
  _FingerGeom(Offset(33, -26), 0.46, [26, 22], 15.5),
  // 食指
  _FingerGeom(Offset(22, -42), 0.10, [26, 22, 18], 13.2),
  // 中指：最长，略偏于掌中
  _FingerGeom(Offset(2, -48), 0.0, [29, 24, 19], 14.0),
  // 名指
  _FingerGeom(Offset(-18, -43), -0.11, [25, 21, 17], 12.6),
  // 小指：最短，贴于掌缘
  _FingerGeom(Offset(-32, -34), -0.28, [21, 17], 11.0),
];

/// 各指节全屈时转过的角度（弧度，按指节自根向端计）：掌指关节最活、
/// 末节最钝，合之约为一只拳的弯折量。
const _kFlex = <double>[0.90, 1.10, 0.70];

const _kFingerNames = <String>['大指', '食指', '中指', '名指', '小指'];

const _kCnNumeral = <String, int>{
  '一': 1,
  '二': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
  '十': 10,
  '十一': 11,
  '十二': 12,
  '十三': 13,
};

/// 小臂与掌（原点在掌心，-y 指向指尖，+y 沿小臂而下）。
const _kArmRect = Rect.fromLTRB(-17, 4, 17, 56);
const _kPalmRect = Rect.fromLTRB(-38, -44, 38, 12);
