import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrodash/fixed_height_grid_delegate.dart';

SliverConstraints _constraints({
  double crossAxisExtent = 1006,
  AxisDirection crossAxisDirection = AxisDirection.right,
}) => SliverConstraints(
  axisDirection: AxisDirection.down,
  growthDirection: GrowthDirection.forward,
  userScrollDirection: ScrollDirection.idle,
  scrollOffset: 0,
  precedingScrollExtent: 0,
  overlap: 0,
  remainingPaintExtent: 400,
  crossAxisExtent: crossAxisExtent,
  crossAxisDirection: crossAxisDirection,
  viewportMainAxisExtent: 400,
  remainingCacheExtent: 400,
  cacheOrigin: 0,
);

SliverGridRegularTileLayout _layoutOf(
  SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight delegate, {
  double crossAxisExtent = 1006,
  AxisDirection crossAxisDirection = AxisDirection.right,
}) =>
    delegate.getLayout(
          _constraints(
            crossAxisExtent: crossAxisExtent,
            crossAxisDirection: crossAxisDirection,
          ),
        )
        as SliverGridRegularTileLayout;

void main() {
  test('splits the cross axis into equally wide columns', () {
    const delegate = SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
      crossAxisCount: 3,
      mainAxisSpacing: 7,
      crossAxisSpacing: 5,
      height: 75,
    );

    final layout = _layoutOf(delegate);

    expect(layout.crossAxisCount, 3);
    expect(layout.childMainAxisExtent, 75);
    expect(layout.mainAxisStride, 82);
    expect(layout.childCrossAxisExtent, closeTo((1006 - 10) / 3, 1e-9));
    expect(layout.crossAxisStride, closeTo((1006 - 10) / 3 + 5, 1e-9));
    expect(layout.reverseCrossAxis, isFalse);
  });

  test('defaults to a 56 pixel tall row without spacing', () {
    const delegate = SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
      crossAxisCount: 1,
    );

    final layout = _layoutOf(delegate, crossAxisExtent: 400);

    expect(layout.childMainAxisExtent, 56);
    expect(layout.mainAxisStride, 56);
    expect(layout.childCrossAxisExtent, 400);
    expect(layout.crossAxisStride, 400);
  });

  test('reverses the cross axis for a reversed axis direction', () {
    const delegate = SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
      crossAxisCount: 2,
    );

    final layout = _layoutOf(delegate, crossAxisDirection: AxisDirection.left);

    expect(layout.reverseCrossAxis, isTrue);
  });

  test('relayouts only when a layout argument changes', () {
    const delegate = SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
      crossAxisCount: 2,
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      height: 75,
    );

    expect(
      delegate.shouldRelayout(
        const SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
          crossAxisCount: 2,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          height: 75,
        ),
      ),
      isFalse,
    );
    for (final changed in [
      const SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
        crossAxisCount: 3,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        height: 75,
      ),
      const SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 5,
        height: 75,
      ),
      const SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
        crossAxisCount: 2,
        mainAxisSpacing: 5,
        crossAxisSpacing: 6,
        height: 75,
      ),
      const SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
        crossAxisCount: 2,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        height: 76,
      ),
    ]) {
      expect(delegate.shouldRelayout(changed), isTrue);
    }
  });
}
