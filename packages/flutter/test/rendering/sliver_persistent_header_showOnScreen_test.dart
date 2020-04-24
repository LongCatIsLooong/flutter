// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef _HeaderBuilder = Widget Function(BuildContext context, double shrinkOffset, bool overlapsContent);

class _TestSliverPersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TestSliverPersistentHeaderDelegate(this.minExtent, this.maxExtent, this.builder);

  final _HeaderBuilder builder;
  @override
  final double maxExtent;

  @override
  final double minExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return builder(context, shrinkOffset, overlapsContent);
  }

  @override
  bool shouldRebuild(_TestSliverPersistentHeaderDelegate oldDelegate) => true;
}


void main() {
  Axis innerScrollDirection;
  Axis outerScrollDirection;
  bool innerReversed = false;
  bool outerReversed = false;

  ScrollController innerScrollController;
  ScrollController outerScrollController;

  bool pinned = false;
  bool floating = false;

  double minimumExtent;
  double maximumExtent;

  const Key headerKey = Key('Header');
  Widget defaultBuilder(BuildContext context, double shrinkOffset, bool overlapsContent) => const SizedBox.expand(key: headerKey);

  SliverPersistentHeader pinnedPadder(double dimension) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TestSliverPersistentHeaderDelegate(
        dimension,
        dimension,
        (BuildContext context, double shrinkOffset, bool overlapsContent) => const SizedBox.expand(),
      ),
    );
  }

  Future<RenderBox> buildNestedScroller({
    WidgetTester tester,
    double innerScrollOffset = 0,
    double outerScrollOffset = 0,
  }) async {
    const Key containerKey = Key('container');
    const Widget sliverPadder = SliverPadding(padding: EdgeInsets.all(300));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Container(
            key: containerKey,
            height: 600.0,
            width: 600.0,
            child: CustomScrollView(
              controller: outerScrollController = ScrollController(initialScrollOffset: outerScrollOffset),
              reverse: outerReversed,
              scrollDirection: outerScrollDirection,
              slivers: <Widget>[
                pinnedPadder(300),
                sliverPadder,
                SliverToBoxAdapter(
                  child: Container(
                    height: 600.0,
                    width: 600.0,
                    child: CustomScrollView(
                      controller: innerScrollController = ScrollController(initialScrollOffset: innerScrollOffset),
                      reverse: innerReversed,
                      scrollDirection: innerScrollDirection,
                      slivers: <Widget>[
                        sliverPadder,
                        pinnedPadder(100),
                        SliverPersistentHeader(
                          pinned: pinned,
                          floating: floating,
                          delegate: _TestSliverPersistentHeaderDelegate(minimumExtent, maximumExtent, defaultBuilder),
                        ),
                        sliverPadder,
                        pinnedPadder(200),
                      ],
                    ),
                  ),
                ),
                sliverPadder,
                pinnedPadder(400),
              ],
            ),
          ),
        ),
      ),
    );

    return tester.renderObject(find.byKey(containerKey));
  }

  setUp(() {
    innerScrollDirection = Axis.vertical;
    outerScrollDirection = Axis.vertical;
    innerReversed = false;
    outerReversed = false;
  });

  group('pinned = false, floating = false', () {

    setUp(() {
        pinned = false;
        floating = false;
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        final RenderBox coordinateSpace = await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(coordinateSpace),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        expect(rect.size, const Size(150, 150));
        expect(rect.bottomLeft, const Offset(0, 600));

        // Scroll to a random offset that the rect is still entirely visible.
        innerScrollController.jumpTo(400);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should not scroll the inner viewport.
        expect(innerScrollController.offset, 400);

        // Scroll the sliver out of the viewport.
        innerScrollController.jumpTo(900);
        await tester.pumpAndSettle();

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should scroll the persistent header back into the viewport.
        expect(innerScrollController.offset, 600);
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.up',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;
        innerScrollDirection = Axis.vertical;
        innerReversed = true;

        final RenderBox coordinateSpace = await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(coordinateSpace),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        expect(rect.size, const Size(150, 150));
        expect(rect.bottomLeft, const Offset(0, 600));
        print(innerScrollController.offset);

        // Scroll to a random offset that the rect is still entirely visible.
        innerScrollController.jumpTo(400);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should not scroll the inner viewport.
        expect(innerScrollController.offset, 400);

        // Scroll the sliver out of the viewport.
        innerScrollController.jumpTo(800);
        await tester.pumpAndSettle();

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        print(MatrixUtils.transformPoint(
          renderObjectOfInterest.getTransformTo(coordinateSpace),
          Offset.zero,
      ));
        // Should scroll the persistent header back into the viewport.
        expect(innerScrollController.offset, 600);
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.left',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        innerScrollDirection = Axis.horizontal;

        final RenderBox coordinateSpace = await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(coordinateSpace),
          rectOfInterest,
        );

        // Should move to the bottom right of the screen.
        expect(rect.size, const Size(150, 150));
        expect(rect.bottomRight, const Offset(600, 600));

        // Scroll to a random offset that the rect is still entirely visible.
        innerScrollController.jumpTo(400);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should not scroll the inner viewport.
        expect(innerScrollController.offset, 400);

        // Scroll the sliver out of the viewport.
        innerScrollController.jumpTo(900);
        await tester.pumpAndSettle();

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should scroll the persistent header back into the viewport.
        expect(innerScrollController.offset, 600);
    });
  });

  group('pinned = true, floating = false', () {

    setUp(() {
        pinned = true;
        floating = false;
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        final RenderBox coordinateSpace = await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(coordinateSpace),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        expect(rect.size, const Size(150, 150));
        expect(rect.bottomLeft, const Offset(0, 600));

        // Scroll to a random offset that the rect is still entirely visible.
        innerScrollController.jumpTo(400);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should not scroll the inner viewport.
        expect(innerScrollController.offset, 400);

        // Scroll the sliver so it pins to the leading edge.
        innerScrollController.jumpTo(900);
        await tester.pumpAndSettle();

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // The inner viewport should not scroll.
        expect(innerScrollController.offset, 900);
    });

    testWidgets(
      "Nested viewports persistent header showOnScreen, when the rect exceeds the renderObject's bounds",
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        final RenderBox coordinateSpace = await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = const Offset(-50, -50) & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(coordinateSpace),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        expect(rect.size, const Size(150, 150));
        expect(rect.bottomLeft, const Offset(-50, 600));

        // Scroll to a random offset that the rect is still entirely visible.
        innerScrollController.jumpTo(400);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should not scroll the inner viewport.
        expect(innerScrollController.offset, 400);

        // Scroll the sliver so it pins to the leading edge.
        innerScrollController.jumpTo(900);
        await tester.pumpAndSettle();

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // The inner viewport SHOULD scroll.
        final Rect newRect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(coordinateSpace),
          rectOfInterest,
        );

        expect(newRect.bottomLeft, const Offset(-50, 400));
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.up',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;
        innerScrollDirection = Axis.vertical;
        innerReversed = true;

        final RenderBox coordinateSpace = await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(coordinateSpace),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        expect(rect.size, const Size(150, 150));
        expect(rect.bottomLeft, const Offset(0, 600));
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.left',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        innerScrollDirection = Axis.horizontal;

        final RenderBox coordinateSpace = await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(coordinateSpace),
          rectOfInterest,
        );

        // Should move to the bottom right of the screen.
        expect(rect.size, const Size(150, 150));
        expect(rect.bottomRight, const Offset(600, 600));
    });
  });
}
