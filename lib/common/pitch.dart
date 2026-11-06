import 'dart:math' as math;
import 'dart:typed_data';

/// 古琴音高识别与音符分割（端上纯 Dart 实现，全程离线，不上传任何音频）。
///
/// 链路：麦克风 PCM16 → 均值抽取降采样 → YIN 基频估计 + 短时能量
/// → 起音检测 → 音符分割（起音时刻 / 音高中值 / 时值）。
///
/// 古琴单音余响长达数秒，相邻音常相互叠置，因此起音判定不能只靠「静音→有声」
/// 的阈值穿越，而采用「能量陡升」与「音高突变」双判据，保证连弹时仍可切分。
class PitchConfig {
  const PitchConfig._();

  /// 向麦克风请求的采集参数（44.1kHz / 单声道 / PCM16）。
  static const int inputRate = 44100;

  /// 抽取降采样倍数（多点均值，兼作抗混叠），分析率 8820Hz。
  static const int decim = 5;
  static const int analysisRate = inputRate ~/ decim;

  /// YIN 分析窗长与步进（分析率下的样本数）。
  static const int frame = 1024; // ≈116ms，可覆盖一弦散音 C2(65.4Hz)
  static const int hop = 128; // ≈14.5ms

  static const double minFreq = 56.0; // 略低于 C2，留出绰/注滑入余量
  static const double maxFreq = 1100.0;
}

/// 一次被识别出的弹奏音（时间基准为「本次采集开始」）。
class DetectedNote {
  const DetectedNote({
    required this.onsetMs,
    required this.offsetMs,
    required this.freq,
    required this.confidence,
  });

  final double onsetMs;
  final double offsetMs;
  final double freq;
  final double confidence;

  double get durMs => offsetMs - onsetMs;

  /// 十二平均律 MIDI（带小数，便于换算音分偏差）。
  double get midiFloat => 69.0 + 12.0 * (math.log(freq / 440.0) / math.ln2);

  int get midi => midiFloat.round();

  DetectedNote shifted(double deltaMs) => DetectedNote(
        onsetMs: onsetMs + deltaMs,
        offsetMs: offsetMs + deltaMs,
        freq: freq,
        confidence: confidence,
      );
}

/// 流式音符识别器：把 PCM16 字节流喂给 [feed]，识别到的音符通过 [onNote] 回调。
class PracticeListener {
  PracticeListener({this.onNote, this.onProgress});

  /// 识别出一个完整音符时回调（音高为该音起始段的中值）。
  final void Function(DetectedNote note)? onNote;

  /// 每个分析帧回调一次，用于电平条与实时音高显示。
  final void Function(double rms, double? freq)? onProgress;

  static const double _yinThreshold = 0.20;
  static const int _maxPitchSamples = 25;

  final List<double> _samples = <double>[];
  int _pos = 0;
  double _acc = 0;
  int _accCount = 0;

  double _prevRms = 0;
  double _floor = 0.002;
  double _lastOnsetMs = -1e9;

  bool _open = false;
  double _onsetMs = 0;
  double _lastLoudMs = 0;
  double _stablePitch = 0;
  double _bestConf = 0;
  int _hopsSinceOnset = 0;
  final List<double> _pitches = <double>[];

  bool get isOpen => _open;

  void reset() {
    _samples.clear();
    _pos = 0;
    _acc = 0;
    _accCount = 0;
    _prevRms = 0;
    _floor = 0.002;
    _lastOnsetMs = -1e9;
    _open = false;
    _onsetMs = 0;
    _lastLoudMs = 0;
    _stablePitch = 0;
    _bestConf = 0;
    _hopsSinceOnset = 0;
    _pitches.clear();
  }

  /// 输入一段单声道 PCM16LE 数据。
  void feed(Uint8List bytes) {
    if (bytes.length < 2) return;
    final bd = ByteData.sublistView(bytes);
    final m = bytes.length ~/ 2;
    for (var i = 0; i < m; i++) {
      _acc += bd.getInt16(i * 2, Endian.little) / 32768.0;
      if (++_accCount >= PitchConfig.decim) {
        _samples.add(_acc / PitchConfig.decim);
        _acc = 0;
        _accCount = 0;
      }
    }
    _process();
  }

  /// 采集结束时调用：把仍在余响中的末音收束并上报。
  void flush() {
    if (_open) _close(_lastLoudMs + 1);
  }

  void _process() {
    const frame = PitchConfig.frame;
    const hop = PitchConfig.hop;
    while (_samples.length - _pos >= frame) {
      final end = _pos + frame;
      final timeMs = end * 1000.0 / PitchConfig.analysisRate;

      var sum = 0.0;
      for (var i = end - hop; i < end; i++) {
        sum += _samples[i] * _samples[i];
      }
      final rms = math.sqrt(sum / hop);

      final pitch = _yin(_samples, _pos);
      _step(timeMs, rms, pitch?.$1, pitch?.$2 ?? 0.0);
      _pos += hop;
    }
    // 已处理过的样本不再需要，攒够一批再整体裁掉，避免频繁搬运。
    if (_pos > frame * 4) {
      _samples.removeRange(0, _pos);
      _pos = 0;
    }
  }

  void _step(double timeMs, double rms, double? freq, double conf) {
    onProgress?.call(rms, conf >= 0.55 ? freq : null);

    final loudThreshold = math.max(_floor * 3.5, 0.004);
    final loud = rms > loudThreshold;
    if (!loud) _floor = _floor * 0.94 + rms * 0.06;

    // 起音判据一：能量陡升（拨弦的音头）。
    final rise = _prevRms > 1e-6 ? rms / _prevRms : 1.0;
    final energyOnset = loud && rise > 1.65 && rms > _floor * 3.0;

    // 起音判据二：音高突变（前音余响未落时又起新音）。
    final pitchJump = loud &&
        freq != null &&
        conf >= 0.6 &&
        _open &&
        _stablePitch > 0 &&
        (1200 * (math.log(freq / _stablePitch) / math.ln2)).abs() > 75;

    final onset = (energyOnset || pitchJump) && (timeMs - _lastOnsetMs) > 95;

    if (onset) {
      if (_open) _close(timeMs);
      _open = true;
      _onsetMs = timeMs;
      _hopsSinceOnset = 0;
      _pitches.clear();
      _stablePitch = 0;
      _bestConf = 0;
      _lastOnsetMs = timeMs;
      _lastLoudMs = timeMs;
    } else if (_open) {
      if (loud) _lastLoudMs = timeMs;
      if (loud && freq != null && conf >= 0.55) {
        // 跳过音头瞬态，取起始段音高代表本音
        if (_hopsSinceOnset >= 2 && _pitches.length < _maxPitchSamples) {
          _pitches.add(freq);
        }
        if (conf > _bestConf) _bestConf = conf;
        if (_stablePitch == 0 && _hopsSinceOnset >= 2) _stablePitch = freq;
      }
      if (timeMs - _lastLoudMs > 220) _close(timeMs);
    }

    _hopsSinceOnset++;
    _prevRms = rms;
  }

  void _close(double endMs) {
    if (!_open) return;
    _open = false;
    final durMs = endMs - _onsetMs;
    // 过短或无声高（如节拍器 click、环境噪声）一律丢弃
    if (durMs < 90 || _pitches.length < 3) return;
    final sorted = List<double>.of(_pitches)..sort();
    onNote?.call(DetectedNote(
      onsetMs: _onsetMs,
      offsetMs: endMs,
      freq: sorted[sorted.length ~/ 2],
      confidence: _bestConf,
    ));
  }

  (double, double)? _yin(List<double> x, int start) =>
      yinPitch(x, start, threshold: _yinThreshold);
}

/// YIN 基频估计（音符识别与琴音可视化共用），返回 (频率, 置信度)。
///
/// [x] 为分析率下的样本序列，[start] 为分析窗起点；无可靠基频时返回 null。
(double, double)? yinPitch(
  List<double> x,
  int start, {
  int frame = PitchConfig.frame,
  double threshold = 0.20,
}) {
  final minLag = (PitchConfig.analysisRate / PitchConfig.maxFreq).floor();
  final maxLag = (PitchConfig.analysisRate / PitchConfig.minFreq).ceil();
  if (start + frame > x.length) return null;
  final n = frame - maxLag;
  if (n <= 0) return null;

  // 差函数 d(tau)
  final d = Float64List(maxLag + 1);
  for (var tau = 1; tau <= maxLag; tau++) {
    var s = 0.0;
    final base = start + tau;
    for (var j = 0; j < n; j++) {
      final diff = x[start + j] - x[base + j];
      s += diff * diff;
    }
    d[tau] = s;
  }

  // 累积均值归一化差函数
  final c = Float64List(maxLag + 1);
  c[0] = 1.0;
  var running = 0.0;
  for (var tau = 1; tau <= maxLag; tau++) {
    running += d[tau];
    c[tau] = running <= 0 ? 1.0 : d[tau] * tau / running;
  }

  // 绝对阈值：取首个低于阈值处的局部极小
  var tau = minLag;
  while (tau <= maxLag) {
    if (c[tau] < threshold) {
      while (tau + 1 <= maxLag && c[tau + 1] < c[tau]) {
        tau++;
      }
      break;
    }
    tau++;
  }
  if (tau > maxLag) return null;

  // 抛物线插值细化
  var better = tau.toDouble();
  if (tau > minLag && tau < maxLag) {
    final a = c[tau - 1];
    final b = c[tau];
    final e = c[tau + 1];
    final denom = a - 2 * b + e;
    if (denom.abs() > 1e-9) better = tau + 0.5 * (a - e) / denom;
  }
  if (better <= 0) return null;

  final freq = PitchConfig.analysisRate / better;
  if (freq < PitchConfig.minFreq || freq > PitchConfig.maxFreq) return null;
  return (freq, (1.0 - c[tau]).clamp(0.0, 1.0));
}
