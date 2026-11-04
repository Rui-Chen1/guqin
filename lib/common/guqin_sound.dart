import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 古琴单音音效（散音 / 按音 / 泛音 × 七弦）。
///
/// 触弦到出声的延迟几乎全部来自「载入音频源 + 准备播放器」，因此这里为每个
/// 音效预先建立好已完成 setSource 的播放器，播放时只做 seek(0) + resume()，
/// 把响应压到几十毫秒；每个音各自持有播放器，连续划弦时多音可自然叠加。
class GuqinSound {
  GuqinSound._();
  static final GuqinSound instance = GuqinSound._();

  static const _prefix = 'audio/sfx/';
  static const _kinds = ['open', 'press', 'harm'];

  /// 音效文件名，例如 file('open', 3) → open_3.m4a（0 起为一弦）。
  static String file(String kind, int stringIndex) => '${kind}_$stringIndex.m4a';

  /// 三种基本音色 × 七弦（供琴音可视化预热）。
  static List<String> get all => [
        for (final k in _kinds)
          for (var i = 0; i < 7; i++) file(k, i),
      ];

  /// 某一种音色的七根弦。
  static List<String> stringSet(String kind) => [
        for (var i = 0; i < 7; i++) file(kind, i),
      ];

  final Map<String, AudioPlayer> _players = {};
  final Map<String, double> _volumes = {};
  bool _contextReady = false;

  /// 初始化音频会话：显式走扬声器、忽略 iOS 静音键。
  Future<void> ensureContext() async {
    if (_contextReady) return;
    _contextReady = true;
    try {
      await AudioPlayer.global.setAudioContext(AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
        focus: AudioContextConfigFocus.mixWithOthers,
        respectSilence: false,
        stayAwake: false,
      ).build());
    } catch (e) {
      debugPrint('GuqinSound context error: $e');
    }
  }

  /// 预热音效（幂等）：页面 initState 时调用，之后触发即为瞬时发声。
  Future<void> preload(Iterable<String> files) async {
    await ensureContext();
    for (final f in files) {
      if (_players.containsKey(f)) continue;
      final player = AudioPlayer();
      try {
        // stop 模式：播放结束后保留音源，便于 seek(0) 立刻重播。
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource('$_prefix$f'));
        _players[f] = player;
      } catch (e) {
        debugPrint('GuqinSound preload failed ($f): $e');
        await player.dispose();
      }
    }
  }

  /// 立即发声。已预热则为瞬时响应。
  Future<void> play(String file, {double volume = 0.9}) async {
    var player = _players[file];
    if (player == null) {
      await preload([file]);
      player = _players[file];
      if (player == null) return;
    }
    try {
      // 音量不变时省去一次平台调用，进一步压缩触弦延迟
      if (_volumes[file] != volume) {
        _volumes[file] = volume;
        await player.setVolume(volume);
      }
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      debugPrint('GuqinSound play failed ($file): $e');
    }
  }

  /// 停止全部发声（离开页面或暂停时调用）。
  Future<void> stopAll() async {
    for (final player in _players.values) {
      try {
        await player.stop();
      } catch (_) {
        // 忽略停止失败
      }
    }
  }
}
