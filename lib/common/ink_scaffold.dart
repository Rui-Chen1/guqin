import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 水墨底纹：宣纸底 + 大字留白 + 淡月 + 云气 + 三重远山。
///
/// 与首页同源。其余页面统一铺一层此底纹，全应用便都有「展卷临琴」之境，
/// 而非只有首页古风、内页却是空白纸。
class InkBackdrop extends StatefulWidget {
  const InkBackdrop({super.key, this.opacity = 1.0, this.scroll});

  /// 底纹浓度，内页可略淡以免喧宾夺主。
  final double opacity;

  /// 若页面可滚动，可传入控制器以获得缓慢视差。
  final ScrollController? scroll;

  @override
  State<InkBackdrop> createState() => _InkBackdropState();
}

class _InkBackdropState extends State<InkBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroll = widget.scroll;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: scroll == null ? _enter : Listenable.merge([_enter, scroll]),
        builder: (context, _) {
          final offset =
              (scroll != null && scroll.hasClients) ? scroll.offset : 0.0;
          return CustomPaint(
            size: Size.infinite,
            painter: InkBackdropPainter(
              progress: _enter.value,
              scroll: offset,
              opacity: widget.opacity,
            ),
          );
        },
      ),
    );
  }
}

/// 带水墨底纹的页面骨架。
///
/// 除首页外的一切页面都用它替代 [Scaffold]，背景方能连贯一致。
class InkScaffold extends StatelessWidget {
  const InkScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.scrollController,
    this.backgroundImageAsset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  /// 传入页面的滚动控制器，远山等背景即随之缓移（视差）。
  final ScrollController? scrollController;
  final String? backgroundImageAsset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: backgroundImageAsset == null
                  ? InkBackdrop(scroll: scrollController)
                  : Opacity(
                      opacity: 0.32,
                      child: Image.asset(
                        backgroundImageAsset!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
            ),
          ),
          Positioned.fill(child: body),
        ],
      ),
    );
  }
}

class InkBackdropPainter extends CustomPainter {
  InkBackdropPainter({
    required this.progress,
    required this.scroll,
    this.opacity = 1.0,
  });

  /// 入场进度 0→1。
  final double progress;

  /// 已滚动距离，用于视差。
  final double scroll;

  /// 整体浓度。
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final a = progress.clamp(0.0, 1.0) * opacity;
    final enter = 1.0 - progress.clamp(0.0, 1.0); // 入场偏移量：1 → 0

    // 1) 宣纸底：天光偏亮，地面转暖
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFAF5EB), Color(0xFFF3EAD9), Color(0xFFE7D8BE)],
          stops: [0.0, 0.52, 1.0],
        ).createShader(rect),
    );

    // 2) 留白题字：竖排大字水印
    _watermark(canvas, size, a);

    // 3) 淡月：月晕 + 月轮
    final moon = Offset(w * 0.80, h * 0.14);
    final r = math.min(w, h) * 0.060;
    canvas.drawCircle(
      moon,
      r * 3.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF7E4).withValues(alpha: 0.55 * a),
            const Color(0x00FFF7E4),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: r * 3.6)),
    );
    canvas.drawCircle(moon, r,
        Paint()..color = const Color(0xFFFCF5E3).withValues(alpha: 0.92 * a));

    // 4) 云气：三条横向柔带，入场时自左缓缓展开
    for (var i = 0; i < 3; i++) {
      final my = h * (0.44 + i * 0.11) - scroll * 0.03 + enter * 16;
      final mx = w * 0.5 - enter * (70.0 + i * 36);
      final oval = Rect.fromCenter(
          center: Offset(mx, my), width: w * 1.3, height: h * 0.075);
      canvas.drawOval(
        oval,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0x00FFFFFF),
              Colors.white.withValues(alpha: 0.38 * a),
              const Color(0x00FFFFFF),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(oval),
      );
    }

    // 5) 远山三重：由淡至浓，山脚没入画面底部；层深不同，视差略异
    _mountain(canvas, size,
        baseY: h * 0.60 - scroll * 0.035 + enter * 26,
        amp: h * 0.095,
        seed: 7,
        color: const Color(0xFF9A8B72).withValues(alpha: 0.22 * a));
    _mountain(canvas, size,
        baseY: h * 0.72 - scroll * 0.055 + enter * 26,
        amp: h * 0.115,
        seed: 19,
        color: const Color(0xFF6E6350).withValues(alpha: 0.24 * a));
    _mountain(canvas, size,
        baseY: h * 0.85 - scroll * 0.075 + enter * 26,
        amp: h * 0.135,
        seed: 31,
        color: const Color(0xFF453E33).withValues(alpha: 0.28 * a));
  }

  /// 竖排大字水印：如屏风题字，极淡，只作留白处的书卷气。
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
        canvas, Offset(size.width * 0.09, size.height * 0.30 - scroll * 0.02));
  }

  /// 一座远山：峰谷相间的折线，用二次贝塞尔略作圆润，收于画面底部。
  void _mountain(
    Canvas canvas,
    Size size, {
    required double baseY,
    required double amp,
    required int seed,
    required Color color,
  }) {
    final rnd = math.Random(seed);
    final w = size.width;
    final h = size.height;
    const pairs = 5;
    final step = w / (pairs * 2);

    final pts = <Offset>[
      Offset(0, baseY - amp * (0.30 + rnd.nextDouble() * 0.30))
    ];
    var x = 0.0;
    for (var i = 0; i < pairs * 2; i++) {
      x += step;
      final k = i.isEven
          ? (0.55 + rnd.nextDouble() * 0.45)
          : (0.10 + rnd.nextDouble() * 0.22);
      pts.add(Offset(x, baseY - k * amp));
    }

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p = pts[i - 1];
      final c = pts[i];
      path.quadraticBezierTo(p.dx, p.dy, (p.dx + c.dx) / 2, (p.dy + c.dy) / 2);
    }
    path
      ..lineTo(pts.last.dx, pts.last.dy)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant InkBackdropPainter old) =>
      old.progress != progress ||
      old.scroll != scroll ||
      old.opacity != opacity;
}
