import 'dart:math' as math;
import 'dart:typed_data';

import '../../common/pitch.dart';
import '../../data/practice_data.dart';

/// 单音问题分类。
enum NoteFault {
  good('准确'),
  intonation('徽位偏差'),
  wrong('错音'),
  timing('节奏偏差'),
  missed('漏弹');

  const NoteFault(this.label);
  final String label;
}

/// 一个标准谱音的比对结果。
class NoteResult {
  const NoteResult({
    required this.index,
    required this.target,
    required this.expectedMs,
    this.detected,
    this.timingMs = 0,
    this.cents = 0,
    required this.fault,
    required this.advice,
  });

  final int index;
  final TargetNote target;

  /// 该音在本次速度下的标准起音时刻。
  final double expectedMs;
  final DetectedNote? detected;

  /// 节奏偏差（正为偏晚）。
  final double timingMs;

  /// 音分偏差（正为偏高）。
  final double cents;
  final NoteFault fault;

  /// 针对性的纠正建议。
  final String advice;

  bool get matched => detected != null;
}

/// 一次完整演奏的评测结果。
class PracticeResult {
  const PracticeResult({
    required this.results,
    required this.extras,
    required this.startOffsetMs,
    required this.trendMsPerSec,
    required this.score,
  });

  final List<NoteResult> results;

  /// 多弹 / 未对应到谱面的音数。
  final int extras;

  /// 全局起奏 / 时基偏差（正为整体偏晚）。
  final double startOffsetMs;

  /// 越弹越快（负）或越弹越慢（正）的趋势，单位 ms/秒。
  final double trendMsPerSec;
  final int score;

  int count(NoteFault f) => results.where((r) => r.fault == f).length;

  int get matchedCount => results.where((r) => r.matched).length;

  List<NoteResult> get problems =>
      results.where((r) => r.fault != NoteFault.good).toList();

  double get avgAbsCents {
    final m = results.where((r) => r.matched).toList();
    if (m.isEmpty) return 0;
    return m.map((r) => r.cents.abs()).reduce((a, b) => a + b) / m.length;
  }

  double get avgAbsTimingMs {
    final m = results.where((r) => r.matched).toList();
    if (m.isEmpty) return 0;
    return m.map((r) => r.timingMs.abs()).reduce((a, b) => a + b) / m.length;
  }

  String get summary {
    if (score >= 90) return '音位与节奏俱佳，可试着提高速度或换更长的句段。';
    if (score >= 75) return '整体稳定，个别音的音准或时值再收一收便更干净。';
    if (score >= 55) return '基本跟上了，建议放慢速度，先把每个音按准再求流畅。';
    return '先不要赶，逐音按准、逐拍对齐，再逐步提速。';
  }
}

/// 将识别到的音符与标准谱比对，输出错音 / 徽位偏差 / 节奏偏差与演奏打分。
///
/// 比对以「动态时间规整」（DTW）对齐：在音高代价与顺序单调的约束下，
/// 求目标音与实奏音的最优对应路径。整体快慢由路径的全局斜率体现（报告为
/// 起奏偏差与速度趋势），句内的合理伸缩由局部折点吸收——散板曲目以局部时基
/// 度量节奏偏差，因此渐快渐慢、气口长短不再被误判为「节奏偏差」或「漏弹」。
///
/// [speed] 为本次练习的速度倍率（0.6~1.2），标准谱时刻相应放缩。
PracticeResult evaluate(
  PracticePhrase phrase,
  List<DetectedNote> detected, {
  double speed = 1.0,
}) {
  final targets = phrase.notes;
  final det = List<DetectedNote>.of(detected)
    ..sort((a, b) => a.onsetMs.compareTo(b.onsetMs));
  final n = targets.length;

  if (n == 0) {
    return PracticeResult(
      results: const [],
      extras: det.length,
      startOffsetMs: 0,
      trendMsPerSec: 0,
      score: 0,
    );
  }

  final expected = [for (final t in targets) t.timeMs / speed];

  // 第一步：DTW 对齐。得到每个目标音对应的实奏音（无对应即漏弹）与匹配对。
  final align = _align(targets, expected, det, phrase.rubato);

  // 第二步：全局时基。以匹配对拟合「实奏时刻 ≈ A × 标准时刻 + B」，
  // 斜率 A 即整体快慢，截距 B 即起奏偏差（二者均单独报告，不计入逐音节奏偏差）。
  final warp = _fitWarp(align.pairs);

  // 第三步：逐音比对。散板以局部时基度量节奏偏差，入调以全局时基为准。
  final timingTol = phrase.rubato ? 260.0 : 160.0;
  final results = <NoteResult>[];

  for (var i = 0; i < n; i++) {
    final t = targets[i];
    final j = align.targetToDet[i];

    if (j < 0) {
      results.add(NoteResult(
        index: i,
        target: t,
        expectedMs: expected[i],
        fault: NoteFault.missed,
        advice: '漏弹：此处应弹 ${positionLabel(t.midi)}（${noteName(t.midi)}），'
            '先把左手按位找准，右手再落指。',
      ));
      continue;
    }

    final d = det[j];
    final timing = _timingDev(align, i, warp, phrase.rubato);
    final cents = 1200 * math.log(d.freq / t.freq) / math.ln2;
    final ac = cents.abs();
    final at = timing.abs();

    final NoteFault fault;
    if (ac > 100) {
      fault = NoteFault.wrong;
    } else if (ac > 30) {
      fault = NoteFault.intonation;
    } else if (at > timingTol) {
      fault = NoteFault.timing;
    } else {
      fault = NoteFault.good;
    }

    results.add(NoteResult(
      index: i,
      target: t,
      expectedMs: expected[i],
      detected: d,
      timingMs: timing,
      cents: cents,
      fault: fault,
      advice: _advice(t, d, fault, timing, cents, timingTol, phrase.rubato),
    ));
  }

  return PracticeResult(
    results: results,
    extras: align.extra,
    startOffsetMs: warp.b,
    trendMsPerSec: (warp.a - 1) * 1000,
    score: _score(results, timingTol),
  );
}

// ------------------------------------------------------------------ DTW 对齐

/// 单音匹配代价上限（约 80 音分）：超过此偏差仍判为「同一次落指」，
/// 由音准判为错音，而不是拆成「漏弹 + 多弹」。
const double _matchCapCost = 2.0;

/// 每单位代价对应的音分偏移。
const double _centsPerUnit = 40.0;

/// 目标音无对应（漏弹）与实奏音多余（多弹）的代价，略高于匹配上限，
/// 使 DP 在「能对上」时优先对齐。
const double _missPenalty = 2.2;
const double _extraPenalty = 2.2;

/// 全局时基：实奏时刻 = a × 标准时刻 + b。
class _Warp {
  const _Warp(this.a, this.b);

  /// 整体速度比（1.0 为与标准谱等速）。
  final double a;

  /// 起奏偏差（毫秒，正为整体偏晚）。
  final double b;
}

class _Align {
  const _Align(this.targetToDet, this.extra, this.pairs, this.pairOf);

  /// 每个目标音对应的实奏音下标，-1 表示漏弹。
  final List<int> targetToDet;

  /// 实奏音中未被对应上的数量（多弹）。
  final int extra;

  /// 匹配对 (标准时刻, 实奏时刻)，按目标音顺序排列。
  final List<(double, double)> pairs;

  /// 每个目标音对应的匹配对下标，-1 表示漏弹。
  final List<int> pairOf;
}

double _matchCost(TargetNote t, DetectedNote d) {
  final cents = 1200 * math.log(d.freq / t.freq) / math.ln2;
  return math.min(cents.abs() / _centsPerUnit, _matchCapCost);
}

/// 时基带：限制 DTW 中「标准时刻」与「实奏时刻」可对应的最大偏离（毫秒）。
///
/// 带宽随曲中时刻线性放宽，以容纳整体快慢；散板曲目放宽更多，因其允许的
/// 伸缩本就更大。必须在曲末仍留出足够余量，否则整体偏慢的演奏会在后半段
/// 被整段判成漏弹——固定窗口（旧实现为 ±260ms）正是死在这里。
double _bandMs(double expectedMs, bool rubato) {
  final abs0 = rubato ? 1000.0 : 500.0;
  final rel = rubato ? 0.65 : 0.35;
  return abs0 + rel * expectedMs;
}

/// 目标音与实奏音的 DTW 对齐。
///
/// 状态转移：对角（对齐）／向上（目标音漏弹）／向左（实奏音多弹）。
/// 对角转移仅在 [bandMs] 允许时才可走，由此把「顺序单调」与「局部伸缩有界」
/// 同时表达出来。
_Align _align(
  List<TargetNote> targets,
  List<double> expected,
  List<DetectedNote> det,
  bool rubato,
) {
  final n = targets.length;
  final m = det.length;
  final w = m + 1;
  final dp = Float32List((n + 1) * w);
  final back = Int8List((n + 1) * w);

  for (var j = 1; j <= m; j++) {
    dp[j] = dp[j - 1] + _extraPenalty;
    back[j] = 3;
  }
  for (var i = 1; i <= n; i++) {
    final row = i * w;
    final prev = row - w;
    dp[row] = dp[prev] + _missPenalty;
    back[row] = 2;
    final t = targets[i - 1];
    final e = expected[i - 1];
    final band = _bandMs(e, rubato);
    for (var j = 1; j <= m; j++) {
      var best = dp[prev + j] + _missPenalty;
      var flag = 2;
      final left = dp[row + j - 1] + _extraPenalty;
      if (left < best) {
        best = left;
        flag = 3;
      }
      if ((det[j - 1].onsetMs - e).abs() <= band) {
        final diag = dp[prev + j - 1] + _matchCost(t, det[j - 1]);
        if (diag < best) {
          best = diag;
          flag = 1;
        }
      }
      dp[row + j] = best;
      back[row + j] = flag;
    }
  }

  final detUsed = List<bool>.filled(m, false);
  final targetToDet = List<int>.filled(n, -1);
  var i = n;
  var j = m;
  while (i > 0 || j > 0) {
    final flag = back[i * w + j];
    if (flag == 1) {
      targetToDet[i - 1] = j - 1;
      detUsed[j - 1] = true;
      i--;
      j--;
    } else if (flag == 2) {
      i--;
    } else if (flag == 3) {
      j--;
    } else {
      break;
    }
  }

  final pairs = <(double, double)>[];
  final pairOf = List<int>.filled(n, -1);
  var pi = 0;
  for (var k = 0; k < n; k++) {
    final d = targetToDet[k];
    if (d < 0) continue;
    pairOf[k] = pi++;
    pairs.add((expected[k], det[d].onsetMs));
  }

  return _Align(targetToDet, detUsed.where((u) => !u).length, pairs, pairOf);
}

/// 以匹配对做最小二乘拟合，得到全局时基。
_Warp _fitWarp(List<(double, double)> pairs) {
  if (pairs.isEmpty) return const _Warp(1, 0);
  if (pairs.length == 1) {
    return _Warp(1, pairs.first.$2 - pairs.first.$1);
  }
  return _leastSquares(pairs);
}

/// 最小二乘拟合 (x=标准时刻, y=实奏时刻)，斜率限幅在 [0.4, 2.5]，
/// 避免个别错配把整体速度比拉飞。
_Warp _leastSquares(
  List<(double, double)> pairs, {
  double lo = 0.4,
  double hi = 2.5,
}) {
  var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
  for (final (x, y) in pairs) {
    sx += x;
    sy += y;
    sxx += x * x;
    sxy += x * y;
  }
  final cnt = pairs.length.toDouble();
  final varX = sxx - sx * sx / cnt;
  var a = varX > 1e-6 ? (sxy - sx * sy / cnt) / varX : 1.0;
  a = a.clamp(lo, hi);
  return _Warp(a, (sy - a * sx) / cnt);
}

/// 某匹配音的节奏偏差（毫秒，正为偏晚）。
///
/// 入调曲目以全局时基为基准，整体快慢已由 [warp] 吸收，余下的即真实节奏偏差；
/// 散板曲目改用该音邻近匹配对拟合的局部时基，使句内的渐快渐慢被视为合理伸缩，
/// 只有局部时基解释不了的突变才计入偏差。
double _timingDev(_Align align, int targetIndex, _Warp warp, bool rubato) {
  final p = align.pairs[align.pairOf[targetIndex]];
  if (!rubato) return p.$2 - (warp.a * p.$1 + warp.b);

  const winMs = 5000.0;
  final near = <(double, double)>[];
  for (final q in align.pairs) {
    if ((q.$1 - p.$1).abs() <= winMs) near.add(q);
  }
  final w = near.length >= 4 ? _leastSquares(near) : warp;
  return p.$2 - (w.a * p.$1 + w.b);
}

String _advice(
  TargetNote t,
  DetectedNote d,
  NoteFault fault,
  double timingMs,
  double cents,
  double timingTol,
  bool rubato,
) {
  final ac = cents.abs();
  final at = timingMs.abs();
  final buf = StringBuffer();

  if (fault == NoteFault.wrong) {
    buf.write('错音：应为 ${noteName(t.midi)}，辨认成 ${noteName(d.midi)}'
        '（差 ${ac.round()} 音分）。请按 ${positionLabel(t.midi)} 重新找准左手按位。');
  } else if (fault == NoteFault.intonation) {
    buf.write('徽位偏差：音准${cents > 0 ? '偏高' : '偏低'} ${ac.round()} 音分，'
        '左手按位${cents > 0 ? '略向琴尾' : '略向岳山'}挪一点即可回到 ${positionLabel(t.midi)}。');
  }

  if (at > timingTol) {
    if (buf.isNotEmpty) buf.write('；');
    buf.write('节奏${timingMs < 0 ? '偏早' : '偏晚'} ${at.round()} 毫秒，');
    // 散板无恒定拍点，不作「跟着节拍走」之劝，只就句内呼吸论缓急。
    buf.write(timingMs < 0
        ? (rubato ? '落指稍缓一点，让这一句更从容。' : '落指稍缓一点，跟着节拍走。')
        : (rubato ? '落指再果断些，气口收得更紧。' : '落指再果断些，抢在拍点上起音。'));
  }

  if (buf.isEmpty) {
    buf.write(rubato
        ? '音高与句内气口均稳，${positionLabel(t.midi)} 的按取很干净。'
        : '音高与节拍均准确，${positionLabel(t.midi)} 的按取很干净。');
  }
  return buf.toString();
}

double _pitchScore(double cents) {
  final a = cents.abs();
  if (a <= 25) return 100;
  if (a <= 60) return 100 - (a - 25) / 35 * 30;
  if (a <= 120) return 70 - (a - 60) / 60 * 40;
  return math.max(0, 30 - (a - 120) / 100 * 30).toDouble();
}

/// 节奏分。散板曲目按 [timingTol] 放宽刻度，使自由伸缩不额外扣分。
double _timeScore(double ms, double timingTol) {
  final a = ms.abs() * (160.0 / timingTol);
  if (a <= 80) return 100;
  if (a <= 200) return 100 - (a - 80) / 120 * 40;
  if (a <= 400) return 60 - (a - 200) / 200 * 40;
  return 20;
}

int _score(List<NoteResult> results, double timingTol) {
  if (results.isEmpty) return 0;
  var sum = 0.0;
  for (final r in results) {
    if (!r.matched) continue; // 漏弹计 0 分
    sum += 0.6 * _pitchScore(r.cents) + 0.4 * _timeScore(r.timingMs, timingTol);
  }
  return (sum / results.length).round().clamp(0, 100);
}

