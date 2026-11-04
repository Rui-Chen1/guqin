import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guqin_doc/common/ink_scaffold.dart';
import 'package:guqin_doc/common/widgets.dart';
import 'package:guqin_doc/features/notation/notation_svg.dart';

void main() {
  testWidgets('标签组件正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TagChip('散音'))),
    );

    expect(find.text('散音'), findsOneWidget);
  });

  testWidgets('水墨背景使用现有山水图', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox.expand(child: InkBackdrop())),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is InkBackdropPainter,
      ),
      findsOneWidget,
    );
  });

  testWidgets('指定图片背景时保持比例填充页面', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InkScaffold(
          backgroundImageAsset: 'assets/images/qin_hero_mist.jpg',
          body: SizedBox.expand(),
        ),
      ),
    );

    final background = tester.widget<Image>(find.byType(Image).first);
    expect(background.image, isA<AssetImage>());
    expect((background.image as AssetImage).assetName,
        'assets/images/qin_hero_mist.jpg');
    expect(background.fit, BoxFit.cover);
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
}
