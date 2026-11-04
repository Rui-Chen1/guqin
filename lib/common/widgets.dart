import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 书卷装饰组件集。
///
/// 全应用共用这一套「宣纸 · 朱砂 · 鎏金」的卷册语汇：方角细线、印章题签、
/// 画心装裱，替代现代界面常见的圆角与柔光渐变。

// ---------------------------------------------------------------- 装饰小件

/// 细金线，用于题签处作点缀。
class HairLine extends StatelessWidget {
  const HairLine({super.key, this.width = 26});
  final double width;

  @override
  Widget build(BuildContext context) =>
      Container(width: width, height: 1, color: AppColors.gold.withValues(alpha: 0.75));
}

/// 朱砂印：方框双线，白字居中（多字则竖排）。
class Seal extends StatelessWidget {
  const Seal(this.text, {super.key, this.size = 44});
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
            offset: const Offset(0, 3),
          ),
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

/// 金色细竖线，用作信息之间的分隔。
class DotDivider extends StatelessWidget {
  const DotDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 9,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: AppColors.gold.withValues(alpha: 0.6),
      );
}

/// 白描分隔线。
class HairDivider extends StatelessWidget {
  const HairDivider({super.key, this.margin = EdgeInsets.zero});
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, margin: margin, color: AppColors.line);
}

// ---------------------------------------------------------------- 图片

/// 水墨渐变占位（资源缺失时的回退）。
class InkPlaceholder extends StatelessWidget {
  final double? height;
  final IconData icon;
  const InkPlaceholder({super.key, this.height, this.icon = Icons.music_note});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFE6D4), Color(0xFFDDCEB3), Color(0xFFC8B694)],
        ),
      ),
      child: Center(
        child: Icon(icon, size: 30, color: AppColors.inkSoft.withValues(alpha: 0.4)),
      ),
    );
  }
}

/// 画心装裱：细金边 + 内缩画心（读取 assets/images 下的本地资源）。
class GuqinImage extends StatelessWidget {
  final String asset;
  final double height;
  final IconData icon;
  const GuqinImage({
    super.key,
    required this.asset,
    this.height = 160,
    this.icon = Icons.auto_stories_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(border: Border.all(color: AppColors.gold.withValues(alpha: 0.4))),
      child: Image.asset(
        asset,
        height: height - 4,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => InkPlaceholder(height: height - 4, icon: icon),
      ),
    );
  }
}

// ---------------------------------------------------------------- 容器

/// 通用册页面板：方角、细描边、轻投影，替代现代圆角卡片。
class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: AppTheme.card,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 标题

/// 章节题头：朱砂菱形点 + 标题 + 细金线 + 小注。
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionTitle({super.key, required this.title, this.subtitle, this.trailing});

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
                  fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 3)),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: AppColors.gold.withValues(alpha: 0.35))),
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Text(subtitle!,
                style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft, letterSpacing: 1.5)),
          ],
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 标签 / 功能格

/// 小标签：方角细框，如卷册上的钤记。
class TagChip extends StatelessWidget {
  final String text;
  final Color? color;
  const TagChip(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.jade;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.45))),
      child: Text(text, style: TextStyle(fontSize: 10.5, color: c, letterSpacing: 1)),
    );
  }
}

/// 功能入口：册页式方格，可标以汉字编号（壹 貳 叁 …）。
class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? numeral;

  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.numeral,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.card,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (numeral != null)
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.cinnabar.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(numeral!,
                            style: const TextStyle(
                                fontSize: 11, height: 1.0, color: AppColors.cinnabar)),
                      ),
                    const Spacer(),
                    Icon(icon, size: 17, color: color.withValues(alpha: 0.55)),
                  ],
                ),
                const SizedBox(height: 9),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 3),
                Expanded(
                  child: Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, height: 1.45, color: AppColors.inkSoft)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 徽位

/// 徽位刻度尺（13 徽），多处页面复用。
class HuiRuler extends StatelessWidget {
  final double height;
  const HuiRuler({super.key, this.height = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _HuiRulerPainter(), size: Size.infinite),
    );
  }
}

class _HuiRulerPainter extends CustomPainter {
  static const _labels = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二', '十三'];
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 6), Offset(size.width, size.height - 6), line);
    for (var i = 0; i < 13; i++) {
      final x = size.width * (i + 1) / 14;
      final isKey = i == 6;
      final dot = Paint()..color = isKey ? AppColors.cinnabar : AppColors.gold;
      canvas.drawCircle(Offset(x, size.height - 6), isKey ? 3.5 : 2.5, dot);
      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.inkSoft,
            fontFamily: AppTheme.serifFamily,
            fontFamilyFallback: AppTheme.serifFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 0));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------- 动效

/// 墨色晕开：每当 [trigger] 变化，便自 [origin] 处晕开数圈淡墨。
///
/// 与琴境页的落指涟漪同一语汇，用于「点击减字」这类需要即时反馈之处。
class InkBloom extends StatefulWidget {
  final Widget child;

  /// 触发值：每次变化即播放一次晕开。
  final int trigger;

  /// 晕开位置（相对 child 的对齐比例）。
  final Alignment origin;

  /// 墨色，默认淡墨。
  final Color color;

  const InkBloom({
    super.key,
    required this.child,
    required this.trigger,
    this.origin = Alignment.center,
    this.color = AppColors.ink,
  });

  @override
  State<InkBloom> createState() => _InkBloomState();
}

class _InkBloomState extends State<InkBloom> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  @override
  void didUpdateWidget(covariant InkBloom old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          if (_c.value > 0 && _c.value < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _InkBloomPainter(
                    t: _c.value,
                    origin: widget.origin,
                    color: widget.color,
                  ),
                ),
              ),
            ),
        ],
      ),
      child: widget.child,
    );
  }
}

class _InkBloomPainter extends CustomPainter {
  _InkBloomPainter({required this.t, required this.origin, required this.color});

  final double t;
  final Alignment origin;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = origin.alongSize(size);
    final maxR = math.max(size.width, size.height) * 0.62;

    // 中心一抹淡墨，随即化开
    final blot = (t / 0.28).clamp(0.0, 1.0) * (1 - t);
    if (blot > 0) {
      canvas.drawCircle(
        c,
        maxR * 0.16,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.16 * blot), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: maxR * 0.16)),
      );
    }

    // 三圈涟漪，逐层扩散、渐次消隐
    for (var r = 0; r < 3; r++) {
      final rt = ((t - r * 0.13) / 0.74).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      canvas.drawCircle(
        c,
        rt * maxR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6 + 2.0 * (1 - rt)
          ..color = color.withValues(alpha: 0.22 * (1 - rt)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InkBloomPainter old) =>
      old.t != t || old.origin != origin || old.color != color;
}
