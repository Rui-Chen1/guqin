import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/guqin_sound.dart';
import '../../common/ink_scaffold.dart';
import '../../common/widgets.dart';
import '../../theme/app_theme.dart';

enum _InputMode { image, poem }

class _SoundNote {
  const _SoundNote(this.kind, this.string);

  final String kind;
  final int string;

  String get asset => GuqinSound.file(kind, string);
}

/// 声景画布上的一滴琴音墨痕。
class _Ripple {
  _Ripple(this.pos, this.birth);
  final Offset pos;
  final double birth; // 秒，相对 _rippleTimer 起点
}

class _Mood {
  const _Mood({
    required this.name,
    required this.description,
    required this.ambience,
    required this.notes,
    required this.color,
  });

  final String name;
  final String description;
  final String ambience;
  final List<_SoundNote> notes;
  final Color color;
}

const _moods = [
  _Mood(
    name: '清幽',
    description: '疏朗、清冷，以清越泛音和松风衬出山水幽意。',
    ambience: 'amb_forest.m4a',
    notes: [
      _SoundNote('harm', 4),
      _SoundNote('open', 2),
      _SoundNote('harm', 5),
      _SoundNote('press', 3),
      _SoundNote('harm', 6),
      _SoundNote('open', 1),
      _SoundNote('harm', 4),
      _SoundNote('press', 2),
    ],
    color: AppColors.jade,
  ),
  _Mood(
    name: '苍茫',
    description: '低回、辽阔，以低音散音和绵长风声铺展远山。',
    ambience: 'amb_forest.m4a',
    notes: [
      _SoundNote('open', 0),
      _SoundNote('press', 1),
      _SoundNote('open', 2),
      _SoundNote('open', 0),
      _SoundNote('harm', 3),
      _SoundNote('press', 2),
      _SoundNote('open', 1),
      _SoundNote('harm', 4),
    ],
    color: Color(0xFF687C8D),
  ),
  _Mood(
    name: '明朗',
    description: '轻快、明澈，以较高音区的泛音点染天光。',
    ambience: 'amb_study.m4a',
    notes: [
      _SoundNote('harm', 6),
      _SoundNote('open', 4),
      _SoundNote('harm', 5),
      _SoundNote('open', 3),
      _SoundNote('harm', 6),
      _SoundNote('press', 4),
      _SoundNote('harm', 5),
      _SoundNote('open', 6),
    ],
    color: Color(0xFFAA8550),
  ),
  _Mood(
    name: '沉静',
    description: '平和、内敛，以中低音按音和夜虫声安放心绪。',
    ambience: 'amb_night.m4a',
    notes: [
      _SoundNote('press', 2),
      _SoundNote('open', 1),
      _SoundNote('press', 3),
      _SoundNote('harm', 4),
      _SoundNote('open', 2),
      _SoundNote('press', 1),
      _SoundNote('harm', 3),
      _SoundNote('open', 0),
    ],
    color: Color(0xFF79708A),
  ),
  _Mood(
    name: '萧瑟',
    description: '疏朗、清劲，以高音泛音像秋风扫叶，一声一停顿。',
    ambience: 'amb_forest.m4a',
    notes: [
      _SoundNote('harm', 6),
      _SoundNote('open', 3),
      _SoundNote('press', 5),
      _SoundNote('open', 2),
      _SoundNote('harm', 5),
      _SoundNote('press', 4),
      _SoundNote('open', 1),
      _SoundNote('harm', 6),
    ],
    color: Color(0xFF9C8A6A),
  ),
  _Mood(
    name: '热烈',
    description: '明快、跳动，用较高音区连拨，像春风里的落花。',
    ambience: 'amb_study.m4a',
    notes: [
      _SoundNote('open', 4),
      _SoundNote('open', 5),
      _SoundNote('harm', 6),
      _SoundNote('open', 5),
      _SoundNote('harm', 6),
      _SoundNote('open', 6),
      _SoundNote('harm', 5),
      _SoundNote('open', 4),
    ],
    color: Color(0xFFB5543C),
  ),
];

class MoodSoundPage extends StatefulWidget {
  const MoodSoundPage({super.key});

  @override
  State<MoodSoundPage> createState() => _MoodSoundPageState();
}

class _MoodSoundPageState extends State<MoodSoundPage> {
  final _picker = ImagePicker();
  final _poemController = TextEditingController();
  final _ambiencePlayer = AudioPlayer();

  _InputMode _inputMode = _InputMode.image;
  _Mood _mood = _moods.first;
  Uint8List? _imageBytes;
  String? _imageName;
  String _sourceSummary = '选择一张图片，或输入几句诗词';
  Timer? _noteTimer;
  int _noteIndex = 0;
  double _tempo = 1;
  double _qinVolume = 0.62;
  double _ambienceVolume = 0.24;
  bool _analyzing = false;
  bool _playing = false;
  bool _busy = false;
  int _playSession = 0;
  final List<_Ripple> _ripples = [];

  @override
  void dispose() {
    _playSession++;
    _noteTimer?.cancel();
    _poemController.dispose();
    unawaited(_ambiencePlayer.dispose());
    unawaited(GuqinSound.instance.stopAll());
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
        _inputMode = _InputMode.image;
        _sourceSummary = '已选图片，正在从画面色调推定意境';
        _analyzing = true;
      });
      final mood = await _moodFromImage(bytes);
      if (!mounted) return;
      setState(() {
        _mood = mood;
        _sourceSummary = '依据画面明暗与色调，建议生成「${mood.name}」琴音';
        _analyzing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      _showMessage('读取图片失败：$error');
    }
  }

  Future<_Mood> _moodFromImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 48,
      targetHeight: 48,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null || data.lengthInBytes < 4) {
          throw StateError('无法分析所选图片的像素数据');
        }
        var luminance = 0.0;
        var blueBalance = 0.0;
        var saturation = 0.0;
        var count = 0;
        for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
          final alpha = data.getUint8(i + 3) / 255;
          if (alpha < 0.1) continue;
          final red = data.getUint8(i) / 255;
          final green = data.getUint8(i + 1) / 255;
          final blue = data.getUint8(i + 2) / 255;
          luminance += (0.2126 * red + 0.7152 * green + 0.0722 * blue) * alpha;
          blueBalance += (blue - (red + green) / 2) * alpha;
          saturation += (math.max(red, math.max(green, blue)) -
                  math.min(red, math.min(green, blue))) *
              alpha;
          count++;
        }
        if (count == 0) throw StateError('图片没有可分析的有效像素');
        luminance /= count;
        blueBalance /= count;
        saturation /= count;
        if (luminance < 0.38) return _moods[3];
        if (luminance > 0.72 && saturation < 0.28) return _moods[2];
        if (blueBalance > 0.06) return _moods[0];
        if (luminance < 0.52) return _moods[1];
        return _moods[2];
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  void _analyzePoem() {
    final text = _poemController.text.trim();
    if (text.isEmpty) {
      _showMessage('请先输入或粘贴一段诗词');
      return;
    }
    final mood = _moodFromPoem(text);
    setState(() {
      _inputMode = _InputMode.poem;
      _mood = mood;
      _sourceSummary = '从诗句意象推定为「${mood.name}」：${mood.description}';
    });
  }

  void _setTempo(double value) {
    setState(() => _tempo = value);
    if (_playing) {
      _noteTimer?.cancel();
      _noteTimer = Timer.periodic(_noteInterval, (_) => _playCurrentNote());
    }
  }

  _Mood _moodFromPoem(String text) {
    const categories = <List<String>>[
      ['空山', '幽', '竹', '松', '泉', '清', '寒', '云', '深林', '孤'],
      ['大漠', '长河', '苍茫', '远山', '万里', '风急', '江阔', '天涯', '落日'],
      ['春', '花', '晴', '明月', '日出', '晓', '莺', '暖', '绿', '朝阳'],
      ['夜', '静', '愁', '霜', '秋', '别', '梦', '月落', '孤舟', '寒灯'],
      ['萧瑟', '秋风', '落叶', '雁', '霜叶', '枯藤', '西风', '残阳'],
      ['热烈', '欢', '桃', '红', '舞', '鼓', '少年', '春风得意', '桃花'],
    ];
    final scores = [
      for (final words in categories) words.where(text.contains).length,
    ];
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return _moods[best];
  }

  Future<void> _togglePlayback() async {
    if (_busy) return;
    if (_playing) {
      await _stopPlayback();
      return;
    }
    if (_inputMode == _InputMode.poem && _poemController.text.trim().isEmpty) {
      _showMessage('请先输入诗词并生成意境');
      return;
    }
    if (_inputMode == _InputMode.poem) _analyzePoem();
    if (_imageBytes == null && _inputMode == _InputMode.image) {
      _showMessage('请先选择图片，或切换到诗词输入');
      return;
    }
    setState(() => _busy = true);
    final session = ++_playSession;
    try {
      await _ambiencePlayer.setReleaseMode(ReleaseMode.loop);
      await _ambiencePlayer.setVolume(_ambienceVolume);
      await _ambiencePlayer
          .setSource(AssetSource('audio/sfx/${_mood.ambience}'));
      await GuqinSound.instance.preload(_mood.notes.map((note) => note.asset));
      if (!mounted || session != _playSession) return;
      await _ambiencePlayer.resume();
      setState(() {
        _busy = false;
        _playing = true;
        _noteIndex = 0;
        _ripples.clear();
      });
      _playCurrentNote();
      _noteTimer = Timer.periodic(_noteInterval, (_) => _playCurrentNote());
    } catch (error) {
      if (!mounted || session != _playSession) return;
      setState(() => _busy = false);
      _showMessage('声音准备失败：$error');
    }
  }

  Duration get _noteInterval => Duration(milliseconds: (2800 / _tempo).round());

  void _playCurrentNote() {
    if (!_playing) return;
    final note = _mood.notes[_noteIndex % _mood.notes.length];
    unawaited(GuqinSound.instance.play(note.asset, volume: _qinVolume));
    _spawnRipple();
    setState(() => _noteIndex++);
  }

  void _spawnRipple([Offset? pos]) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _ripples.removeWhere((r) => now - r.birth > 2.2);
    final p = pos ??
        Offset(0.15 + math.Random().nextDouble() * 0.7,
            0.2 + math.Random().nextDouble() * 0.6);
    _ripples.add(_Ripple(p, now));
  }

  /// 用户点画布：即兴加入一个本意境里的音。
  void _userTap(Offset local, Size size) {
    if (!_playing) {
      _showMessage('先点「生成并聆听」，再点画布加入你的一音');
      return;
    }
    final pool = _mood.notes;
    final note = pool[math.Random().nextInt(pool.length)];
    unawaited(GuqinSound.instance.play(note.asset, volume: _qinVolume));
    _spawnRipple(Offset(local.dx / size.width, local.dy / size.height));
    HapticFeedback.lightImpact();
  }

  Future<void> _stopPlayback() async {
    _playSession++;
    _noteTimer?.cancel();
    _noteTimer = null;
    setState(() {
      _playing = false;
      _busy = false;
      _ripples.clear();
    });
    try {
      await _ambiencePlayer.stop();
    } catch (error) {
      _showMessage('停止环境声失败：$error');
    }
    await GuqinSound.instance.stopAll();
  }

  void _selectMood(_Mood mood) {
    setState(() {
      _mood = mood;
      _sourceSummary = '已调整为「${mood.name}」：${mood.description}';
    });
    if (_playing) unawaited(_restartWithMood());
  }

  void _randomMood() {
    final pool = _moods.where((m) => m != _mood).toList();
    _selectMood(pool[math.Random().nextInt(pool.length)]);
  }

  Future<void> _restartWithMood() async {
    await _stopPlayback();
    if (mounted) await _togglePlayback();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return InkScaffold(
      appBar: AppBar(title: const Text('意境生音')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: AppColors.paper.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: AppColors.line.withValues(alpha: 0.8)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _togglePlayback,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.jade,
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_playing ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    _busy
                        ? '正在准备声音…'
                        : _playing
                            ? '停止声景'
                            : '生成并聆听',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _randomMood,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(88, 48),
                ),
                child: const Text('随机一曲'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          const PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('以景入弦',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(
                  '选一幅画，或写下几句诗。让画面色调与文字意象，化作一段可聆听的古琴声景。',
                  style: TextStyle(
                      fontSize: 12.5, height: 1.8, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SegmentedButton<_InputMode>(
            segments: const [
              ButtonSegment(
                value: _InputMode.image,
                icon: Icon(Icons.image_outlined),
                label: Text('图生音'),
              ),
              ButtonSegment(
                value: _InputMode.poem,
                icon: Icon(Icons.edit_note),
                label: Text('诗词生音'),
              ),
            ],
            selected: {_inputMode},
            onSelectionChanged: (selection) =>
                setState(() => _inputMode = selection.first),
          ),
          const SizedBox(height: 14),
          if (_inputMode == _InputMode.image) _imageInput() else _poemInput(),
          const SizedBox(height: 18),
          const SectionTitle(title: '意境调和', subtitle: '可手动调整'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mood in _moods)
                ChoiceChip(
                  label: Text(mood.name),
                  selected: mood == _mood,
                  onSelected: (_) => _selectMood(mood),
                  selectedColor: mood.color.withValues(alpha: 0.16),
                  side: BorderSide(
                    color: mood == _mood ? mood.color : AppColors.line,
                  ),
                  labelStyle: TextStyle(
                    color: mood == _mood ? mood.color : AppColors.inkSoft,
                  ),
                ),
            ],
          ),
          PaperCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: _mood.color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('「${_mood.name}」意境',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _mood.color)),
                      const SizedBox(height: 5),
                      Text(_sourceSummary,
                          style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.6,
                              color: AppColors.inkSoft)),
                      const SizedBox(height: 5),
                      Text(_mood.description,
                          style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.6,
                              color: AppColors.ink)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: '声景画布', subtitle: '播放时点画布，你也弹一音'),
          _SoundCanvas(
            ripples: _ripples,
            color: _mood.color,
            label: _mood.name,
            onTap: _userTap,
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _playing ? '点一下画布，即兴弹一个音' : '点「生成并聆听」开始声景',
              style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: '声音构成', subtitle: '本地生成 · 离线可用'),
          PaperCard(
            child: Column(
              children: [
                _volumeControl(
                  label: '琴声密度',
                  value: _tempo,
                  min: 0.65,
                  max: 1.45,
                  valueText: _tempo < 0.9
                      ? '疏'
                      : _tempo > 1.2
                          ? '密'
                          : '适中',
                  onChanged: _setTempo,
                ),
                _volumeControl(
                  label: '古琴音量',
                  value: _qinVolume,
                  min: 0,
                  max: 1,
                  valueText: '${(_qinVolume * 100).round()}%',
                  onChanged: (value) => setState(() => _qinVolume = value),
                ),
                _volumeControl(
                  label: '环境音量',
                  value: _ambienceVolume,
                  min: 0,
                  max: 0.8,
                  valueText: '${(_ambienceVolume * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _ambienceVolume = value);
                    unawaited(_ambiencePlayer.setVolume(value));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 10),
          const Text(
            '当前版本在本机根据图像色调或诗词关键词编排琴音，并配合应用内环境音；不是云端 AI 音频生成。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10.5, height: 1.6, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _imageInput() {
    return PaperCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_imageBytes case final bytes?)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.memory(
                bytes,
                height: 210,
                fit: BoxFit.contain,
                errorBuilder: (_, error, __) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _showMessage('图片预览失败：$error');
                  });
                  return const SizedBox(
                    height: 120,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  );
                },
              ),
            )
          else
            Container(
              height: 142,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.line),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.landscape_outlined,
                      size: 38, color: AppColors.gold),
                  SizedBox(height: 8),
                  Text('选择一幅山水、庭院或日常照片',
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                ],
              ),
            ),
          if (_imageName != null) ...[
            const SizedBox(height: 8),
            Text(_imageName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _analyzing ? null : _pickImage,
            icon: _analyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_analyzing
                ? '正在分析色调…'
                : _imageBytes == null
                    ? '从相册选择图片'
                    : '更换图片'),
          ),
        ],
      ),
    );
  }

  Widget _poemInput() {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _poemController,
            minLines: 4,
            maxLines: 7,
            maxLength: 180,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '例如：空山新雨后，天气晚来秋。',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _analyzePoem,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('提取诗中意境'),
          ),
        ],
      ),
    );
  }

  Widget _volumeControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required String valueText,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppColors.jade,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(valueText,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
        ),
      ],
    );
  }
}

/// 声景画布：每滴琴音像一滴墨，在画中晕开。
class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.ripples,
    required this.now,
    required this.color,
  });

  final List<_Ripple> ripples;
  final double now;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in ripples) {
      final age = now - r.birth;
      if (age < 0 || age > 2.2) continue;
      final t = age / 2.2;
      final center = Offset(r.pos.dx * size.width, r.pos.dy * size.height);
      final radius = 8 + t * 60;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: (1 - t) * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        center,
        4,
        Paint()..color = color.withValues(alpha: (1 - t) * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.ripples.length != ripples.length || old.color != color;
}

/// 声景画布：内部用 Ticker 驱动重绘，不触发外层 setState，
/// 避免鼠标事件与定时器撞车导致 mouse_tracker 断言。
class _SoundCanvas extends StatefulWidget {
  const _SoundCanvas({
    required this.ripples,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final List<_Ripple> ripples;
  final Color color;
  final String label;
  final void Function(Offset local, Size size) onTap;

  @override
  State<_SoundCanvas> createState() => _SoundCanvasState();
}

class _SoundCanvasState extends State<_SoundCanvas> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: GestureDetector(
        onTapDown: (d) => widget.onTap(
            d.localPosition, Size(MediaQuery.sizeOf(context).width - 32, 180)),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.color.withValues(alpha: 0.18),
                AppColors.paper,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _RipplePainter(
                  ripples: widget.ripples,
                  now: now,
                  color: widget.color,
                ),
              ),
              Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    color: widget.color.withValues(alpha: 0.22),
                    fontFamily: 'Kaiti SC',
                    fontFamilyFallback: const ['STKaiti', 'serif'],
                    letterSpacing: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
