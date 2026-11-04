import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/guqin_sound.dart';
import '../../data/app_database.dart';

/// 功能八：数字琴境体验。
///
/// 三境沉浸式场景——「山林 · 书斋 · 月夜」，每境配一幅自绘古风画面、
/// 一首真人演奏的琴曲背景乐（循环）与一段氛围音（松风 / 檐雨 / 夜虫，循环），
/// 画面上的七弦可触可划，拨弦即出散音、多弦可同时余振。
/// 一境之内，曲、声、景相和，营造抚琴的氛围感。
class RealmPage extends StatefulWidget {
  const RealmPage({super.key});

  @override
  State<RealmPage> createState() => _RealmPageState();
}

/// 一境：场景名 + 题画诗 + 配曲 + 氛围音。
class _Scene {
  const _Scene({
    required this.name,
    required this.title,
    required this.poem,
    required this.slug,
    required this.piece,
    required this.ambience,
    required this.ambienceName,
  });

  /// 场景名（山林 / 书斋 / 月夜）。
  final String name;

  /// 场景题名。
  final String title;

  /// 题画诗。
  final String poem;

  /// 背景琴曲的资源标识（assets/audio/<slug>.mp3）。
  final String slug;

  /// 背景琴曲曲名。
  final String piece;

  /// 氛围音文件名（assets/audio/sfx/ 之下）。
  final String ambience;

  /// 氛围音名（松风 / 檐雨 / 夜虫）。
  final String ambienceName;
}

const List<_Scene> _scenes = [
  _Scene(
    name: '山林',
    title: '空山抚琴',
    poem: '空山新雨，松风入弦',
    slug: 'liushui',
    piece: '流水',
    ambience: 'amb_forest.m4a',
    ambienceName: '松风',
  ),
  _Scene(
    name: '书斋',
    title: '明窗净几',
    poem: '炉香乍爇，弦上读易',
    slug: 'kongziduyi',
    piece: '孔子读易',
    ambience: 'amb_study.m4a',
    ambienceName: '檐雨',
  ),
  _Scene(
    name: '月夜',
    title: '月下横琴',
    poem: '月落平沙，雁影泠泠',
    slug: 'pingsha',
    piece: '平沙落雁',
    ambience: 'amb_night.m4a',
    ambienceName: '夜虫',
  ),
];

class _RealmPageState extends State<RealmPage> with TickerProviderStateMixin {
  static const _stringLabels = ['宫', '商', '角', '徵', '羽', '少宫', '少商'];

  /// 背景琴曲（真人录音，循环）。
  final AudioPlayer _music = AudioPlayer();

  /// 氛围音（循环）。
  final AudioPlayer _ambience = AudioPlayer();

  late final AnimationController _ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

  /// 七根弦各自的拨动进度（1.0 为静止）。逐弦独立，连续划弦时
  /// 多弦可同时余振，形成「弦上流水」的叠加听感。
  final List<double> _pluckAge = List.filled(7, 1.0);
  final List<double> _pluckX = List.filled(7, 0.0);
  static const _pluckSeconds = 1.4;

  final Stopwatch _clock = Stopwatch();
  double _lastElapsed = 0;

  int _realm = 0;
  int _plucked = -1;
  bool _sound = true;
  bool _loading = false;
  int _session = 0;

  _Scene get _scene => _scenes[_realm];

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.bumpProgress('realm_views');
    // 预建播放器，触弦即为瞬时发声
    unawaited(GuqinSound.instance.preload(GuqinSound.stringSet('open')));
    _ambient.addListener(_advance);
    _clock.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_applyScene()));
  }

  /// 由环境动画逐帧驱动弦振衰减。
  void _advance() {
    final now = _clock.elapsedMicroseconds / 1e6;
    final dt = (now - _lastElapsed).clamp(0.0, 0.1);
    _lastElapsed = now;
    if (dt <= 0) return;
    for (var i = 0; i < _pluckAge.length; i++) {
      if (_pluckAge[i] < 1) {
        _pluckAge[i] = math.min(1.0, _pluckAge[i] + dt / _pluckSeconds);
      }
    }
  }

  @override
  void dispose() {
    _session++;
    _ambient.removeListener(_advance);
    _ambient.dispose();
    unawaited(_music.dispose());
    unawaited(_ambience.dispose());
    // 离开琴境即停止余响，避免返回主页后琴音仍在响
    unawaited(GuqinSound.instance.stopAll());
    super.dispose();
  }

  // ---------------------------------------------------------------- 音频

  /// 载入当前境的琴曲与氛围音；[_sound] 为真则随即起奏。
  Future<void> _applyScene() async {
    final session = ++_session;
    final scene = _scene;
    setState(() => _loading = true);
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.42);
      await _music.setSource(AssetSource('audio/${scene.slug}.mp3'));
      await _ambience.setReleaseMode(ReleaseMode.loop);
      await _ambience.setVolume(0.30);
      await _ambience.setSource(AssetSource('audio/sfx/${scene.ambience}'));
      if (_sound) {
        await _music.resume();
        await _ambience.resume();
      }
    } catch (e) {
      debugPrint('琴境音频载入失败：$e');
    }
    if (!mounted || session != _session) return;
    setState(() => _loading = false);
  }

  void _switchRealm(int i) {
    if (i == _realm) return;
    setState(() {
      _realm = i;
      _plucked = -1;
    });
    unawaited(_applyScene());
  }

  void _toggleSound() {
    setState(() => _sound = !_sound);
    if (_sound) {
      unawaited(_music.resume());
      unawaited(_ambience.resume());
    } else {
      unawaited(_music.pause());
      unawaited(_ambience.pause());
    }
  }

  // ---------------------------------------------------------------- 交互

  void _onInteraction(Offset local, Size size) {
    // 依据纵向位置判断所触琴弦
    final regionTop = size.height * 0.62;
    final regionBottom = size.height * 0.92;
    if (local.dy < regionTop - 26 || local.dy > regionBottom + 26) return;
    final ratio =
        ((local.dy - regionTop) / (regionBottom - regionTop)).clamp(0.0, 1.0).toDouble();
    final index = (ratio * 6).round();

    // 同一根弦余振未消则不重复触发；划奏换弦不受限制
    if (_pluckAge[index] < 0.12) return;

    _pluckAge[index] = 0;
    _pluckX[index] = local.dx.clamp(0.0, size.width).toDouble();
    setState(() => _plucked = index);

    GuqinSound.instance.play(GuqinSound.file('open', index), volume: 0.9);
    HapticFeedback.lightImpact();
    AppDatabase.instance.bumpProgress('realm_plucks');
  }

  // ---------------------------------------------------------------- 视图

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    return Scaffold(
      backgroundColor: AppColorsNight.base,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onTapDown: (d) => _onInteraction(d.localPosition, size),
            onPanUpdate: (d) => _onInteraction(d.localPosition, size),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) => CustomPaint(
                    painter: RealmPainter(
                      realm: _realm,
                      ambient: _ambient.value,
                      plucks: List<double>.of(_pluckAge),
                      pluckXs: List<double>.of(_pluckX),
                    ),
                    size: size,
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                              color: Colors.white,
                            ),
                            const Spacer(),
                            ...List.generate(_scenes.length, (i) {
                              final on = i == _realm;
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: GestureDetector(
                                  onTap: () => _switchRealm(i),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: on ? 0.22 : 0.08),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: on ? 0.6 : 0.2)),
                                    ),
                                    child: Text(
                                      _scenes[i].name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        letterSpacing: 2,
                                        color: Colors.white
                                            .withValues(alpha: on ? 1 : 0.7),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          scene.title,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 24,
                            height: 1.4,
                            letterSpacing: 6,
                            fontWeight: FontWeight.w300,
                            fontFamily: 'Songti SC',
                            fontFamilyFallback: const ['STSong', 'Kaiti SC', 'serif'],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scene.poem,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 14,
                            height: 1.6,
                            letterSpacing: 3,
                          ),
                        ),
                        const Spacer(),
                        if (_plucked >= 0)
                          Center(
                            child: Text(
                              '「${_stringLabels[_plucked]}」',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 15,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            '轻触或划动琴弦，聆听弦上回响',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11.5,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(child: _audioBar(scene)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _audioBar(_Scene scene) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_sound ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              size: 15, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            _loading
                ? '载入琴曲…'
                : '琴曲《${scene.piece}》 · ${scene.ambienceName}',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _toggleSound,
            child: Text(
              _sound ? '静音' : '有声',
              style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 1,
                color: Colors.white.withValues(alpha: 0.9),
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 夜色底（与全局色板区分，此处为沉浸场景专用）。
class AppColorsNight {
  AppColorsNight._();
  static const base = Color(0xFF0B0F18);
}

/// 琴境画笔：三境各自的古风场景 + 近景古琴与七弦。
class RealmPainter extends CustomPainter {
  RealmPainter({
    required this.realm,
    required this.ambient,
    required this.plucks,
    required this.pluckXs,
  });

  /// 0 山林 / 1 书斋 / 2 月夜。
  final int realm;

  /// 环境动效进度 0..1 循环。
  final double ambient;

  /// 各弦拨动进度，1.0 为静止。
  final List<double> plucks;

  /// 各弦拨动位置。
  final List<double> pluckXs;

  @override
  void paint(Canvas canvas, Size size) {
    switch (realm) {
      case 0:
        _forestScene(canvas, size);
      case 1:
        _studyScene(canvas, size);
      default:
        _nightScene(canvas, size);
    }
    _drawQin(canvas, size);
  }

  // -------------------------------------------------------------- 山林

  void _forestScene(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.62;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E332C), Color(0xFF3A5745), Color(0xFF7E9070)],
          stops: [0.0, 0.52, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 晨光
    final sun = Offset(w * 0.26, horizon - h * 0.30);
    canvas.drawCircle(
      sun,
      h * 0.11,
      Paint()
        ..color = const Color(0xFFFFE3AE).withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.06),
    );

    // 远山三重（绿墨）
    _mountains(canvas, w, horizon, h, 0.15, -0.02 * h, const Color(0x33202A24), 3.0, 0.4);
    _mountains(canvas, w, horizon, h, 0.12, 0.01 * h, const Color(0x55202925), 4.5, 1.0);
    _mountains(canvas, w, horizon, h, 0.10, 0.03 * h, const Color(0x77202824), 5.5, 1.6);

    // 山间飞瀑
    canvas.drawLine(
      Offset(w * 0.70, horizon - h * 0.19),
      Offset(w * 0.665, horizon - h * 0.004),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..strokeWidth = 2.6,
    );

    _mist(canvas, w, h, horizon, Colors.white, 0.055);

    // 松树剪影
    _pine(canvas, Offset(w * 0.09, horizon + h * 0.015), h * 0.28, const Color(0xCC0E1712));
    _pine(canvas, Offset(w * 0.18, horizon + h * 0.05), h * 0.20, const Color(0xAA0E1712));
    _pine(canvas, Offset(w * 0.93, horizon + h * 0.02), h * 0.24, const Color(0xCC0E1712));

    _particles(canvas, w, h, const Color(0xFFDCE7C0), 14, 0.30);
  }

  // -------------------------------------------------------------- 书斋

  void _studyScene(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1E14), Color(0xFF4A3320), Color(0xFF241A12)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 灯火晕
    final lamp = Offset(w * 0.30, h * 0.40);
    canvas.drawCircle(
      lamp,
      h * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFC978).withValues(alpha: 0.26),
            const Color(0x00FFC978),
          ],
        ).createShader(Rect.fromCircle(center: lamp, radius: h * 0.34)),
    );

    // 窗（右侧）：夜色 + 月 + 棂格
    final win = Rect.fromLTWH(w * 0.58, h * 0.08, w * 0.34, h * 0.32);
    canvas.drawRect(win, Paint()..color = const Color(0xFF101828));
    canvas.drawCircle(
      Offset(win.center.dx + win.width * 0.16, win.top + win.height * 0.30),
      h * 0.028,
      Paint()..color = const Color(0xFFF3EEDD).withValues(alpha: 0.9),
    );
    final lattice = Paint()
      ..color = const Color(0x99160F0A)
      ..strokeWidth = 2;
    for (var i = 1; i < 4; i++) {
      final x = win.left + win.width * i / 4;
      canvas.drawLine(Offset(x, win.top), Offset(x, win.bottom), lattice);
    }
    for (var i = 1; i < 3; i++) {
      final y = win.top + win.height * i / 3;
      canvas.drawLine(Offset(win.left, y), Offset(win.right, y), lattice);
    }
    canvas.drawRect(
      win,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xCC160F0A),
    );

    // 案几
    final deskY = h * 0.50;
    canvas.drawRect(
      Rect.fromLTWH(0, deskY, w, h - deskY),
      Paint()..color = const Color(0xFF1B130C),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, deskY, w, 2.5),
      Paint()..color = const Color(0xFF6B4E30).withValues(alpha: 0.6),
    );

    // 卷册堆（左）
    final sx = w * 0.10;
    for (var i = 0; i < 4; i++) {
      final rh = h * 0.014;
      canvas.drawRect(
        Rect.fromLTWH(sx, deskY - rh * (i + 1), w * 0.20, rh),
        Paint()..color = Color.lerp(const Color(0xFF6B4E30), const Color(0xFFB79A6A), i / 3)!,
      );
    }

    // 香炉（中）与香烟
    final bx = w * 0.46;
    canvas.drawRect(
      Rect.fromLTWH(bx, deskY - h * 0.045, w * 0.09, h * 0.045),
      Paint()..color = const Color(0xFF8A6A3A),
    );
    for (var i = 0; i < 3; i++) {
      final path = Path();
      for (var s = 0; s <= 20; s++) {
        final t = s / 20;
        final y = deskY - h * 0.045 - t * h * 0.15;
        final x = bx + w * 0.045 + math.sin(t * 6 + ambient * 6 + i) * w * 0.02;
        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.12 - i * 0.03),
      );
    }

    _particles(canvas, w, h, const Color(0xFFFFE8B8), 10, 0.18);
  }

  // -------------------------------------------------------------- 月夜

  void _nightScene(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.62;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0F1E), Color(0xFF16213A), Color(0xFF26324A)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 星
    for (var i = 0; i < 48; i++) {
      final seed = i * 2.399;
      final x = (math.sin(seed) * 0.5 + 0.5) * w;
      final y = (math.cos(seed * 1.7) * 0.5 + 0.5) * (horizon - h * 0.06);
      final tw = 0.5 + 0.5 * math.sin(ambient * 2 * math.pi + i);
      canvas.drawCircle(
        Offset(x, y),
        0.8 + tw * 0.7,
        Paint()..color = Colors.white.withValues(alpha: 0.16 + tw * 0.28),
      );
    }

    // 明月
    final bodyX = w * 0.74;
    final bodyY = horizon - h * 0.30;
    canvas.drawCircle(
      Offset(bodyX, bodyY),
      h * 0.055,
      Paint()
        ..color = const Color(0xFFF3EEDD).withValues(alpha: 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.03),
    );
    canvas.drawCircle(
      Offset(bodyX, bodyY),
      h * 0.032,
      Paint()..color = const Color(0xFFF3EEDD),
    );

    _mountains(canvas, w, horizon, h, 0.16, -0.05 * h, const Color(0x55000000), 3.0, 0.4);
    _mountains(canvas, w, horizon, h, 0.12, 0.0, const Color(0x88000000), 4.5, 1.0);

    // 水面
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF121A2C), Color(0xFF060910)],
        ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );

    // 月光倒影
    for (var i = 0; i < 14; i++) {
      final y = horizon + 8 + i * 9.0;
      if (y > h) break;
      final wobble = math.sin(ambient * 2 * math.pi + i * 0.8) * 10;
      final segW = w * (0.05 + 0.03 * math.sin(i * 1.7 + ambient * 6));
      canvas.drawLine(
        Offset(bodyX - segW / 2 + wobble, y),
        Offset(bodyX + segW / 2 + wobble, y),
        Paint()..color = const Color(0xFFF3EEDD).withValues(alpha: 0.16 - i * 0.008),
      );
    }

    _mist(canvas, w, h, horizon, Colors.white, 0.045);
  }

  // -------------------------------------------------------------- 公共笔法

  void _mountains(Canvas canvas, double w, double horizon, double h, double heightFactor,
      double offset, Color color, double seedK, double phase) {
    final path = Path()..moveTo(0, horizon + offset);
    const steps = 80;
    for (var i = 0; i <= steps; i++) {
      final x = w * i / steps;
      final n = x / w;
      final y = horizon +
          offset -
          h *
              heightFactor *
              (0.5 +
                  0.5 *
                      math.sin(n * math.pi * seedK + phase) *
                      math.cos(n * math.pi * (seedK * 0.6) + phase * 2));
      path.lineTo(x, y);
    }
    path
      ..lineTo(w, horizon + offset)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _mist(Canvas canvas, double w, double h, double horizon, Color color, double alpha) {
    for (var i = 0; i < 5; i++) {
      final p = (ambient + i / 5) % 1.0;
      final y = horizon - h * 0.16 + i * h * 0.055;
      final x = -w * 0.3 + p * w * 1.6;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w * 0.55, height: h * 0.05),
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
    }
  }

  void _particles(Canvas canvas, double w, double h, Color color, int count, double alpha) {
    for (var i = 0; i < count; i++) {
      final seed = i * 2.399;
      final px = ((math.sin(seed) * 0.5 + 0.5) * w + ambient * w * 0.35) % w;
      final py = ((math.cos(seed * 1.3) * 0.5 + 0.5) * h + ambient * h * 0.25) % h;
      canvas.drawCircle(
        Offset(px, py),
        1.2 + (i % 3) * 0.6,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  /// 松树剪影：一竿树干 + 层叠针叶。
  void _pine(Canvas canvas, Offset base, double height, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(base.dx - 1.4, base.dy - height, 2.8, height), paint);
    for (var i = 0; i < 5; i++) {
      final t = i / 5;
      final yTop = base.dy - height * (0.34 + t * 0.62);
      final halfW = height * (0.05 + 0.15 * (1 - t)) + 2;
      final layerH = height * 0.26;
      final path = Path()
        ..moveTo(base.dx, yTop)
        ..lineTo(base.dx - halfW, yTop + layerH)
        ..lineTo(base.dx + halfW, yTop + layerH)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  /// 近景古琴：琴身、七弦（逐弦独立余振）与岳山。
  void _drawQin(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = h * 0.62;
    final bottom = h * 0.92;
    final spacing = (bottom - top) / 6;

    // 琴身（近景透视梯形）
    final body = Path()
      ..moveTo(w * 0.06, h * 0.56)
      ..lineTo(w * 0.94, h * 0.56)
      ..lineTo(w * 1.02, h * 1.02)
      ..lineTo(-w * 0.02, h * 1.02)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4B3423), Color(0xFF2E1F15)],
        ).createShader(Rect.fromLTWH(0, h * 0.56, w, h * 0.46)),
    );

    // 七弦
    for (var i = 0; i < 7; i++) {
      final y = top + i * spacing;
      final t = plucks[i];
      final vibrating = t < 1;
      final paint = Paint()
        ..color = vibrating ? const Color(0xFFFFE9A8) : Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = (1.0 + i * 0.35) * (vibrating ? 1.8 : 1.0)
        ..strokeCap = StrokeCap.round;

      if (vibrating) {
        // 弦振
        final amp = 16 * (1 - t) * math.exp(-2 * t);
        final path = Path();
        for (double x = 0; x <= w; x += 4) {
          final norm = x / w;
          final env = math.sin(norm * math.pi);
          final dy = amp * env * math.sin(norm * math.pi * 6 - t * 40);
          if (x == 0) {
            path.moveTo(x, y + dy);
          } else {
            path.lineTo(x, y + dy);
          }
        }
        canvas.drawPath(path, paint);

        // 涟漪
        for (var r = 0; r < 3; r++) {
          final rt = (t - r * 0.16).clamp(0.0, 1.0).toDouble();
          if (rt <= 0) continue;
          canvas.drawCircle(
            Offset(pluckXs[i], y),
            rt * w * 0.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * (1 - rt)
              ..color = const Color(0xFFFFE9A8).withValues(alpha: 0.30 * (1 - rt)),
          );
        }
      } else {
        canvas.drawLine(Offset(0, y), Offset(w, y), paint);
      }
    }

    // 岳山
    canvas.drawRect(
      Rect.fromLTWH(w * 0.06, h * 0.555, w * 0.88, 3),
      Paint()..color = const Color(0xFF1E140D),
    );
  }

  @override
  bool shouldRepaint(covariant RealmPainter old) =>
      old.realm != realm ||
      old.ambient != ambient ||
      !listEquals(old.plucks, plucks) ||
      !listEquals(old.pluckXs, pluckXs);
}
