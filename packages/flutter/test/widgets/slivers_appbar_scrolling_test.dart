// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

void verifyPaintPosition(GlobalKey key, Offset ideal) {
  final RenderObject target = key.currentContext.findRenderObject();
  expect(target.parent, isA<RenderViewport>());
  final SliverPhysicalParentData parentData = target.parentData as SliverPhysicalParentData;
  final Offset actual = parentData.paintOffset;
  expect(actual, ideal);
}

void main() {
  testWidgets('Sliver appbars - scrolling', (WidgetTester tester) async {
    GlobalKey key1, key2, key3, key4, key5;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(
          slivers: <Widget>[
            BigSliver(key: key1 = GlobalKey()),
            SliverPersistentHeader(key: key2 = GlobalKey(), delegate: TestDelegate()),
            SliverPersistentHeader(key: key3 = GlobalKey(), delegate: TestDelegate()),
            BigSliver(key: key4 = GlobalKey()),
            BigSliver(key: key5 = GlobalKey()),
          ],
        ),
      ),
    );
    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final double max = RenderBigSliver.height * 3.0 + TestDelegate().maxExtent * 2.0 - 600.0; // 600 is the height of the test viewport
    assert(max < 10000.0);
    expect(max, 1450.0);
    expect(position.pixels, 0.0);
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, max);
    position.animateTo(10000.0, curve: Curves.linear, duration: const Duration(minutes: 1));
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
    expect(position.pixels, max);
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, max);
    verifyPaintPosition(key1, const Offset(0.0, 0.0));
    verifyPaintPosition(key2, const Offset(0.0, 0.0));
    verifyPaintPosition(key3, const Offset(0.0, 0.0));
    verifyPaintPosition(key4, const Offset(0.0, 0.0));
    verifyPaintPosition(key5, const Offset(0.0, 50.0));
  });

  testWidgets('Sliver appbars - scrolling off screen', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    final TestDelegate delegate = TestDelegate();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(
          slivers: <Widget>[
            const BigSliver(),
            SliverPersistentHeader(key: key, delegate: delegate),
            const BigSliver(),
            const BigSliver(),
          ],
        ),
      ),
    );
    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.animateTo(RenderBigSliver.height + delegate.maxExtent - 5.0, curve: Curves.linear, duration: const Duration(minutes: 1));
    await tester.pumpAndSettle(const Duration(milliseconds: 1000));
    final RenderBox box = tester.renderObject<RenderBox>(find.byType(Container));
    final Rect rect = Rect.fromPoints(box.localToGlobal(Offset.zero), box.localToGlobal(box.size.bottomRight(Offset.zero)));
    expect(rect, equals(const Rect.fromLTWH(0.0, -195.0, 800.0, 200.0)));
  });

  testWidgets('Sliver appbars - scrolling - overscroll gap is below header', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPersistentHeader(delegate: TestDelegate()),
            SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                const SizedBox(
                  height: 300.0,
                  child: Text('X'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );

    expect(tester.getTopLeft(find.byType(Container)), Offset.zero);
    expect(tester.getTopLeft(find.text('X')), const Offset(0.0, 200.0));

    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.jumpTo(-50.0);
    await tester.pump();

    expect(tester.getTopLeft(find.byType(Container)), Offset.zero);
    expect(tester.getTopLeft(find.text('X')), const Offset(0.0, 250.0));
  });

  testWidgets('Sliver appbars const child delegate - scrolling - overscroll gap is below header', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPersistentHeader(delegate: TestDelegate()),
            const SliverList(
              delegate: SliverChildListDelegate.fixed(<Widget>[
                SizedBox(
                  height: 300.0,
                  child: Text('X'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );

    expect(tester.getTopLeft(find.byType(Container)), Offset.zero);
    expect(tester.getTopLeft(find.text('X')), const Offset(0.0, 200.0));

    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.jumpTo(-50.0);
    await tester.pump();

    expect(tester.getTopLeft(find.byType(Container)), Offset.zero);
    expect(tester.getTopLeft(find.text('X')), const Offset(0.0, 250.0));
  });

  testWidgets(
    'RenderSliverPersistentHeader.showOnScreen does not scroll all the way to the top, '
    'unless the visible header height is less than minExtent',
    (WidgetTester tester) async {
      final ScrollController controller = ScrollController(initialScrollOffset: 1100);
      final FocusNode focusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: controller,
              slivers: <Widget>[
                const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 300,
                  title: SizedBox(
                    height: 50,
                    child: TextField(
                      controller: TextEditingController(text: 'Title'),
                      focusNode: focusNode,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 1000)),
              ],
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(controller.offset, 1100);

      // Move the viewport down so that the SliverAppBar is partially obstructed.
      focusNode.unfocus();
      controller.jumpTo(0);
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // The TextField should be entirely visible.
      expect(controller.offset, greaterThan(350));
  });

  testWidgets(
    'RenderSliverPersistentHeader.showOnScreen works in a nested scroll view',
    (WidgetTester tester) async {
      final ScrollController outerController = ScrollController(initialScrollOffset: 0);
      final ScrollController innerController = ScrollController(initialScrollOffset: 1100);

      final FocusNode focusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: outerController,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Container(
                    height: 600,
                    // The inner viewport is as large as the screen size.
                    child: CustomScrollView(
                      controller: innerController,
                      slivers: <Widget>[
                        const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                        SliverAppBar(
                          pinned: true,
                          expandedHeight: 300,
                          title: SizedBox(
                            height: 50,
                            child: TextField(
                              controller: TextEditingController(text: 'Title'),
                              focusNode: focusNode,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 1000)),
              ],
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Initially the TextField is visible. No scrolling needed.
      expect(outerController.offset, 0);
      expect(innerController.offset, 1100);

      focusNode.unfocus();
      // Set it up so that both viewports need to be scrolled to reveal the
      // TextField.
      outerController.jumpTo(800);
      innerController.jumpTo(0);
      await tester.pumpAndSettle();

      expect(outerController.offset, 800);
      expect(innerController.offset, 0);

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // The TextField should be entirely visible, at the bottom of the inner
      // viewport and the bottom of the outer viewport.
      expect(outerController.offset, lessThan(800));
      expect(innerController.offset, greaterThan(350));
      expect(
        tester.renderObject(find.text('Title')).paintBounds.expandToInclude(Offset.zero & const Size(800, 600)),
        Offset.zero & const Size(800, 600),
      );
  });
}

class TestDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get maxExtent => 200.0;

  @override
  double get minExtent => 200.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(height: maxExtent);
  }

  @override
  bool shouldRebuild(TestDelegate oldDelegate) => false;
}


class RenderBigSliver extends RenderSliver {
  static const double height = 550.0;
  double get paintExtent => (height - constraints.scrollOffset).clamp(0.0, constraints.remainingPaintExtent) as double;

  @override
  void performLayout() {
    geometry = SliverGeometry(
      scrollExtent: height,
      paintExtent: paintExtent,
      maxPaintExtent: height,
    );
  }
}

class BigSliver extends LeafRenderObjectWidget {
  const BigSliver({ Key key }) : super(key: key);
  @override
  RenderBigSliver createRenderObject(BuildContext context) {
    return RenderBigSliver();
  }
}
