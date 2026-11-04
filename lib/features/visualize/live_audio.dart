import 'dart:math' as math;
import 'dart:typed_data';

import '../../common/pitch.dart';

/// 一帧实时音频分析结果。所有数值都由麦克风采到的真实信号算出。
class AudioFrame {
  const AudioFrame({
    required this.rms,
    required this.freq,
    required this.conf,
    required this.centroidRatio,
    required this.highRatio,
    required this.harmonics,
    required this.decayMs,
  });

  /// 短时能量（0~1），反映弹奏强弱。
  final double rms;

  /// 基频（Hz）；置信度不足时为 null。
  final double? freq;
  final double conf;

  /// 谱心 / 基频——与音高无关的音色亮度指标。
  final double centroidRatio;

  /// 4 倍基频以上的能量占比（0~1）。
  final double highRatio;

  /// 相对基频的第 1~16 次谐波幅度（峰值归一）；无声高时为 null。
  final Float32List? harmonics;

  /// 本次起振后衰减 20dB 的时间（ms）；尚未测满一整段余响时为 null。
  final double? decayMs;
}

/// 琴音实时分析器：PCM16 → 抽取降采样 → 短时能量 / 加窗 FFT 频谱 /
/// YIN 基频 / 谐波包络 / 谱心与高频占比 / 余响衰减时间。
///
/// 与智能演奏辅助共用同一套 YIN（[yinPitch]）与降采样参数，保证识别口径一致。
class LiveAudioAnalyzer {
  LiveAudioAnalyzer({this.onFrame}) {
    // 初始化窗函数
    const frame = PitchConfig.frame;
    for (var i = 0; i < frame; i++) {
      _window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (frame - 1));
    }
  }

  /// 每分析一帧回调一次（约 69 帧/秒）。
  final void Function(AudioFrame frame)? onFrame;

  /// 声波频谱的对数频段数。
  static const int bandCount = 48;

  /// 谐波包络维数。
  static const int harmonicCount = 16;

  static const double bandLowHz = 60;
  static const double bandHighHz = 4000;

  /// 声纹瀑布保留帧数（约 150 × 14.5ms ≈ 2.2 秒）。
  static const int historyLength = 150;

  /// 音高轨迹保留帧数（约 420 × 14.5ms ≈ 6.1 秒）。
  static const int pitchHistoryLength = 420;

  /// 一帧的时长（毫秒）。
  static const double hopMs = PitchConfig.hop * 1000.0 / PitchConfig.analysisRate;

  /// 衰减测量最长时间（毫秒）。
  static const double _decayWindowMs = 6000;

  final List<double> _samples = <double>[];
  int _pos = 0;
  double _acc = 0;
  int _accCount = 0;

  final Float64List _re = Float64List(PitchConfig.frame);
  final Float64List _im = Float64List(PitchConfig.frame);
  final Float64List _mag = Float64List(PitchConfig.frame ~/ 2 + 1);

  /// 预计算汉宁窗，避免每帧重复计算。
  final Float64List _window = Float64List(PitchConfig.frame);

  final List<Float32List> _spec =
      List<Float32List>.generate(historyLength, (_) => Float32List(bandCount));
  int _specWrite = 0;
  final Float32List _bands = Float32List(bandCount);

  final Float32List _pitchRing = Float32List(pitchHistoryLength);
  int _pitchWrite = 0;

  double _bandPeak = 1e-6;
  double _prevRms = 0;
  double _centroid = 0;
  double _highRatio = 0;
  Float32List? _harmonics;

  double _peakRms = 0;
  int _sinceOnset = -1;
  double? _decayMs;

  /// 声纹瀑布按时间先后取第 [row] 行（0 为最早，historyLength-1 为最新）。
  Float32List specRow(int row) => _spec[(_specWrite + row) % historyLength];

  /// 音高轨迹按时间先后取第 [row] 个采样；无音高帧为 NaN。
  double pitchAt(int row) => _pitchRing[(_pitchWrite + row) % pitchHistoryLength];

  /// 声纹瀑布只保留 [historyLength] 帧，其余为静默。
  bool get hasEnoughHistory => _specWrite >= historyLength;

  int get filledFrames => math.min(_specWrite, historyLength);

  void reset() {
    _samples.clear();
    _pos = 0;
    _acc = 0;
    _accCount = 0;
    _specWrite = 0;
    _pitchWrite = 0;
    for (final row in _spec) {
      row.fillRange(0, row.length, 0);
    }
    _pitchRing.fillRange(0, _pitchRing.length, double.nan);
    _bandPeak = 1e-6;
    _prevRms = 0;
    _centroid = 0;
    _highRatio = 0;
    _harmonics = null;
    _peakRms = 0;
    _sinceOnset = -1;
    _decayMs = null;
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

  void _process() {
    const frame = PitchConfig.frame;
    const hop = PitchConfig.hop;
    while (_samples.length - _pos >= frame) {
      _analyze(_pos);
      _pos += hop;
    }
    // 已处理的样本攒够一批再整体裁掉，避免频繁搬运。
    if (_pos > frame * 4) {
      _samples.removeRange(0, _pos);
      _pos = 0;
    }
  }

  void _analyze(int start) {
    const frame = PitchConfig.frame;

    // 短时能量取窗尾一个 hop，反映「此刻」的强弱
    var sum = 0.0;
    for (var i = start + frame - PitchConfig.hop; i < start + frame; i++) {
      sum += _samples[i] * _samples[i];
    }
    final rms = math.sqrt(sum / PitchConfig.hop);

    // 加窗 FFT → 幅度谱
    const half = frame / 2;
    for (var i = 0; i < frame; i++) {
      _re[i] = _samples[start + i] * _window[i];
      _im[i] = 0;
    }
    _fft(_re, _im);
    for (var k = 0; k <= half; k++) {
      _mag[k] = math.sqrt(_re[k] * _re[k] + _im[k] * _im[k]);
    }

    final pitch = yinPitch(_samples, start);
    final freq = (pitch != null && pitch.$2 >= 0.5) ? pitch.$1 : null;
    final conf = pitch?.$2 ?? 0;

    _bandsOut();
    // 写入环形缓冲区，必须取模防止越界；复用列表减少内存分配。
    _spec[_specWrite % historyLength].setAll(0, _bands);
    _specWrite++;

    // 谐波包络与音色指标
    if (freq != null) {
      _harmonics = _harmonicEnvelope(freq);
      _centroid = _spectralCentroid(freq);
      _highRatio = _highBandRatio(freq);
    } else {
      _harmonics = null;
      _centroid = 0;
      _highRatio = 0;
    }

    _pitchRing[_pitchWrite % pitchHistoryLength] = freq == null ? double.nan : _midi(freq);
    _pitchWrite++;

    _trackDecay(rms);

    onFrame?.call(AudioFrame(
      rms: rms,
      freq: freq,
      conf: conf,
      centroidRatio: freq == null ? 0 : _centroid / freq,
      highRatio: _highRatio,
      harmonics: _harmonics == null ? null : Float32List.fromList(_harmonics!),
      decayMs: _decayMs,
    ));
  }

  /// 对数频段能量，用缓慢衰减的峰值自适应归一（0~1）。
  void _bandsOut() {
    const df = PitchConfig.analysisRate / PitchConfig.frame;
    const ratio = bandHighHz / bandLowHz;
    var framePeak = 0.0;
    for (var b = 0; b < bandCount; b++) {
      final lo = bandLowHz * math.pow(ratio, b / bandCount);
      final hi = bandLowHz * math.pow(ratio, (b + 1) / bandCount);
      final k0 = math.max(1, (lo / df).floor());
      final k1 = math.min(_mag.length - 1, (hi / df).ceil());
      var v = 0.0;
      for (var k = k0; k <= k1; k++) {
        if (_mag[k] > v) v = _mag[k];
      }
      _bands[b] = v;
      if (v > framePeak) framePeak = v;
    }
    // 自适应增益：参考峰值「快跟随当前帧、约 0.3 秒半衰」。
    // 缓释过慢（如 0.995）会让一次强音之后的所有频谱都塌到接近零，
    // 看上去就像「只有开头在动、后面不动了」。
    _bandPeak = math.max(framePeak, _bandPeak * 0.97);
    if (_bandPeak <= 1e-9) _bandPeak = 1e-9;
    for (var b = 0; b < bandCount; b++) {
      final db = 20 * (math.log(_bands[b] / _bandPeak) / math.ln10);
      _bands[b] = ((db + 62) / 62).clamp(0.0, 1.0);
    }
  }

  Float32List _harmonicEnvelope(double f0) {
    const df = PitchConfig.analysisRate / PitchConfig.frame;
    final out = Float32List(harmonicCount);
    var peak = 0.0;
    for (var k = 1; k <= harmonicCount; k++) {
      final fk = k * f0;
      if (fk >= PitchConfig.analysisRate / 2) break;
      final k0 = math.max(1, ((fk * 0.94) / df).floor());
      final k1 = math.min(_mag.length - 1, ((fk * 1.06) / df).ceil());
      var v = 0.0;
      for (var j = k0; j <= k1; j++) {
        if (_mag[j] > v) v = _mag[j];
      }
      out[k - 1] = v;
      if (v > peak) peak = v;
    }
    if (peak > 1e-9) {
      for (var i = 0; i < harmonicCount; i++) {
        out[i] /= peak;
      }
    }
    return out;
  }

  double _spectralCentroid(double f0) {
    const df = PitchConfig.analysisRate / PitchConfig.frame;
    final k0 = math.max(1, (f0 * 0.9 / df).floor());
    var num = 0.0;
    var den = 0.0;
    for (var k = k0; k < _mag.length; k++) {
      final e = _mag[k] * _mag[k];
      num += (k * df) * e;
      den += e;
    }
    return den <= 0 ? 0 : num / den;
  }

  double _highBandRatio(double f0) {
    const df = PitchConfig.analysisRate / PitchConfig.frame;
    final totalFrom = math.max(1, (f0 * 0.9 / df).floor());
    final highFrom = math.max(1, (4 * f0 / df).floor());
    var total = 0.0;
    var high = 0.0;
    for (var k = totalFrom; k < _mag.length; k++) {
      final e = _mag[k] * _mag[k];
      total += e;
      if (k >= highFrom) high += e;
    }
    return total <= 0 ? 0 : high / total;
  }

  /// 起振后跟踪能量包络，测出衰减 20dB 所需时间。
  void _trackDecay(double rms) {
    final rise = _prevRms > 1e-6 ? rms / _prevRms : 1.0;
    if (rms > 0.006 && rise > 1.6) {
      _peakRms = rms;
      _sinceOnset = 0;
      _decayMs = null;
    } else if (_sinceOnset >= 0) {
      _sinceOnset++;
      if (rms > _peakRms) _peakRms = rms;
      if (rms < _peakRms * 0.1) {
        _decayMs = _sinceOnset * hopMs;
        _sinceOnset = -1;
      } else if (_sinceOnset * hopMs > _decayWindowMs) {
        _sinceOnset = -1;
      }
    }
    _prevRms = rms;
  }

  static double _midi(double f) => 69.0 + 12.0 * (math.log(f / 440.0) / math.ln2);

  /// 原地迭代 radix-2 FFT（长度须为 2 的幂）。
  static void _fft(Float64List re, Float64List im) {
    final n = re.length;
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        var t = re[i];
        re[i] = re[j];
        re[j] = t;
        t = im[i];
        im[i] = im[j];
        im[j] = t;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wr = math.cos(ang);
      final wi = math.sin(ang);
      for (var i = 0; i < n; i += len) {
        var cr = 1.0;
        var ci = 0.0;
        final half = len >> 1;
        for (var j = 0; j < half; j++) {
          final ur = re[i + j];
          final ui = im[i + j];
          final vr = re[i + j + half] * cr - im[i + j + half] * ci;
          final vi = re[i + j + half] * ci + im[i + j + half] * cr;
          re[i + j] = ur + vr;
          im[i + j] = ui + vi;
          re[i + j + half] = ur - vr;
          im[i + j + half] = ui - vi;
          final nr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = nr;
        }
      }
    }
  }
}
