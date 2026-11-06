import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guqin_doc/common/ink_scaffold.dart';
import 'package:guqin_doc/common/widgets.dart';
import 'package:guqin_doc/features/experience/mood_sound_page.dart';
import 'package:guqin_doc/features/notation/notation_svg.dart';
import 'package:guqin_doc/features/realm/realm_page.dart';

void main() {
  testWidgets('标签组件正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TagChip('散音'))),
    );

    expect(find.text('散音'), findsOneWidget);
  });

  testWidgets('页面背景统一使用用户选择的水墨图', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox.expand(child: InkBackdrop())),
    );

    final background = tester.widget<Image>(find.byType(Image));
    expect(background.image, isA<AssetImage>());
    expect(
      (background.image as AssetImage).assetName,
      sharedPageBackgroundAsset,
    );
  });

  testWidgets('统一背景按比例填充页面', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InkScaffold(
          body: SizedBox.expand(),
        ),
      ),
    );

    final background = tester.widget<Image>(find.byType(Image).first);
    expect(background.image, isA<AssetImage>());
    expect(
        (background.image as AssetImage).assetName, sharedPageBackgroundAsset);
    expect(background.fit, BoxFit.cover);
  });

  testWidgets('首页四个主页面可恢复原水墨背景', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InkScaffold(
          backgroundImageAsset: 'assets/images/qin_hero_mist.jpg',
          body: SizedBox.expand(),
        ),
      ),
    );

    final background = tester.widget<Image>(find.byType(Image).first);
    expect(
      (background.image as AssetImage).assetName,
      'assets/images/qin_hero_mist.jpg',
    );
    expect(
        find.ancestor(of: find.byType(Image), matching: find.byType(Opacity)),
        findsOneWidget);
  });

  testWidgets('窄尺寸减字符号不产生文字溢出', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NotationGlyph(
              leftHand: '中',
              hui: '十',
              rightHand: '勾',
              stringNum: '三',
              size: 72,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('琴境水墨背景支持开启和关闭动态效果', (WidgetTester tester) async {
    for (final motion in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(360, 800),
            painter: RealmPainter(
              realm: 0,
              ambient: 0.4,
              plucks: const [0.2, 1, 1, 1, 1, 1, 1],
              pluckXs: const [180, 0, 0, 0, 0, 0, 0],
              immersiveMotion: motion,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('意境生音的生成按钮固定在底部可见', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: MoodSoundPage()),
    );

    final action = find.widgetWithText(FilledButton, '生成并聆听');
    expect(action, findsOneWidget);
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });
}
