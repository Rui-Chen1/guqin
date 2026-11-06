import 'package:flutter/material.dart';

/// 全局配色：以「宣纸 · 墨 · 朱砂 · 青玉 · 鎏金」为主的水墨国风色板。
class AppColors {
  static const paper = Color(0xFFF4EDE0); // 宣纸底
  static const paperLight = Color(0xFFFBF6EC); // 卡片底
  static const ink = Color(0xFF2B2620); // 墨色
  static const inkSoft = Color(0xFF6B6055); // 淡墨
  static const cinnabar = Color(0xFF9E3B2F); // 朱砂
  static const cinnabarSoft = Color(0xFFC05A4A);
  static const jade = Color(0xFF4E6E5D); // 青玉
  static const gold = Color(0xFFC2A15A); // 鎏金
  static const line = Color(0xFFE3D8C4); // 描线
  static const night = Color(0xFF14161C); // 夜色
}

class AppTheme {
  /// 书卷字族：正文一律走宋体／楷体一系，缺字时回退系统衬线。
  ///
  /// 这是全应用「去现代感」的关键：默认的 Roboto／San Francisco 无衬线
  /// 带强烈的科技界面气息，换成宋体后整页便有纸墨书卷之味。
  static const String serifFamily = 'Songti SC';
  static const List<String> serifFallback = [
    'STSong',
    'Kaiti SC',
    'STKaiti',
    'Songti TC',
    'Noto Serif CJK SC',
    'Noto Serif SC',
    'serif',
  ];

  /// 楷体：题画诗、落款等最见笔意处单独使用。
  static const String kaiFamily = 'Kaiti SC';
  static const List<String> kaiFallback = [
    'STKaiti',
    'Kaiti TC',
    'Songti SC',
    'STSong',
    'Noto Serif CJK SC',
    'serif',
  ];

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: const ColorScheme.light(
        primary: AppColors.cinnabar,
        onPrimary: Colors.white,
        secondary: AppColors.jade,
        onSecondary: Colors.white,
        surface: AppColors.paperLight,
        onSurface: AppColors.ink,
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper.withValues(alpha: 0.82),
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
        titleTextStyle: const TextStyle(
          color: AppColors.ink,
          fontFamily: serifFamily,
          fontFamilyFallback: serifFallback,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 4,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      // 全局套用书卷字族：原生 Text / Button / 输入框一并受益。
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
        fontFamily: serifFamily,
        fontFamilyFallback: serifFallback,
      ),
      // 底部弹层（减字谱释义、琴曲信息）改用宣纸册页质感。
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paperLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(
          color: AppColors.paperLight,
          fontFamily: serifFamily,
          fontFamilyFallback: serifFallback,
          fontSize: 12.5,
          letterSpacing: 1,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
      ),
      // 分类筛选用的小签：方角，与卷册一致（M3 默认的胶囊感太现代）。
      chipTheme: base.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
      ),
      // 方角按钮，替代 M3 默认的胶囊形。
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cinnabar,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          textStyle: const TextStyle(
            fontFamily: serifFamily,
            fontFamilyFallback: serifFallback,
            letterSpacing: 1.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.jade,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          textStyle: const TextStyle(
            fontFamily: serifFamily,
            fontFamilyFallback: serifFallback,
            letterSpacing: 1,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.ink),
        textStyle: TextStyle(
          color: AppColors.paperLight,
          fontFamily: serifFamily,
          fontFamilyFallback: serifFallback,
          fontSize: 11.5,
        ),
      ),
    );
  }

  /// 统一的册页面板装饰：方角、细描边、轻投影（替代现代圆角卡片）。
  /// 面板用半透明宣纸白，让后面的水墨底图隐约透出，全应用气质统一。
  static BoxDecoration get card => BoxDecoration(
        color: AppColors.paperLight.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142B2620),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      );
}
