// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/src/foundation/persistent_rb_tree.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _TestTree = RBTree<void>;

List<RBTree<Value>> toSortedList<Value>(RBTree<Value> tree, { int startingKey = 0 }) {
  final List<RBTree<Value>> list = <RBTree<Value>>[];
  tree.visitAscending((RBTree<Value> node) {
    list.add(node);
    return false;
  }, startingKey);
  return list;
}

void main() {
  group('RBTree constructors', () {
    test('red constructor checks for BST invariants', () {
      final RBTree<Object?> less = RBTree<Object?>.black(0, null);
      final RBTree<Object?> more = RBTree<Object?>.black(100, null);
      final RBTree<Object?> mid = RBTree<Object?>.black(50, null);

      expect(() => RBTree<Object?>.red(50, null, left: mid), throwsAssertionError);
      expect(() => RBTree<Object?>.red(50, null, right: mid), throwsAssertionError);
      expect(() => RBTree<Object?>.red(50, null, left: mid, right: mid), throwsAssertionError);
      expect(() => RBTree<Object?>.red(50, null, right: less), throwsAssertionError);
      expect(() => RBTree<Object?>.red(50, null, left: more, right: less), throwsAssertionError);

      expect(() => RBTree<Object?>.red(50, null, left: less, right: more), returnsNormally);
    });

    test('black constructor checks for BST invariants', () {
      final RBTree<Object?> less = RBTree<Object?>.black(0, null);
      final RBTree<Object?> more = RBTree<Object?>.black(100, null);
      final RBTree<Object?> mid = RBTree<Object?>.black(50, null);

      expect(() => RBTree<Object?>.black(50, null, left: mid), throwsAssertionError);
      expect(() => RBTree<Object?>.black(50, null, right: mid), throwsAssertionError);
      expect(() => RBTree<Object?>.black(50, null, left: mid, right: mid), throwsAssertionError);
      expect(() => RBTree<Object?>.black(50, null, right: less), throwsAssertionError);
      expect(() => RBTree<Object?>.black(50, null, left: more, right: less), throwsAssertionError);

      expect(() => RBTree<Object?>.black(50, null, left: less, right: more), returnsNormally);
    });

    test('fromSortedList expects a non-empty sorted list', () {
      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[]), throwsAssertionError);

      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[(0, null)]), returnsNormally);

      // Duplications are not allowed.
      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[(0, null), (0, null)]), throwsAssertionError);
      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[(1, null), (0, null)]), throwsAssertionError);
      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[(0, null), (1, null)]), returnsNormally);
    });

    test('fromSortedList expects a non-empty sorted list', () {
      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[]), throwsAssertionError);

      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[(0, null)]), returnsNormally);

      // Duplications are not allowed.
      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[(0, null), (0, null)]), throwsAssertionError);
      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[(1, null), (0, null)]), throwsAssertionError);
      expect(() => RBTree<Object?>.fromSortedList(const <(int, Object?)>[(0, null), (1, null)]), returnsNormally);
    });

    test('fromSortedList constructs a rb tree', () {
      for (int i = 1; i < 1025; i += 1) {
        final List<(int, int)> sortedList = List<(int, int)>.generate(i, (int index) => (index, index * index));
        final RBTree<int> tree = RBTree<int>.fromSortedList(sortedList);
        final List<(int, int)> toList = toSortedList(tree)
          .map((RBTree<int> node) => (node.key, node.value))
          .toList();
        expect(toList, sortedList);
      }
    });
  });

  group('BST operations', () {
    int getKey<Value>(RBTree<Value> tree) => tree.key;

    test('visitAscending startingKey filtering', () {
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
}
