import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';

/// 减字谱矢量渲染。
///
/// 外框与四条分割线各自成独立 SVG，故可逐线淡入、四区单独高亮——
/// 这正是「拼合造字」之理的视觉化：四个部件合而成一字。
/// 四宫格分别对应「左手指法 / 徽位 / 右手指法 / 弦序」四要素。
class NotationSvg {
  NotationSvg._();

  static String _hex(Color c) {
    String h(double v) =>
        (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${h(c.r)}${h(c.g)}${h(c.b)}';
  }

  /// 减字谱外框（含朱砂钤记），纯几何图形，跨平台解析稳定。
  static String frame({
    Color stroke = const Color(0xFFC2A15A),
    Color fill = const Color(0xFFFBF6EC),
  }) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 116">'
      '<rect x="2" y="2" width="96" height="112" rx="12" fill="${_hex(fill)}" '
      'stroke="${_hex(stroke)}" stroke-width="2.5"/>'
      '<circle cx="86" cy="16" r="4" fill="#9E3B2F" opacity="0.75"/>'
      '</svg>';

  /// 四条分割线段：0 左上横 / 1 右上横 / 2 上竖 / 3 下竖，各成一体。
  static const List<String> _segments = [
    '8,58,50,58',
    '50,58,92,58',
    '50,10,50,58',
    '50,58,50,106',
  ];

  static String divider(int i) {
    final p = _segments[i.clamp(0, 3)].split(',');
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 116">'
        '<line x1="${p[0]}" y1="${p[1]}" x2="${p[2]}" y2="${p[3]}" '
        'stroke="#BBAE93" stroke-width="1.4" stroke-linecap="round"/></svg>';
  }

  /// 装饰性弦纹（用于谱面背景）。
  static String stringLines(int count) {
    final b = StringBuffer(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">');
    for (var i = 0; i < count; i++) {
      final y = 8 + i * (84 / (count - 1));
      b.write('<line x1="4" y1="$y" x2="96" y2="$y" stroke="#C2A15A" '
          'stroke-width="${0.6 + i * 0.12}" opacity="0.35"/>');
    }
    b.write('</svg>');
    return b.toString();
  }
}

/// 减字四宫的语义标签（依次为 左上 / 右上 / 左下 / 右下）。
const List<String> kQuadrantNames = ['左手指法', '徽位', '右手指法', '弦序'];

/// 单个减字谱符号。
///
/// 四宫格可整体渲染，亦可单独高亮其一（供拆解动画使用）。
class NotationGlyph extends StatelessWidget {
  final String leftHand;
  final String? leftTech;
  final String hui;
  final String rightHand;
  final String stringNum;
  final double size;
  final VoidCallback? onTap;

  /// 外框描边色：未识者浅灰、已识者淡绿。
  final Color borderColor;
  final Color fillColor;

  /// 高亮象限：0 左上 / 1 右上 / 2 左下 / 3 右下；-1 为不高亮。
  final int highlight;
  final double highlightT;

  /// 四条分割线各自的不透明度（逐条淡入时用）。
  final List<double> dividerOpacity;

  const NotationGlyph({
    super.key,
    required this.leftHand,
    this.leftTech,
    required this.hui,
    required this.rightHand,
    required this.stringNum,
    this.size = 84,
    this.onTap,
    this.borderColor = const Color(0xFFC2A15A),
    this.fillColor = const Color(0xFFFBF6EC),
    this.highlight = -1,
    this.highlightT = 0,
    this.dividerOpacity = const [1, 1, 1, 1],
  });

  List<({String text, String? sub, Alignment align, Color color, double scale})>
      get _quads => [
            (
              text: leftHand,
              sub: leftTech,
              align: const Alignment(-0.5, -0.5),
              color: AppColors.ink,
              scale: 1.0
            ),
            (
              text: hui,
              sub: null,
              align: const Alignment(0.5, -0.5),
              color: AppColors.cinnabar,
              scale: 0.86
            ),
            (
              text: rightHand,
              sub: null,
              align: const Alignment(-0.5, 0.5),
              color: AppColors.jade,
              scale: 1.0
            ),
            (
              text: stringNum,
              sub: null,
              align: const Alignment(0.5, 0.5),
              color: AppColors.cinnabar,
              scale: 0.86
            ),
          ];

  @override
  Widget build(BuildContext context) {
    final h = size * 1.16;
    final fs = size * 0.36;
    final quads = _quads;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SvgPicture.string(
                NotationSvg.frame(stroke: borderColor, fill: fillColor),
                fit: BoxFit.fill),
            for (var i = 0; i < 4; i++)
              Opacity(
                opacity: dividerOpacity[i].clamp(0.0, 1.0),
                child:
                    SvgPicture.string(NotationSvg.divider(i), fit: BoxFit.fill),
              ),
            // 高亮之处：一团鎏金晕，自四宫中心向外散开
            for (var i = 0; i < 4; i++)
              if (highlight == i && highlightT > 0)
                Align(
                  alignment: quads[i].align,
                  child: Container(
                    width: size / 2,
                    height: h / 2,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.52 * highlightT),
                          AppColors.gold.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
            // 四字：减字本体用古楷，与注释的细宋体分别
            for (var i = 0; i < 4; i++)
              Align(
                alignment: quads[i].align,
                child: SizedBox(
                  width: size / 2,
                  height: size * 0.58,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Transform.scale(
                        scale: 1 + 0.14 * (highlight == i ? highlightT : 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              quads[i].text,
                              style: TextStyle(
                                fontSize: fs * quads[i].scale,
                                height: 1,
                                color: quads[i].color,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTheme.kaiFamily,
                                fontFamilyFallback: AppTheme.kaiFallback,
                                shadows: highlight == i && highlightT > 0
                                    ? [
                                        Shadow(
                                          color: AppColors.cinnabar.withValues(
                                              alpha: 0.30 * highlightT),
                                          blurRadius: 9,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            if (quads[i].sub != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 1, bottom: 2),
                                child: Text(
                                  quads[i].sub!,
                                  style: TextStyle(
                                    fontSize: fs * 0.5,
                                    height: 1,
                                    color:
                                        quads[i].color.withValues(alpha: 0.8),
                                    fontFamily: AppTheme.kaiFamily,
                                    fontFamilyFallback: AppTheme.kaiFallback,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ 拆解动画时间轴

/// 第 [i] 条分割线的浮现进度（t: 0..1）。
double notationDividerT(double t, int i) =>
    ((t - (0.06 + i * 0.05)) / 0.16).clamp(0.0, 1.0);

/// 第 [i] 区的高亮强度（t: 0..1）。末区常亮，终态四区同辉。
double notationQuadT(double t, int i) {
  final a = 0.34 + i * 0.14;
  final ramp = ((t - a) / 0.16).clamp(0.0, 1.0);
  final tail = (1 - (t - a - 0.16) / 0.16).clamp(0.0, 1.0);
  final own = i == 3 ? ramp : (ramp < tail ? ramp : tail);
  final all = ((t - 0.88) / 0.12).clamp(0.0, 1.0) * 0.5;
  return own > all ? own : all;
}

/// 文字标签的淡入进度：只进不退，弹出后即常驻可读。
double notationLabelT(double t, int i) =>
    ((t - (0.30 + i * 0.14)) / 0.18).clamp(0.0, 1.0);

/// 拆解演示：外框与四线渐显，四区依次高亮。
class NotationReveal extends StatelessWidget {
  final String leftHand;
  final String? leftTech;
  final String hui;
  final String rightHand;
  final String stringNum;
  final double size;
  final double t;

  const NotationReveal({
    super.key,
    required this.leftHand,
    this.leftTech,
    required this.hui,
    required this.rightHand,
    required this.stringNum,
    required this.t,
    this.size = 128,
  });

  @override
  Widget build(BuildContext context) {
    var hi = -1;
    var hv = 0.0;
    for (var i = 0; i < 4; i++) {
      final v = notationQuadT(t, i);
      if (v > hv) {
        hv = v;
        hi = i;
      }
    }
    return Opacity(
      opacity: (t / 0.28).clamp(0.0, 1.0),
      child: NotationGlyph(
        leftHand: leftHand,
        leftTech: leftTech,
        hui: hui,
        rightHand: rightHand,
        stringNum: stringNum,
        size: size,
        borderColor: AppColors.gold,
        highlight: hi,
        highlightT: hv,
        dividerOpacity: [for (var i = 0; i < 4; i++) notationDividerT(t, i)],
      ),
    );
  }
}
