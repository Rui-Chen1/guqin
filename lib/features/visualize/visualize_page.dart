import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../common/ink_scaffold.dart';
import '../../common/pitch.dart';
import '../../common/widgets.dart';
import '../../data/app_database.dart';
import '../../data/practice_data.dart';
import '../../theme/app_theme.dart';
import 'harmonic_references.dart';
import 'live_audio.dart';

/// 功能七：琴音可视化。
///
/// 用真实麦克风采集琴音（PCM16 / 44.1kHz / 单声道），在端上离线完成
/// 短时能量、加窗 FFT 频谱、YIN 基频、谐波包络与余响衰减的分析，
/// 据此实时绘制「声波频谱 · 声纹瀑布 · 音高轨迹」，并对照本地单音音效
/// 实测出的散音 / 按音 / 泛音指纹，直观呈现三种音色的声学差异。
/// 音频仅在本机内存中分析，不上传、不落盘。
class VisualizePage extends StatefulWidget {
  const VisualizePage({super.key});

  @override
  State<VisualizePage> createState() => _VisualizePageState();
}

class _VisualizePageState extends State<VisualizePage>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;

  late final LiveAudioAnalyzer _analyzer;
  late final AnimationController _tick;

  /// 最新一帧分析结果（供指标文字实时刷新）。
  final ValueNotifier<AudioFrame?> _frame = ValueNotifier<AudioFrame?>(null);

  /// 供画笔读取的最新帧（画笔由 [_tick] 每帧重绘，无需通知）。
  AudioFrame? _latest;

  bool _listening = false;
  bool _busy = false;
  String? _error;
  int _session = 0;

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.bumpProgress('visualize_views');
    _analyzer = LiveAudioAnalyzer(onFrame: _onFrame);
    _tick = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _session++;
    unawaited(_sub?.cancel());
    unawaited(_recorder.dispose());
    _tick.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onFrame(AudioFrame frame) {
    _latest = frame;
    _frame.value = frame;
  }

  // ---------------------------------------------------------------- 采集

  Future<void> _start() async {
    if (_busy || _listening) return;
    final session = ++_session;
    setState(() {
      _busy = true;
      _error = null;
    });

    var granted = false;
    try {
      granted = await _recorder.hasPermission();
    } catch (_) {
      granted = false;
    }
    if (!mounted || session != _session) return;
    if (!granted) {
      setState(() {
        _busy = false;
        _error = '未获得麦克风权限，无法采集琴音。请在系统设置中允许「弦上知音」使用麦克风。';
      });
      return;
    }

    _analyzer.reset();
    _latest = null;
    _frame.value = null;

    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: PitchConfig.inputRate,
        numChannels: 1,
      ));
      _sub = stream.listen(
        (bytes) => _analyzer.feed(bytes),
        onError: (Object e) {
          debugPrint('录音流错误：$e');
          setState(() => _error = '采集过程出错：$e');
        },
        onDone: () {
          debugPrint('录音流已结束');
          if (_listening) {
            setState(() => _error = '录音流意外结束，请重试。');
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '无法启动麦克风：$e';
      });
      return;
    }
    if (!mounted || session != _session) return;

    _tick.repeat();
    setState(() {
      _busy = false;
      _listening = true;
    });
  }

  Future<void> _stop() async {
    _session++;
    final sub = _sub;
    _sub = null;
    if (sub != null) await sub.cancel();
    try {
      await _recorder.stop();
    } catch (_) {
      // 忽略停止失败
    }
    _tick.stop();
    if (!mounted) return;
    setState(() => _listening = false);
  }

  // ---------------------------------------------------------------- 音色辨识

  /// 以「谱心 / 高频占比 / 余响」三项实测指标，就近匹配三种音色指纹。
  ///
  /// 三种音色的谐波包络本就很接近，故只作「最接近」参考，不做确定判定。
  int? _match(AudioFrame? f) {
    if (f == null || f.freq == null) return null;
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < kTimbreReferences.length; i++) {
      final r = kTimbreReferences[i];
      final dc = (f.centroidRatio - r.centroidRatio) / 0.4;
      final dh = (f.highRatio - r.highRatio) / 0.06;
      final dd = f.decayMs == null ? 0.0 : (f.decayMs! - r.decayMs) / 1800.0;
      final d = dc * dc + dh * dh + dd * dd;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------- 视图

  @override
  Widget build(BuildContext context) {
    return InkScaffold(
      appBar: AppBar(title: const Text('琴音可视化')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _controlCard(),
          const SizedBox(height: 14),
          _metricCard(),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.bar_chart,
            color: AppColors.jade,
            title: '声波频谱',
            note: '60Hz–4kHz 对数频段',
            height: 132,
            child: AnimatedBuilder(
              animation: _tick,
              builder: (_, __) => CustomPaint(
                painter: _SpectrumPainter(
                  analyzer: _analyzer,
                  t: _tick.value,
                  active: _listening,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            icon: Icons.waves,
            color: const Color(0xFF3C7EA8),
            title: '声纹瀑布',
            note: '近 2.2 秒，上旧下新',
            height: 176,
            child: AnimatedBuilder(
              animation: _tick,
              builder: (_, __) => CustomPaint(
                painter: _WaterfallPainter(analyzer: _analyzer, t: _tick.value),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            icon: Icons.show_chart,
            color: AppColors.cinnabar,
            title: '音高轨迹',
            note: '近 6 秒，纵轴为音名',
            height: 128,
            child: AnimatedBuilder(
              animation: _tick,
              builder: (_, __) {
                final f = _latest;
                final midi = f?.freq == null
                    ? null
                    : 69.0 + 12.0 * math.log(f!.freq! / 440.0) / math.ln2;
                return CustomPaint(
                  painter: _PitchPainter(
                    analyzer: _analyzer,
                    t: _tick.value,
                    currentMidi: midi,
                    label: f?.freq == null || midi == null
                        ? ''
                        : '${noteName(midi.round())} · ${f!.freq!.toStringAsFixed(0)}Hz',
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _timbreCard(),
          const SizedBox(height: 16),
          const _ReferenceNote(),
        ],
      ),
    );
  }

  Widget _controlCard() {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '实时采集',
            trailing: FilledButton.icon(
              onPressed: _busy ? null : (_listening ? _stop : _start),
              icon: Icon(_listening ? Icons.stop : Icons.mic_none_outlined, size: 16),
              label: Text(_listening ? '停止' : '开始采集'),
            ),
          ),
          Text(
            _error ??
                (_listening
                    ? '正在分析麦克风采到的琴音，画面随音色与强弱实时变化。'
                    : '点击「开始采集」，对着麦克风弹奏古琴（或发出乐音），即可看到实时声学图形。'),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.75,
              color: _error == null ? AppColors.inkSoft : AppColors.cinnabar,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '全部计算在本机完成，音频不上传、不落盘。',
            style: TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _metricCard() {
    return AnimatedBuilder(
      animation: _frame,
      builder: (context, _) {
        final f = _frame.value;
        final freq = f?.freq;
        final midi = freq == null ? null : 69.0 + 12.0 * math.log(freq / 440.0) / math.ln2;
        final match = _match(f);
        return PaperCard(
          child: Column(
            children: [
              Row(
                children: [
                  _metric('音名', midi == null ? '—' : noteName(midi.round())),
                  _metric('基频', freq == null ? '—' : '${freq.toStringAsFixed(1)} Hz'),
                  _metric('电平',
                      f == null ? '—' : '${(f.rms * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                  _metric('最接近', match == null ? '—' : kTimbreReferences[match].name),
                ],
              ),
              const SizedBox(height: 12),
              _levelBar(f?.rms ?? 0),
            ],
          ),
        );
      },
    );
  }

  Widget _timbreCard() {
    return AnimatedBuilder(
      animation: _frame,
      builder: (context, _) {
        final f = _frame.value;
        final match = _match(f);
        return PaperCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.equalizer, size: 16, color: AppColors.gold),
                  SizedBox(width: 6),
                  Text('谐波包络与音色辨识',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 108,
                child: AnimatedBuilder(
                  animation: _tick,
                  builder: (_, __) => CustomPaint(
                    painter: _EnvelopePainter(
                      live: _latest?.harmonics,
                      reference: match == null
                          ? null
                          : kTimbreReferences[match].envelope,
                      t: _tick.value,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _timbreTable(f, match),
            ],
          ),
        );
      },
    );
  }

  Widget _timbreTable(AudioFrame? f, int? match) {
    Widget head(String s, {bool right = false}) => Expanded(
          child: Text(s,
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
        );

    Widget cell(String s, {bool right = false, bool strong = false}) => Expanded(
          child: Text(s,
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
                  color: strong ? AppColors.ink : AppColors.inkSoft)),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              head('音色'),
              head('谱心/基频', right: true),
              head('高频占比', right: true),
              head('余响', right: true),
            ],
          ),
        ),
        for (final r in kTimbreReferences)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                cell(r.name, strong: match == kTimbreReferences.indexOf(r)),
                cell(r.centroidRatio.toStringAsFixed(2), right: true),
                cell('${(r.highRatio * 100).toStringAsFixed(1)}%', right: true),
                cell('${(r.decayMs / 1000).toStringAsFixed(1)}s', right: true),
              ],
            ),
          ),
        const HairDivider(margin: EdgeInsets.symmetric(vertical: 6)),
        Row(
          children: [
            cell('实时', strong: true),
            cell(f?.freq == null ? '—' : f!.centroidRatio.toStringAsFixed(2), right: true),
            cell(f?.freq == null ? '—' : '${(f!.highRatio * 100).toStringAsFixed(1)}%',
                right: true),
            cell(f?.decayMs == null ? '—' : '${(f!.decayMs! / 1000).toStringAsFixed(1)}s',
                right: true),
          ],
        ),
      ],
    );
  }

  Widget _panel({
    required IconData icon,
    required Color color,
    required String title,
    required String note,
    required double height,
    required Widget child,
  }) {
    return PaperCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(note, style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            width: double.infinity,
            child: ClipRect(child: child),
          ),
        ],
      ),
    );
  }

  Widget _metric(String k, String v) => Expanded(
        child: Column(
          children: [
            Text(v,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(k, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
          ],
        ),
      );

  Widget _levelBar(double rms) {
    final v = (rms * 6).clamp(0.0, 1.0).toDouble();
    return Container(
      height: 7,
      decoration: const BoxDecoration(color: Color(0xFF23262C)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4E9E8A), Color(0xFFE9C97A), Color(0xFFC8553D)],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceNote extends StatelessWidget {
  const _ReferenceNote();

  @override
  Widget build(BuildContext context) {
    return const PaperCard(
      child: Text(
        '音色辨析（取自本地单音音效的实测指纹）：\n'
        '散音 · 全弦振动，低次谐波强、余响最长（约 4.2 秒），音色浑厚宽广。\n'
        '按音 · 按弦取音，谐波居中、余响约 2.8 秒，音色温润近人。\n'
        '泛音 · 触徽分段振动，高次谐波衰减最快、余响约 2.2 秒，音色空灵清越。\n'
        '注：三者谐波包络本就十分接近，故「最接近」仅供参照；实际弹奏因触弦力度、'
        '位置与录音环境不同，各项数值会有出入。',
        style: TextStyle(fontSize: 12, height: 1.9, color: AppColors.inkSoft),
      ),
    );
  }
}

// ------------------------------------------------------------------ 画笔

const Color _panelBg = Color(0xFF15171C);

/// 强度 → 色彩：暗青 → 玉色 → 鎏金 → 朱砂。
Color _heat(double v) {
  final x = v.clamp(0.0, 1.0).toDouble();
  if (x <= 0.02) return _panelBg;
  if (x < 0.5) {
    return Color.lerp(const Color(0xFF17242E), const Color(0xFF2E7A69), x / 0.5)!;
  }
  if (x < 0.88) {
    return Color.lerp(const Color(0xFF2E7A69), const Color(0xFFEFD79B), (x - 0.5) / 0.38)!;
  }
  return Color.lerp(const Color(0xFFEFD79B), const Color(0xFFC8553D), (x - 0.88) / 0.12)!;
}

void _label(Canvas canvas, String s, Offset at, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontFamily: AppTheme.serifFamily,
        fontFamilyFallback: AppTheme.serifFallback,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, at);
}

void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
  final total = (b - a).distance;
  if (total <= 0.5) return;
  final dir = (b - a) / total;
  var d = 0.0;
  while (d < total) {
    final e = math.min(d + 4.0, total);
    canvas.drawLine(a + dir * d, a + dir * e, paint);
    d = e + 3.0;
  }
}

/// 声波频谱：最新一帧的 48 个对数频段能量。
class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.analyzer, required this.t, required this.active});
  final LiveAudioAnalyzer analyzer;
  final double t;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _panelBg);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    const n = LiveAudioAnalyzer.bandCount;
    // 取环里最新的一帧（此前误用 bandCount-1，取到的是约 1.5 秒前的旧帧）
    final row = analyzer.specRow(LiveAudioAnalyzer.historyLength - 1);
    const gap = 1.5;
    final bw = (size.width - gap * (n - 1)) / n;
    for (var b = 0; b < n; b++) {
      final v = row[b].clamp(0.0, 1.0).toDouble();
      final h = math.max(1.5, v * size.height * 0.94);
      final x = b * (bw + gap);
      canvas.drawRect(Rect.fromLTWH(x, size.height - h, bw, h), Paint()..color = _heat(v));
    }

    // 频率刻度
    const ticks = [100.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0];
    final logLow = math.log(LiveAudioAnalyzer.bandLowHz);
    final logSpan = math.log(LiveAudioAnalyzer.bandHighHz / LiveAudioAnalyzer.bandLowHz);
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (final f in ticks) {
      final x = (math.log(f) - logLow) / logSpan * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, 6), tickPaint);
      final label = f >= 1000
          ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k'
          : f.toStringAsFixed(0);
      _label(canvas, label, Offset(x + 2, 2), 8, Colors.white.withValues(alpha: 0.38));
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter old) => old.t != t || old.active != active;
}

/// 声纹瀑布：近 2.2 秒的频谱回溯（上旧下新）。
class _WaterfallPainter extends CustomPainter {
  _WaterfallPainter({required this.analyzer, required this.t});
  final LiveAudioAnalyzer analyzer;
  final double t;

  /// 量化热力色阶：瀑布每帧最多要画 150×48 格，逐格 Color.lerp 会制造
  /// 大量临时对象并拖垮帧率，这里预先算好 33 级色阶直接取用。
  static final List<Color> _ramp = List<Color>.generate(33, (i) => _heat(i / 32));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _panelBg);
    const rows = LiveAudioAnalyzer.historyLength;
    const cols = LiveAudioAnalyzer.bandCount;
    final cw = size.width / cols;
    final rh = size.height / rows;
    final paint = Paint();
    for (var r = 0; r < rows; r++) {
      final row = analyzer.specRow(r);
      final y = r * rh;
      for (var b = 0; b < cols; b++) {
        final v = row[b].clamp(0.0, 1.0).toDouble();
        if (v <= 0.06) continue;
        paint.color = _ramp[(v * 32).round()];
        canvas.drawRect(Rect.fromLTWH(b * cw, y, cw + 0.7, rh + 0.7), paint);
      }
    }
    _label(canvas, '旧', Offset(size.width - 16, 2), 8, Colors.white.withValues(alpha: 0.32));
    _label(canvas, '新', Offset(size.width - 16, size.height - 12), 8,
        Colors.white.withValues(alpha: 0.55));
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter old) => old.t != t;
}

/// 音高轨迹：近 6 秒的基频（MIDI）折线。
class _PitchPainter extends CustomPainter {
  _PitchPainter({
    required this.analyzer,
    required this.t,
    required this.currentMidi,
    required this.label,
  });

  final LiveAudioAnalyzer analyzer;
  final double t;
  final double? currentMidi;
  final String label;

  static const double _lo = 36; // C2
  static const double _hi = 84; // C6

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _panelBg);

    double yOf(double midi) {
      final r = ((midi - _lo) / (_hi - _lo)).clamp(0.0, 1.0);
      return size.height - r * size.height;
    }

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var m = 36; m <= 84; m += 12) {
      final y = yOf(m.toDouble());
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      _label(canvas, noteName(m), Offset(2, y - 10), 8, Colors.white.withValues(alpha: 0.3));
    }

    const n = LiveAudioAnalyzer.pitchHistoryLength;
    final path = Path();
    var started = false;
    for (var r = 0; r < n; r++) {
      final m = analyzer.pitchAt(r);
      if (m.isNaN) {
        started = false;
        continue;
      }
      final x = size.width * r / (n - 1);
      final y = yOf(m);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFE9C97A).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFF0D89A),
    );

    final cur = currentMidi;
    if (cur != null) {
      final y = yOf(cur);
      canvas.drawCircle(Offset(size.width - 4, y), 4, Paint()..color = AppColors.cinnabar);
      _label(canvas, label, Offset(size.width - 92, y - 18), 9.5,
          Colors.white.withValues(alpha: 0.88));
    }
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => old.t != t;
}

/// 谐波包络：实时 16 次谐波柱状 + 最接近音色的参考包络虚线。
class _EnvelopePainter extends CustomPainter {
  _EnvelopePainter({required this.live, required this.reference, required this.t});
  final Float32List? live;
  final List<double>? reference;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _panelBg);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    const n = LiveAudioAnalyzer.harmonicCount;
    const gap = 3.0;
    final bw = (size.width - gap * (n - 1)) / n;
    final vals = live;
    for (var k = 0; k < n; k++) {
      final v = vals == null ? 0.0 : vals[k].clamp(0.0, 1.0).toDouble();
      final x = k * (bw + gap);
      final h = math.max(1.5, v * size.height * 0.9);
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - h, bw, h),
        Paint()..color = Color.lerp(AppColors.jade, const Color(0xFFF0D89A), k / (n - 1))!,
      );
    }

    final ref = reference;
    if (ref != null) {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.75);
      Offset? prev;
      for (var k = 0; k < n; k++) {
        final x = k * (bw + gap) + bw / 2;
        final y = size.height - ref[k].clamp(0.0, 1.0) * size.height * 0.9;
        final p = Offset(x, y);
        if (prev != null) _dashed(canvas, prev, p, line);
        prev = p;
        canvas.drawCircle(p, 1.6, Paint()..color = Colors.white.withValues(alpha: 0.85));
      }
    }

    _label(canvas, live == null ? '等待音高…' : '基频 → 第 16 次谐波', const Offset(2, 2), 8.5,
        Colors.white.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(covariant _EnvelopePainter old) => old.t != t;
}
