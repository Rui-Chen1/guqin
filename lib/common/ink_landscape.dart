import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 水墨立轴画笔：绫边装裱 · 纸纹水渍 · 淡月归鸿 · 平远三重 · 峻拔主峰 ·
/// 飞瀑断云 · 云海烟岚 · 近坡老松 · 崖畔丹叶。
///
/// 取「高远」之势：主峰一峰突起、峰脊积墨点苔，长皴如斧劈；山腰横云一道，
/// 山根没入烟岚，故峰高而不见其底。远山以淡墨化入纸面，近坡重墨压住下缘；
/// 崖畔几点朱砂丹叶是全画唯一的暖色，与钤印相照。
///
/// 首页与内页共用此画笔，只以 [density]、[framed] 二参数分主次：
/// 首页 density = 1、framed = true，是一幅被装裱起来的画；
/// 内页 density ≈ 0.5、framed = false，淡墨只作纸底。
/// 如此「展卷临琴」之境贯通全应用，而非首页古风、内页却是空纸。
class InkLandscapePainter extends CustomPainter {
  InkLandscapePainter({
    required this.progress,
    required this.drift,
    required this.scroll,
    this.density = 1.0,
    this.framed = false,
    this.riverLandscape = false,
    this.foregroundOnly = false,
  });

  /// 入场进度 0→1。
  final double progress;

  /// 循环时间轴 0→1，驱动云气、月华与归鸿的缓慢流动。
  final double drift;

  /// 已滚动距离，用于视差。
  final double scroll;

  /// 墨色浓度：内页调低，以免喧宾夺主。
  final double density;

  /// 是否画绫边装裱与天地界线。
  final bool framed;

  /// 是否使用富春江式平远水面构图。
  final bool riverLandscape;

  /// Whether to paint only subtle atmospheric detail over an image background.
  final bool foregroundOnly;

  static const double _twoPi = math.pi * 2;

  /// 徽墨偏暖，非纯黑；全画墨色皆由此稀释而出。
  static const Color _ink = AppColors.ink;

  /// 纸白，用于云、雾、瀑的留白处。
  static const Color _paperGlow = Color(0xFFF8F5EE);

  static const List<Offset> _peakShape = [
    Offset(0.000, 0.920),
    Offset(0.050, 0.865),
    Offset(0.100, 0.800),
    Offset(0.150, 0.700),
    Offset(0.200, 0.610),
    Offset(0.245, 0.585),
    Offset(0.285, 0.470),
    Offset(0.335, 0.400),
    Offset(0.375, 0.372),
    Offset(0.405, 0.330),
    Offset(0.452, 0.300),
    Offset(0.490, 0.268),
    Offset(0.525, 0.296),
    Offset(0.570, 0.345),
    Offset(0.615, 0.420),
    Offset(0.670, 0.470),
    Offset(0.700, 0.530),
    Offset(0.760, 0.600),
    Offset(0.830, 0.690),
    Offset(0.900, 0.790),
    Offset(1.000, 0.902),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final a = progress.clamp(0.0, 1.0) * density;
    final enter = 1.0 - progress.clamp(0.0, 1.0);

    if (foregroundOnly) {
      _cloudBank(canvas, size, a, enter);
      return;
    }

    if (riverLandscape) {
      _paintRiverLandscape(canvas, size, a, enter);
      return;
    }

    // 四重景深各按不同速度错位，滚动时生出「云行山不动」的长卷纵深。
    final far = -scroll * 0.018 + enter * 42;
    final mid = -scroll * 0.050 + enter * 28;
    final near = -scroll * 0.095 + enter * 14;

    // 1) 宣纸底：暖白渐变 + 四周暗角，两缘裱以绫边
    _paperGround(canvas, size);

    // 2) 纸纹：纤维、沙点与淡淡水渍
    _paperGrain(canvas, size, a);

    // 3) 淡月：月晕随呼吸微涨落
    _moon(canvas, size, a);

    // 4) 天际平远：淡墨远山横亘题签之后
    _mount(canvas, size,
        baseY: h * 0.178 + far * 0.35,
        amp: h * 0.058,
        seed: 5,
        ink: 0.095,
        a: a,
        texture: false);
    _mount(canvas, size,
        baseY: h * 0.222 + far * 0.55,
        amp: h * 0.068,
        seed: 41,
        ink: 0.145,
        a: a,
        texture: false);
    _mount(canvas, size,
        baseY: h * 0.268 + far * 0.75,
        amp: h * 0.075,
        seed: 23,
        ink: 0.115,
        a: a,
        texture: false);

    _mount(canvas, size,
        baseY: h * 0.395 + far,
        amp: h * 0.085,
        seed: 57,
        ink: 0.165,
        a: a,
        texture: false);

    // 6) 主峰：一峰突起，峻拔入云
    _greatPeak(canvas, size, a, mid);

    // Keep the waterfall anchored to the main peak as the canvas scrolls.
    _waterfall(canvas, size, a, mid);

    // 9) 云海：横贯山腰的白练
    _cloudBank(canvas, size, a, enter);

    // 10) 烟岚：空气纵深
    _haze(canvas, size, a);

    // 11) 近山与坡岸：重墨石骨，崖畔丹叶
    _mount(canvas, size,
        baseY: h * 0.800 + near,
        amp: h * 0.190,
        seed: 13,
        ink: 0.42,
        a: a,
        dominate: 2,
        moss: true);

    // 12) 老松下的文人听琴：剪影化入意境
    _pine(canvas, size, a, near);
    _scholar(canvas, size, a, near);
    _redLeaves(canvas, size, a, near);

    // 13) 淡墨归鸿
    _cranes(canvas, size, a);

    // 14) 题字与落款
    _watermark(canvas, size, a);
    _colophon(canvas, size, a);
    _marginalia(canvas, size, a);
  }

  void _paintRiverLandscape(Canvas canvas, Size size, double a, double enter) {
    final w = size.width;
    final h = size.height;
    final driftX = math.sin(drift * _twoPi) * w * 0.002;
    final scrollY = -scroll * 0.006 + enter * 8;

    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4F0E7), Color(0xFFFAF8F2), Color(0xFFF5F1E8)],
          stops: [0.0, 0.58, 1.0],
        ).createShader(rect),
    );
    _paperGrain(canvas, size, a * 0.72);

    _riverMountain(
      canvas,
      size,
      points: [
        const Offset(0, 0.345),
        const Offset(0.08, 0.315),
        const Offset(0.16, 0.326),
        const Offset(0.255, 0.272),
        const Offset(0.34, 0.309),
        const Offset(0.43, 0.286),
        const Offset(0.52, 0.322),
        const Offset(0.62, 0.266),
        const Offset(0.72, 0.302),
        const Offset(0.83, 0.258),
        const Offset(0.91, 0.304),
        const Offset(1, 0.282),
      ],
      offsetX: driftX * 0.4,
      offsetY: scrollY * 0.32,
      color: const Color(0xFF66736B),
      opacity: 0.20 * a,
    );
    _riverMountain(
      canvas,
      size,
      points: [
        const Offset(0, 0.421),
        const Offset(0.09, 0.375),
        const Offset(0.18, 0.402),
        const Offset(0.275, 0.344),
        const Offset(0.37, 0.382),
        const Offset(0.47, 0.351),
        const Offset(0.57, 0.394),
        const Offset(0.68, 0.352),
        const Offset(0.78, 0.398),
        const Offset(0.89, 0.356),
        const Offset(1, 0.392),
      ],
      offsetX: -driftX * 0.55,
      offsetY: scrollY * 0.62,
      color: const Color(0xFF59655D),
      opacity: 0.17 * a,
    );
    _riverMountain(
      canvas,
      size,
      points: [
        const Offset(0, 0.474),
        const Offset(0.11, 0.443),
        const Offset(0.21, 0.461),
        const Offset(0.31, 0.421),
        const Offset(0.41, 0.452),
        const Offset(0.52, 0.424),
        const Offset(0.63, 0.466),
        const Offset(0.74, 0.43),
        const Offset(0.86, 0.466),
        const Offset(1, 0.438),
      ],
      offsetX: driftX * 0.2,
      offsetY: scrollY * 0.86,
      color: const Color(0xFF777D73),
      opacity: 0.105 * a,
    );

    _riverShore(canvas, size, a, scrollY);

    final mistRect = Rect.fromLTWH(0, h * 0.385 + scrollY, w, h * 0.105);
    canvas.drawRect(
      mistRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _paperGlow.withValues(alpha: 0.02 * a),
            _paperGlow.withValues(alpha: 0.42 * a),
            _paperGlow.withValues(alpha: 0.04 * a),
          ],
        ).createShader(mistRect),
    );

    _riverRipples(canvas, size, a, driftX, scrollY);
  }

  void _riverMountain(
    Canvas canvas,
    Size size, {
    required List<Offset> points,
    required double offsetX,
    required double offsetY,
    required Color color,
    required double opacity,
  }) {
    final w = size.width;
    final h = size.height;
    final ridgePoints = points
        .map((point) => Offset(point.dx * w + offsetX, point.dy * h + offsetY))
        .toList();
    final ridge = Path()..moveTo(ridgePoints.first.dx, ridgePoints.first.dy);
    for (var i = 1; i < ridgePoints.length; i++) {
      final previous = ridgePoints[i - 1];
      final current = ridgePoints[i];
      final midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      ridge.quadraticBezierTo(
          previous.dx, previous.dy, midpoint.dx, midpoint.dy);
    }
    ridge.lineTo(ridgePoints.last.dx, ridgePoints.last.dy);
    final body = Path.from(ridge)
      ..lineTo(w, h * 0.60)
      ..lineTo(0, h * 0.60)
      ..close();

    final bounds = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.66),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.22, 1],
        ).createShader(bounds),
    );

    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: opacity * 0.60),
    );

    canvas.save();
    canvas.clipPath(body);
    final texture = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: opacity * 0.36);
    for (var i = 1; i < ridgePoints.length - 1; i += 3) {
      final peak = ridgePoints[i];
      final endX = math.min(w, peak.dx + w * 0.075);
      final startY = peak.dy + h * 0.018;
      final endY = startY + h * 0.035;
      canvas.drawPath(
        Path()
          ..moveTo(peak.dx + w * 0.012, startY)
          ..quadraticBezierTo(
            peak.dx + w * 0.045,
            startY + h * 0.006,
            endX,
            endY,
          ),
        texture,
      );
    }
    canvas.restore();
  }

  void _riverShore(Canvas canvas, Size size, double a, double dy) {
    final w = size.width;
    final h = size.height;
    final shorePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1
      ..color = _ink.withValues(alpha: 0.12 * a);
    final shorelines = [
      Path()
        ..moveTo(-w * 0.05, h * 0.592 + dy)
        ..cubicTo(
          w * 0.08,
          h * 0.570 + dy,
          w * 0.13,
          h * 0.607 + dy,
          w * 0.26,
          h * 0.586 + dy,
        )
        ..cubicTo(
          w * 0.31,
          h * 0.579 + dy,
          w * 0.34,
          h * 0.589 + dy,
          w * 0.39,
          h * 0.594 + dy,
        ),
      Path()
        ..moveTo(w * 0.62, h * 0.614 + dy)
        ..cubicTo(
          w * 0.70,
          h * 0.600 + dy,
          w * 0.73,
          h * 0.572 + dy,
          w * 0.81,
          h * 0.586 + dy,
        )
        ..cubicTo(
          w * 0.88,
          h * 0.600 + dy,
          w * 0.92,
          h * 0.559 + dy,
          w * 1.05,
          h * 0.570 + dy,
        ),
    ];
    for (final shoreline in shorelines) {
      canvas.drawPath(shoreline, shorePaint);
    }

    final grass = Paint()
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.09 * a);
    for (var i = 0; i < 22; i++) {
      final onLeft = i < 11;
      final x = onLeft ? w * (0.02 + i * 0.031) : w * (0.68 + (i - 11) * 0.032);
      final y =
          (onLeft ? h * 0.59 : h * 0.60) + dy + math.sin(i * 1.7) * h * 0.012;
      final length = h * (0.006 + (i % 3) * 0.002);
      canvas.drawLine(Offset(x, y), Offset(x + w * 0.008, y - length), grass);
    }
  }

  void _riverRipples(Canvas canvas, Size size, double a, double dx, double dy) {
    final w = size.width;
    final h = size.height;
    const marks =
        <({double x, double y, double length, double bend, double alpha})>[
      (x: 0.08, y: 0.492, length: 0.16, bend: -0.008, alpha: 0.075),
      (x: 0.38, y: 0.515, length: 0.25, bend: 0.006, alpha: 0.090),
      (x: 0.67, y: 0.487, length: 0.20, bend: -0.005, alpha: 0.070),
      (x: 0.18, y: 0.552, length: 0.28, bend: 0.005, alpha: 0.068),
      (x: 0.57, y: 0.574, length: 0.30, bend: -0.006, alpha: 0.080),
      (x: 0.05, y: 0.626, length: 0.21, bend: 0.004, alpha: 0.052),
      (x: 0.72, y: 0.642, length: 0.19, bend: -0.004, alpha: 0.055),
    ];
    for (final mark in marks) {
      final startX = w * mark.x + dx;
      final y = h * mark.y + dy;
      final endX = math.min(w, startX + w * mark.length);
      final line = Path()
        ..moveTo(startX, y)
        ..cubicTo(
          startX + (endX - startX) * 0.32,
          y + h * mark.bend,
          startX + (endX - startX) * 0.68,
          y - h * mark.bend * 0.6,
          endX,
          y + h * mark.bend * 0.2,
        );
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = mark.y > 0.60 ? 0.65 : 0.9
          ..strokeCap = StrokeCap.round
          ..color = _ink.withValues(alpha: mark.alpha * a),
      );
    }
  }

  /// 宣纸底 + 立轴装裱：暖白渐变、四周暗角，两缘裱以绫边并勒细线。
  ///
  /// 绫边是「这是一幅画」的第一眼凭据：画心与屏框之间隔一道旧米黄，
  /// 纸便不再是屏幕的底色，而是一件被装裱起来的东西。
  void _paperGround(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8E3D6), Color(0xFFDDD7C8), Color(0xFFD0C9B8)],
          stops: [0.0, 0.52, 1.0],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [const Color(0x002B2620), _ink.withValues(alpha: 0.18)],
          stops: const [0.46, 1.0],
        ).createShader(rect),
    );

    if (!framed) return;

    // 绫边：两缘各裱一条，色自浅入深，如绢帛受光
    final band = math.max(10.0, size.width * 0.036);
    final silk = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF0EBDF), Color(0xFFE2DBCB), Color(0xFFD3CAB5)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, band, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, band, size.height), silk);
    canvas.drawRect(
        Rect.fromLTWH(size.width - band, 0, band, size.height), silk);

    // 内缘勒线：画心与绫边的分界
    final edge = Paint()
      ..strokeWidth = 1.1
      ..color = const Color(0xFFA79C82).withValues(alpha: 0.42);
    canvas.drawLine(Offset(band, 0), Offset(band, size.height), edge);
    canvas.drawLine(Offset(size.width - band, 0),
        Offset(size.width - band, size.height), edge);

    // 天地：上下各压一道，令画幅四面收边
    final earth = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xFFA79C82).withValues(alpha: 0.30);
    canvas.drawLine(const Offset(0, 0.6), Offset(size.width, 0.6), earth);
    canvas.drawLine(Offset(0, size.height - 0.6),
        Offset(size.width, size.height - 0.6), earth);
  }

  /// 纸纹：定种随机的细纤维、沙点与淡淡水渍，静态不随帧变，纯为质感。
  void _paperGrain(Canvas canvas, Size size, double a) {
    final rnd = math.Random(20261027);
    final fiber = Paint()
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.016 * a);
    for (var i = 0; i < 110; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final len = 6 + rnd.nextDouble() * 26;
      final ang = rnd.nextDouble() * math.pi;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(ang) * len, y + math.sin(ang) * len),
        fiber,
      );
    }
    final speck = Paint()..color = _ink.withValues(alpha: 0.024 * a);
    for (var i = 0; i < 70; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.5 + rnd.nextDouble() * 0.8,
        speck,
      );
    }
    // 水渍：数团极淡的晕，如旧纸受潮
    for (var i = 0; i < 4; i++) {
      final c =
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = size.width * (0.12 + rnd.nextDouble() * 0.18);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _ink.withValues(alpha: 0.013 * a),
              const Color(0x002B2620)
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  /// 淡月：三层月晕 + 月轮 + 一圈极淡的轮廓。
  /// 增加了金色边缘光晕，使其更具吸引力。
  void _moon(Canvas canvas, Size size, double a) {
    final breathe = 1 + 0.045 * math.sin(drift * _twoPi);
    final moon = Offset(size.width * 0.745, size.height * 0.108);
    final r = math.min(size.width, size.height) * 0.052 * breathe;

    // 金色环境光
    canvas.drawCircle(
      moon,
      r * 5.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFAEC).withValues(alpha: 0.58 * a),
            const Color(0xFFFFFAEC).withValues(alpha: 0.16 * a),
            const Color(0x00FFFAEC),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: moon, radius: r * 5.2)),
    );
    canvas.drawCircle(moon, r,
        Paint()..color = const Color(0xFFFDFAF0).withValues(alpha: 0.95 * a));
    canvas.drawCircle(
      moon,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFFC9BDA4).withValues(alpha: 0.42 * a),
    );
  }

  /// 一座平远小山。
  ///
  /// 山体自上而下由浓入淡、化入纸面；入山体界内再压一道积墨带，令山骨显；
  /// [texture] 时沿脊补斧劈皴，[moss] 时于峰脊攒点苔，最后于脊线外勒一笔。
  /// [dominate] 指定某折点拔为主峰，取「一峰突起」之势。
  void _mount(
    Canvas canvas,
    Size size, {
    required double baseY,
    required double amp,
    required int seed,
    required double ink,
    required double a,
    bool texture = true,
    bool moss = false,
    int? dominate,
  }) {
    final rnd = math.Random(seed);
    final w = size.width;
    final h = size.height;
    const pairs = 6;
    final step = w / pairs;

    final pts = <Offset>[
      Offset(0, baseY - amp * (0.34 + rnd.nextDouble() * 0.30))
    ];
    for (var i = 1; i <= pairs; i++) {
      final k = i.isEven
          ? (0.05 + rnd.nextDouble() * 0.35)
          : (0.58 + rnd.nextDouble() * 0.42);
      pts.add(Offset(step * i, baseY - k * amp));
    }
    if (dominate != null) {
      pts[dominate] = Offset(
          pts[dominate].dx, baseY - amp * (1.02 + rnd.nextDouble() * 0.10));
    }

    final ridge = _smoothPath(pts);
    final top = ridge.getBounds().top;

    final body = Path.from(ridge)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _ink.withValues(alpha: math.min(ink * 1.35, 0.98) * a),
            _ink.withValues(alpha: ink * 0.90 * a),
            _ink.withValues(alpha: ink * 0.08 * a),
          ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(Rect.fromLTRB(0, top, w, h)),
    );

    // 山体之内的一切笔触皆以形体为界，免得留白处染上墨
    canvas.save();
    canvas.clipPath(body);

    // 积墨带：沿脊压一道宽笔
    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = amp * 0.34
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withValues(alpha: ink * 0.30 * a),
    );

    if (texture) {
      // 斧劈皴：自脊线顺坡斜扫的短笔，示山石肌理
      final chaps = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round
        ..color = _ink.withValues(alpha: math.min(ink * 0.9, 0.5) * a);
      for (var i = 0; i < pts.length - 1; i++) {
        final p0 = pts[i];
        final p1 = pts[i + 1];
        final lean = p1.dy > p0.dy ? 0.42 : -0.42;
        for (var s = 0; s < 3; s++) {
          final t = (s + 0.7) / 3.6;
          final x0 = p0.dx + (p1.dx - p0.dx) * t;
          final y0 = p0.dy + (p1.dy - p0.dy) * t;
          final len = amp * (0.18 + rnd.nextDouble() * 0.16);
          canvas.drawPath(
            Path()
              ..moveTo(x0, y0)
              ..quadraticBezierTo(x0 + len * lean, y0 + len * 0.55,
                  x0 + len * lean * 1.5, y0 + len),
            chaps,
          );
        }
      }
    }

    if (moss) {
      // 苔点：攒聚峰脊，如矾头点苔
      final dots = Paint()
        ..color = _ink.withValues(alpha: math.min(ink * 1.15, 0.55) * a);
      for (var i = 1; i < pts.length; i++) {
        final p = pts[i];
        for (var d = 0, n = 1 + rnd.nextInt(3); d < n; d++) {
          canvas.drawCircle(
            Offset(p.dx + (rnd.nextDouble() - 0.5) * 22,
                p.dy + rnd.nextDouble() * amp * 0.24),
            0.9 + rnd.nextDouble() * 1.4,
            dots,
          );
        }
      }
    }

    canvas.restore();

    // 勒：脊线外再描一线，山骨清晰
    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withValues(alpha: math.min(ink * 1.6, 0.72) * a),
    );
  }

  /// 主峰：一峰突起，峻拔入云，是全画的山骨。
  ///
  /// 山形取「高远」——峰顶高揭近画幅五分之一，折点密而陡，长皴自脊下垂如斧劈；
  /// 腰际横云一道，山根没入烟岚，故峰虽高而不见其底。与 [_mount] 的平远小山
  /// 判然两途：彼以形胜，此以势胜。
  void _greatPeak(Canvas canvas, Size size, double a, double dy) {
    final w = size.width;
    final h = size.height;
    final rnd = math.Random(913);
    final pts = _peakRidge(size, dy);
    final ridge = _smoothPath(pts);
    final top = ridge.getBounds().top;
    final body = Path.from(ridge)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final peak = pts.reduce((p, q) => p.dy < q.dy ? p : q);

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _ink.withValues(alpha: 0.30 * a),
            _ink.withValues(alpha: 0.16 * a),
            _ink.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTRB(0, top, w, h)),
    );

    canvas.save();
    canvas.clipPath(body);

    final spine = <Offset>[peak];
    for (var i = 1; i <= 6; i++) {
      final t = i / 6;
      spine.add(Offset(
        peak.dx - w * 0.07 * t + (rnd.nextDouble() - 0.5) * w * 0.03,
        peak.dy + (h - peak.dy) * 0.7 * t,
      ));
    }
    final shade = _smoothPath(spine)
      ..lineTo(w, spine.last.dy)
      ..lineTo(w, 0)
      ..lineTo(peak.dx, 0)
      ..close();
    canvas.drawPath(
      shade,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..shader = LinearGradient(
          colors: [
            _ink.withValues(alpha: 0.26 * a),
            _ink.withValues(alpha: 0.08 * a),
          ],
        ).createShader(Rect.fromLTRB(peak.dx - w * 0.1, 0, w, h)),
    );

    _facets(canvas, peak, size, a, rnd);

    for (var k = 0; k < 3; k++) {
      canvas.drawPath(
        ridge.shift(Offset(w * 0.01 * (k + 1), h * 0.035 * (k + 1))),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * (0.030 - k * 0.006)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7.0 + k * 2)
          ..color = _ink.withValues(alpha: (0.12 - k * 0.025) * a),
      );
    }

    final chap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 2; i < pts.length - 2; i += 2) {
      final point = pts[i];
      final inShade = point.dx > _spineX(spine, point.dy);
      final count = inShade ? 3 : 1;
      final slope = (pts[i + 1].dy - pts[i - 1].dy) /
          (pts[i + 1].dx - pts[i - 1].dx + 0.001);
      final lean = (slope * 0.25).clamp(-0.6, 0.6);
      for (var s = 0; s < count; s++) {
        final length = h * (0.04 + rnd.nextDouble() * 0.08);
        var x = point.dx + (rnd.nextDouble() - 0.5) * 6;
        var y = point.dy + rnd.nextDouble() * h * 0.015;
        final pieces = 2 + rnd.nextInt(3);
        for (var q = 0; q < pieces; q++) {
          final segment = length / pieces;
          if (rnd.nextDouble() >= 0.3) {
            chap
              ..strokeWidth = 0.5 + rnd.nextDouble()
              ..color = _ink.withValues(
                alpha: (inShade ? 0.30 : 0.14) * (1 - q / pieces * 0.6) * a,
              );
            canvas.drawLine(
              Offset(x, y),
              Offset(x + segment * lean, y + segment),
              chap,
            );
          }
          x += segment * lean * 1.2;
          y += segment * 1.15;
        }
      }
    }

    final tree = Paint()
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.38 * a);
    for (var i = 6; i < pts.length - 6; i += 8) {
      if (rnd.nextDouble() < 0.4) continue;
      final point = pts[i];
      for (var n = 0, count = 2 + rnd.nextInt(3); n < count; n++) {
        final x = point.dx + (rnd.nextDouble() - 0.5) * 14;
        final y = point.dy + 2 + rnd.nextDouble() * 5;
        tree.strokeWidth = 0.8 + rnd.nextDouble() * 0.6;
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y - 3 - rnd.nextDouble() * 4),
          tree,
        );
      }
    }

    canvas.restore();

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < pts.length - 1; i++) {
      if (rnd.nextDouble() < 0.12) continue;
      final inShade = pts[i].dx > peak.dx - w * 0.05;
      edge
        ..strokeWidth = (inShade ? 1.4 : 0.8) * (0.7 + rnd.nextDouble() * 0.6)
        ..color = _ink.withValues(alpha: (inShade ? 0.50 : 0.28) * a);
      canvas.drawLine(pts[i], pts[i + 1], edge);
    }
  }

  double _spineX(List<Offset> spine, double y) {
    for (var i = 0; i < spine.length - 1; i++) {
      if (y <= spine[i + 1].dy) {
        final t = ((y - spine[i].dy) / (spine[i + 1].dy - spine[i].dy + 0.001))
            .clamp(0.0, 1.0);
        return spine[i].dx + (spine[i + 1].dx - spine[i].dx) * t;
      }
    }
    return spine.last.dx;
  }

  void _facets(
      Canvas canvas, Offset peak, Size size, double a, math.Random rnd) {
    final w = size.width;
    final h = size.height;
    final ends = <Offset>[
      for (var i = 0; i < 6; i++)
        Offset(
          peak.dx + (i - 2.2) * w * 0.20 + (rnd.nextDouble() - 0.5) * w * 0.06,
          h * (0.78 + rnd.nextDouble() * 0.08),
        ),
    ];
    for (var i = 0; i < ends.length - 1; i++) {
      final dark = i >= 2;
      final tone = dark ? 0.20 : (i.isEven ? 0.07 : 0.03);
      final mid = Offset(
        (peak.dx + ends[i].dx) / 2 + (rnd.nextDouble() - 0.5) * 18,
        (peak.dy + ends[i].dy) / 2,
      );
      final nextMid = Offset(
        (peak.dx + ends[i + 1].dx) / 2,
        (peak.dy + ends[i + 1].dy) / 2,
      );
      final facet = Path()
        ..moveTo(peak.dx, peak.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, ends[i].dx, ends[i].dy)
        ..lineTo(ends[i + 1].dx, ends[i + 1].dy)
        ..quadraticBezierTo(
          nextMid.dx,
          nextMid.dy,
          peak.dx,
          peak.dy,
        )
        ..close();
      canvas.drawPath(
        facet,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
          ..color = _ink.withValues(alpha: tone * a),
      );
    }
  }

  /// 崖畔丹叶：浓墨山根上点几笔朱砂。
  ///
  /// 全画自月白、纸黄至墨黑，皆在暖冷之间；唯此数点朱砂最艳，
  /// 与钤印、朱砂小签同出一色，令满纸秋意有了着落。
  void _redLeaves(Canvas canvas, Size size, double a, double dy) {
    final rnd = math.Random(177);
    final leaf = Paint();
    for (final c in [
      Offset(size.width * 0.825, size.height * 0.812 + dy),
      Offset(size.width * 0.350, size.height * 0.886 + dy),
      Offset(size.width * 0.580, size.height * 0.920 + dy),
    ]) {
      for (var i = 0; i < 15; i++) {
        final ang = rnd.nextDouble() * _twoPi;
        final rad = math.sqrt(rnd.nextDouble()) * size.width * 0.045;
        leaf.color = AppColors.cinnabar
            .withValues(alpha: (0.22 + rnd.nextDouble() * 0.28) * a);
        canvas.drawCircle(
          Offset(c.dx + math.cos(ang) * rad, c.dy + math.sin(ang) * rad * 0.72),
          0.6 + rnd.nextDouble() * 1.8,
          leaf,
        );
      }
    }
  }

  /// 飞瀑：自峰之右胁跌落，中段横石一截，遂成两叠；旁以浓墨勒出石壁。
  void _waterfall(Canvas canvas, Size size, double a, double dy) {
    final w = size.width;
    final h = size.height;
    final pts = _peakRidge(size, dy);
    final rnd = math.Random(88);
    final centerX = w * 0.585;
    final top = _ridgeY(pts, centerX) + h * 0.03;
    final bottom = h * 0.655 + dy;
    const steps = 28;

    double centerAt(double t) =>
        centerX + w * 0.055 * t + math.sin(t * math.pi * 2.6) * w * 0.007;

    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final y = top + (bottom - top) * t;
      final halfWidth =
          w * (0.005 + 0.016 * t * t) * (0.85 + rnd.nextDouble() * 0.30);
      left.add(Offset(centerAt(t) - halfWidth, y));
      right.add(Offset(centerAt(t) + halfWidth, y));
    }

    final fall = Path()..moveTo(left.first.dx, left.first.dy);
    for (final point in left.skip(1)) {
      fall.lineTo(point.dx, point.dy);
    }
    for (final point in right.reversed) {
      fall.lineTo(point.dx, point.dy);
    }
    fall.close();

    final bank = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.18 * a)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    canvas.drawPath(Path()..addPolygon(left, false), bank);
    canvas.drawPath(Path()..addPolygon(right, false), bank);

    canvas.drawPath(
      fall,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _paperGlow.withValues(alpha: 0.0),
            _paperGlow.withValues(alpha: 0.92 * a),
            _paperGlow.withValues(alpha: 0.70 * a),
            _paperGlow.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.12, 0.70, 1.0],
        ).createShader(fall.getBounds()),
    );

    final streak = Paint()
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 6; k++) {
      final across = (k + 0.5) / 6;
      final phase = rnd.nextDouble();
      for (var i = 0; i < steps; i += 2) {
        final next = math.min(i + 2, steps);
        Offset pointAt(int index) => Offset(
              left[index].dx + (right[index].dx - left[index].dx) * across,
              left[index].dy,
            );
        final flow = 0.5 +
            0.5 * math.sin(_twoPi * (i / steps * 2.5 - drift * 30 + phase));
        streak.color = _ink.withValues(alpha: (0.04 + 0.12 * flow) * a);
        canvas.drawLine(pointAt(i), pointAt(next), streak);
      }
    }

    final crag = Paint()
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.26 * a);
    for (var i = 0; i < 11; i++) {
      final t = 0.05 + rnd.nextDouble() * 0.9;
      final index = (t * steps).round();
      final isLeft = rnd.nextBool();
      final edge = isLeft ? left[index] : right[index];
      final direction = isLeft ? -1.0 : 1.0;
      final length = h * (0.012 + rnd.nextDouble() * 0.028);
      crag.strokeWidth = 0.6 + rnd.nextDouble();
      canvas.drawLine(
        edge + Offset(direction * w * 0.004, 0),
        edge + Offset(direction * (w * 0.004 + length * 0.5), length),
        crag,
      );
    }

    final mist = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    for (var i = 0; i < 9; i++) {
      final mx = centerAt(1) + (rnd.nextDouble() - 0.5) * w * 0.16;
      final my = bottom -
          rnd.nextDouble() * h * 0.02 +
          math.sin(_twoPi * (drift * 3 + i * 0.11)) * 4;
      mist.color =
          _paperGlow.withValues(alpha: (0.18 + rnd.nextDouble() * 0.14) * a);
      canvas.drawCircle(Offset(mx, my), 7 + rnd.nextDouble() * 11, mist);
    }
  }

  List<Offset> _peakPoints(Size size, double dy) => [
        for (final point in _peakShape)
          Offset(point.dx * size.width, point.dy * size.height + dy),
      ];

  List<Offset> _peakRidge(Size size, double dy) {
    final rnd = math.Random(913);
    final base = _peakPoints(size, 0);
    final points = <Offset>[];
    for (var i = 0; i < base.length - 1; i++) {
      for (var k = 0; k < 6; k++) {
        final t = k / 6;
        points.add(Offset(
          base[i].dx +
              (base[i + 1].dx - base[i].dx) * t +
              (rnd.nextDouble() - 0.5) * size.width * 0.008,
          base[i].dy +
              (base[i + 1].dy - base[i].dy) * t +
              (rnd.nextDouble() - 0.5) * size.height * 0.010 +
              dy,
        ));
      }
    }
    points.add(base.last + Offset(0, dy));
    return points;
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final midpoint = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
          points[i].dx, points[i].dy, midpoint.dx, midpoint.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  double _ridgeY(List<Offset> points, double x) {
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      if (x <= end.dx) {
        final t = ((x - start.dx) / (end.dx - start.dx)).clamp(0.0, 1.0);
        return start.dy + (end.dy - start.dy) * t;
      }
    }
    return points.last.dy;
  }

  /// 文人观景剪影：老松下的雅集。
  ///
  /// 灵感来自参考图 3：在近景增加人物剪影，提升意境深度。
  void _scholar(Canvas canvas, Size size, double a, double dy) {
    final x = size.width * 0.26;
    final y = size.height * 0.93 + dy;
    final p = Paint()..color = _ink.withValues(alpha: 0.45 * a);

    // 观景者一
    canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + 5, y - 18, x + 2, y - 22) // 身躯
        ..addOval(Rect.fromLTWH(x - 2, y - 28, 8, 8)), // 头部
      p,
    );

    // 观景者二
    final tx = x + 25;
    canvas.drawPath(
      Path()
        ..moveTo(tx, y)
        ..quadraticBezierTo(tx - 3, y - 15, tx, y - 20)
        ..addOval(Rect.fromLTWH(tx - 3, y - 26, 7, 7)),
      p,
    );
  }

  /// 几笔淡墨写归鸿。
  void _cranes(Canvas canvas, Size size, double a) {
    final w = size.width;
    final h = size.height;
    const flock = <(double, double, double, double)>[
      (0, 0, 1.00, 0.00),
      (-20, 9, 0.80, 0.30),
      (-38, -3, 0.65, 0.55),
      (-52, 11, 0.50, 0.80),
    ];
    final baseX = w * (1.12 - 1.24 * drift);
    final baseY = h * 0.17 + math.sin(_twoPi * drift * 2) * h * 0.012;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final (dx, dy, scale, phase) in flock) {
      final wingSpan = 10.0 * scale;
      final flap = math.sin(_twoPi * (drift * 60 + phase));
      final tip = -wingSpan * 0.45 * flap;
      final center = Offset(baseX + dx, baseY + dy);
      paint
        ..strokeWidth = 0.7 + scale * 0.5
        ..color = _ink.withValues(alpha: (0.22 + 0.22 * scale) * a);
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - wingSpan, center.dy + tip)
          ..quadraticBezierTo(
            center.dx - wingSpan * 0.45,
            center.dy + tip - wingSpan * 0.30,
            center.dx,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx + wingSpan * 0.45,
            center.dy + tip - wingSpan * 0.30,
            center.dx + wingSpan,
            center.dy + tip,
          ),
        paint,
      );
      canvas.drawCircle(
        center,
        0.9 * scale + 0.3,
        Paint()..color = _ink.withValues(alpha: 0.4 * a),
      );
    }
  }

  /// 近景老松：自坡石斜出，以重墨写干、细笔攒针。
  void _pine(Canvas canvas, Size size, double a, double dy) {
    final w = size.width;
    final h = size.height;
    final random = math.Random(21);
    _tree(
      canvas,
      Offset(w * 0.14, h * 1.0 + dy),
      h * 0.10,
      0.12,
      6,
      random,
      a,
      pine: true,
    );
    for (final x in [0.36, 0.42, 0.66, 0.72]) {
      _tree(canvas, Offset(w * x, h * 0.86 + dy), h * 0.025, 0, 3, random, a);
    }
  }

  void _tree(
    Canvas canvas,
    Offset base,
    double length,
    double angle,
    int depth,
    math.Random random,
    double a, {
    bool pine = false,
  }) {
    if (depth == 0 || length < 2) {
      final leaf = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4)
        ..color = _ink.withValues(alpha: 0.20 * a);
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          base +
              Offset(
                (random.nextDouble() - 0.5) * 8,
                (random.nextDouble() - 0.5) * 6,
              ),
          2 + random.nextDouble() * 3,
          leaf,
        );
      }
      return;
    }

    final end = base + Offset(math.sin(angle), -math.cos(angle)) * length;
    canvas.drawLine(
      base,
      end,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = depth * 0.55
        ..color = _ink.withValues(alpha: (0.30 + depth * 0.05) * a),
    );
    final branches = depth > 3 ? 2 : 3;
    for (var i = 0; i < branches; i++) {
      _tree(
        canvas,
        end,
        length * (0.66 + random.nextDouble() * 0.16),
        angle +
            (random.nextDouble() - 0.5) * 1.2 +
            (pine ? (i.isEven ? -0.5 : 0.5) : 0),
        depth - 1,
        random,
        a,
        pine: pine,
      );
    }
  }

  /// 云海：天际薄霭两条、山腰白练五条，缓缓漂移、微微起伏，分出三远之深。
  void _cloudBank(Canvas canvas, Size size, double a, double enter) {
    // 天际薄霭：飘在远山与题签之间
    for (var i = 0; i < 2; i++) {
      final ph = (drift + i * 0.30) * _twoPi;
      final cy =
          size.height * (0.150 + i * 0.036) + enter * 12 + math.sin(ph) * 2.5;
      final oval = Rect.fromCenter(
        center: Offset(
            size.width * 0.5 + math.sin(ph * 0.7) * size.width * 0.04, cy),
        width: size.width * 1.06,
        height: size.height * 0.020,
      );
      canvas.drawOval(
        oval,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              _paperGlow.withValues(alpha: 0.0),
              _paperGlow.withValues(alpha: 0.55 * a),
              _paperGlow.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(oval),
      );
    }
    // 山腰云海：改为更为错落的团云，避免形成横向线条
    for (var i = 0; i < 4; i++) {
      final ph = (drift + i * 0.28) * _twoPi;
      final cx = size.width * (0.18 + (i % 2) * 0.52) +
          math.sin(ph * 0.7) * size.width * 0.10;
      final cy = size.height * (0.46 + i * 0.058) -
          scroll * 0.035 +
          enter * 22 +
          math.sin(ph) * 8;
      final oval = Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * (0.50 + (i % 3) * 0.12),
        height: size.height * (0.040 + i * 0.010),
      );
      canvas.drawOval(
        oval,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              _paperGlow.withValues(alpha: 0.0),
              _paperGlow.withValues(alpha: 0.70 * a),
              _paperGlow.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(oval),
      );
    }
  }

  /// 烟岚：中部一层纸白薄雾，把远山、主峰、近坡三景化开，生出空气与纵深。
  void _haze(Canvas canvas, Size size, double a) {
    final r =
        Rect.fromLTWH(0, size.height * 0.42, size.width, size.height * 0.58);
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _paperGlow.withValues(alpha: 0.0),
            _paperGlow.withValues(alpha: 0.30 * a),
            _paperGlow.withValues(alpha: 0.38 * a),
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(r),
    );
  }

  /// 左上留白题字：竖排大字，如屏风题字。
  void _watermark(Canvas canvas, Size size, double a) {
    final tp = TextPainter(
      text: TextSpan(
        text: '高山流水'.split('').join('\n'),
        style: TextStyle(
          fontFamily: AppTheme.kaiFamily,
          fontFamilyFallback: AppTheme.kaiFallback,
          fontSize: 40,
          height: 1.5,
          color: AppColors.ink.withValues(alpha: 0.05 * a),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(
        canvas, Offset(0.118 * size.width, size.height * 0.30 - scroll * 0.02));
  }

  /// 右侧落款：竖排小字 + 朱砂小印，与左上题字遥相呼应。
  void _colophon(Canvas canvas, Size size, double a) {
    final tp = TextPainter(
      text: TextSpan(
        text: '弦上知音'.split('').join('\n'),
        style: TextStyle(
          fontFamily: AppTheme.kaiFamily,
          fontFamilyFallback: AppTheme.kaiFallback,
          fontSize: 12,
          height: 1.6,
          color: AppColors.ink.withValues(alpha: 0.20 * a),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final x = size.width * 0.855;
    final y = size.height * 0.34 - scroll * 0.012;
    tp.paint(canvas, Offset(x, y));
    canvas.drawRect(
      Rect.fromLTWH(x + tp.width * 0.5 - 5, y + tp.height + 8, 10, 10),
      Paint()..color = AppColors.cinnabar.withValues(alpha: 0.22 * a),
    );
  }

  /// 边栏题识：绫边以内各题竖排小字，如装裱上的边款，随卷轻移、淡墨化入纸面。
  ///
  /// 左缘取「万壑松风」、「高山流水」为联，右缘取「松風水月」为识，
  /// 与左上题字遥相呼应，纸面遂不空。
  void _marginalia(Canvas canvas, Size size, double a) {
    _sideText(canvas, '萬壑松風', size.width * 0.052,
        size.height * 0.408 - scroll * 0.006, 11, 0.16 * a);
    _sideText(canvas, '高山流水', size.width * 0.080,
        size.height * 0.452 - scroll * 0.008, 11, 0.13 * a);
    _sideText(canvas, '松風水月', size.width * 0.902,
        size.height * 0.600 - scroll * 0.010, 13, 0.14 * a);
  }

  /// 竖排一列小字，字距疏朗，如卷上题识。
  void _sideText(Canvas canvas, String text, double x, double y,
      double fontSize, double alpha) {
    final tp = TextPainter(
      text: TextSpan(
        text: text.split('').join('\n'),
        style: TextStyle(
          fontFamily: AppTheme.kaiFamily,
          fontFamilyFallback: AppTheme.kaiFallback,
          fontSize: fontSize,
          height: 1.85,
          color: _ink.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant InkLandscapePainter old) =>
      old.progress != progress ||
      old.drift != drift ||
      old.scroll != scroll ||
      old.density != density ||
      old.framed != framed ||
      old.riverLandscape != riverLandscape ||
      old.foregroundOnly != foregroundOnly;
}
