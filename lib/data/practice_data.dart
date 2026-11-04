import 'dart:math' as math;

import 'practice_scores.dart';

/// 单条标准谱音符（时间相对曲首，取自真人演奏录音的音高与时值）。
class TargetNote {
  final int timeMs;
  final int midi;
  final int durMs;
  const TargetNote(this.timeMs, this.midi, this.durMs);

  /// 该音的标准频率（十二平均律）。
  double get freq => 440.0 * math.pow(2.0, (midi - 69) / 12.0);
}

/// 一个练习句段（「逐句跟练」的最小单位）。
class PracticePhrase {
  final String id;
  final String title;
  final String level;
  final String hint;
  final int baseBpm;

  /// 整曲是否散板（自由节拍、无恒定拍点）。
  ///
  /// 由 gen_practice.py 依据录音的脉冲拟合残差自动判定：残差大于阈值
  /// 说明该曲没有稳定的局部律动，即散板。散板曲目记谱不设小节线，
  /// 音位对齐亦放宽对局部伸缩的容忍（见 practice_engine.dart）。
  final bool rubato;
  final List<TargetNote> notes;
  const PracticePhrase({
    required this.id,
    required this.title,
    required this.level,
    required this.hint,
    required this.baseBpm,
    this.rubato = false,
    required this.notes,
  });
}

/// 正调（F 调）七弦散音 MIDI：C2 D2 F2 G2 A2 C3 D3。
const List<int> kOpenStrings = [36, 38, 41, 43, 45, 48, 50];

const List<String> kStringNames = ['一', '二', '三', '四', '五', '六', '七'];

const List<String> _pitchNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];

/// MIDI → 音名（如 43 → G2）。
String noteName(int midi) => '${_pitchNames[midi % 12]}${midi ~/ 12 - 1}';

/// MIDI → 频率。
double midiToFreq(int midi) => 440.0 * math.pow(2.0, (midi - 69) / 12.0);

/// 该音落在第几弦（取不高于它的最高空弦；正调按弦习惯）。
int stringIndexFor(int midi) {
  var idx = 0;
  for (var i = 0; i < kOpenStrings.length; i++) {
    if (kOpenStrings[i] <= midi) idx = i;
  }
  return idx;
}

/// 是否为七弦散音。
bool isOpenString(int midi) => kOpenStrings.contains(midi);

/// 十三徽位置（占岳山至龙龈全弦长的比例）。
const List<double> kHuiFractions = [
  0.125, 1 / 6, 0.2, 0.25, 1 / 3, 0.4, 0.5, 0.6, 2 / 3, 0.75, 0.8, 5 / 6, 0.875,
];

const List<String> _numNames = [
  '', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二', '十三',
];

/// 徽位名（1 → 一徽）。
String huiName(int hui) => '${_numNames[hui]}徽';

/// 某音若在第 [stringIndex] 弦上按出，最接近的徽位（1..13）；
/// 低于该弦散音（即不在此弦上按出）时返回 null。
int? huiFor(int midi, int stringIndex) {
  if (stringIndex < 0 || stringIndex >= kOpenStrings.length) return null;
  final ratio = midiToFreq(midi) / midiToFreq(kOpenStrings[stringIndex]);
  if (ratio <= 1.0) return null;
  final x = 1.0 - 1.0 / ratio; // 相对岳山的弦长比例
  var best = 1;
  var bestD = double.infinity;
  for (var i = 0; i < kHuiFractions.length; i++) {
    final d = (kHuiFractions[i] - x).abs();
    if (d < bestD) {
      bestD = d;
      best = i + 1;
    }
  }
  return best;
}

/// 该音在琴上的按取位置描述（如「四弦七徽」/「一弦散音」）。
String positionLabel(int midi) {
  final s = stringIndexFor(midi);
  if (isOpenString(midi)) return '${kStringNames[s]}弦散音';
  final hui = huiFor(midi, s);
  return hui == null ? '${kStringNames[s]}弦按音' : '${kStringNames[s]}弦${huiName(hui)}';
}

/// 练习句段库。
///
/// 十首琴曲的标准谱见 [kPracticePhrases]（practice_scores.dart，由 gen_practice.py
/// 从各曲真人演奏录音逐帧估计基频后生成），因此旋律与练习时长都与该曲实际录音一致；
/// 各曲是否散板亦由该脚本从录音的律动特征自动判出。
/// 另附一条不属于曲目的散音基础练习（节拍规整，非散板）。
class PracticeData {
  PracticeData._();

  static const PracticePhrase _openStrings = PracticePhrase(
    id: 'open_strings',
    title: '散音练习',
    level: '基础',
    hint: '一弦至七弦，散音上下行',
    baseBpm: 60,
    notes: [
      TargetNote(0, 36, 900),
      TargetNote(900, 38, 900),
      TargetNote(1800, 41, 900),
      TargetNote(2700, 43, 900),
      TargetNote(3600, 45, 900),
      TargetNote(4500, 48, 900),
      TargetNote(5400, 50, 900),
      TargetNote(6300, 48, 900),
      TargetNote(7200, 45, 900),
      TargetNote(8100, 43, 900),
    ],
  );

  static final List<PracticePhrase> phrases = [_openStrings, ...kPracticePhrases];
}
