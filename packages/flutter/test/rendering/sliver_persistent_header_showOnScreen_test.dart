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

  RenderBox innerViewportContainer;
  RenderBox outerViewportContainer;

  bool pinned = false;
  bool floating = false;

  double minimumExtent;
  double maximumExtent;

  const Key headerKey = Key('Header');
  Widget defaultBuilder(BuildContext context, double shrinkOffset, bool overlapsContent) => const SizedBox.expand(key: headerKey);

  SliverPersistentHeader pinnedPadder(double minExtent, [double maxExtent]) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TestSliverPersistentHeaderDelegate(
        minExtent,
        maxExtent ?? minExtent,
        (BuildContext context, double shrinkOffset, bool overlapsContent) => const SizedBox.expand(),
      ),
    );
  }

  Future<void> buildNestedScroller({
    WidgetTester tester,
    double innerScrollOffset = 0,
    double outerScrollOffset = 0,
  }) async {
    const Key outerKey = Key('outer');
    const Key innerKey = Key('inner');
    const Widget sliverPadder = SliverToBoxAdapter(child: SizedBox(height: 600, width: 600));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Container(
            key: outerKey,
            height: 600.0,
            width: 600.0,
            child: CustomScrollView(
              controller: outerScrollController = ScrollController(initialScrollOffset: outerScrollOffset),
              reverse: outerReversed,
              scrollDirection: outerScrollDirection,
              slivers: <Widget>[
                pinnedPadder(10, 20),
                sliverPadder,
                SliverToBoxAdapter(
                  child: Container(
                    key: innerKey,
                    height: 600.0,
                    width: 600.0,
                    child: CustomScrollView(
                      controller: innerScrollController = ScrollController(initialScrollOffset: innerScrollOffset),
                      reverse: innerReversed,
                      scrollDirection: innerScrollDirection,
                      slivers: <Widget>[
                        sliverPadder,
                        pinnedPadder(10, 20),
                        SliverPersistentHeader(
                          pinned: pinned,
                          floating: floating,
                          delegate: _TestSliverPersistentHeaderDelegate(minimumExtent, maximumExtent, defaultBuilder),
                        ),
                        sliverPadder,
                        pinnedPadder(10, 20),
                      ],
                    ),
                  ),
                ),
                sliverPadder,
                pinnedPadder(10, 20),
              ],
            ),
          ),
        ),
      ),
    );

    outerViewportContainer = tester.renderObject(find.byKey(outerKey, skipOffstage: false));
    innerViewportContainer = tester.renderObject(find.byKey(innerKey, skipOffstage: false));
  }

  EdgeInsets getInsets(WidgetTester tester, { RenderBox within, Finder of, Rect rect }) {
    of ??= find.byKey(headerKey, skipOffstage: false);

    final RenderBox targetRenderBox = tester.renderObject(of);
    final Rect targetRect = MatrixUtils.transformRect(
      targetRenderBox.getTransformTo(within),
      rect ?? Offset.zero & targetRenderBox.size,
    );
    return EdgeInsets.fromLTRB(
      targetRect.left,
      targetRect.top,
      within.size.width - targetRect.right ,
      within.size.height - targetRect.bottom,
    );
  }

  setUp(() {
    innerScrollDirection = Axis.vertical;
    outerScrollDirection = Axis.vertical;
    innerReversed = false;
    outerReversed = false;
    outerViewportContainer = null;
    innerViewportContainer = null;
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

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
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

        print(getInsets(tester, within: innerViewportContainer));
        print(getInsets(tester, within: outerViewportContainer));

        // Scroll the sliver out of the viewport.
        innerScrollController.jumpTo(800);
        await tester.pumpAndSettle();

        print('---' * 20);
        print(innerScrollController.offset);
        print(getInsets(tester, within: innerViewportContainer, rect: rectOfInterest));
        print(getInsets(tester, within: outerViewportContainer, rect: rectOfInterest));
        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should scroll the persistent header back into the viewport.
        print(getInsets(tester, within: innerViewportContainer, rect: rectOfInterest));
        print(getInsets(tester, within: outerViewportContainer, rect: rectOfInterest));
        expect(
          innerScrollController.offset,
          600 + 10,  // leading padding + pinned padding
        );
    });

    testWidgets(
      "Nested viewports persistent header showOnScreen, when the rect exceeds the renderObject's bounds",
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = const Offset(-50, -50) & const Size(300, 300);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        expect(rect.size, const Size(300, 300));
        expect(rect.bottomLeft, const Offset(-50, 600));

        // Scroll to a random offset that the rect is still entirely visible.
        innerScrollController.jumpTo(400);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should not scroll the inner viewport.
        expect(innerScrollController.offset, 400);

        // Scroll the sliver so it moves past the leading edge.
        innerScrollController.jumpTo(900);
        await tester.pumpAndSettle();

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // The inner viewport SHOULD scroll.
        final Rect newRect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        print(newRect);
        final EdgeInsets innerInsets = getInsets(tester, within: innerViewportContainer, rect: rectOfInterest);
        final EdgeInsets outerInsets = getInsets(tester, within: outerViewportContainer, rect: rectOfInterest);
        expect(innerInsets.left, -50);
        expect(outerInsets.left, -50);

        expect(innerInsets.top, 10);
        expect(outerInsets.top, 10);
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.up',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;
        innerScrollDirection = Axis.vertical;
        innerReversed = true;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(160, 160);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        //expect(rect.size, const Size(150, 150));
        expect(rect.bottomLeft, const Offset(0, 600));

        // Scroll to a random offset that the rect is still entirely visible.
        innerScrollController.jumpTo(400);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should not scroll the inner viewport.
        expect(innerScrollController.offset, 400);

        // Scroll the sliver out of the viewport.
        innerScrollController.jumpTo(800);
        await tester.pumpAndSettle();

        print(MatrixUtils.transformRect(
            renderObjectOfInterest.getTransformTo(outerViewportContainer),
            rectOfInterest,
        ));
        print(innerScrollController.offset);
        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        print(MatrixUtils.transformRect(
            renderObjectOfInterest.getTransformTo(outerViewportContainer),
            rectOfInterest,
        ));

        final EdgeInsets innerInsets = getInsets(tester, within: innerViewportContainer, rect: rectOfInterest);
        final EdgeInsets outerInsets = getInsets(tester, within: outerViewportContainer, rect: rectOfInterest);

        print(innerInsets);
        print(outerInsets);
        // Should scroll the persistent header back into the viewport.
        expect(innerScrollController.offset, 600);
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.right',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        innerScrollDirection = Axis.horizontal;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        print(getInsets(tester, within: innerViewportContainer, rect: rectOfInterest));
        print(getInsets(tester, within: outerViewportContainer, rect: rectOfInterest));
        // Should move to the bottom right of the screen.
        print(MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(innerViewportContainer),
          rectOfInterest,
        ));
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

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);
        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final EdgeInsets insets = getInsets(tester, within: outerViewportContainer, rect: rectOfInterest);
        MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        print(getInsets(tester, within: innerViewportContainer, rect: rectOfInterest));
        expect(getInsets(tester, within: innerViewportContainer, rect: rectOfInterest).isNonNegative, isTrue);
        // Should move to bottom of the screen.
        expect(insets.isNonNegative, isTrue);
        expect(insets.bottom, 0);

        // Scroll to a random offset that the rect is still entirely visible.
        innerScrollController.jumpTo(400);
        await tester.pumpAndSettle();

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();
        // Should not scroll the inner viewport.
        expect(innerScrollController.offset, 400);

        // Scroll the sliver so it pins to the leading edge.
        innerScrollController.jumpTo(800);
        await tester.pumpAndSettle();

        renderObjectOfInterest.showOnScreen(rect: Offset.zero & const Size(100, 100));
        await tester.pumpAndSettle();

        print(getInsets(tester, within: innerViewportContainer, rect: rectOfInterest));
        print(getInsets(tester, within: outerViewportContainer, rect: rectOfInterest));
        // The inner viewport should not scroll.
        expect(innerScrollController.offset, 800);
    });

    testWidgets(
      "Nested viewports persistent header showOnScreen, when the rect exceeds the renderObject's bounds",
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = const Offset(-50, -50) & const Size(300, 300);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        expect(rect.bottomLeft, const Offset(-50, 600));

        // Scroll to a random offset that the rect is still entirely visible,
        // but not pinned to either edge.
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
        final EdgeInsets innerInsets = getInsets(tester, within: innerViewportContainer, rect: rectOfInterest);
        final EdgeInsets outerInsets = getInsets(tester, within: innerViewportContainer, rect: rectOfInterest);

        print(innerInsets);
        print(outerInsets);
        expect(innerInsets.top, greaterThanOrEqualTo(-50));
        expect(innerInsets.bottom, greaterThanOrEqualTo(0));
        expect(outerInsets.top, greaterThanOrEqualTo(-50));
        expect(outerInsets.bottom, greaterThanOrEqualTo(0));
        expect((renderObjectOfInterest as RenderBox).size, const Size(600, 200));
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.up',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;
        innerScrollDirection = Axis.vertical;
        innerReversed = true;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        expect(rect.size, const Size(150, 150));
        expect(rect.bottomLeft, const Offset(0, 600));
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.right',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        innerScrollDirection = Axis.horizontal;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final EdgeInsets innerInsets = getInsets(tester, within: innerViewportContainer, rect: rectOfInterest);
        final EdgeInsets outerInsets = getInsets(tester, within: outerViewportContainer, rect: rectOfInterest);
        // Should move to the bottom right of the screen.
        expect(innerInsets.isNonNegative, isTrue);
        expect(outerInsets.isNonNegative, isTrue);
        expect(outerInsets.bottom, 0);
    });
  });

  group('pinned = false, floating = true', () {
    setUp(() {
      pinned = false;
      floating = true;
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        print(getInsets(tester, within: innerViewportContainer, rect: rectOfInterest));
        print(getInsets(tester, within: outerViewportContainer, rect: rectOfInterest));
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
        innerScrollController.jumpTo(800);
        await tester.pumpAndSettle();

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // The inner viewport should not scroll.
        expect(innerScrollController.offset, 800);
    });

    testWidgets(
      "Nested viewports persistent header showOnScreen, when the rect exceeds the renderObject's bounds",
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = const Offset(-50, -50) & const Size(300, 300);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        // Should move to bottom of the screen.
        expect(rect.bottomLeft, const Offset(-50, 600));

        // Scroll to a random offset that the rect is still entirely visible,
        // but not pinned to either edge.
        innerScrollController.jumpTo(400);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        // Should not scroll the inner viewport.
        expect(innerScrollController.offset, 400);

        // Scroll the sliver so it's obstructed by the leading edge.
        innerScrollController.jumpTo(900);
        await tester.pumpAndSettle();

        print('>>>>>>>' * 10);
        // The inner viewport SHOULD scroll.
        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);
        await tester.pumpAndSettle();

        final EdgeInsets innerInsets = getInsets(tester,
          within: innerViewportContainer,
          rect: rectOfInterest,
        );
        final EdgeInsets outerInsets = getInsets(tester,
          within: outerViewportContainer,
          rect: rectOfInterest,
        );

        expect(innerInsets.top, greaterThanOrEqualTo(-50));
        expect(innerInsets.bottom, greaterThanOrEqualTo(0));

        expect((renderObjectOfInterest as RenderBox).size, const Size(600, 200));
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.up',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;
        innerScrollDirection = Axis.vertical;
        innerReversed = true;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        print(getInsets(tester, within: innerViewportContainer, rect: rectOfInterest));
        print(getInsets(tester, within: outerViewportContainer, rect: rectOfInterest));
        // Should move to bottom of the screen.
        expect(rect.size, const Size(150, 150));
        expect(rect.bottomLeft, const Offset(0, 600));
    });

    testWidgets(
      'Nested viewports persistent header showOnScreen, inner scrollDirection = AxisDirection.right',
      (WidgetTester tester) async {
        minimumExtent = 100;
        maximumExtent = 200;

        innerScrollDirection = Axis.horizontal;

        await buildNestedScroller(tester: tester);

        final RenderObject renderObjectOfInterest = tester.renderObject(find.byKey(headerKey, skipOffstage: false));
        final Rect rectOfInterest = Offset.zero & const Size(150, 150);

        renderObjectOfInterest.showOnScreen(rect: rectOfInterest);

        await tester.pumpAndSettle();

        final Rect rect = MatrixUtils.transformRect(
          renderObjectOfInterest.getTransformTo(outerViewportContainer),
          rectOfInterest,
        );

        final EdgeInsets innerInsets = getInsets(tester, within: innerViewportContainer, rect: rectOfInterest);
        final EdgeInsets outerInsets = getInsets(tester, within: outerViewportContainer, rect: rectOfInterest);
        // Should move to the bottom right of the screen.
        expect(innerInsets.isNonNegative, isTrue);
        expect(outerInsets.isNonNegative, isTrue);
        expect(outerInsets.bottom, 0);
    });
  });
}
