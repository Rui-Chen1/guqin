import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'root_scaffold.dart';

/// 动态启动页：模拟古琴七弦拨动与水墨晕染效果。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();

    // 动画结束后进入主页
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const RootScaffold(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. 水墨晕染背景 (随着时间扩散)
              CustomPaint(
                painter: _InkSplashPainter(progress: _controller.value),
              ),
              // 2. 居中古琴七弦线描 (伴随拨动震动)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(200, 120),
                      painter: _VibratingStringsPainter(progress: _controller.value),
                    ),
                    const SizedBox(height: 40),
                    // 3. 标题淡入
                    Opacity(
                      opacity: math.min(1.0, math.max(0.0, (_controller.value - 0.4) / 0.4)),
                      child: const Column(
                        children: [
                          Text(
                            '弦 上 知 音',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'GUQIN ART EXPERIENCE',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 水墨晕染效果 Painter
class _InkSplashPainter extends CustomPainter {
  final double progress;
  _InkSplashPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

    // 在四个角落和中心模拟墨点扩散
    final centers = [
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.3),
      Offset(size.width * 0.3, size.height * 0.8),
      Offset(size.width * 0.7, size.height * 0.7),
      Offset(size.width * 0.5, size.height * 0.5),
    ];

    for (var i = 0; i < centers.length; i++) {
      final opacity = math.min(0.08, (1.0 - progress) * 0.1);
      if (opacity <= 0) continue;

      paint.color = AppColors.ink.withValues(alpha: opacity);
      final radius = (size.width * 0.4) * (progress + i * 0.1);
      canvas.drawCircle(centers[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkSplashPainter oldDelegate) => true;
}

/// 七弦震动效果 Painter
class _VibratingStringsPainter extends CustomPainter {
  final double progress;
  _VibratingStringsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const stringCount = 7;
    final spacing = size.height / (stringCount + 1);

    for (int i = 0; i < stringCount; i++) {
      final y = spacing * (i + 1);
      
      // 线条颜色随序号加深
      paint.color = AppColors.ink.withValues(alpha: 0.1 + (i / stringCount) * 0.7);
      paint.strokeWidth = 1.0 + (i / stringCount) * 1.5;

      // 震动逻辑：前期剧烈，后期平稳
      final vibrationProgress = math.max(0.0, 1.0 - progress * 1.5);
      final amplitude = vibrationProgress * 8.0 * (1 - i / stringCount);
      final frequency = 10.0 + i * 2.0;
      
      final path = Path();
      path.moveTo(0, y);
      
      // 使用正弦波模拟震动
      for (double x = 0; x <= size.width; x += 2) {
        final offsetX = x / size.width;
        // 两头固定，中间震动
        final wave = math.sin(offsetX * math.pi) * 
                     math.sin(progress * frequency + i) * 
                     amplitude;
        path.lineTo(x, y + wave);
      }
      
      canvas.drawPath(path, paint);
    }

    // 绘制一个朱砂印点 (淡入)
    if (progress > 0.6) {
      final sealOpacity = math.min(1.0, (progress - 0.6) / 0.2);
      final sealPaint = Paint()..color = AppColors.cinnabar.withValues(alpha: sealOpacity);
      canvas.drawRect(
        Rect.fromLTWH(size.width - 20, 10, 12, 12),
        sealPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VibratingStringsPainter oldDelegate) => true;
}
