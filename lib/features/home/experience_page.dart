import 'package:flutter/material.dart';

import '../../common/features.dart';
import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../theme/app_theme.dart';

/// 体验页：四大数字体验类功能汇总。
class ExperiencePage extends StatelessWidget {
  const ExperiencePage({super.key});

  static const _numerals = ['伍', '陆', '柒', '捌'];

  @override
  Widget build(BuildContext context) {
    return InkScaffold(
      backgroundImageAsset: 'assets/images/qin_hero_mist.jpg',
      appBar: AppBar(title: const Text('体验')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          // 墨色卷签：以印章起首，替代现代渐变横幅。
          Container(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Seal('境', size: 26),
                    SizedBox(width: 10),
                    Text('数字琴境 · 沉浸体验',
                        style: TextStyle(
                            color: Color(0xFFF2E9D6),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5)),
                  ],
                ),
                SizedBox(height: 11),
                Text('以轻量化虚拟场景与实时音画可视化，让非遗古琴「看得见、摸得着」。',
                    style: TextStyle(
                        color: Color(0xFFC9BCA2), fontSize: 12, height: 1.8)),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionTitle(title: '四大体验', subtitle: '点击即入'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kExperienceFeatures.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 134,
            ),
            itemBuilder: (context, i) {
              final f = kExperienceFeatures[i];
              return FeatureTile(
                numeral: i < _numerals.length ? _numerals[i] : '${i + 5}',
                icon: f.icon,
                title: f.title,
                subtitle: f.subtitle,
                color: f.color,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: f.builder)),
              );
            },
          ),
        ],
      ),
    );
  }
}
