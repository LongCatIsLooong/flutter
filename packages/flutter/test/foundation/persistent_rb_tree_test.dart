// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/src/foundation/persistent_rb_tree.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _TestTree = RBTree<void>;

List<(int, Value)> toSortedList<Value>(RBTree<Value>? tree, { int startingKey = 0 }) {
  final List<(int, Value)> list = <(int, Value)>[];
  if (tree == null) {
    return list;
  }
  final Iterator<(int, Value)> iterator = tree.getRunsEndAfter(startingKey);
  while (iterator.moveNext()) {
    list.add(iterator.current);
  }
  return list;
}

void main() {
  group('RBTree constructors', () {
    test('red constructor checks for BST invariants', () {
      final _TestTree less = _TestTree.black(0, null);
      final _TestTree more = _TestTree.black(100, null);
      final _TestTree mid = _TestTree.black(50, null);

      expect(() => _TestTree.red(50, null, left: mid), throwsAssertionError);
      expect(() => _TestTree.red(50, null, right: mid), throwsAssertionError);
      expect(() => _TestTree.red(50, null, left: mid, right: mid), throwsAssertionError);
      expect(() => _TestTree.red(50, null, right: less), throwsAssertionError);
      expect(() => _TestTree.red(50, null, left: more, right: less), throwsAssertionError);

      expect(() => _TestTree.red(50, null, left: less, right: more), returnsNormally);
    });

    test('black constructor checks for BST invariants', () {
      final _TestTree less = _TestTree.red(0, null);
      final _TestTree more = _TestTree.red(100, null);
      final _TestTree mid = _TestTree.red(50, null);

      expect(() => _TestTree.black(50, null, left: mid), throwsAssertionError);
      expect(() => _TestTree.black(50, null, right: mid), throwsAssertionError);
      expect(() => _TestTree.black(50, null, left: mid, right: mid), throwsAssertionError);
      expect(() => _TestTree.black(50, null, right: less), throwsAssertionError);
      expect(() => _TestTree.black(50, null, left: more, right: less), throwsAssertionError);

      expect(() => _TestTree.black(50, null, left: less, right: more), returnsNormally);
    });

    test('red constructor checks for black violations', () {
      final _TestTree child1 = _TestTree.red(0, null);
      final _TestTree child2 = _TestTree.black(100, null);

      expect(() => _TestTree.red(50, null, left: child1), returnsNormally);
      expect(() => _TestTree.red(50, null, left: child1, right: child2), throwsAssertionError);
      expect(() => _TestTree.red(50, null, right: child2), throwsAssertionError);
    });

    test('black constructor checks for black violations', () {
      final _TestTree child1 = _TestTree.black(0, null);
      final _TestTree child2 = _TestTree.black(100, null);

      expect(() => _TestTree.black(50, null, left: child1, right: child2), returnsNormally);
      expect(() => _TestTree.black(50, null, left: child1), throwsAssertionError);
      expect(() => _TestTree.black(50, null, right: child2), throwsAssertionError);
    });

    test('fromSortedList expects a non-empty sorted list', () {
      expect(() => _TestTree.fromSortedList(const <(int, Object?)>[]), throwsAssertionError);

      expect(() => _TestTree.fromSortedList(const <(int, Object?)>[(0, null)]), returnsNormally);

      // Duplications are not allowed.
      expect(() => _TestTree.fromSortedList(const <(int, Object?)>[(0, null), (0, null)]), throwsAssertionError);
      expect(() => _TestTree.fromSortedList(const <(int, Object?)>[(1, null), (0, null)]), throwsAssertionError);
      expect(() => _TestTree.fromSortedList(const <(int, Object?)>[(0, null), (1, null)]), returnsNormally);
    });

    test('fromSortedList constructs a rb tree', () {
      for (int i = 1; i < 1025; i += 1) {
        final List<(int, int)> sortedList = List<(int, int)>.generate(i, (int index) => (index, index * index));
        final RBTree<int> tree = RBTree<int>.fromSortedList(sortedList);
        final List<(int, int)> toList = toSortedList(tree)
          .toList();
        expect(toList, sortedList);
      }
    });
  });

  group('BST operations', () {
    int getKey<Value>((int, Value) pair) => pair.$1;

    test('getRunsEndAfter', () {
      final List<int> sortedList = List<int>.generate(10, (int index) => index * index);
      final _TestTree tree = _TestTree.fromSortedList(sortedList.map((int i) => (i, i)).toList());

      expect(toSortedList(tree, startingKey: -1).map(getKey), <int>[0, 1, 4, 9, 16, 25, 36, 49, 64, 81]);
      expect(toSortedList(tree, startingKey: 0).map(getKey), <int>[0, 1, 4, 9, 16, 25, 36, 49, 64, 81]);
      expect(toSortedList(tree, startingKey: 1).map(getKey), <int>[1, 4, 9, 16, 25, 36, 49, 64, 81]);
      expect(toSortedList(tree, startingKey: 24).map(getKey), <int>[25, 36, 49, 64, 81]);
      expect(toSortedList(tree, startingKey: 100).map(getKey), <int>[]);
    });

    test('getNodeLessThanOrEqualTo', () {
      final List<int> sortedList = List<int>.generate(10, (int index) => index * index);
      final _TestTree tree = _TestTree.fromSortedList(sortedList.map((int i) => (i, i)).toList());

      expect(tree.getNodeLessThanOrEqualTo(100)?.key, 81);
      expect(tree.getNodeLessThanOrEqualTo(24)?.key, 16);
      expect(tree.getNodeLessThanOrEqualTo(1)?.key, 1);
      expect(tree.getNodeLessThanOrEqualTo(0)?.key, 0);
      expect(tree.getNodeLessThanOrEqualTo(-1)?.key, null);
    });

    test('getNodeGreaterThan', () {
      final List<int> sortedList = List<int>.generate(10, (int index) => index * index);
      final _TestTree tree = _TestTree.fromSortedList(sortedList.map((int i) => (i, i)).toList());

      expect(tree.getNodeGreaterThan(100)?.key, null);
      expect(tree.getNodeGreaterThan(24)?.key, 25);
      expect(tree.getNodeGreaterThan(1)?.key, 4);
      expect(tree.getNodeGreaterThan(0)?.key, 1);
      expect(tree.getNodeGreaterThan(-1)?.key, 0);
    });
  });

  group('RB operations', () {
    int getKey<Value>((int, Value) pair) => pair.$1;

    test('insert', () {
      _TestTree testTree = _TestTree.red(50, null);
      List<int> insertAndFlatten(Iterable<int> keys) {
        for (final int key in keys) {
          testTree = testTree.insert(key, null);
        }
        return toSortedList(testTree).map(getKey).toList();
      }

      expect(toSortedList(testTree).map(getKey), <int>[50]);

      expect(insertAndFlatten(List<int>.generate(5, (int index) => 51 + index * index)), <int>[50, 51, 52, 55, 60, 67]);
      expect(insertAndFlatten(List<int>.generate(5, (int index) => index * index)), <int>[0, 1, 4, 9, 16, 50, 51, 52, 55, 60, 67]);
      expect(insertAndFlatten(<int>[100]), <int>[0, 1, 4, 9, 16, 50, 51, 52, 55, 60, 67, 100]);
      expect(insertAndFlatten(<int>[49]), <int>[0, 1, 4, 9, 16, 49, 50, 51, 52, 55, 60, 67, 100]);
      // Duplicates
      expect(
        insertAndFlatten(<int>[0, 1, 4, 9, 16, 49, 50, 51, 52, 55, 60, 67, 100]),
        <int>[0, 1, 4, 9, 16, 49, 50, 51, 52, 55, 60, 67, 100],
      );
    });

    test('join', () {
      // Right joins a taller tree.
      _TestTree leftTree = _TestTree.fromSortedList(<(int, void)>[for (int i = 0; i < 5; i++) (i, null)]);
      _TestTree rightTree = _TestTree.fromSortedList(<(int, void)>[for (int i = 50; i < 85; i++) (i, null)]);
      expect(
        toSortedList(leftTree.join(rightTree, 10, null)).map(getKey),
        <int>[
          for (int i = 0; i < 5; i++) i,
          10,
          for (int i = 50; i < 85; i++) i,
        ],
      );

      // Right joins a shorter tree.
      leftTree = _TestTree.fromSortedList(<(int, void)>[for (int i = 0; i < 55; i++) (i, null)]);
      rightTree = _TestTree.fromSortedList(<(int, void)>[for (int i = 80; i < 88; i++) (i, null)]);
      expect(
        toSortedList(leftTree.join(rightTree, 60, null)).map(getKey),
        <int>[
          for (int i = 0; i < 55; i++) i,
          60,
          for (int i = 80; i < 88; i++) i,
        ],
      );

      // Right joins a tree of the same height.
      leftTree = _TestTree.fromSortedList(<(int, void)>[for (int i = 0; i < 18; i++) (i, null)]);
      rightTree = _TestTree.fromSortedList(<(int, void)>[for (int i = 80; i < 88; i++) (i, null)]);
      expect(
        toSortedList(leftTree.join(rightTree, 60, null)).map(getKey),
        <int>[
          for (int i = 0; i < 18; i++) i,
          60,
          for (int i = 80; i < 88; i++) i,
        ],
      );
    });

    test('join random test', () {
      const int lower = 0;
      const int upper = 50;

      for (int pivot = lower + 1; pivot < upper - 1; pivot += 1) {
        final RBTree<void> leftTree = _TestTree.fromSortedList(<(int, void)>[for (int i = lower; i < pivot; i += 1) (i, null)]);
        final RBTree<void> rightTree = _TestTree.fromSortedList(<(int, void)>[for (int i = pivot + 1; i < upper; i += 1) (i, null)]);
        final RBTree<void> joinedTree = leftTree.join(rightTree, pivot, null);
        expect(toSortedList(joinedTree).map(getKey), <int>[for (int i = lower; i < upper; i++) i]);
      }
    });

    test('skipUntil / takeLessThan', () {
      const int lower = 1;
      const int upper = 37;
      final _TestTree tree = _TestTree.fromSortedList(<(int, void)>[for (int i = lower; i < upper; i++) (i, null)]);

      for (int threshold = 0; threshold < 40; threshold += 1) {
        final int mid = threshold.clamp(lower, upper);
        expect(
          toSortedList(tree.takeLessThan(threshold)).map(getKey),
          <int>[for (int i = lower; i < mid; i += 1) i],
          reason: 'less than $threshold',
        );
        expect(
          toSortedList(tree.skipUntil(threshold)).map(getKey),
          <int>[for (int i = mid; i < upper; i += 1) i],
          reason: 'greater than or equal to $threshold',
        );
      }
    });
  });
}
