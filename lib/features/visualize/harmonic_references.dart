// 由 gen_visual_refs.py 从 assets/audio/sfx 的单音音效中提取生成，请勿手改。
//
// 三种音色的实测声学指纹，供琴音可视化把实时采集的琴音与参考对照。
// 特征取自起振后 30~280ms 的稳定段，七根弦取平均。

class TimbreReference {
  const TimbreReference({
    required this.name,
    required this.envelope,
    required this.centroidRatio,
    required this.highRatio,
    required this.decayMs,
  });

  /// 音色名。
  final String name;

  /// 16 维谐波包络：第 n 项为第 (n+1) 次谐波的相对幅度，峰值归一为 1。
  final List<double> envelope;

  /// 谱心 / 基频——与音高无关的「亮度」指标。
  final double centroidRatio;

  /// 4 倍基频以上的能量占比（0~1）。
  final double highRatio;

  /// 起振后衰减 20dB 所需时间（毫秒），越小衰减越快。
  final double decayMs;
}

const List<TimbreReference> kTimbreReferences = [
  TimbreReference(
    name: '散音',
    envelope: [1.0000, 0.5670, 0.3221, 0.2606, 0.1849, 0.1077, 0.1201, 0.0701, 0.0585, 0.0614, 0.0467, 0.0425, 0.0375, 0.0400, 0.0284, 0.0351],
    centroidRatio: 1.847,
    highRatio: 0.0794,
    decayMs: 4179,
  ),
  TimbreReference(
    name: '按音',
    envelope: [1.0000, 0.5507, 0.2901, 0.2029, 0.1296, 0.0974, 0.1112, 0.0642, 0.0570, 0.0555, 0.0421, 0.0311, 0.0292, 0.0045, 0.0039, 0.0025],
    centroidRatio: 1.601,
    highRatio: 0.0493,
    decayMs: 2797,
  ),
  TimbreReference(
    name: '泛音',
    envelope: [1.0000, 0.5027, 0.2208, 0.2321, 0.1702, 0.1181, 0.0132, 0.0113, 0.0109, 0.0078, 0.0050, 0.0025, 0.0019, 0.0013, 0.0010, 0.0008],
    centroidRatio: 1.554,
    highRatio: 0.0545,
    decayMs: 2201,
  ),
];
