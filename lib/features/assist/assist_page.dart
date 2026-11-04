import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../../common/guqin_sound.dart';
import '../../common/ink_scaffold.dart';
import '../../common/pitch.dart';
import '../../common/widgets.dart';
import '../../data/app_database.dart';
import '../../data/practice_data.dart';
import '../../theme/app_theme.dart';
import 'practice_engine.dart';

/// 功能六：智能演奏辅助（AI 陪练）。
///
/// 用真实麦克风采集弹奏音频，在端上离线完成「音高 + 起音」分析，
/// 与真实琴谱抽取的标准谱逐音比对，识别错音、徽位（音准）偏差与节奏偏差，
/// 并提供节拍引导、速度调节、逐句跟练与演奏打分。
/// 全部分析在本机完成，音频不上传、不落盘。
class AssistPage extends StatefulWidget {
  const AssistPage({super.key});

  @override
  State<AssistPage> createState() => _AssistPageState();
}

class _AssistPageState extends State<AssistPage> {
  static const int _countInBeats = 4;

  int _phraseIndex = 0;
  double _speed = 1.0;
  bool _guide = true;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  PracticeListener? _listener;
  final Stopwatch _sw = Stopwatch();

  /// 首个数据块到达时的时间戳（毫秒），用于把「流内时刻」换算到墙钟。
  double _streamOriginMs = -1;

  /// 句首对应的墙钟时间戳（毫秒）。
  double _phraseOriginMs = 0;

  bool _listening = false;
  bool _busy = false;
  int _countIn = 0;
  String? _error;
  int _session = 0;

  final List<DetectedNote> _live = <DetectedNote>[];
  PracticeResult? _result;

  Timer? _ui;
  Timer? _autoStop;
  int _lastBeat = -1;
  double _level = 0;
  double? _liveFreq;

  final ValueNotifier<double> _nowN = ValueNotifier<double>(-1e9);
  final ValueNotifier<double> _levelN = ValueNotifier<double>(0);
  final ValueNotifier<double?> _freqN = ValueNotifier<double?>(null);
  final ValueNotifier<double?> _centsN = ValueNotifier<double?>(null);

  PracticePhrase get _phrase => PracticeData.phrases[_phraseIndex];

  double get _beatMs => 60000.0 / (_phrase.baseBpm * _speed);

  double get _phraseMs => _phrase.notes.last.timeMs / _speed;

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.bumpProgress('assist_views');
    unawaited(GuqinSound.instance.preload(const ['click.m4a']));
  }

  @override
  void dispose() {
    _ui?.cancel();
    _autoStop?.cancel();
    unawaited(_sub?.cancel());
    unawaited(_recorder.dispose());
    _nowN.dispose();
    _levelN.dispose();
    _freqN.dispose();
    _centsN.dispose();
    // 离开辅助页即停止余响，避免长尾干扰主页
    unawaited(GuqinSound.instance.stopAll());
    super.dispose();
  }

  // ---------------------------------------------------------------- 采集

  Future<void> _start() async {
    if (_busy || _listening) return;
    final session = ++_session;
    final beat = _beatMs;

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _live.clear();
      _countIn = _countInBeats;
      _level = 0;
      _liveFreq = null;
    });
    _nowN.value = -_countInBeats * beat;

    // 权限
    var ok = false;
    try {
      ok = await _recorder.hasPermission();
    } catch (_) {
      ok = false;
    }
    if (!mounted || session != _session) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _countIn = 0;
        _error = '未获得麦克风权限，无法采集比对。请在系统设置中允许「弦上知音」使用麦克风。';
      });
      return;
    }

    await GuqinSound.instance.preload(const ['click.m4a']);

    // 倒数四拍（此时尚未录音，避免节拍声被录入）
    for (var b = _countInBeats; b >= 1; b--) {
      if (!mounted || session != _session) return;
      setState(() => _countIn = b);
      HapticFeedback.selectionClick();
      if (_guide) {
        unawaited(GuqinSound.instance.play('click.m4a', volume: b == _countInBeats ? 0.85 : 0.5));
      }
      await Future<void>.delayed(Duration(milliseconds: beat.round()));
    }
    if (!mounted || session != _session) return;
    setState(() => _countIn = 0);

    // 开始采集
    final listener = PracticeListener(onNote: _onNote, onProgress: _onProgress);
    _listener = listener;
    _streamOriginMs = -1;
    _sw
      ..reset()
      ..start();
    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: PitchConfig.inputRate,
        numChannels: 1,
      ));
      _sub = stream.listen(
        (bytes) {
          if (_streamOriginMs < 0) {
            _streamOriginMs = _sw.elapsedMicroseconds / 1000.0;
          }
          listener.feed(bytes);
        },
        onError: (Object e) => debugPrint('录音流错误：$e'),
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

    _phraseOriginMs = _sw.elapsedMicroseconds / 1000.0;
    setState(() {
      _busy = false;
      _listening = true;
    });

    _ui = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    _autoStop = Timer(
      Duration(milliseconds: (_phraseMs + 1400).round()),
      () {
        if (_listening) unawaited(_stop());
      },
    );
  }

  Future<void> _stop() async {
    _session++;
    _ui?.cancel();
    _ui = null;
    _autoStop?.cancel();
    _autoStop = null;
    _listener?.flush();
    final sub = _sub;
    _sub = null;
    if (sub != null) {
      await sub.cancel();
    }
    try {
      await _recorder.stop();
    } catch (_) {
      // 忽略停止失败
    }
    _sw.stop();
    final result = evaluate(_phrase, _live, speed: _speed);
    if (!mounted) return;
    setState(() {
      _listening = false;
      _busy = false;
      _countIn = 0;
      _result = result;
    });
    HapticFeedback.mediumImpact();
  }

  void _onNote(DetectedNote note) {
    if (!mounted || _streamOriginMs < 0) return;
    // 流内时刻 → 相对句首的时刻
    final delta = _streamOriginMs - _phraseOriginMs;
    setState(() => _live.add(note.shifted(delta)));
  }

  void _onProgress(double rms, double? freq) {
    _level = rms;
    _liveFreq = freq;
  }

  void _tick() {
    final now = _sw.elapsedMicroseconds / 1000.0 - _phraseOriginMs;
    _nowN.value = now;
    _levelN.value = _level;
    _freqN.value = _liveFreq;

    final f = _liveFreq;
    if (f == null) {
      _centsN.value = null;
    } else {
      var bestD = double.infinity;
      double? ref;
      for (final t in _phrase.notes) {
        final d = (t.timeMs / _speed - now).abs();
        if (d < bestD) {
          bestD = d;
          ref = t.freq;
        }
      }
      _centsN.value = ref == null ? null : 1200 * math.log(f / ref) / math.ln2;
    }

    // 节拍引导：以视觉脉冲与轻触提示拍点（散板无恒定拍点，仅保留倒数拍声）
    if (_guide && !_phrase.rubato && now >= 0) {
      final b = (now / _beatMs).floor();
      if (b != _lastBeat) {
        _lastBeat = b;
        HapticFeedback.selectionClick();
      }
    }
  }

  void _selectPhrase(int i) {
    if (_busy || _listening) return;
    setState(() {
      _phraseIndex = i;
      _result = null;
      _live.clear();
    });
    _nowN.value = -1e9;
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final phrase = _phrase;
    return InkScaffold(
      appBar: AppBar(title: const Text('智能演奏辅助')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _phraseBar(),
          const SizedBox(height: 12),
          _phraseCard(phrase),
          const SizedBox(height: 14),
          _trackCard(phrase),
          const SizedBox(height: 14),
          _controls(),
          const SizedBox(height: 14),
          _livePanel(),
          const SizedBox(height: 14),
          _statsRow(),
          if (_result != null) ...[
            const SizedBox(height: 14),
            _resultCard(_result!),
          ],
          const SizedBox(height: 16),
          const _FooterNote(),
        ],
      ),
    );
  }

  Widget _phraseBar() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PracticeData.phrases.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == _phraseIndex;
          return GestureDetector(
            onTap: () => _selectPhrase(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.cinnabar : AppColors.paperLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? AppColors.cinnabar : AppColors.line),
              ),
              child: Text(
                PracticeData.phrases[i].title,
                style: TextStyle(fontSize: 12, color: on ? Colors.white : AppColors.inkSoft),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _phraseCard(PracticePhrase phrase) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(phrase.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(width: 8),
              TagChip(phrase.level),
              const Spacer(),
              Text('${phrase.notes.length} 音',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 6),
          Text(phrase.hint,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.6)),
          const SizedBox(height: 4),
          Text(
              phrase.rubato
                  ? '散板 · 自由节拍（无恒定拍点）· 引导速度 ${(phrase.baseBpm * _speed).round()} BPM'
                  : '原谱 ${phrase.baseBpm} BPM · 当前 ${(phrase.baseBpm * _speed).round()} BPM',
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }

  Widget _trackCard(PracticePhrase phrase) {
    return PaperCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ValueListenableBuilder<double>(
                valueListenable: _nowN,
                builder: (context, now, _) => CustomPaint(
                  painter: _TrackPainter(
                    nowMs: now,
                    speed: _speed,
                    targets: phrase.notes,
                    beatMs: _beatMs,
                    detected: _live,
                    rubato: phrase.rubato,
                    result: _result,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _listening ? Icons.graphic_eq : Icons.music_note_outlined,
                size: 14,
                color: _listening ? AppColors.cinnabar : AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _busy
                      ? '预备：第 $_countIn 拍后开始'
                      : (_listening
                          ? (phrase.rubato
                              ? '正在采集弹奏，此为散板，请依曲中呼吸自由弹奏'
                              : '正在采集弹奏，请跟着拍点逐音弹奏')
                          : (_result != null ? '本轮结束，可查看下方评测' : '点「开始练习」，倒数四拍后开始采集')),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                ),
              ),
              if (_result != null) TagChip('${_result!.score} 分', color: AppColors.cinnabar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    final locked = _busy || _listening;
    return PaperCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || _listening ? _stop : _start,
                  style: FilledButton.styleFrom(
                    backgroundColor: (_busy || _listening) ? AppColors.inkSoft : AppColors.cinnabar,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: Icon((_busy || _listening) ? Icons.stop : Icons.mic, size: 18),
                  label: Text(_busy || _listening ? '停止' : (_result != null ? '重新练习' : '开始练习')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: AppColors.paper,
                    disabledForegroundColor: AppColors.inkSoft,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.hearing, size: 18),
                  label: Text(_listening ? '采集中…' : '建议佩戴耳机'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('速度', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              Expanded(
                child: Slider(
                  value: _speed,
                  min: 0.6,
                  max: 1.2,
                  divisions: 6,
                  activeColor: AppColors.cinnabar,
                  label: '${_speed.toStringAsFixed(1)}×',
                  onChanged: locked
                      ? null
                      : (v) => setState(() {
                            _speed = v;
                            _result = null;
                            _live.clear();
                            _nowN.value = -1e9;
                          }),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('${_speed.toStringAsFixed(1)}×',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: AppColors.ink)),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.speed, size: 15, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    _phrase.rubato
                        ? '节奏引导（倒数拍声；散板不设拍点脉冲）'
                        : '节拍引导（倒数拍声 + 拍点视觉与轻触）',
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              ),
              Switch(
                value: _guide,
                activeTrackColor: AppColors.cinnabarSoft,
                onChanged: locked ? null : (v) => setState(() => _guide = v),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 15, color: AppColors.cinnabar),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.cinnabar, height: 1.5)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _livePanel() {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('实时识别',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const Spacer(),
              ValueListenableBuilder<double>(
                valueListenable: _levelN,
                builder: (context, level, _) => SizedBox(
                  width: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (level * 6).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: AppColors.line,
                      valueColor: const AlwaysStoppedAnimation(AppColors.jade),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                child: ValueListenableBuilder<double?>(
                  valueListenable: _freqN,
                  builder: (context, freq, _) => Text(
                    freq == null ? '—' : noteName((69 + 12 * (math.log(freq / 440) / math.ln2)).round()),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<double?>(
                  valueListenable: _centsN,
                  builder: (context, cents, _) => _CentsBar(cents: cents),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('音准条：指针居中为音准，偏左偏低、偏右偏高（±50 音分满量程）。',
              style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final r = _result;
    return Row(
      children: [
        _stat('准确', '${r?.count(NoteFault.good) ?? 0}', AppColors.jade),
        _stat('徽位偏差', '${r?.count(NoteFault.intonation) ?? 0}', AppColors.gold),
        _stat('错音', '${r?.count(NoteFault.wrong) ?? 0}', AppColors.cinnabar),
        _stat(_phrase.rubato ? '伸缩偏差' : '节奏偏差',
            '${r?.count(NoteFault.timing) ?? 0}', AppColors.cinnabarSoft),
        _stat('漏弹', '${r?.count(NoteFault.missed) ?? 0}', AppColors.inkSoft),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
          ],
        ),
      );

  Widget _resultCard(PracticeResult r) {
    final problems = r.problems;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('本轮评测',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const Spacer(),
              Text('命中 ${r.matchedCount}/${r.results.length}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${r.score}',
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cinnabar,
                      height: 1)),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('分', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '平均音准偏差 ${r.avgAbsCents.round()} 音分 · '
                  '${_phrase.rubato ? '平均句内伸缩偏差' : '平均节奏偏差'} '
                  '${r.avgAbsTimingMs.round()} 毫秒'
                  '${r.extras > 0 ? ' · 多弹 ${r.extras} 音' : ''}\n'
                  '起奏${r.startOffsetMs >= 0 ? '偏晚' : '偏早'} ${r.startOffsetMs.abs().round()} 毫秒'
                  '${r.trendMsPerSec.abs() > 25 ? '，整体${r.trendMsPerSec > 0 ? '越弹越慢' : '越弹越快'}' : ''}',
                  style: const TextStyle(fontSize: 12, height: 1.8, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(r.summary,
              style: const TextStyle(fontSize: 12, height: 1.7, color: AppColors.ink)),
          if (problems.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('逐音纠正',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const Spacer(),
                Text('共 ${problems.length} 处',
                    style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
            const SizedBox(height: 8),
            // 整曲动辄数百音，仅列出偏差最大的若干处，避免逐条堆叠拖慢渲染。
            for (final p in _worst(problems, 20)) _problemRow(p),
            if (problems.length > 20)
              Text('另有 ${problems.length - 20} 处偏差未列出，建议放慢速度重练相关段落。',
                  style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.6)),
          ],
        ],
      ),
    );
  }

  /// 取偏差最重的若干处（错音 > 徽位 > 节奏 > 漏弹），并按谱面顺序返回。
  static List<NoteResult> _worst(List<NoteResult> problems, int n) {
    if (problems.length <= n) return problems;
    int rank(NoteFault f) => switch (f) {
          NoteFault.wrong => 0,
          NoteFault.intonation => 1,
          NoteFault.timing => 2,
          NoteFault.missed => 3,
          NoteFault.good => 4,
        };
    final sorted = List<NoteResult>.of(problems)
      ..sort((a, b) {
        final c = rank(a.fault).compareTo(rank(b.fault));
        return c != 0 ? c : a.index.compareTo(b.index);
      });
    return sorted.take(n).toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  Widget _problemRow(NoteResult p) {
    final color = switch (p.fault) {
      NoteFault.wrong => AppColors.cinnabar,
      NoteFault.intonation => AppColors.gold,
      NoteFault.timing => AppColors.cinnabarSoft,
      NoteFault.missed => AppColors.inkSoft,
      NoteFault.good => AppColors.jade,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text('${p.index + 1}',
                style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TagChip(p.fault.label, color: color),
                    const SizedBox(width: 6),
                    Text('标准 ${noteName(p.target.midi)} · ${positionLabel(p.target.midi)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(p.advice,
                    style: const TextStyle(fontSize: 11.5, height: 1.65, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 音准条：指针偏离中线表示音分偏差。
class _CentsBar extends StatelessWidget {
  final double? cents;
  const _CentsBar({this.cents});

  @override
  Widget build(BuildContext context) {
    final c = cents;
    final clamped = c == null ? 0.0 : c.clamp(-50.0, 50.0);
    final color = c == null
        ? AppColors.line
        : (c.abs() <= 10
            ? AppColors.jade
            : (c.abs() <= 30 ? AppColors.gold : AppColors.cinnabar));
    return SizedBox(
      height: 30,
      child: CustomPaint(
        painter: _CentsPainter(clamped, color, c != null),
        size: Size.infinite,
      ),
    );
  }
}

class _CentsPainter extends CustomPainter {
  final double cents;
  final Color color;
  final bool active;
  _CentsPainter(this.cents, this.color, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final line = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = -2; i <= 2; i++) {
      final x = size.width * (0.5 + i * 0.2);
      canvas.drawLine(Offset(x, cy - (i == 0 ? 7 : 4)), Offset(x, cy + (i == 0 ? 7 : 4)), line);
    }
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), line);
    for (var i = -1; i <= 1; i += 2) {
      final x = size.width * 0.5 + size.width * 0.4 * (i == 0 ? 0 : i.toDouble());
      canvas.drawLine(Offset(x, cy - 4), Offset(x, cy + 4), line..color = AppColors.line);
    }

    final x = size.width * (0.5 + (cents / 50) * 0.4);
    canvas.drawLine(
      Offset(x, 2),
      Offset(x, size.height - 2),
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(x, cy), 3.5, Paint()..color = color.withValues(alpha: active ? 1 : 0.3));
  }

  @override
  bool shouldRepaint(covariant _CentsPainter old) =>
      old.cents != cents || old.color != color || old.active != active;
}

/// 演奏轨道：标准谱音符自右向左移动，左侧为判定线。
///
/// 入调曲目以等距竖线提示拍点；散板曲目不设小节线，改以随时间缓缓起伏
/// 的横向气流与音位微光提示，呈现自由节拍的呼吸感（见 [_paintBreath]）。
class _TrackPainter extends CustomPainter {
  final double nowMs;
  final double speed;
  final List<TargetNote> targets;
  final double beatMs;
  final List<DetectedNote> detected;
  final PracticeResult? result;

  /// 是否散板（自由节拍）：为 true 时隐藏小节线。
  final bool rubato;

  static const double _hitRatio = 0.20;
  static const double _lookaheadMs = 3200.0;

  _TrackPainter({
    required this.nowMs,
    required this.speed,
    required this.targets,
    required this.beatMs,
    required this.detected,
    required this.rubato,
    this.result,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241F1A), Color(0xFF33291F)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final top = size.height * 0.10;
    final bottom = size.height * 0.90;
    final pxPerMs = size.width / _lookaheadMs;
    final hitX = size.width * _hitRatio;

    var lo = 127;
    var hi = 0;
    for (final t in targets) {
      lo = math.min(lo, t.midi);
      hi = math.max(hi, t.midi);
    }
    if (targets.isEmpty) {
      lo = 36;
      hi = 50;
    }
    lo -= 2;
    hi += 2;

    double yOf(double midi) {
      final span = (hi - lo).toDouble();
      final f = span <= 0 ? 0.5 : ((hi - midi) / span).clamp(0.0, 1.0);
      return top + f * (bottom - top);
    }

    // 七弦参考线
    final guide = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 0; i < kOpenStrings.length; i++) {
      final m = kOpenStrings[i];
      if (m < lo || m > hi) continue;
      final y = yOf(m.toDouble());
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
      final tp = TextPainter(
        text: TextSpan(
          text: kStringNames[i],
          style: TextStyle(fontSize: 8.5, color: Colors.white.withValues(alpha: 0.28)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, y - tp.height - 1));
    }

    // 节奏引导：散板以呼吸气流，入调以等距拍点竖线
    if (rubato) {
      _paintBreath(canvas, size, hitX, pxPerMs, top, bottom);
    } else if (beatMs > 4) {
      final beatPaint = Paint()..color = Colors.white.withValues(alpha: 0.07);
      final downbeatPaint = Paint()..color = const Color(0xFFE9C97A).withValues(alpha: 0.16);
      final firstBeat = ((nowMs - hitX / pxPerMs) / beatMs).floor();
      final lastBeat = ((nowMs + (size.width - hitX) / pxPerMs) / beatMs).ceil();
      for (var b = firstBeat; b <= lastBeat; b++) {
        if (b < 0) continue;
        final x = hitX + (b * beatMs - nowMs) * pxPerMs;
        if (x < -1 || x > size.width + 1) continue;
        canvas.drawLine(
          Offset(x, top - 6),
          Offset(x, bottom + 6),
          b % 4 == 0 ? downbeatPaint : beatPaint,
        );
      }
    }

    // 判定线
    canvas.drawLine(
      Offset(hitX, 0),
      Offset(hitX, size.height),
      Paint()
        ..color = const Color(0xFFE9C97A).withValues(alpha: 0.55)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(hitX, 0),
      Offset(hitX, size.height),
      Paint()
        ..color = const Color(0xFFE9C97A).withValues(alpha: 0.14)
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 标准谱音符
    final res = result;
    for (var i = 0; i < targets.length; i++) {
      final t = targets[i];
      final tx = t.timeMs / speed;
      final x = hitX + (tx - nowMs) * pxPerMs;
      if (x < -40 || x > size.width + 40) continue;
      final y = yOf(t.midi.toDouble());

      final r = res == null ? null : res.results[i];
      final color = r == null
          ? Colors.white.withValues(alpha: 0.88)
          : switch (r.fault) {
              NoteFault.good => const Color(0xFF8FBF9F),
              NoteFault.intonation => const Color(0xFFE9C97A),
              NoteFault.wrong => const Color(0xFFE0705C),
              NoteFault.timing => const Color(0xFFC9A0A0),
              NoteFault.missed => const Color(0xFF6B6055),
            };

      // 命中时把「实际起音位置」用连线标出，直观呈现节奏偏差
      final d = r?.detected;
      if (d != null) {
        final dx = hitX + (d.onsetMs - nowMs) * pxPerMs;
        canvas.drawLine(
          Offset(x, y),
          Offset(dx, y),
          Paint()
            ..color = color.withValues(alpha: 0.55)
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(Offset(dx, y), 3, Paint()..color = color);
      }

      const rad = 12.5;
      canvas.drawCircle(Offset(x, y), rad, Paint()..color = color.withValues(alpha: 0.92));
      if (r == null) {
        canvas.drawCircle(
          Offset(x, y),
          rad,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.25),
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: noteName(t.midi),
          style: const TextStyle(
            fontSize: 8.5,
            color: Color(0xFF241F1A),
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.serifFamily,
            fontFamilyFallback: AppTheme.serifFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // 实时采集到的音（青色刻线）
    if (result == null) {
      for (final d in detected) {
        final x = hitX + (d.onsetMs - nowMs) * pxPerMs;
        if (x < -20 || x > size.width + 20) continue;
        final y = yOf(d.midiFloat);
        canvas.drawLine(
          Offset(x, y - 7),
          Offset(x, y + 7),
          Paint()
            ..color = const Color(0xFF7FD6C0).withValues(alpha: 0.85)
            ..strokeWidth = 2,
        );
        canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = const Color(0xFF7FD6C0));
      }
    }

    if (result != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );
    }
  }

  /// 散板段落的呼吸感引导。
  ///
  /// 不设小节线：横向流式布局不落在固定拍格上，而以一条随时间缓缓起伏的
  /// 气流线（约五秒一息）配合各音起音处的柔光提示，让音位的疏密由乐句
  /// 自身的伸缩决定，而非被等距网格切割。
  void _paintBreath(
      Canvas canvas, Size size, double hitX, double pxPerMs, double top, double bottom) {
    final phase = (nowMs / 5000.0) * 2 * math.pi;
    final breathe = 0.5 + 0.5 * math.sin(phase); // 0~1，呼吸强度
    final midY = (top + bottom) / 2;

    // 气流线：两重正弦叠加，呈现无恒定拍点的流动感
    final flow = Path();
    for (double x = -10; x <= size.width + 10; x += 8) {
      final y = midY +
          math.sin(x / 96.0 + phase) * size.height * 0.055 +
          math.sin(x / 41.0 - phase * 0.7) * size.height * 0.016;
      if (x <= -10) {
        flow.moveTo(x, y);
      } else {
        flow.lineTo(x, y);
      }
    }
    canvas.drawPath(
      flow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.04 + 0.045 * breathe),
    );

    // 起音微光：随呼吸明灭，代替等距拍点
    final glow = Paint()..color = const Color(0xFFE9C97A).withValues(alpha: 0.05 + 0.07 * breathe);
    for (final t in targets) {
      final x = hitX + (t.timeMs / speed - nowMs) * pxPerMs;
      if (x < -20 || x > size.width + 20) continue;
      canvas.drawCircle(Offset(x, midY), 8 + 4 * breathe, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) =>
      old.nowMs != nowMs ||
      old.speed != speed ||
      old.detected.length != detected.length ||
      old.targets != targets ||
      old.rubato != rubato ||
      old.result != result;
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return const PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('关于识别与隐私',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
          SizedBox(height: 8),
          Text(
            '采集：麦克风以 44.1kHz 单声道 PCM 流式输入。\n'
            '分析：端上完成抽取降采样、YIN 基频估计与起音检测，切分出每个音的'
            '音高与时值，再与本曲真人演奏录音抽取的标准谱逐音比对。\n'
            '记谱：标准谱以（起始时刻, MIDI 音高, 时值）三元组记录，不设小节与拍号；'
            '入调曲目另附等距拍点引导，散板曲目则依录音自身的律动判定为自由节拍，'
            '隐藏小节线并放宽对句内伸缩的容忍。\n'
            '对齐：以动态时间规整（DTW）在时基带内求最优对应路径，容忍散板中'
            '合理的伸缩，并据此分离整体快慢与起奏偏差。\n'
            '判定：音分偏差 > 100 判为错音，30~100 判为徽位（音准）偏差，'
            '入调曲目起音时值偏差 > 160ms、散板曲目 > 260ms 判为节奏偏差；'
            '整体时延会先做统一对齐，单独作为「起奏偏差」报告。\n'
            '隐私：音频全程仅在本机内存中分析，不上传、不落盘。',
            style: TextStyle(fontSize: 12, height: 1.9, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
