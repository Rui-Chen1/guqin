/// 数据模型定义（琴曲、文化资料、指法、减字谱符号）。
library;

/// 琴曲资料（结构化元数据）。
class GuqinPiece {
  final int? id;
  final String slug; // 资源标识，对应 assets/images/piece_<slug>.jpg 与 assets/audio/<slug>.mp3
  final String title; // 曲名
  final String dynasty; // 朝代
  final String author; // 传谱 / 作者
  final String mode; // 宫调 / 定弦
  final String difficulty; // 入门 / 进阶 / 精研
  final int durationSec; // 参考时长（秒）
  final String intro; // 曲意简介
  final String background; // 典故与背景
  final List<String> tags; // 标签

  const GuqinPiece({
    this.id,
    required this.slug,
    required this.title,
    required this.dynasty,
    required this.author,
    required this.mode,
    required this.difficulty,
    required this.durationSec,
    required this.intro,
    required this.background,
    this.tags = const [],
  });

  /// 琴曲配图（本地资源）。
  String get imageAsset => 'assets/images/piece_$slug.jpg';

  /// 琴曲试听音频（audioplayers 的 AssetSource 以 assets/ 为根目录）。
  /// 均为真人演奏录音，来源见 [audioCredit]。
  String get audioSource => 'audio/$slug.mp3';

  /// 各曲试听录音的演奏者与授权署名（取自 Wikimedia Commons 自由授权音频）。
  static const Map<String, String> _credits = {
    'liushui': '录音：Charlie Huang ｜ CC BY 2.5 ｜ 来源：Wikimedia Commons',
    'shenrenchang': '录音：Charlie Huang ｜ CC BY-SA 2.5 ｜ 来源：Wikimedia Commons',
    'meihua': '录音：Charlie Huang ｜ CC BY-SA 3.0 ｜ 来源：Wikimedia Commons',
    'pingsha': '录音：Charlie Huang ｜ CC BY 2.5 ｜ 来源：Wikimedia Commons',
    'yangguan': '录音：Charlie Huang ｜ CC BY-SA 3.0 ｜ 来源：Wikimedia Commons',
    'peilan': '录音：Charlie Huang ｜ CC BY 2.5 ｜ 来源：Wikimedia Commons',
    'jiukuang': '录音：Charlie Huang ｜ CC BY 2.5 ｜ 来源：Wikimedia Commons',
    'kongziduyi': '录音：Charlie Huang ｜ CC BY 2.5 ｜ 来源：Wikimedia Commons',
    'zuiyu': '录音：Charlie Huang ｜ CC BY-SA 3.0 ｜ 来源：Wikimedia Commons',
    'qiufengci': '录音：Charlie Huang ｜ CC BY 2.5 ｜ 来源：Wikimedia Commons',
  };

  /// 试听录音署名文本。
  String get audioCredit =>
      _credits[slug] ?? '录音来源：Wikimedia Commons（自由授权）';

  Map<String, Object?> toMap() => {
        'id': id,
        'slug': slug,
        'title': title,
        'dynasty': dynasty,
        'author': author,
        'mode': mode,
        'difficulty': difficulty,
        'duration_sec': durationSec,
        'intro': intro,
        'background': background,
        'tags': tags.join(','),
      };

  factory GuqinPiece.fromMap(Map<String, Object?> m) => GuqinPiece(
        id: m['id'] as int?,
        slug: (m['slug'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        dynasty: (m['dynasty'] ?? '') as String,
        author: (m['author'] ?? '') as String,
        mode: (m['mode'] ?? '') as String,
        difficulty: (m['difficulty'] ?? '') as String,
        durationSec: (m['duration_sec'] ?? 0) as int,
        intro: (m['intro'] ?? '') as String,
        background: (m['background'] ?? '') as String,
        tags: ((m['tags'] ?? '') as String)
            .split(',')
            .where((e) => e.isNotEmpty)
            .toList(),
      );
}

/// 古琴文化资料条目。
class CultureArticle {
  final int? id;
  final String slug; // 资源标识，对应 assets/images/article_<slug>.jpg
  final String category; // 历史 / 形制 / 琴派 / 工艺 / 琴道
  final String title;
  final String summary;
  final String content;

  const CultureArticle({
    this.id,
    required this.slug,
    required this.category,
    required this.title,
    required this.summary,
    required this.content,
  });

  /// 文化资料配图（本地资源）。
  String get imageAsset => 'assets/images/article_$slug.jpg';

  Map<String, Object?> toMap() => {
        'id': id,
        'slug': slug,
        'category': category,
        'title': title,
        'summary': summary,
        'content': content,
      };

  factory CultureArticle.fromMap(Map<String, Object?> m) => CultureArticle(
        id: m['id'] as int?,
        slug: (m['slug'] ?? '') as String,
        category: (m['category'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        summary: (m['summary'] ?? '') as String,
        content: (m['content'] ?? '') as String,
      );
}

/// 指法（含右手指法、左手指法与三种音色）。
class Fingering {
  final String name; // 减字号，如「抹」
  final String pinyin;
  final String category; // 右手指法 / 左手指法 / 基本音色
  final String desc;
  final String tip; // 演奏要领
  final String motion; // 动画动作类型：pluck_down / pluck_up / press / harmonic / slide

  const Fingering({
    required this.name,
    required this.pinyin,
    required this.category,
    required this.desc,
    required this.tip,
    required this.motion,
  });
}

/// 减字谱符号（拆解为四要素，便于渲染与讲解）。
class NotationSymbol {
  final String leftHand; // 左手指，如 大 / 食 / 中 / 名
  final String? leftTech; // 左手技法，如 吟 / 猱 / 绰 / 注
  final String hui; // 徽位，如 九 / 七
  final String rightHand; // 右手指法，如 勾 / 挑 / 抹
  final String stringNum; // 弦序，如 一 / 二
  final String reading; // 读法，如「大九勾一」
  final String meaning; // 释义

  const NotationSymbol({
    required this.leftHand,
    this.leftTech,
    required this.hui,
    required this.rightHand,
    required this.stringNum,
    required this.reading,
    required this.meaning,
  });
}
