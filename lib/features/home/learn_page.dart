import 'package:flutter/material.dart';

import '../../common/features.dart';
import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../theme/app_theme.dart';

/// 习琴页：四大学习类功能汇总。
class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  static const _numerals = ['壹', '貳', '叁', '肆'];

  @override
  Widget build(BuildContext context) {
    return InkScaffold(
      backgroundImageAsset: 'assets/images/qin_hero_mist.jpg',
      appBar: AppBar(title: const Text('习琴')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          const SectionTitle(title: '入门次第', subtitle: '循序而进'),
          const PaperCard(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Text(
              '① 文化资料库建立认知　→　② 琴曲资料库聆听与了解　→　'
              '③ 减字谱学习识谱　→　④ 指法动画教学练手',
              style: TextStyle(
                  fontSize: 12.5, height: 2.0, color: AppColors.inkSoft),
            ),
          ),
          const SizedBox(height: 26),
          const SectionTitle(title: '四大功课', subtitle: '点击即入'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kLearningFeatures.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 134,
            ),
            itemBuilder: (context, i) {
              final f = kLearningFeatures[i];
              return FeatureTile(
                numeral: i < _numerals.length ? _numerals[i] : '${i + 1}',
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
