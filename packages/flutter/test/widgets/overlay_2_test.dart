// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _LayoutFinishedMatcher extends Matcher {
  const _LayoutFinishedMatcher();

  @override
  Description describe(Description description) {
    return description.add('The render subtree is fully laid out');
  }

  @override
  bool matches(covariant RenderObject object, Map<dynamic, dynamic> matchState) {
    bool hasDirtyNode = object.debugNeedsLayout;
    void visitor(RenderObject renderObject) {
      hasDirtyNode = hasDirtyNode || renderObject.debugNeedsLayout;
      if (!hasDirtyNode)
        renderObject.visitChildren(visitor);
    }

    object.visitChildren(visitor);
    return !hasDirtyNode;
  }
}

const Matcher _hasFinishedLayout = _LayoutFinishedMatcher();

class _ManyRelayoutBoundaries extends StatelessWidget {
  const _ManyRelayoutBoundaries({
    required this.levels,
    required this.child,
  });

  final Widget child;

  final int levels;

  @override
  Widget build(BuildContext context) {
    final Widget result = levels <= 1
      ? child
      : _ManyRelayoutBoundaries(levels: levels - 1, child: child);
    return SizedBox.square(dimension: 50, child: result);
  }
}

void main() {
  testWidgets('The remote child sees the right inherited widgets', (WidgetTester tester) async {
    int buildCount = 0;
    TextDirection? directionSeenByRemoteChild;
    TextDirection textDirection = TextDirection.rtl;
    late StateSetter setState;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (BuildContext context) {
                return StatefulBuilder(
                  builder: (BuildContext context, StateSetter setter) {
                    setState = setter;
                    return Directionality(
                      textDirection: textDirection,
                      child: EvilWidget(
                        overlayInfo: OverlayInfo.of(context)!,
                        remoteChild: Builder(builder: (BuildContext context) {
                          buildCount += 1;
                          directionSeenByRemoteChild = Directionality.maybeOf(context);
                          return const SizedBox();
                        }),
                        child: const SizedBox(),
                      ),
                    );
                  }
                );
              },
            ),
          ],
        ),
      ),
    );
    expect(buildCount, 1);
    expect(directionSeenByRemoteChild, textDirection);

    setState(() {
      textDirection = TextDirection.ltr;
    });
    await tester.pump();
    expect(buildCount, 2);
    expect(directionSeenByRemoteChild, textDirection);
  });

  testWidgets('Remote child can use Positioned', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (BuildContext context) {
                return StatefulBuilder(
                  builder: (BuildContext context, StateSetter setter) {
                    return EvilWidget(
                      overlayInfo: OverlayInfo.of(context)!,
                      remoteChild: const Positioned(
                        width: 30,
                        height: 30,
                        child: Placeholder(),
                      ),
                      child: const SizedBox(),
                    );
                  }
                );
              },
            ),
          ],
        ),
      ),
    );

    expect(tester.getTopLeft(find.byType(Placeholder)), Offset.zero) ;
    expect(tester.getSize(find.byType(Placeholder)), const Size(30, 30)) ;
  });

  testWidgets('child is laid out before remote child', (WidgetTester tester) async {
    final GlobalKey overlayChildKey = GlobalKey(debugLabel: 'overlay child 1');
    final RenderBox childBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
    final RenderBox remoteChildBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
    int layoutCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (BuildContext context) {
                return Container(
                  key: overlayChildKey,
                  child: _ManyRelayoutBoundaries(levels: 50, child: Builder(builder: (BuildContext context) {
                    return EvilWidget(
                      overlayInfo: OverlayInfo.of(context)!,
                      remoteChild: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                        final RenderObject renderChild1 = overlayChildKey.currentContext!.findRenderObject()!;
                        expect(renderChild1, _hasFinishedLayout);
                        layoutCount += 1;
                        return WidgetToRenderBoxAdapter(renderBox: remoteChildBox);
                      }),
                      child: WidgetToRenderBoxAdapter(renderBox: childBox),
                    );
                  })),
                );
              }
            ),
          ],
        ),
      ),
    );
    expect(layoutCount, 1);

    childBox.markNeedsLayout();
    final RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox> renderLayoutBuilder = remoteChildBox.parent! as RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox>;
    renderLayoutBuilder.markNeedsBuild();
    final RenderObject renderChild1 = overlayChildKey.currentContext!.findRenderObject()!;
    expect(renderChild1, isNot(_hasFinishedLayout));
    // Make sure childBox's depth is greater than that of the remote
    // child, and childBox's parent isn't dirty (childBox is a dirty relayout
    // boundary).
    assert(childBox.depth > remoteChildBox.depth);
    assert(childBox.debugNeedsLayout);
    assert(!childBox.parent!.debugNeedsLayout);

    await tester.pump();
    expect(layoutCount, 2);
  });

  group('GlobalKey Reparenting', () {
    testWidgets('child is laid out before remote child after reparenting 1', (WidgetTester tester) async {
      int layoutCount = 0;

      final GlobalKey overlayChildKey1 = GlobalKey(debugLabel: 'overlay child 1');
      final RenderBox childBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
      final RenderBox remoteChildBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
      final OverlayEntry overlayEntry1 = OverlayEntry(builder: (BuildContext context) {
        return Container(
          key: overlayChildKey1,
          child: _ManyRelayoutBoundaries(
            levels: 50,
            child: Builder(builder: (BuildContext context) {
              return EvilWidget(
                overlayInfo: OverlayInfo.of(context)!,
                remoteChild: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                  layoutCount += 1;
                  final RenderObject renderChild1 = overlayChildKey1.currentContext!.findRenderObject()!;
                  expect(renderChild1, _hasFinishedLayout);
                  return WidgetToRenderBoxAdapter(renderBox: remoteChildBox);
                }),
                child: WidgetToRenderBoxAdapter(renderBox: childBox),
              );
            }),
          ),
        );
      });
      final OverlayEntry overlayEntry2 = OverlayEntry(builder: (BuildContext context) => const Placeholder());
      final OverlayEntry overlayEntry3 = OverlayEntry(builder: (BuildContext context) => const Placeholder());

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: <OverlayEntry>[overlayEntry1, overlayEntry2, overlayEntry3],
          ),
        ),
      );
      expect(layoutCount, 1);

      childBox.markNeedsLayout();
      final RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox> renderLayoutBuilder = remoteChildBox.parent! as RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox>;
      renderLayoutBuilder.markNeedsBuild();
      final RenderObject renderChild1 = overlayChildKey1.currentContext!.findRenderObject()!;
      expect(renderChild1, isNot(_hasFinishedLayout));
      // Make sure childBox's depth is greater than that of the remote
      // child, and childBox's parent isn't dirty (childBox is a dirty relayout
      // boundary).
      assert(childBox.depth > remoteChildBox.depth);
      assert(childBox.debugNeedsLayout);
      assert(!childBox.parent!.debugNeedsLayout);

      tester.state<OverlayState>(find.byType(Overlay)).rearrange(<OverlayEntry>[overlayEntry3, overlayEntry2, overlayEntry1]);
      await tester.pump();
      expect(layoutCount, 2);
    });

    testWidgets('child is laid out before remote child after reparenting 2', (WidgetTester tester) async {
      final GlobalKey overlayChildKey1 = GlobalKey(debugLabel: 'overlay child 1');
      final GlobalKey overlayChildKey3 = GlobalKey(debugLabel: 'overlay child 3');
      final GlobalKey targetGlobalKey = GlobalKey(debugLabel: 'target widget');
      final RenderBox childBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
      final RenderBox remoteChildBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());

      late StateSetter setState1;
      late StateSetter setState2;
      bool targetMovedToOverlayEntry3 = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(builder: (BuildContext context) {
                return Container(
                  key: overlayChildKey1,
                  child: _ManyRelayoutBoundaries(
                    levels: 50,
                    child: StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                      setState1 = stateSetter;
                      return targetMovedToOverlayEntry3 ? const SizedBox() : EvilWidget(
                        key: targetGlobalKey,
                        overlayInfo: OverlayInfo.of(context)!,
                        remoteChild: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                          final RenderObject renderChild1 = overlayChildKey1.currentContext!.findRenderObject()!;
                          expect(renderChild1, _hasFinishedLayout);
                          return WidgetToRenderBoxAdapter(renderBox: remoteChildBox);
                        }),
                        child: WidgetToRenderBoxAdapter(renderBox: childBox),
                      );
                    }),
                  ),
                );
              }),
              OverlayEntry(builder: (BuildContext context) => const Placeholder()),
              OverlayEntry(builder: (BuildContext context) {
                return SizedBox(
                  key: overlayChildKey3,
                  child: StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                    setState2 = stateSetter;
                    return !targetMovedToOverlayEntry3 ? const SizedBox() : EvilWidget(
                      key: targetGlobalKey,
                      overlayInfo: OverlayInfo.of(context)!,
                      remoteChild: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                        final RenderObject renderChild3 = overlayChildKey3.currentContext!.findRenderObject()!;
                        expect(renderChild3, _hasFinishedLayout);
                        return WidgetToRenderBoxAdapter(renderBox: remoteChildBox);
                      }),
                      child: WidgetToRenderBoxAdapter(renderBox: childBox),
                    );
                  }),
                );
              }),
            ],
          ),
        ),
      );

      childBox.markNeedsLayout();
      final RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox> renderLayoutBuilder = remoteChildBox.parent! as RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox>;
      renderLayoutBuilder.markNeedsBuild();
      final RenderObject renderChild1 = overlayChildKey1.currentContext!.findRenderObject()!;
      expect(renderChild1, isNot(_hasFinishedLayout));
      // Make sure childBox's depth is greater than that of the remote
      // child, and childBox's parent isn't dirty (childBox is a dirty relayout
      // boundary).
      assert(childBox.depth > remoteChildBox.depth);
      assert(childBox.debugNeedsLayout);
      assert(!childBox.parent!.debugNeedsLayout);
      setState1(() {});
      setState2(() {});
      targetMovedToOverlayEntry3 = true;

      await tester.pump();
    });

    testWidgets('child is laid out before remote child after reparenting to a different overlay', (WidgetTester tester) async {
      final GlobalKey overlayChildKey1 = GlobalKey(debugLabel: 'overlay child 1');
      final GlobalKey overlayChildKey3 = GlobalKey(debugLabel: 'overlay child 3');
      final GlobalKey targetGlobalKey = GlobalKey(debugLabel: 'target widget');
      final RenderBox childBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
      final RenderBox remoteChildBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());

      late StateSetter setState1;
      late StateSetter setState2;
      bool targetMovedToOverlayEntry3 = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(builder: (BuildContext context) {
                return Container(
                  key: overlayChildKey1,
                  child: _ManyRelayoutBoundaries(
                    levels: 50,
                    child: StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                      setState1 = stateSetter;
                      return targetMovedToOverlayEntry3 ? const SizedBox() : EvilWidget(
                        key: targetGlobalKey,
                        overlayInfo: OverlayInfo.of(context)!,
                        remoteChild: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                          final RenderObject renderChild1 = overlayChildKey1.currentContext!.findRenderObject()!;
                          expect(renderChild1, _hasFinishedLayout);
                          return WidgetToRenderBoxAdapter(renderBox: remoteChildBox);
                        }),
                        child: WidgetToRenderBoxAdapter(renderBox: childBox),
                      );
                    }),
                  ),
                );
              }),
              OverlayEntry(builder: (BuildContext context) => const Placeholder()),
              OverlayEntry(builder: (BuildContext context) {
                return Overlay(
                  initialEntries: <OverlayEntry>[
                    OverlayEntry(builder: (BuildContext context) {
                      return SizedBox(
                        key: overlayChildKey3,
                        child: StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                          setState2 = stateSetter;
                          return !targetMovedToOverlayEntry3 ? const SizedBox() : EvilWidget(
                            key: targetGlobalKey,
                            overlayInfo: OverlayInfo.of(context)!,
                            remoteChild: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                              final RenderObject renderChild3 = overlayChildKey3.currentContext!.findRenderObject()!;
                              expect(renderChild3, _hasFinishedLayout);
                              return WidgetToRenderBoxAdapter(renderBox: remoteChildBox);
                            }),
                            child: WidgetToRenderBoxAdapter(renderBox: childBox),
                          );
                        }),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      );

      childBox.markNeedsLayout();
      final RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox> renderLayoutBuilder = remoteChildBox.parent! as RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox>;
      renderLayoutBuilder.markNeedsBuild();
      final RenderObject renderChild1 = overlayChildKey1.currentContext!.findRenderObject()!;
      expect(renderChild1, isNot(_hasFinishedLayout));
      // Make sure childBox's depth is greater than that of the remote
      // child, and childBox's parent isn't dirty (childBox is a dirty relayout
      // boundary).
      assert(childBox.depth > remoteChildBox.depth);
      assert(childBox.debugNeedsLayout);
      assert(!childBox.parent!.debugNeedsLayout);
      setState1(() {});
      setState2(() {});
      // Reparent a nested overlay.
      targetMovedToOverlayEntry3 = true;

      await tester.pump();
    });

    testWidgets(
      'child is laid out before remote child after reparenting to a different overlay and remove the remote child',
      (WidgetTester tester) async {
        final GlobalKey overlayChildKey1 = GlobalKey(debugLabel: 'overlay child 1');
        final GlobalKey overlayChildKey3 = GlobalKey(debugLabel: 'overlay child 3');
        final GlobalKey targetGlobalKey = GlobalKey(debugLabel: 'target widget');
        final RenderBox childBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
        final RenderBox remoteChildBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());

        late StateSetter setState1;
        late StateSetter setState2;
        bool targetMovedToOverlayEntry3 = false;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Overlay(
              initialEntries: <OverlayEntry>[
                OverlayEntry(builder: (BuildContext context) {
                  return Container(
                    key: overlayChildKey1,
                    child: _ManyRelayoutBoundaries(
                      levels: 50,
                      child: StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                        setState1 = stateSetter;
                        return targetMovedToOverlayEntry3 ? const SizedBox() : EvilWidget(
                          key: targetGlobalKey,
                          overlayInfo: OverlayInfo.of(context)!,
                          remoteChild: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                            final RenderObject renderChild1 = overlayChildKey1.currentContext!.findRenderObject()!;
                            expect(renderChild1, _hasFinishedLayout);
                            return WidgetToRenderBoxAdapter(renderBox: remoteChildBox);
                          }),
                          child: WidgetToRenderBoxAdapter(renderBox: childBox),
                        );
                      }),
                    ),
                  );
                }),
                OverlayEntry(builder: (BuildContext context) => const Placeholder()),
                OverlayEntry(builder: (BuildContext context) {
                  return Overlay(
                    initialEntries: <OverlayEntry>[
                      OverlayEntry(builder: (BuildContext context) {
                        return SizedBox(
                          key: overlayChildKey3,
                          child: StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                            setState2 = stateSetter;
                            return !targetMovedToOverlayEntry3 ? const SizedBox() : EvilWidget(
                              key: targetGlobalKey,
                              overlayInfo: OverlayInfo.of(context)!,
                              remoteChild: null,
                              child: WidgetToRenderBoxAdapter(renderBox: childBox),
                            );
                          }),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        );

        childBox.markNeedsLayout();
        final RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox> renderLayoutBuilder = remoteChildBox.parent! as RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox>;
        renderLayoutBuilder.markNeedsBuild();
        final RenderObject renderChild1 = overlayChildKey1.currentContext!.findRenderObject()!;
        expect(renderChild1, isNot(_hasFinishedLayout));
        // Make sure childBox's depth is greater than that of the remote
        // child, and childBox's parent isn't dirty (childBox is a dirty relayout
        // boundary).
        assert(childBox.depth > remoteChildBox.depth);
        assert(childBox.debugNeedsLayout);
        assert(!childBox.parent!.debugNeedsLayout);
        setState1(() {});
        setState2(() {});
        // Reparent a nested overlay.
        targetMovedToOverlayEntry3 = true;

        await tester.pump();
    });

    testWidgets('Swap child and remoteChild', (WidgetTester tester) async {
      final GlobalKey overlayChildKey1 = GlobalKey(debugLabel: 'overlay child 1');
      final RenderBox childBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
      final RenderBox remoteChildBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());

      late StateSetter setState;
      bool swapChildAndRemoteChild = false;

      // WidgetToRenderBoxAdapter has its own builtin GlobalKey.
      final Widget child1 = WidgetToRenderBoxAdapter(renderBox: remoteChildBox);
      final Widget child2 = WidgetToRenderBoxAdapter(renderBox: childBox);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(builder: (BuildContext context) {
                return Container(
                  key: overlayChildKey1,
                  child: _ManyRelayoutBoundaries(
                    levels: 50,
                    child: StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                      setState = stateSetter;
                      return EvilWidget(
                        overlayInfo: OverlayInfo.of(context)!,
                        remoteChild: swapChildAndRemoteChild ? child1 : child2,
                        child: swapChildAndRemoteChild ? child2 : child1,
                      );
                    }),
                  ),
                );
              }),
            ],
          ),
        ),
      );

      setState(() { swapChildAndRemoteChild = true; });
      await tester.pump();
    });

    testWidgets('forgotChild', (WidgetTester tester) async {
      final GlobalKey overlayChildKey1 = GlobalKey(debugLabel: 'overlay child 1');
      final RenderBox childBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
      final RenderBox remoteChildBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());

      late StateSetter setState1;
      late StateSetter setState2;
      bool takeChildren = false;

      // WidgetToRenderBoxAdapter has its own builtin GlobalKey.
      final Widget child1 = WidgetToRenderBoxAdapter(renderBox: remoteChildBox);
      final Widget child2 = WidgetToRenderBoxAdapter(renderBox: childBox);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(builder: (BuildContext context) {
                return StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                  setState2 = stateSetter;
                  return EvilWidget(
                    overlayInfo: OverlayInfo.of(context)!,
                    remoteChild: takeChildren ? child2 : null,
                    child: takeChildren ? child1 : null,
                  );
                });
              }),
              OverlayEntry(builder: (BuildContext context) {
                return Container(
                  key: overlayChildKey1,
                  child: _ManyRelayoutBoundaries(
                    levels: 50,
                    child: StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                      setState1 = stateSetter;
                      return EvilWidget(
                        overlayInfo: OverlayInfo.of(context)!,
                        remoteChild: takeChildren ? null : child1,
                        child: takeChildren ? null : child2,
                      );
                    }),
                  ),
                );
              }),
            ],
          ),
        ),
      );

      setState2(() { takeChildren = true; });
      setState1(() { });
      await tester.pump();
    });

    testWidgets('Nested EvilWidget: swap inner and outer', (WidgetTester tester) async {
      final GlobalKey outerKey = GlobalKey(debugLabel: 'Original Outer Widget');
      final GlobalKey innerKey = GlobalKey(debugLabel: 'Original Inner Widget');

      final RenderBox child1Box = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
      final RenderBox child2Box = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
      final RenderBox remoteChildBox = RenderConstrainedBox(additionalConstraints: const BoxConstraints());

      late StateSetter setState;
      bool swapped = false;

      // WidgetToRenderBoxAdapter has its own builtin GlobalKey.
      final Widget child1 = WidgetToRenderBoxAdapter(renderBox: child1Box);
      final Widget child2 = WidgetToRenderBoxAdapter(renderBox: child2Box);
      final Widget child3 = WidgetToRenderBoxAdapter(renderBox: remoteChildBox);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(builder: (BuildContext context) {
                return StatefulBuilder(builder: (BuildContext context, StateSetter stateSetter) {
                  setState = stateSetter;
                  return EvilWidget(
                    key: swapped ? outerKey : innerKey,
                    overlayInfo: OverlayInfo.of(context)!,
                    remoteChild: Builder(builder: (BuildContext context) {
                      return EvilWidget(
                        key: swapped ? innerKey : outerKey,
                        overlayInfo: OverlayInfo.of(context)!,
                        remoteChild: EvilWidget(
                          overlayInfo: OverlayInfo.of(context)!,
                          child: null,
                          remoteChild: child3,
                        ),
                        child: child2,
                      );
                    }),
                    child: child1,
                  );
                });
              }),
            ],
          ),
        ),
      );

      setState(() { swapped = true; });
      await tester.pump();
    });
  });
}
