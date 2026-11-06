import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/guqin_sound.dart';
import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../data/app_database.dart';
import '../../theme/app_theme.dart';

/// 功能二：古琴三维展示。
/// 采用轻量化自绘 3D（透视投影 + 画家算法 + 简易光照）离线渲染琴身、七弦与十三徽，
/// 支持拖拽旋转、双指缩放、自动旋转；生产环境可替换为 model_viewer_plus + GLB。
class ModelPage extends StatefulWidget {
  const ModelPage({super.key});

  @override
  State<ModelPage> createState() => _ModelPageState();
}

class _ModelPageState extends State<ModelPage> with TickerProviderStateMixin {
  double _yaw = -0.6;
  double _pitch = 0.55;
  double _scale = 1.0;
  double _lastScale = 1.0;
  int _styleIndex = 0;
  int _detailIndex = 0;
  bool _autoRotate = true;
  bool _perspective = true;

  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat();
  late final TabController _details = TabController(length: 4, vsync: this);

  /// 七弦拨弦余振进度（1=静止），0 起随时间衰减。
  final List<double> _pluckAge = List.filled(7, 1.0);
  late final AnimationController _vibe =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  static const _styles = ['仲尼', '连珠', '落霞'];
  static const _detailTabs = ['形制', '名琴', '音色', '身世'];
  static const _detailText = [
    [
      ('琴式源流', '仲尼式为古琴常见形制之一，琴首圆润，项腰收放有度，整体端庄简雅。'),
      ('形制特点', '琴体线条简洁，肩、腰曲线含蓄，适合观察古琴由琴首至琴尾的轮廓变化。'),
    ],
    [
      ('琴式源流', '连珠式以连贯圆转的轮廓见长，琴体曲线衔接流畅，如珠相连。'),
      ('形制特点', '琴肩与琴腰的曲线更为饱满，适合对照观察不同琴式的比例与收束。'),
    ],
    [
      ('琴式源流', '落霞式以舒展灵动的外形为特色，琴体轮廓富有变化。'),
      ('形制特点', '琴首、琴腰与琴尾的线条更显轻盈，可与仲尼式的端正轮廓比较。'),
    ],
  ];
  static const _detailContent = [
    [
      ('琴体结构', '琴面承弦，底板与琴面合围成共鸣腔。岳山承托琴弦，龙池、凤沼帮助琴体发声。'),
      ('十三徽', '琴面徽位标记泛音位置，七徽位于弦长中点。画面中的圆点对应十三徽。'),
    ],
    [
      ('传世名琴', '古琴名琴常以斫制者、收藏者或流传故事闻名。不同形制的琴体也留下了各自的审美印记。'),
      ('欣赏提示', '观察琴体轮廓、断纹与漆色时，可结合题跋、铭文和传承记录了解其来历。'),
    ],
    [
      ('七弦', '古琴设七弦，由外向内依次对应宫、商、角、徵、羽、少宫、少商。'),
      ('音色特点', '古琴音色含蓄而有层次，散音浑厚，泛音清越，按音则随左手吟猱产生细微变化。'),
    ],
    [
      ('千年琴史', '古琴承载着礼乐、文人生活与传习传统。琴式演变也映照了历代审美与斫琴技艺。'),
      ('琴人相传', '从制琴、调弦到操缦，琴文化依靠师承与谱本延续，并于2003年列入联合国教科文组织人类非物质文化遗产代表作名录。'),
    ],
  ];

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.bumpProgress('model_views');
    unawaited(GuqinSound.instance.preload(GuqinSound.stringSet('open')));
    unawaited(GuqinSound.instance.preload(GuqinSound.stringSet('harm')));
    _details.addListener(() {
      if (_details.index != _detailIndex) {
        setState(() => _detailIndex = _details.index);
      }
    });
  }

  @override
  void dispose() {
    _details.dispose();
    _spin.dispose();
    _vibe.dispose();
    unawaited(GuqinSound.instance.stopAll());
    super.dispose();
  }

  void _reset() {
    setState(() {
      _yaw = -0.6;
      _pitch = 0.55;
      _scale = 1.0;
      _autoRotate = true;
    });
  }

  /// 点弦即拨；点在徽位附近则出泛音。
  void _onTapQin(Offset local, Size viewSize) {
    final yaw = _autoRotate ? _yaw + _spin.value * 2 * math.pi : _yaw;
    Offset sp(V3 p) => Guqin3DPainter.projectPoint(
          viewSize,
          yaw: yaw,
          pitch: _pitch,
          scale: _scale,
          perspective: _perspective,
          p: p,
        );
    final mid = Guqin3DPainter.halfWidth(
            Guqin3DPainter._zStart + Guqin3DPainter._len * 0.5, _styleIndex) *
        0.74;
    var best = -1, bestD = 34.0;
    for (var i = 0; i < 7; i++) {
      final x = -mid + 2 * mid * i / 6;
      final c = sp(V3(x, Guqin3DPainter._halfThick + 0.03,
          Guqin3DPainter._zStart + Guqin3DPainter._len * 0.5));
      final d = (c - local).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best < 0) return;

    var harmonic = false;
    for (final f in Guqin3DPainter._huiFractions) {
      final hp = sp(V3(0, Guqin3DPainter._halfThick + 0.006,
          Guqin3DPainter._zStart + 0.03 + Guqin3DPainter._stringLen * f));
      if ((hp - local).distance < 20) {
        harmonic = true;
        break;
      }
    }

    setState(() => _pluckAge[best] = 0);
    GuqinSound.instance.play(
      GuqinSound.file(harmonic ? 'harm' : 'open', best),
      volume: 0.9,
    );
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return InkScaffold(
      appBar: AppBar(
        title: const Text('古琴三维展示'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _autoRotate = !_autoRotate),
            icon: Icon(_autoRotate ? Icons.pause : Icons.play_arrow, size: 18),
            label: Text(_autoRotate ? '暂停' : '旋转'),
            style: TextButton.styleFrom(foregroundColor: AppColors.ink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          Text(
            '琴式 · ${_styles[_styleIndex]}式',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          PaperCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SizedBox(
                  height: 340,
                  child: LayoutBuilder(
                    builder: (context, bc) {
                      final viewSize = Size(bc.maxWidth, bc.maxHeight);
                      return GestureDetector(
                        onScaleStart: (_) => _lastScale = _scale,
                        onTapDown: (d) => _onTapQin(d.localPosition, viewSize),
                        onScaleUpdate: (d) {
                          setState(() {
                            _yaw += d.focalPointDelta.dx * 0.008;
                            _pitch = (_pitch + d.focalPointDelta.dy * 0.006)
                                .clamp(-1.2, 1.2)
                                .toDouble();
                            if (d.pointerCount > 1) {
                              _scale = (_lastScale * d.scale)
                                  .clamp(0.6, 2.4)
                                  .toDouble();
                            }
                            _autoRotate = false;
                          });
                        },
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_spin, _vibe]),
                          builder: (context, _) {
                            final yaw = _autoRotate
                                ? _yaw + _spin.value * 2 * math.pi
                                : _yaw;
                            // 逐弦衰减余振
                            for (var i = 0; i < 7; i++) {
                              if (_pluckAge[i] < 1) {
                                _pluckAge[i] =
                                    math.min(1.0, _pluckAge[i] + 0.016 / 1.6);
                              }
                            }
                            return CustomPaint(
                              painter: Guqin3DPainter(
                                yaw: yaw,
                                pitch: _pitch,
                                scale: _scale,
                                perspective: _perspective,
                                styleIndex: _styleIndex,
                                pluckAges: List.of(_pluckAge),
                                vibratePhase: _vibe.value,
                              ),
                              size: Size.infinite,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    '拖动旋转 · 双指缩放 · 点弦即拨 · 点徽为泛音',
                    style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _styles.length; i++)
                ChoiceChip(
                  label: Text('${_styles[i]}式'),
                  selected: _styleIndex == i,
                  onSelected: (_) => setState(() => _styleIndex = i),
                  selectedColor: AppColors.jade.withValues(alpha: 0.16),
                  side: BorderSide(
                    color: _styleIndex == i ? AppColors.jade : AppColors.line,
                  ),
                  labelStyle: TextStyle(
                    color:
                        _styleIndex == i ? AppColors.jade : AppColors.inkSoft,
                  ),
                ),
              _controlChip(
                icon: _perspective
                    ? Icons.view_in_ar
                    : Icons.view_agenda_outlined,
                label: '透视',
                selected: _perspective,
                onTap: () => setState(() => _perspective = !_perspective),
              ),
              _controlChip(
                icon: Icons.restart_alt,
                label: '复位',
                selected: false,
                onTap: _reset,
              ),
            ],
          ),
          const SizedBox(height: 20),
          TabBar(
            controller: _details,
            labelColor: AppColors.cinnabar,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.cinnabar,
            tabs: [for (final tab in _detailTabs) Tab(text: tab)],
          ),
          const SizedBox(height: 14),
          for (final section in _detailContent[_detailIndex])
            PaperCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.$1,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(section.$2,
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.8,
                          color: AppColors.inkSoft)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            _detailText[_styleIndex]
                .map((item) => '${item.$1}：${item.$2}')
                .join('\n\n'),
            style: const TextStyle(
                fontSize: 12, height: 1.8, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _controlChip({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
      backgroundColor:
          selected ? AppColors.jade.withValues(alpha: 0.12) : AppColors.paper,
      side: BorderSide(color: selected ? AppColors.jade : AppColors.line),
      labelStyle: TextStyle(
          fontSize: 12, color: selected ? AppColors.jade : AppColors.inkSoft),
    );
  }
}

/// 三维点。
class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);
  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  double get length => math.sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l == 0 ? const V3(0, 0, 0) : V3(x / l, y / l, z / l);
  }

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
}

/// 古琴轻量化三维画笔。
class Guqin3DPainter extends CustomPainter {
  final double yaw;
  final double pitch;
  final double scale;
  final bool showStrings;
  final bool perspective;
  final int styleIndex;

  /// 高亮徽位（0 起，对应一徽…十三徽）；-1 为不高亮。
  final int highlightHui;

  /// 高亮弦（0 起，对应一弦…七弦）；-1 为不高亮。
  final int highlightString;

  /// 高亮呼吸相位 0..1，用于脉冲光晕。
  final double pulse;

  /// 七弦余振进度（1=静止）。
  final List<double> pluckAges;

  /// 振动相位 0..1。
  final double vibratePhase;

  Guqin3DPainter({
    required this.yaw,
    required this.pitch,
    required this.scale,
    this.showStrings = true,
    this.perspective = true,
    this.styleIndex = 0,
    this.highlightHui = -1,
    this.highlightString = -1,
    this.pulse = 0,
    this.pluckAges = const [],
    this.vibratePhase = 0,
  });

  // 十三徽对应的弦长比例（自岳山起）
  static const _huiFractions = [
    1 / 8,
    1 / 6,
    1 / 5,
    1 / 4,
    1 / 3,
    2 / 5,
    1 / 2,
    3 / 5,
    2 / 3,
    3 / 4,
    4 / 5,
    5 / 6,
    7 / 8,
  ];

  static const double _len = 3.0; // 琴身长度（模型单位）
  static const double _zStart = -1.5;
  static const double _halfThick = 0.05;
  static const double _stringLen = 3.0;
  static const _surfaceColors = [
    Color(0xFF9A6E44),
    Color(0xFF8A6243),
    Color(0xFFA5784D),
  ];
  static const _sideColors = [
    Color(0xFF6B4A2F),
    Color(0xFF5D4230),
    Color(0xFF765438),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + size.height * 0.06;
    final base = math.min(size.width, size.height) * 0.30 * scale;

    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosP = math.cos(pitch), sinP = math.sin(pitch);

    // 世界 -> 视图 -> 屏幕
    V3 rot(V3 p) {
      final x1 = p.x * cosY + p.z * sinY;
      final z1 = -p.x * sinY + p.z * cosY;
      final y2 = p.y * cosP - z1 * sinP;
      final z2 = p.y * sinP + z1 * cosP;
      return V3(x1, y2, z2);
    }

    Offset project(V3 p) {
      final v = rot(p);
      final f = perspective ? 3.2 / (3.2 + v.z + 1.2) : 1.0;
      return Offset(cx + v.x * base * f, cy - v.y * base * f);
    }

    double depth(V3 p) => rot(p).z;

    // 光照方向（视图空间固定）
    const lightDir = V3(-0.4, 0.85, 0.5);

    final faces = <_Face>[];
    final style = styleIndex.clamp(0, 2).toInt();

    // 沿琴身长度分段构建面板 / 底板 / 侧墙
    const steps = 36;
    for (var i = 0; i < steps; i++) {
      final z0 = _zStart + _len * i / steps;
      final z1 = _zStart + _len * (i + 1) / steps;
      final w0 = halfWidth(z0, style);
      final w1 = halfWidth(z1, style);

      void addQuad(List<V3> pts, Color color) => faces.add(_Face(pts, color));

      // 面板（上表面 y = +halfThick）
      addQuad([
        V3(-w0, _halfThick, z0),
        V3(w0, _halfThick, z0),
        V3(w1, _halfThick, z1),
        V3(-w1, _halfThick, z1),
      ], _surfaceColors[style]);

      // 底板
      addQuad([
        V3(-w0, -_halfThick, z0),
        V3(-w1, -_halfThick, z1),
        V3(w1, -_halfThick, z1),
        V3(w0, -_halfThick, z0),
      ], const Color(0xFF4A3220));

      // 左 / 右侧墙
      addQuad([
        V3(-w0, _halfThick, z0),
        V3(-w1, _halfThick, z1),
        V3(-w1, -_halfThick, z1),
        V3(-w0, -_halfThick, z0),
      ], _sideColors[style]);
      addQuad([
        V3(w0, _halfThick, z0),
        V3(w0, -_halfThick, z0),
        V3(w1, -_halfThick, z1),
        V3(w1, _halfThick, z1),
      ], _sideColors[style]);
    }

    // 岳山（承弦之高骨）
    faces.add(_Face([
      const V3(-0.24, _halfThick, _zStart),
      const V3(0.24, _halfThick, _zStart),
      const V3(0.24, _halfThick + 0.045, _zStart),
      const V3(-0.24, _halfThick + 0.045, _zStart),
    ], const Color(0xFF3E2A1A)));

    // 按深度排序（远 -> 近），画家算法
    faces.sort((a, b) => b.avgDepth(depth).compareTo(a.avgDepth(depth)));

    for (final f in faces) {
      final n = f.normal();
      final lit = (n.dot(lightDir)).clamp(-1.0, 1.0).toDouble();
      final shade = 0.62 + 0.38 * ((lit + 1) / 2);
      final paint = Paint()..color = _shade(f.color, shade);
      final path = Path();
      final pts = f.points.map(project).toList();
      path.moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = Colors.black.withValues(alpha: 0.10),
      );
    }

    // 十三徽
    for (var i = 0; i < _huiFractions.length; i++) {
      final z = _zStart + 0.03 + _stringLen * _huiFractions[i];
      final p = project(V3(0, _halfThick + 0.006, z));
      final isKey = i == 6;
      final r = isKey ? 4.6 : 3.2;
      final on = highlightHui == i;
      if (on) {
        final glow = 0.6 + 0.4 * pulse;
        canvas.drawCircle(
          p,
          r + 4.5 * glow,
          Paint()
            ..color = const Color(0xFFE9C97A).withValues(alpha: 0.42 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawCircle(
        p,
        r * (on ? 1.35 : 1.0),
        Paint()
          ..color = on
              ? const Color(0xFFFFE9A8)
              : (isKey ? const Color(0xFFE9C97A) : const Color(0xFFF3E6CE)),
      );
      canvas.drawCircle(
        p,
        r * (on ? 1.35 : 1.0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = on ? 1.6 : 0.8
          ..color =
              on ? AppColors.cinnabar : Colors.black.withValues(alpha: 0.28),
      );
    }

    // 七弦（可振动：拨过后随相位起伏）
    if (showStrings) {
      final spread = halfWidth(_zStart + _len * 0.5, style) * 0.74;
      for (var i = 0; i < 7; i++) {
        final x = -spread + 2 * spread * i / 6;
        final age = i < pluckAges.length ? pluckAges[i] : 1.0;
        final amp = age < 1 ? 0.025 * (1 - age) * math.exp(-2.0 * age) : 0.0;
        final on = highlightString == i;

        // 沿弦长采样，拨过时中间微微起伏
        final pts = <Offset>[];
        const N = 28;
        for (var s = 0; s <= N; s++) {
          final tz = s / N;
          final z = _zStart + 0.03 + tz * _stringLen;
          final env = math.sin(tz * math.pi);
          final dy =
              amp * env * math.sin(tz * math.pi * 1.5 - vibratePhase * 22);
          pts.add(project(V3(x, _halfThick + 0.03 + dy, z)));
        }
        if (on) {
          final glow = 0.6 + 0.4 * pulse;
          final glowPath = Path()..moveTo(pts.first.dx, pts.first.dy);
          for (final p in pts.skip(1)) {
            glowPath.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(
            glowPath,
            Paint()
              ..color = const Color(0xFFFFE9A8).withValues(alpha: 0.55 * glow)
              ..strokeWidth = 6.0
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
          );
        }
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final p in pts.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = on ? const Color(0xFFFFDFA0) : const Color(0xFFF6EEDC)
            ..strokeWidth = (1.0 + i * 0.16) * (on ? 1.9 : 1.0)
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // 地面投影
    final shadowPath = Path();
    final sPts = [
      const V3(-1.0, -_halfThick - 0.6, _zStart),
      const V3(1.0, -_halfThick - 0.6, _zStart),
      const V3(1.0, -_halfThick - 0.6, _zStart + _len),
      const V3(-1.0, -_halfThick - 0.6, _zStart + _len),
    ].map(project).toList();
    shadowPath.moveTo(sPts.first.dx, sPts.first.dy);
    for (final p in sPts.skip(1)) {
      shadowPath.lineTo(p.dx, p.dy);
    }
    shadowPath.close();
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  /// 琴身半宽（含项、腰曲线）。
  static double halfWidth(double z, int style) {
    final t = (z - _zStart) / _len; // 0..1
    var w = 0.28;
    // 项（琴头一侧收窄）
    if (t < 0.16) {
      w *= 0.72 + 0.28 * (t / 0.16);
    }
    // Each selection gives the silhouette a distinct, stylized waist profile.
    final waistStart = style == 1 ? 0.58 : 0.62;
    final waistEnd = style == 1 ? 0.88 : 0.86;
    final waistDepth = style == 1 ? 0.08 : (style == 2 ? 0.22 : 0.16);
    if (t > waistStart && t < waistEnd) {
      w *= 1 -
          waistDepth *
              math.sin(math.pi * (t - waistStart) / (waistEnd - waistStart));
    }
    // 尾端微收
    if (t > 0.94) {
      final tailTaper = style == 2 ? 0.12 : 0.06;
      w *= 1 - tailTaper * (t - 0.94) / 0.06;
    }
    return w;
  }

  Color _shade(Color c, double k) => Color.fromARGB(
        255,
        (c.r * 255 * k).clamp(0, 255).round(),
        (c.g * 255 * k).clamp(0, 255).round(),
        (c.b * 255 * k).clamp(0, 255).round(),
      );

  @override
  bool shouldRepaint(covariant Guqin3DPainter old) =>
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.scale != scale ||
      old.showStrings != showStrings ||
      old.perspective != perspective ||
      old.styleIndex != styleIndex ||
      old.highlightHui != highlightHui ||
      old.highlightString != highlightString ||
      old.pulse != pulse ||
      old.vibratePhase != vibratePhase ||
      old.pluckAges.join() != pluckAges.join();

  /// 与 [paint] 相同的投影，供命中测试用。
  static Offset projectPoint(
    Size size, {
    required double yaw,
    required double pitch,
    required double scale,
    required bool perspective,
    required V3 p,
  }) {
    final cx = size.width / 2;
    final cy = size.height / 2 + size.height * 0.06;
    final base = math.min(size.width, size.height) * 0.30 * scale;
    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosP = math.cos(pitch), sinP = math.sin(pitch);
    final x1 = p.x * cosY + p.z * sinY;
    final z1 = -p.x * sinY + p.z * cosY;
    final y2 = p.y * cosP - z1 * sinP;
    final z2 = p.y * sinP + z1 * cosP;
    final f = perspective ? 3.2 / (3.2 + z2 + 1.2) : 1.0;
    return Offset(cx + x1 * base * f, cy - y2 * base * f);
  }
}

class _Face {
  final List<V3> points;
  final Color color;
  _Face(this.points, this.color);

  double avgDepth(double Function(V3) depth) {
    var sum = 0.0;
    for (final p in points) {
      sum += depth(p);
    }
    return sum / points.length;
  }

  V3 normal() {
    if (points.length < 3) return const V3(0, 1, 0);
    final a = points[1] - points[0];
    final b = points[2] - points[0];
    return a.cross(b).normalized;
  }
}

/// 古琴三维缩略预览：自动缓旋，可高亮指定【徽位 · 弦】。
///
/// 用于减字拆解时联动示意——「九徽、一弦」在琴面何处，一看便知。
class Guqin3DPreview extends StatefulWidget {
  /// 徽位 1..13；0 表示不高亮。
  final int hui;

  /// 弦序 1..7；0 表示不高亮。
  final int stringNum;

  final double height;

  const Guqin3DPreview({
    super.key,
    this.hui = 0,
    this.stringNum = 0,
    this.height = 104,
  });

  @override
  State<Guqin3DPreview> createState() => _Guqin3DPreviewState();
}

class _Guqin3DPreviewState extends State<Guqin3DPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return CustomPaint(
            painter: Guqin3DPainter(
              yaw: -0.5 + math.sin(t * 2 * math.pi) * 0.35,
              pitch: 0.5 + math.sin(t * 2 * math.pi * 2) * 0.05,
              scale: 1.0,
              highlightHui: widget.hui > 0 ? widget.hui - 1 : -1,
              // 一弦最粗（弦径随序号递减），故弦序 n → 索引 7-n。
              highlightString: widget.stringNum > 0 ? 7 - widget.stringNum : -1,
              pulse: (math.sin(t * 2 * math.pi * 3) + 1) / 2,
            ),
          );
        },
      ),
    );
  }
}
