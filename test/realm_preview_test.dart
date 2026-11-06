import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:guqin_doc/features/realm/realm_page.dart';

/// 把琴境画笔渲染成真实 PNG，供人工核对（不参与 CI 断言，只做冒烟检查）。
Future<ui.Image> _load(String path, int targetWidth) async {
  final data = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: targetWidth,
  );
  return (await codec.getNextFrame()).image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('琴境三境可渲染出画面', (tester) async {
    await tester.runAsync(() async {
      // ignore: avoid_print
      print('step1 load');
      final background = await _load(
        'assets/images/qin_hero_mist.jpg',
        1080,
      );
      final qin = await _load('assets/images/realm_guqin.png', 1024);
      // ignore: avoid_print
      print('step2 loaded');

      const size = ui.Size(390, 844);
      for (var scene = 0; scene < 3; scene++) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        RealmPainter(
          realm: scene,
          ambient: 0.37,
          plucks: scene == 0
              ? const [0.18, 1, 1, 1, 1, 1, 1]
              : const [1, 1, 1, 1, 1, 1, 1],
          pluckXs: scene == 0
              ? const [150, 0, 0, 0, 0, 0, 0]
              : const [0, 0, 0, 0, 0, 0, 0],
          immersiveMotion: true,
          background: background,
          qin: qin,
        ).paint(canvas, size);

        // ignore: avoid_print
        print('step3 painted $scene');
        final picture = recorder.endRecording();
        final image =
            await picture.toImage(size.width.toInt(), size.height.toInt());
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        // ignore: avoid_print
        print('step4 encoded $scene');
        expect(bytes, isNotNull);
        expect(bytes!.lengthInBytes, greaterThan(10000));
        File('/tmp/realm_preview_$scene.png')
            .writeAsBytesSync(bytes.buffer.asUint8List());
      }
    });
  });
}
