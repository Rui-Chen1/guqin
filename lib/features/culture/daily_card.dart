import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/app_theme.dart';

/// 每日一签：当天一句琴诗，点朱砂印打卡。
class DailySignCard extends StatefulWidget {
  const DailySignCard({super.key});

  static const _poems = <({String line, String source})>[
    (line: '独坐幽篁里，弹琴复长啸。', source: '王维《竹里馆》'),
    (line: '泠泠七弦上，静听松风寒。', source: '刘长卿《听弹琴》'),
    (line: '欲取鸣琴弹，恨无知音赏。', source: '孟浩然《夏日南亭怀辛大》'),
    (line: '锦瑟无端五十弦，一弦一柱思华年。', source: '李商隐《锦瑟》'),
    (line: '高山流水遇知音，彩云追月得知己。', source: '《列子·汤问》'),
    (line: '虽无宾主意，颇得清净理。', source: '常建《江上琴兴》'),
    (line: '知音如不赏，归卧故山秋。', source: '贾岛《送无可上人》句'),
    (line: '为我一挥手，如听万壑松。', source: '李白《听蜀僧濬弹琴》'),
    (line: '若言琴上有琴声，放在匣中何不鸣？', source: '苏轼《琴诗》'),
    (line: '床头一壶酒，能更几回眠？', source: '韩偓《残春旅舍》句'),
    (line: '七弦为益友，两耳是知音。', source: '白居易《船夜援琴》'),
    (line: '大弦嘈嘈如急雨，小弦切切如私语。', source: '白居易《琵琶行》句'),
    (line: '松下问童子，言师采药去。', source: '贾岛《寻隐者不遇》'),
    (line: '我有一张琴，腹中有万卷书。', source: '民间琴谚'),
  ];

  String get _today =>
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

  ({String line, String source}) get _sign {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return _poems[dayOfYear % _poems.length];
  }

  @override
  State<DailySignCard> createState() => _DailySignCardState();
}

class _DailySignCardState extends State<DailySignCard> {
  bool _stamped = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v =
        await AppDatabase.instance.readProgress('daily_stamp_${widget._today}');
    if (mounted) setState(() => _stamped = v > 0);
  }

  Future<void> _stamp() async {
    if (_stamped) return;
    await AppDatabase.instance.writeProgress('daily_stamp_${widget._today}', 1);
    await AppDatabase.instance.bumpProgress('daily_streak');
    if (mounted) setState(() => _stamped = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget._sign;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.paperLight,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('今日琴签',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.cinnabar,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(s.line,
                    style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Kaiti SC',
                        fontFamilyFallback: ['STKaiti', 'serif'])),
                const SizedBox(height: 4),
                Text('—— ${s.source}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _stamp,
            child: AnimatedScale(
              scale: _stamped ? 1.0 : 0.92,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _stamped
                      ? AppColors.cinnabar
                      : AppColors.paper,
                  border: Border.all(color: AppColors.cinnabar, width: 1.5),
                ),
                child: Text(
                  _stamped ? '已签' : '签',
                  style: TextStyle(
                    fontSize: _stamped ? 14 : 20,
                    color: _stamped ? Colors.white : AppColors.cinnabar,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 古琴冷知识胶囊：可左右滑动的小卡片。
class ColdFactCapsule extends StatefulWidget {
  const ColdFactCapsule({super.key});

  static const _facts = <String>[
    '古琴最初只有五根弦，象征金木水火土；周文王、周武王各加一根，才有今天的七弦。',
    '减字谱是唐代曹柔发明的「汉字密码」，把一个指法拆成上下偏旁拼在一起。',
    '古琴面板是梧桐木，底板是梓木，合起来叫「桐梓合精」。',
    '琴面有十三枚徽位，对应一年十二个月加一个闰月。',
    '「高山流水遇知音」的故事里，俞伯牙弹的是古琴，钟子期是第一个听懂的人。',
    '古琴没有琴码，七根弦直接浮在面板上，靠按弦改变长度出音。',
    '2003 年，古琴艺术被联合国教科文组织列入「人类口头和非物质遗产代表作」。',
    '古人弹琴前要沐浴更衣、焚香净手，这叫「修琴心」。',
    '散音、按音、泛音，是古琴的三种音色，分别象征地、人、天。',
    '一张好琴要做两三年，大漆要反复髹刮几十道，越弹声音越润。',
  ];

  @override
  State<ColdFactCapsule> createState() => _ColdFactCapsuleState();
}

class _ColdFactCapsuleState extends State<ColdFactCapsule> {
  late final int _index =
      math.Random().nextInt(ColdFactCapsule._facts.length);

  @override
  Widget build(BuildContext context) {
    final fact = ColdFactCapsule._facts[_index];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(left: BorderSide(color: AppColors.cinnabar, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined,
              size: 18, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('古琴冷知识',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.inkSoft,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(fact,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.6, color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
