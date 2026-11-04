import 'package:flutter_svg/flutter_svg.dart' show SvgAssetLoader, vg;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('指法动画的双手 SVG 资源可以解析', (tester) async {
    final left = await vg.loadPicture(
      const SvgAssetLoader('assets/images/hand_left_press.svg'),
      null,
    );
    addTearDown(left.picture.dispose);

    final right = await vg.loadPicture(
      const SvgAssetLoader('assets/images/hand_right_pluck.svg'),
      null,
    );
    addTearDown(right.picture.dispose);

    expect(left.size.width, greaterThan(0));
    expect(left.size.height, greaterThan(0));
    expect(right.size.width, greaterThan(0));
    expect(right.size.height, greaterThan(0));
  });
}
