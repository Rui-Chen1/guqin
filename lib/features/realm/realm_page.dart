import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/guqin_sound.dart';
import '../../data/app_database.dart';
import '../experience/mood_sound_page.dart';

/// 功能八：数字琴境体验。
///
/// 三境沉浸式场景——「山林 · 书斋 · 月夜」，使用原水墨山雾背景；
/// 近景是一张写实古琴：生漆漆面（真实断纹材质）、十三徽、岳山、龙龈与七根
/// 粗细递减的丝弦，弦可触可划，拨弦即出散音，多弦可同时余振。
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
    required this.guide,
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

  /// 琴引：本境一句引子要按顺序拨响的弦（0=最粗七弦 … 6=最细一弦）。
  final List<int> guide;
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
    guide: [5, 4, 2, 0],
  ),
  _Scene(
    name: '书斋',
    title: '明窗净几',
    poem: '炉香乍爇，弦上读易',
    slug: 'kongziduyi',
    piece: '孔子读易',
    ambience: 'amb_study.m4a',
    ambienceName: '檐雨',
    guide: [2, 4, 5, 4],
  ),
  _Scene(
    name: '月夜',
    title: '月下横琴',
    poem: '月落平沙，雁影泠泠',
    slug: 'pingsha',
    piece: '平沙落雁',
    ambience: 'amb_night.m4a',
    ambienceName: '夜虫',
    guide: [0, 2, 4, 5],
  ),
];

// ---------------------------------------------------------------- 琴面几何
//
// 拨弦的命中判定与绘制共用同一套几何常量，保证「看到的弦」就是「拨到的弦」。

const double _kQinImageWidth = 1005;
const double _kQinImageHeight = 174;
const double _kQinWidthFactor = 0.94;
const double _kQinTopFactor = 0.53;
const double _kFirstStringY = 43;
const double _kStringStepY = 10.6;
const double _kStringStartX = 40;
const double _kStringEndX = 900;

// Kept for the procedural fallback while the complete qin image is loading.
const double _kQinTop = 0.62;
const double _kStringTop = 0.665;
const double _kStringGap = 0.034;
const double _kStringLeft = 0.06;
const double _kStringRight = 0.92;

class _QinGeometry {
  const _QinGeometry(this.bounds, this.scale);

  final Rect bounds;
  final double scale;

  // 与绘制一致：弦在屏高 0.665 处开始，间距为 bounds.height/7
  double get stringsTop => bounds.top;
  double get stringGap => bounds.height / 7;
  double get stringsLeft => bounds.left + bounds.width * 0.04;
  double get stringsRight => bounds.right - bounds.width * 0.04;
}

_QinGeometry _qinGeometry(Size size) {
  final top = size.height * 0.665;
  final height = size.height * 0.034 * 6; // 6 个间距 = 7 根弦
  return _QinGeometry(
    Rect.fromLTWH(size.width * 0.06, top, size.width * 0.88, height),
    1.0,
  );
}

/// 正在琴面上按弦的左手指。
class _LhTrack {
  _LhTrack({
    required this.string,
    required this.lastX,
    required this.downTime,
    required this.downX,
  });
  int string;
  double lastX;
  double downTime;
  double downX;
}

class _RealmPageState extends State<RealmPage> with TickerProviderStateMixin {
  static const _stringLabels = ['宫', '商', '角', '徵', '羽', '少宫', '少商'];

  /// 背景琴曲（真人录音，循环）。
  final AudioPlayer _music = AudioPlayer();

  /// 氛围音（循环）。
  final AudioPlayer _ambience = AudioPlayer();

  late final AnimationController _ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 48))
        ..repeat();

  /// 七根弦各自的拨动进度（1.0 为静止）。逐弦独立，连续划弦时
  /// 多弦可同时余振，形成「弦上流水」的叠加听感。
  final List<double> _pluckAge = List.filled(7, 1.0);
  final List<double> _pluckX = List.filled(7, 0.0);
  static const _pluckSeconds = 1.6;

  /// 左手按弦状态：true 表示该弦正被按住（按音而非散音），
  /// _pressX 为按弦点的横坐标，用于在琴面画一个柔和的指腹点。
  final List<bool> _pressed = List.filled(7, false);
  final List<double> _pressX = List.filled(7, -1);

  /// 正在琴面上的左手指：pointerId → 跟踪信息。
  final Map<int, _LhTrack> _leftHands = {};

  /// 鼠标党专用：单击左侧即「按住」这根弦，直到再点别处。
  int _mouseLeftString = -1;

  /// 琴引：每境一句引子，按顺序拨对即点亮。
  late List<int> _guide = _scenes[_realm].guide;
  int _guideStep = 0;
  bool _guideDone = false;

  /// 右半屏（靠近岳山）= 右手拨弦；左半屏（靠近龙龈）= 左手按弦。
  static const double _rightHandX = 0.55;
  static const double _leftHandX = 0.45;

  final Stopwatch _clock = Stopwatch();
  double _lastElapsed = 0;

  int _realm = 0;
  int _plucked = -1;
  bool _musicEnabled = true;
  bool _ambienceEnabled = true;
  double _musicVolume = 0.42;
  double _ambienceVolume = 0.12;
  bool _immersiveMotion = true;
  bool _loading = false;
  int _session = 0;

  /// 水墨底图与完整古琴图（解码后的 GPU 纹理）。
  ui.Image? _backdrop;
  ui.Image? _qinImage;

  _Scene get _scene => _scenes[_realm];

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.bumpProgress('realm_views');
    // 预建播放器，触弦即为瞬时发声
    unawaited(GuqinSound.instance.preload(GuqinSound.stringSet('open')));
    unawaited(GuqinSound.instance.preload(GuqinSound.stringSet('press')));
    _ambient.addListener(_advance);
    _clock.start();
    unawaited(_loadArtwork());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_applyScene()));
  }

  /// 解码水墨底图与完整古琴图。
  Future<void> _loadArtwork() async {
    try {
      await _loadSceneBackdrop(_realm);
      final qinData = await rootBundle.load('assets/images/realm_guqin.png');
      final qinCodec = await ui.instantiateImageCodec(
        qinData.buffer.asUint8List(),
        targetWidth: 1024,
      );
      final qinFrame = await qinCodec.getNextFrame();
      if (!mounted) return;
      setState(() => _qinImage = qinFrame.image);
    } catch (e) {
      debugPrint('琴境底图载入失败：$e');
    }
  }

  /// 按场景加载对应底图：山林/书斋/月夜。
  Future<void> _loadSceneBackdrop(int realm) async {
    final file = switch (realm) {
      0 => 'assets/images/realm_forest.jpg',
      1 => 'assets/images/realm_study.jpg',
      _ => 'assets/images/realm_night.jpg',
    };
    final data = await rootBundle.load(file);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 1080,
    );
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _backdrop = frame.image);
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

  /// 载入当前境的琴曲与氛围音，并按各自的开关状态播放。
  Future<void> _applyScene() async {
    final session = ++_session;
    final scene = _scene;
    setState(() => _loading = true);
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicVolume);
      await _music.setSource(AssetSource('audio/${scene.slug}.mp3'));
      await _ambience.setReleaseMode(ReleaseMode.loop);
      await _ambience.setVolume(_ambienceVolume);
      await _ambience.setSource(AssetSource('audio/sfx/${scene.ambience}'));
      if (_musicEnabled) {
        await _music.resume();
      } else {
        await _music.pause();
      }
      if (_ambienceEnabled) {
        await _ambience.resume();
      } else {
        await _ambience.pause();
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
      _guide = _scenes[i].guide;
      _guideStep = 0;
      _guideDone = false;
      _mouseLeftString = -1;
    });
    unawaited(_loadSceneBackdrop(i));
    unawaited(_applyScene());
  }

  void _setMusicEnabled(bool enabled) {
    setState(() => _musicEnabled = enabled);
    unawaited(enabled ? _music.resume() : _music.pause());
  }

  void _setAmbienceEnabled(bool enabled) {
    setState(() => _ambienceEnabled = enabled);
    unawaited(enabled ? _ambience.resume() : _ambience.pause());
  }

  void _setMusicVolume(double volume) {
    setState(() => _musicVolume = volume);
    unawaited(_music.setVolume(volume));
  }

  void _setAmbienceVolume(double volume) {
    setState(() => _ambienceVolume = volume);
    unawaited(_ambience.setVolume(volume));
  }

  // ---------------------------------------------------------------- 交互

  /// 根据触点位置判断落在哪根弦上；不在弦上返回 null。
  (int, double)? _stringHit(Offset local, Size size) {
    final geometry = _qinGeometry(size);
    final top = geometry.stringsTop;
    final step = geometry.stringGap;
    final tolerance = math.max(7.0, step * 0.7);
    final bottom = top + step * 6;
    if (local.dy < top - tolerance || local.dy > bottom + tolerance) {
      return null;
    }
    final i = ((local.dy - top) / step).round().clamp(0, 6);
    return (i, local.dx / size.width);
  }

  /// 同步左手按弦状态：触屏按住的手指 ∪ 鼠标 sticky 按弦。
  void _syncPressed() {
    for (var i = 0; i < 7; i++) {
      _pressed[i] = false;
      _pressX[i] = -1;
    }
    for (final t in _leftHands.values) {
      _pressed[t.string] = true;
      _pressX[t.string] = t.lastX;
    }
    if (_mouseLeftString >= 0) {
      _pressed[_mouseLeftString] = true;
    }
  }

  /// 右手拨弦：该弦被左手按住 → 按音，否则散音；并校验琴引。
  void _pluckString(int i, double xPx) {
    if (_pluckAge[i] < 0.12) return;
    _pluckAge[i] = 0;
    _pluckX[i] = xPx;
    final held = _pressed[i];
    setState(() => _plucked = i);
    GuqinSound.instance
        .play(GuqinSound.file(held ? 'press' : 'open', i), volume: 0.9);
    HapticFeedback.lightImpact();
    AppDatabase.instance.bumpProgress('realm_plucks');
    _checkGuide(i);
  }

  /// 琴引：按顺序拨对下一根弦即点亮；弹完整句解锁本境。
  void _checkGuide(int i) {
    if (_guideDone) return;
    if (_guideStep >= _guide.length) return;
    if (i != _guide[_guideStep]) {
      // 拨错：轻微反馈，不打断
      return;
    }
    setState(() => _guideStep++);
    if (_guideStep >= _guide.length) {
      _guideDone = true;
      AppDatabase.instance.bumpProgress('realm_guide_done');
      // 解锁：把环境音抬起来，像林泉应声
      unawaited(_ambience.setVolume(math.min(1.0, _ambienceVolume + 0.25)));
      HapticFeedback.mediumImpact();
    }
  }

  void _onPointerDown(PointerDownEvent e, RenderBox box, Size size) {
    final local = box.globalToLocal(e.position);
    final hit = _stringHit(local, size);
    if (hit == null) return;
    final (i, xf) = hit;
    if (xf >= _rightHandX) {
      // 右手：拨弦
      _pluckString(i, local.dx);
      return;
    }
    if (xf > _leftHandX) return;

    // 左手区
    final now = _clock.elapsedMicroseconds / 1e6;
    if (e.kind == PointerDeviceKind.mouse) {
      // 鼠标：单击即 sticky 按住；再点同一根弦即抬指
      _mouseLeftString = (_mouseLeftString == i) ? -1 : i;
      _syncPressed();
      setState(() {});
      HapticFeedback.selectionClick();
    } else {
      // 触屏：按下为按住（不发声，等右手拨）
      _leftHands[e.pointer] = _LhTrack(
        string: i,
        lastX: local.dx,
        downTime: now,
        downX: local.dx,
      );
      _syncPressed();
      setState(() {});
      HapticFeedback.selectionClick();
    }
  }

  void _onPointerMove(PointerMoveEvent e, RenderBox box, Size size) {
    final local = box.globalToLocal(e.position);
    final hit = _stringHit(local, size);
    if (hit == null) return;
    final (i, xf) = hit;

    // 右手横划 = 历/拂
    if (xf >= _rightHandX) {
      _pluckString(i, local.dx);
      return;
    }
    if (xf > _leftHandX) return;

    // 鼠标按住后拖动也跟着挪指
    if (e.kind == PointerDeviceKind.mouse) {
      if (_mouseLeftString == i) return;
      _mouseLeftString = i;
      _syncPressed();
      setState(() {});
      return;
    }

    final track = _leftHands[e.pointer];
    if (track == null) return;
    final now = _clock.elapsedMicroseconds / 1e6;
    final heldFor = now - track.downTime;
    final dx = local.dx - track.lastX;
    track.lastX = local.dx;

    if (track.string != i) {
      _pressed[track.string] = false;
      track.string = i;
      _pressed[i] = true;
    } else if (heldFor > 0.25 && dx.abs() > size.width * 0.035) {
      // 按住后沿弦滑动 = 绰/注
      GuqinSound.instance.play(
        GuqinSound.file(dx > 0 ? 'zhu' : 'chuo', i),
        volume: 0.9,
      );
      _pluckAge[i] = 0;
      _pluckX[i] = local.dx;
      HapticFeedback.selectionClick();
    }
    _syncPressed();
    setState(() {});
  }

  void _onPointerUp(PointerEvent e) {
    if (e.kind == PointerDeviceKind.mouse) return; // sticky 不抬指
    final track = _leftHands.remove(e.pointer);
    if (track == null) return;
    final now = _clock.elapsedMicroseconds / 1e6;
    final quick = (now - track.downTime) < 0.28;
    final moved = (track.lastX - track.downX).abs() > 12.0;
    _syncPressed();
    if (quick && !moved) {
      // 轻点左弦 = 泛音
      _pluckAge[track.string] = 0;
      _pluckX[track.string] = track.lastX;
      GuqinSound.instance
          .play(GuqinSound.file('harm', track.string), volume: 0.9);
      HapticFeedback.lightImpact();
      _checkGuide(track.string);
    }
    setState(() {});
  }

  // ---------------------------------------------------------------- 视图

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    return Scaffold(
      backgroundColor: AppColorsRealm.base,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _onPointerDown(
                e, context.findRenderObject() as RenderBox, size),
            onPointerMove: (e) => _onPointerMove(
                e, context.findRenderObject() as RenderBox, size),
            onPointerUp: _onPointerUp,
            onPointerCancel: (e) => _onPointerUp(e),
            child: Stack(
              children: [
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _ambient,
                    builder: (context, _) => CustomPaint(
                      painter: RealmPainter(
                        realm: _realm,
                        ambient: _ambient.value,
                        plucks: List<double>.of(_pluckAge),
                        pluckXs: List<double>.of(_pluckX),
                        pressXs: List<double>.of(_pressX),
                        immersiveMotion: _immersiveMotion,
                        background: _backdrop,
                        qin: _qinImage,
                      ),
                      size: size,
                    ),
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
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  size: 18),
                              color: const Color(0xFFEDE6D6),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const MoodSoundPage()),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B4513), Color(0xFFB8860B)],
                                  ),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.6)),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      '意境生音',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                                      color: Colors.black
                                          .withValues(alpha: on ? 0.38 : 0.18),
                                      border: Border.all(
                                          color: Colors.white.withValues(
                                              alpha: on ? 0.42 : 0.16)),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      _scenes[i].name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        letterSpacing: 2,
                                        color: Colors.white.withValues(
                                            alpha: on ? 0.95 : 0.62),
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
                            color:
                                const Color(0xFFF6EFDF).withValues(alpha: 0.96),
                            fontSize: 24,
                            height: 1.4,
                            letterSpacing: 6,
                            fontWeight: FontWeight.w300,
                            fontFamily: 'Songti SC',
                            fontFamilyFallback: const [
                              'STSong',
                              'Kaiti SC',
                              'serif'
                            ],
                            shadows: const [
                              Shadow(
                                  color: Color(0x99000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scene.poem,
                          style: TextStyle(
                            color:
                                const Color(0xFFE7DFCC).withValues(alpha: 0.74),
                            fontSize: 14,
                            height: 1.6,
                            letterSpacing: 3,
                            shadows: const [
                              Shadow(color: Color(0x99000000), blurRadius: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _guideDone
                              ? '琴引已成 · 林泉应声，雾散半分'
                              : '琴引 · 依次拨响：'
                                  '${_guide.asMap().entries.map((e) {
                                  final done = e.key < _guideStep;
                                  final now = e.key == _guideStep;
                                  final mark = _stringLabels[e.value];
                                  return now
                                      ? '〔$mark〕'
                                      : (done ? '$mark·' : '·$mark');
                                }).join(' ')}',
                          style: TextStyle(
                            color: _guideDone
                                ? const Color(0xFFE9D8A8)
                                    .withValues(alpha: 0.95)
                                : const Color(0xFFCDBF9E)
                                    .withValues(alpha: 0.66),
                            fontSize: 12,
                            letterSpacing: 2,
                            shadows: const [
                              Shadow(color: Color(0x99000000), blurRadius: 8),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (_plucked >= 0)
                          Center(
                            child: Text(
                              '「${_stringLabels[_plucked]}」',
                              style: TextStyle(
                                color: const Color(0xFFF8F0DC)
                                    .withValues(alpha: 0.92),
                                fontSize: 15,
                                letterSpacing: 3,
                                shadows: const [
                                  Shadow(
                                      color: Color(0xCC000000), blurRadius: 10),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            '右半拨弦 · 左半点按为按音，轻点为泛音，长按后拖动为绰注',
                            style: TextStyle(
                              color: const Color(0xFFEDE5D4)
                                  .withValues(alpha: 0.66),
                              fontSize: 11.5,
                              letterSpacing: 1,
                              shadows: const [
                                Shadow(color: Color(0xCC000000), blurRadius: 8),
                              ],
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
        color: Colors.black.withValues(alpha: 0.34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              _musicEnabled || _ambienceEnabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              size: 15,
              color: const Color(0xFFE9E1CF)),
          const SizedBox(width: 8),
          Text(
            _loading ? '载入琴曲…' : '《${scene.piece}》 · ${scene.ambienceName}',
            style: const TextStyle(
              fontSize: 11.5,
              letterSpacing: 1,
              color: Color(0xFFE9E1CF),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '声音设置',
            visualDensity: VisualDensity.compact,
            onPressed: _showAudioSettings,
            icon: const Icon(Icons.tune, size: 18),
            color: const Color(0xFFE9E1CF),
          ),
          IconButton(
            tooltip: _immersiveMotion ? '关闭沉浸动态背景' : '开启沉浸动态背景',
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                setState(() => _immersiveMotion = !_immersiveMotion),
            icon: Icon(
              _immersiveMotion ? Icons.blur_on : Icons.blur_off,
              size: 18,
            ),
            color: const Color(0xFFE9E1CF),
          ),
        ],
      ),
    );
  }

  void _showAudioSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171A20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 34,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '声音设置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                _audioControl(
                  title: '背景琴曲',
                  subtitle: '《${_scene.piece}》',
                  enabled: _musicEnabled,
                  volume: _musicVolume,
                  onEnabledChanged: (value) {
                    setSheetState(() {});
                    _setMusicEnabled(value);
                  },
                  onVolumeChanged: (value) {
                    setSheetState(() {});
                    _setMusicVolume(value);
                  },
                ),
                const SizedBox(height: 8),
                _audioControl(
                  title: '环境声音',
                  subtitle: _scene.ambienceName,
                  enabled: _ambienceEnabled,
                  volume: _ambienceVolume,
                  onEnabledChanged: (value) {
                    setSheetState(() {});
                    _setAmbienceEnabled(value);
                  },
                  onVolumeChanged: (value) {
                    setSheetState(() {});
                    _setAmbienceVolume(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _audioControl({
    required String title,
    required String subtitle,
    required bool enabled,
    required double volume,
    required ValueChanged<bool> onEnabledChanged,
    required ValueChanged<double> onVolumeChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              onChanged: onEnabledChanged,
              activeThumbColor: const Color(0xFFD8BC83),
            ),
          ],
        ),
        Row(
          children: [
            Icon(Icons.volume_down,
                size: 17, color: Colors.white.withValues(alpha: 0.58)),
            Expanded(
              child: Slider(
                value: volume,
                onChanged: onVolumeChanged,
                activeColor: const Color(0xFFD8BC83),
                inactiveColor: Colors.white24,
              ),
            ),
            Icon(Icons.volume_up,
                size: 17, color: Colors.white.withValues(alpha: 0.58)),
          ],
        ),
      ],
    );
  }
}

/// 琴境底色（照片未就绪时的兜底）。
class AppColorsRealm {
  AppColorsRealm._();
  static const base = Color(0xFFF7F5F0);
}

/// 琴境画笔：实景底图 + 动态雾气/光尘 + 完整古琴图与弦振效果。
class RealmPainter extends CustomPainter {
  RealmPainter({
    required this.realm,
    required this.ambient,
    required this.plucks,
    required this.pluckXs,
    required this.immersiveMotion,
    this.background,
    this.qin,
    this.pressXs = const [],
  });

  /// 0 山林 / 1 书斋 / 2 月夜。
  final int realm;

  /// 环境动效进度 0..1 循环。
  final double ambient;

  /// 各弦拨动进度，1.0 为静止。
  final List<double> plucks;

  /// 各弦拨动位置。
  final List<double> pluckXs;

  /// 左手按弦点横坐标（-1 表示未按）。
  final List<double> pressXs;

  /// 控制云雾和拨弦水纹动效。
  final bool immersiveMotion;

  /// 当前境的写实底图。
  final ui.Image? background;

  /// 完整古琴图。
  final ui.Image? qin;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = immersiveMotion ? ambient * math.pi * 2 : 0.0;

    _paintBackdrop(canvas, size, phase);
    _paintAtmosphere(canvas, size, phase);
    // 全局罩一层暖宣纸色，让照片背景变成漫剧手绘感
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE8D8B8).withValues(alpha: 0.28),
            const Color(0xFFC8A878).withValues(alpha: 0.18),
          ],
        ).createShader(Offset.zero & size),
    );
    _drawQin(canvas, size, phase);
    _paintGrade(canvas, size, phase);

    // 上方留白压一层淡墨，保证题名可读，但不再暗黑
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.22),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x662B1D10), Color(0x002B1D10)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.22)),
    );
  }

  // -------------------------------------------------------------- 写实底图

  void _paintBackdrop(Canvas canvas, Size size, double phase) {
    final w = size.width;
    final h = size.height;
    final img = background;

    if (img == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = AppColorsRealm.base,
      );
      return;
    }

    // 极缓的推拉与平移：让照片有「呼吸」而不是一张死图
    final zoom =
        1.045 + (immersiveMotion ? math.sin(phase * 0.5) * 0.012 : 0.0);
    final drift = immersiveMotion
        ? Offset(math.sin(phase * 0.37) * w * 0.008,
            math.cos(phase * 0.29) * h * 0.006)
        : Offset.zero;

    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final scale = math.max(w / iw, h / ih) * zoom;
    final dw = iw * scale;
    final dh = ih * scale;
    final dst = Rect.fromLTWH(
      (w - dw) / 2 + drift.dx,
      (h - dh) / 2 + drift.dy,
      dw,
      dh,
    );
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, iw, ih),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  // -------------------------------------------------------------- 动态氛围

  void _paintAtmosphere(Canvas canvas, Size size, double phase) {
    switch (realm) {
      case 0:
        _forestLife(canvas, size, phase);
      case 1:
        _studyLife(canvas, size, phase);
      default:
        _nightLife(canvas, size, phase);
    }
    _filmGrain(canvas, size);
  }

  void _forestLife(Canvas canvas, Size size, double phase) {
    final w = size.width;
    final h = size.height;
    if (!immersiveMotion) return;

    // 晨光：树隙洒下的光柱，随风轻摆
    for (var i = 0; i < 4; i++) {
      final sway = math.sin(phase * 0.8 + i * 1.4) * w * 0.02;
      final origin = Offset(w * (0.12 + i * 0.11) + sway, -h * 0.02);
      final end = Offset(origin.dx + w * (0.16 + i * 0.03), h * 0.72);
      final path = Path()
        ..moveTo(origin.dx - w * 0.035, origin.dy)
        ..lineTo(origin.dx + w * 0.035, origin.dy)
        ..lineTo(end.dx + w * 0.11, end.dy)
        ..lineTo(end.dx - w * 0.11, end.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFE7B0).withValues(alpha: 0.16 - i * 0.025),
              const Color(0x00FFE7B0),
            ],
          ).createShader(Rect.fromLTRB(
              origin.dx - w * 0.12, 0, end.dx + w * 0.12, end.dy)),
      );
    }

    // 山间薄雾，横向缓移
    for (var i = 0; i < 3; i++) {
      final p = (ambient + i / 3) % 1.0;
      final x = (-0.3 + p * 1.6) * w;
      final y = h * (0.40 + i * 0.055);
      final rect = Rect.fromCenter(
          center: Offset(x, y), width: w * 0.70, height: h * 0.075);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFE9F3EC).withValues(alpha: 0.20),
              const Color(0x00E9F3EC),
            ],
          ).createShader(rect),
      );
    }

    // 浮尘与飞絮，逆光而亮
    for (var i = 0; i < 26; i++) {
      final seed = i * 1.913;
      final baseX = _hash(seed) * w;
      final baseY = _hash(seed + 7.1) * h * 0.66;
      final x = (baseX + phase * w * 0.10 * (0.5 + _hash(seed + 3))) % w;
      final y = baseY + math.sin(phase * 1.2 + i) * h * 0.012;
      final tw = 0.5 + 0.5 * math.sin(phase * 2.0 + i * 0.9);
      final r = 0.9 + (i % 3) * 0.65;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = const Color(0xFFFFF0C8).withValues(alpha: 0.10 + tw * 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }
  }

  void _studyLife(Canvas canvas, Size size, double phase) {
    final w = size.width;
    final h = size.height;
    if (!immersiveMotion) return;

    // 灯焰呼吸
    final pulse = 0.5 + 0.5 * math.sin(phase * 2 + 0.6);
    final lamp = Offset(w * 0.52, h * 0.53);
    final r = w * (0.40 + pulse * 0.03);
    canvas.drawCircle(
      lamp,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD27A).withValues(alpha: 0.13 + pulse * 0.07),
            const Color(0x00FFD27A),
          ],
        ).createShader(Rect.fromCircle(center: lamp, radius: r)),
    );

    // 香烟三缕，缓缓上升再散开
    for (var i = 0; i < 3; i++) {
      final path = Path();
      for (var s = 0; s <= 24; s++) {
        final t = s / 24;
        final y = h * 0.50 - t * h * 0.24;
        final x = w * 0.155 +
            math.sin(t * 5.2 + phase * 2.2 + i * 1.7) *
                w *
                (0.012 + t * 0.035) +
            t * w * 0.05;
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
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.10 - i * 0.02),
      );
    }

    // 窗棂投下的光斑，随月色轻轻晃动
    for (var i = 0; i < 12; i++) {
      final x =
          w * (0.62 + (i % 4) * 0.085) + math.sin(phase * 1.1 + i) * w * 0.004;
      final y = h * (0.16 + (i ~/ 4) * 0.055);
      canvas.drawRect(
        Rect.fromLTWH(x, y, w * 0.07, h * 0.04),
        Paint()..color = const Color(0xFFDFE8FF).withValues(alpha: 0.035),
      );
    }
  }

  void _nightLife(Canvas canvas, Size size, double phase) {
    final w = size.width;
    final h = size.height;
    if (!immersiveMotion) return;

    // 月晕呼吸
    final pulse = 0.5 + 0.5 * math.sin(phase * 0.8);
    final moon = Offset(w * 0.54, h * 0.20);
    final r = w * (0.26 + pulse * 0.02);
    canvas.drawCircle(
      moon,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFDCE9FF).withValues(alpha: 0.11 + pulse * 0.05),
            const Color(0x00DCE9FF),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: r)),
    );

    // 星子闪烁
    for (var i = 0; i < 46; i++) {
      final seed = i * 2.399;
      final x = _hash(seed) * w;
      final y = _hash(seed + 11.3) * h * 0.38;
      final tw = 0.5 + 0.5 * math.sin(phase * 2.4 + i * 1.3);
      canvas.drawCircle(
        Offset(x, y),
        0.55 + tw * 0.7,
        Paint()..color = Colors.white.withValues(alpha: 0.12 + tw * 0.30),
      );
    }

    // 贴水薄雾
    for (var i = 0; i < 4; i++) {
      final p = (ambient + i / 4) % 1.0;
      final x = (-0.35 + p * 1.7) * w;
      final y = h * (0.60 + i * 0.018);
      final rect = Rect.fromCenter(
          center: Offset(x, y), width: w * 0.62, height: h * 0.05);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFBFD6FF).withValues(alpha: 0.09),
              const Color(0x00BFD6FF),
            ],
          ).createShader(rect),
      );
    }

    // 萤火：明灭有致，缓缓游移
    for (var i = 0; i < 9; i++) {
      final seed = i * 3.117;
      final x = _hash(seed) * w + math.sin(phase * 0.9 + i * 2) * w * 0.03;
      final y = h * (0.55 + _hash(seed + 5.2) * 0.22) +
          math.cos(phase * 1.1 + i) * h * 0.012;
      final on = math.max(0.0, math.sin(phase * 2.0 + i * 1.9));
      if (on < 0.15) continue;
      canvas.drawCircle(
        Offset(x, y),
        1.6 + on * 1.2,
        Paint()
          ..color = const Color(0xFFFFE9A8).withValues(alpha: 0.10 + on * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
  }

  /// 细密胶片颗粒：让写实照片与程序化琴面在同一层质感里。
  void _filmGrain(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 110; i++) {
      final x = _hash(i * 1.117 + 0.7) * w;
      final y = _hash(i * 2.037 + 3.3) * h;
      final v = _hash(i * 3.71);
      canvas.drawCircle(
        Offset(x, y),
        0.7 + v * 0.8,
        Paint()
          ..color = (v > 0.5 ? Colors.white : Colors.black)
              .withValues(alpha: 0.018 + v * 0.026),
      );
    }
  }

  // -------------------------------------------------------------- 写实古琴

  void _drawCompleteQin(Canvas canvas, Size size) {
    final image = qin!;
    final geometry = _qinGeometry(size);
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      source,
      geometry.bounds,
      Paint()..filterQuality = FilterQuality.high,
    );

    final stringsTop = geometry.stringsTop;
    final gap = geometry.stringGap;
    final left = geometry.stringsLeft;
    final right = geometry.stringsRight;

    for (var i = 0; i < 7; i++) {
      final y = stringsTop + i * gap;
      final age = plucks[i];
      final vibrating = age < 1;
      final amp = vibrating
          ? math.max(gap * 0.55, size.height * 0.0025) *
              (1 - age) *
              math.exp(-2.4 * age)
          : 0.0;

      if (vibrating) {
        Path stringPath(double extraPhase, double ampScale) {
          final path = Path();
          const nodes = 44;
          for (var s = 0; s <= nodes; s++) {
            final t = s / nodes;
            final x = left + (right - left) * t;
            final envelope = math.sin(t * math.pi);
            final dy = amp *
                ampScale *
                envelope *
                math.sin(t * math.pi * 1.35 - age * 22 + extraPhase);
            if (s == 0) {
              path.moveTo(x, y + dy);
            } else {
              path.lineTo(x, y + dy);
            }
          }
          return path;
        }

        canvas.drawPath(
          stringPath(0, 1),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.black.withValues(alpha: 0.35)
            ..strokeWidth = 1.1,
        );
        canvas.drawPath(
          stringPath(0, 1),
          Paint()
            ..style = PaintingStyle.stroke
            ..color =
                const Color(0xFFFFE6A8).withValues(alpha: 0.48 * (1 - age))
            ..strokeWidth = 2.4
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
        canvas.drawPath(
          stringPath(0, 1),
          Paint()
            ..style = PaintingStyle.stroke
            ..color =
                const Color(0xFFFFF1D1).withValues(alpha: 0.82 * (1 - age))
            ..strokeWidth = 0.8,
        );
      }

      if (vibrating && age < 0.55) {
        final fade = 1 - age / 0.55;
        final x = pluckXs[i];
        canvas.drawCircle(
          Offset(x, y),
          math.max(3, gap * 0.65) * (0.6 + fade),
          Paint()
            ..color = const Color(0xFFFFE6A8).withValues(alpha: 0.34 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        final ripple = (age / 0.9).clamp(0.0, 1.0).toDouble();
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: geometry.bounds.width * (0.10 + ripple * 0.30),
            height: math.max(4, gap * (1.2 + ripple * 1.5)),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color =
                const Color(0xFFE8CF9A).withValues(alpha: 0.16 * (1 - ripple)),
        );
      }
    }

    for (var i = 0; i < 7 && i < pressXs.length; i++) {
      final x = pressXs[i];
      if (x < 0) continue;
      final y = stringsTop + i * gap;
      canvas.drawCircle(
        Offset(x, y),
        math.max(2, gap * 0.2),
        Paint()
          ..color = const Color(0xFFFFE9C4).withValues(alpha: 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(x, y),
        math.max(1.2, gap * 0.1),
        Paint()..color = const Color(0xFFF3DFB4).withValues(alpha: 0.65),
      );
    }
  }

  void _drawQin(Canvas canvas, Size size, double phase) {
    // 不再使用整张预制琴图（悬浮的横版琴），统一用程序绘制的俯视琴面
    final w = size.width;
    final h = size.height;
    final top = h * _kQinTop;
    final stringsTop = h * _kStringTop;
    final gap = h * _kStringGap;
    final stringsBottom = stringsTop + gap * 6;
    final left = w * _kStringLeft;
    final right = w * _kStringRight;

    // 琴面外轮廓：完整七弦琴形状——头宽尾窄、两侧收腰
    final body = Path()
      ..moveTo(-w * 0.02, h * 0.96)
      ..quadraticBezierTo(w * 0.02, top + h * 0.02, w * 0.06, top + h * 0.01)
      ..quadraticBezierTo(w * 0.18, top - h * 0.01, w * 0.30, top + h * 0.005)
      ..quadraticBezierTo(w * 0.50, top - h * 0.01, w * 0.72, top + h * 0.005)
      ..quadraticBezierTo(w * 0.86, top - h * 0.01, w * 0.96, top + h * 0.02)
      ..lineTo(w * 1.02, h * 0.92)
      ..quadraticBezierTo(w * 0.80, h * 0.99, w * 0.50, h * 1.0)
      ..quadraticBezierTo(w * 0.20, h * 1.0, -w * 0.02, h * 0.96)
      ..close();

    // 琴下设影
    canvas.drawPath(
      body.shift(Offset(0, h * 0.008)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.012),
    );

    canvas.save();
    canvas.clipPath(body);

    // 1. 深褐漆色：接近真实黑漆古琴
    canvas.drawRect(
      Rect.fromLTRB(-w * 0.1, top - h * 0.02, w * 1.1, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: switch (realm) {
            0 => const [
                Color(0xFF3A2418),
                Color(0xFF241610),
                Color(0xFF120A06)
              ],
            1 => const [
                Color(0xFF42281A),
                Color(0xFF2A1A10),
                Color(0xFF150C07)
              ],
            _ => const [
                Color(0xFF33201A),
                Color(0xFF1E1310),
                Color(0xFF0E0808)
              ],
          },
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTRB(-w * 0.1, top, w * 1.1, h)),
    );

    // 漆光：一条暖高光，模拟漆面反光
    canvas.drawRect(
      Rect.fromLTRB(-w * 0.1, top - h * 0.01, w * 1.1, top + h * 0.08),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFD8B080).withValues(alpha: 0.18),
            const Color(0x00D8B080),
          ],
        ).createShader(
            Rect.fromLTRB(-w * 0.1, top - h * 0.01, w * 1.1, top + h * 0.10)),
    );

    // 2. 断纹漆面：几条极细暗线模拟牛毛断纹
    final crack = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.20)
      ..strokeWidth = 0.6;
    for (var i = 0; i < 10; i++) {
      final gy = top + h * (0.05 + i * 0.09);
      final gx = _hash(i * 1.3) * w * 0.2;
      canvas.drawLine(
        Offset(gx, gy),
        Offset(gx + w * (0.4 + _hash(i * 2.7) * 0.4),
            gy + math.sin(i * 1.7) * 2),
        crack,
      );
    }

    // 3. 天光在漆面上的走向高光
    final sheen = immersiveMotion ? math.sin(phase * 0.3) * w * 0.05 : 0.0;
    canvas.drawRect(
      Rect.fromLTRB(-w * 0.1, top - h * 0.01, w * 1.1, top + h * 0.16),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFE2B4).withValues(alpha: 0.10),
            const Color(0x00FFE2B4),
          ],
          stops: const [0.0, 0.55],
        ).createShader(Rect.fromLTRB(
            -w * 0.1 + sheen, top, w * 0.8 + sheen, top + h * 0.18)),
    );

    // 4. 十三徽（蚌徽），按徽位比例排布：1/8 1/6 1/5 1/4 1/3 2/5 1/2 ...
    const huiFractions = [
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
    final length = right - left;
    final huiY = stringsTop - h * 0.030;
    for (var i = 0; i < huiFractions.length; i++) {
      final x = right - huiFractions[i] * length;
      final r = 2.2 + (i == 6 ? 0.8 : 0);
      // 徽位微光
      canvas.drawCircle(
        Offset(x, huiY),
        r * 2.1,
        Paint()
          ..color = const Color(0xFFF6EBCB).withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(x, huiY),
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.35),
            colors: [Color(0xFFFDF6E4), Color(0xFFC6B18A), Color(0xFF6E5A3C)],
            stops: [0.0, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(x, huiY), radius: r)),
      );
    }

    // 5. 岳山（右）与龙龈（左）
    _bridge(canvas, w, top, left, right, stringsTop, stringsBottom);

    // 6. 七弦：影、弦身、高光；拨动时做阻尼驻波与动态残影
    for (var i = 0; i < 7; i++) {
      final y = stringsTop + i * gap;
      final thick = 0.95 + i * 0.24;
      final age = plucks[i];
      final vibrating = age < 1;
      final amp =
          vibrating ? gap * 0.13 * (1 - age) * math.exp(-2.4 * age) : 0.0;

      Path stringPath(double extraPhase, double ampScale) {
        final p = Path();
        const nodes = 44;
        for (var s = 0; s <= nodes; s++) {
          final t = s / nodes;
          final x = left + (right - left) * t;
          final env = math.sin(t * math.pi);
          final dy = amp *
              ampScale *
              env *
              math.sin(t * math.pi * 1.35 - age * 22 + extraPhase);
          if (s == 0) {
            p.moveTo(x, y + dy);
          } else {
            p.lineTo(x, y + dy);
          }
        }
        return p;
      }

      // 弦在漆面上的投影，随振动一起晃
      canvas.drawPath(
        stringPath(0, 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black.withValues(alpha: 0.55)
          ..strokeWidth = thick + 0.8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
      canvas.save();
      canvas.translate(0, h * 0.0045);
      canvas.drawPath(
        stringPath(0, 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black.withValues(alpha: 0.30)
          ..strokeWidth = thick + 0.6,
      );
      canvas.restore();

      // 动态残影：三帧错相位，形成相机拖影
      if (vibrating) {
        for (var g = 1; g <= 3; g++) {
          canvas.drawPath(
            stringPath(g * 0.55, 0.72),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0xFFFFDFA0)
                  .withValues(alpha: 0.16 * (1 - age) / g)
              ..strokeWidth = thick
              ..strokeCap = StrokeCap.round,
          );
        }
      }

      // 弦身外的一层柔光：上光漆面上的弦不是一根硬线，而是带一圈反光
      canvas.drawPath(
        stringPath(0, 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFFFEBC0).withValues(alpha: 0.10)
          ..strokeWidth = thick + 2.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // 弦身：蚕丝弦的暖白，中间亮、两端暗
      canvas.drawPath(
        stringPath(0, 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF7A6A4E).withValues(alpha: 0.40),
              const Color(0xFFD8C7A2).withValues(alpha: 0.62),
              const Color(0xFF8E7C5E).withValues(alpha: 0.40),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromLTRB(left, y - 2, right, y + 2))
          ..strokeWidth = thick
          ..strokeCap = StrokeCap.round,
      );

      // 弦顶一线高光，随拨动增亮
      canvas.drawPath(
        stringPath(0.15, 0.9),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withValues(alpha: vibrating ? 0.55 : 0.30)
          ..strokeWidth = math.max(0.7, thick - 0.8)
          ..strokeCap = StrokeCap.round,
      );

      // 触弦处的光点与漆面涟漪
      if (vibrating && age < 0.55) {
        final fade = 1 - age / 0.55;
        final px = pluckXs[i];
        canvas.drawCircle(
          Offset(px, y),
          gap * 0.13 * (0.6 + fade),
          Paint()
            ..color = const Color(0xFFFFE6A8).withValues(alpha: 0.30 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // 弦振带动琴面的一圈涟漪
        final rt = (age / 0.9).clamp(0.0, 1.0).toDouble();
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(px, y + gap * 0.10),
            width: w * (0.10 + rt * 0.30),
            height: gap * (0.9 + rt * 1.5),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color =
                const Color(0xFFE8CF9A).withValues(alpha: 0.16 * (1 - rt)),
        );
      }
    }

    // 左手按弦：一颗温润的指腹点，提示这根弦正被按住
    for (var i = 0; i < 7 && i < pressXs.length; i++) {
      final px = pressXs[i];
      if (px < 0) continue;
      final y = stringsTop + i * gap;
      canvas.drawCircle(
        Offset(px, y),
        gap * 0.20,
        Paint()
          ..color = const Color(0xFFFFE9C4).withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(px, y),
        gap * 0.10,
        Paint()..color = const Color(0xFFF3DFB4).withValues(alpha: 0.55),
      );
    }

    // 7. 面缘：一线天光与内侧阴影，强化厚度
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0x66FFE7C4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.restore();
  }

  /// 岳山（承弦的木桥）与龙龈（弦尾），让七弦有真实的起止。
  void _bridge(Canvas canvas, double w, double top, double left, double right,
      double stringsTop, double stringsBottom) {
    // 岳山：右侧竖向木枕
    final bridgeRect = Rect.fromCenter(
      center: Offset(right, (stringsTop + stringsBottom) / 2),
      width: w * 0.016,
      height: (stringsBottom - stringsTop) + 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bridgeRect, const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1B120B), Color(0xFF5C4227), Color(0xFF140D08)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(bridgeRect),
    );
    canvas.drawRect(
      Rect.fromLTWH(
          right - w * 0.003, bridgeRect.top, w * 0.003, bridgeRect.height),
      Paint()..color = const Color(0xFFFFE9C2).withValues(alpha: 0.35),
    );

    // 龙龈：左侧承弦的低矮木托
    final tailRect = Rect.fromCenter(
      center: Offset(left, (stringsTop + stringsBottom) / 2),
      width: w * 0.012,
      height: (stringsBottom - stringsTop) + 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tailRect, const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF100A06), Color(0xFF46301D), Color(0xFF100A06)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(tailRect),
    );
  }

  // -------------------------------------------------------------- 统一影调

  /// 场景影调、暗角与近景渐隐：把照片、氛围与琴面统一成一个镜头。
  void _paintGrade(Canvas canvas, Size size, double phase) {
    final w = size.width;
    final h = size.height;

    final tint = switch (realm) {
      0 => const Color(0xFF1B2B22),
      1 => const Color(0xFF241608),
      _ => const Color(0xFF081222),
    };

    // 底部渐隐：给琴面的下缘与底部控件留出承托
    canvas.drawRect(
      Rect.fromLTRB(0, h * 0.80, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: 0.0),
            const Color(0xFF05060A).withValues(alpha: 0.72),
          ],
        ).createShader(Rect.fromLTRB(0, h * 0.80, w, h)),
    );

    // 暗角
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.15),
          radius: 1.05,
          colors: [
            const Color(0x00000000),
            const Color(0xFF040608).withValues(alpha: 0.55),
          ],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  double _hash(double v) {
    final s = math.sin(v * 127.1 + 311.7) * 43758.5453;
    return s - s.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant RealmPainter old) {
    if (old.realm != realm ||
        old.immersiveMotion != immersiveMotion ||
        old.background != background ||
        old.qin != qin ||
        !listEquals(old.plucks, plucks) ||
        !listEquals(old.pluckXs, pluckXs) ||
        !listEquals(old.pressXs, pressXs)) {
      return true;
    }
    return immersiveMotion && old.ambient != ambient;
  }
}
