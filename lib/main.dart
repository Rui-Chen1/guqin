import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'common/guqin_sound.dart';
import 'data/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 单机离线：首次启动初始化 SQLite 并灌入古琴资料种子数据。
  await AppDatabase.instance.init();
  // 音频会话与常用音效后台预热，避免首次触弦时才开始载入。
  unawaited(GuqinSound.instance.ensureContext());
  unawaited(GuqinSound.instance.preload(GuqinSound.stringSet('open')));
  runApp(const GuqinApp());
}
