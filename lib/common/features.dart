import 'package:flutter/material.dart';

import '../features/assist/assist_page.dart';
import '../features/culture/culture_list_page.dart';
import '../features/fingering/fingering_page.dart';
import '../features/experience/mood_sound_page.dart';
import '../features/model3d/model_page.dart';
import '../features/notation/notation_page.dart';
import '../features/pieces/piece_list_page.dart';
import '../features/realm/realm_page.dart';
import '../features/visualize/visualize_page.dart';
import '../theme/app_theme.dart';

/// 八大核心功能的统一描述，供首页 / 习琴 / 体验三处复用。
class AppFeature {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  const AppFeature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

/// 核心学习类：资料库 + 减字谱 + 指法动画 + 琴曲资料
const List<AppFeature> kLearningFeatures = [
  AppFeature(
    title: '古琴文化资料库',
    subtitle: '历史 · 形制 · 琴派 · 工艺 · 琴道',
    icon: Icons.auto_stories_outlined,
    color: AppColors.cinnabar,
    builder: _buildCulture,
  ),
  AppFeature(
    title: '琴曲资料查阅',
    subtitle: '结构化琴曲元数据与背景典故',
    icon: Icons.library_music_outlined,
    color: AppColors.jade,
    builder: _buildPieces,
  ),
  AppFeature(
    title: '减字谱学习',
    subtitle: 'SVG 矢量谱面，符号点击即释义',
    icon: Icons.grid_on_outlined,
    color: AppColors.gold,
    builder: _buildNotation,
  ),
  AppFeature(
    title: '指法动画教学',
    subtitle: '散音 · 泛音 · 按音动画演示',
    icon: Icons.pan_tool_alt_outlined,
    color: Color(0xFF7A6BA8),
    builder: _buildFingering,
  ),
];

/// 数字体验类：三维 + 辅助 + 可视化 + 琴境（含意境生音）
const List<AppFeature> kExperienceFeatures = [
  AppFeature(
    title: '古琴三维展示',
    subtitle: '轻量化 3D 模型，多角度查看',
    icon: Icons.view_in_ar_outlined,
    color: AppColors.jade,
    builder: _buildModel,
  ),
  AppFeature(
    title: '智能演奏辅助',
    subtitle: '本地音采集，音高节奏比对反馈',
    icon: Icons.mic_none_outlined,
    color: AppColors.cinnabar,
    builder: _buildAssist,
  ),
  AppFeature(
    title: '琴音可视化',
    subtitle: '波形与频谱实时呈现',
    icon: Icons.graphic_eq_outlined,
    color: Color(0xFF3C7EA8),
    builder: _buildVisualize,
  ),
  AppFeature(
    title: '数字琴境体验',
    subtitle: '沉浸场景 · 双手抚弦 · 意境生音',
    icon: Icons.nights_stay_outlined,
    color: Color(0xFF5A6E8C),
    builder: _buildRealm,
  ),
];

const List<AppFeature> kAllFeatures = [
  ...kLearningFeatures,
  ...kExperienceFeatures
];

Widget _buildCulture(BuildContext c) => const CultureListPage();
Widget _buildPieces(BuildContext c) => const PieceListPage();
Widget _buildNotation(BuildContext c) => const NotationPage();
Widget _buildFingering(BuildContext c) => const FingeringPage();
Widget _buildModel(BuildContext c) => const ModelPage();
Widget _buildAssist(BuildContext c) => const AssistPage();
Widget _buildVisualize(BuildContext c) => const VisualizePage();
Widget _buildRealm(BuildContext c) => const RealmPage();
Widget _buildMoodSound(BuildContext c) => const MoodSoundPage();
