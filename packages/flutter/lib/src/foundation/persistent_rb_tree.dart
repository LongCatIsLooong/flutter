// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart' show immutable;

typedef RBTreeVisitor<Value> = bool Function(RBTree<Value> node);

// Creates a RBTree from the range [startIndex, endIndex) of the given sorted
// association list. All nodes will be black except for those who has no siblings
// (thus unbalanced).
RBTree<Value> _fromSortedList<Value>(List<(int, Value)> sortedList, int startIndex, int endIndex, bool paintDeepestLeavesRed) {
  assert(startIndex >= 0);
  assert(endIndex <= sortedList.length);
  assert(startIndex + 1 <= endIndex);
  final int midIndex = (endIndex + startIndex) ~/ 2;
  final (int key, Value value) = sortedList[midIndex];

  // This is a leaf.
  if (midIndex == startIndex) {
    // The balanced tree is left-leaning: if there's no left node there's no
    // right node.
    assert(endIndex == startIndex + 1);
    return paintDeepestLeavesRed ? RBTree<Value>.red(key, value) : RBTree<Value>.black(key, value);
  }

  // Whether the left branch and the right branch have the same cardinality.
  // This is a left-leaning RB tree where the cardinality of left/right branches
  // differ by at most 1. This allows us to check whether we are in a "tall"
  // branch where the deepest leaves needs to be red nodes to keep the black
  // height balanced:
  // The left branch is in a tall branch iff `isBalanced` is false, or `paintDeepestLeavesRed` is true.
  // The right branch is in a tall branch iff `isBalanced` is true and `paintDeepestLeavesRed` is true.
  final bool isBalanced = (midIndex - startIndex == endIndex - (midIndex + 1));

  final bool hasRightChild = midIndex + 1 < endIndex;
  final RBTree<Value>? right = hasRightChild
    ? _fromSortedList(sortedList, midIndex + 1, endIndex, paintDeepestLeavesRed && isBalanced)
    : null;
  final RBTree<Value> left = _fromSortedList(sortedList, startIndex, midIndex, !isBalanced || paintDeepestLeavesRed);
  assert(left.height == (right?.height ?? 0));
  return RBTree<Value>.black(key, value, left: left, right: right);
}

/// An int-keyed persistent red-black tree, specialized for storing text
/// annotations.
///
/// A red-black tree is a self-balancing binary search tree that maintains the
/// following invariants to assist with tree rebalancing after an update:
///
///  1. A red node can only have black children (a "red violation" if this
///     invariant is not maintained).
///  2. Every path from the a node to a leaf node must have the same number of
///     black nodes (a "black violation" if this invariant is not maintained).
///
/// This particular red-black tree implementation makes a few assumptions to
/// optimize for text annotation storage:
///
///  1. No key collisions.
@immutable
class RBTree<Value> {
  /// Creates a [RBTree].
  RBTree._(this.key, this.value, this.isBlack, this.height, this.left, this.right)
   : assert(left == null || left.key < key),
     assert(right == null || key < right.key),
     assert((left?.height ?? 0) == (right?.height ?? 0)),
     assert(height == (left?.height ?? 0) + (isBlack ? 1 : 0));

  /// Creates a [RBTree] with a red root node.
  ///
  /// {@template flutter.foundation.rbtree.constructor_invariants}
  /// In debug mode, this constructor asserts if the resulting tree is not a
  /// valid BST, or there are black violations. But red violations are allowed
  /// since oprations such as insertion require temporarily introducing red
  /// violations. Consider using [debugCheckNoRedViolation] in debug mode after
  /// updating the tree.
  /// {@endtemplate}
  RBTree.red(this.key, this.value, { this.left, this.right })
   : assert(left == null || left.key < key),
     assert(right == null || key < right.key),
     assert((left?.height ?? 0) == (right?.height ?? 0)),
     isBlack = false,
     height = left?.height ?? 0;

  /// Creates a [RBTree] with a black root node.
  ///
  /// {@macro flutter.foundation.rbtree.constructor_invariants}
  RBTree.black(this.key, this.value, { this.left, this.right })
   : assert(left == null || left.key < key),
     assert(right == null || key < right.key),
     assert((left?.height ?? 0) == (right?.height ?? 0), '$left and $right do not have the same black height.'),
     isBlack = true,
     height = (left?.height ?? 0) + 1;

  /// Creates a [RBTree] from a sorted associated [List].
  factory RBTree.fromSortedList(List<(int, Value)> sortedList) {
    assert(sortedList.isNotEmpty);
    assert(() {
      for (int i = 1; i < sortedList.length; i++) {
        assert(sortedList[i - 1].$1 < sortedList[i].$1);
      }
      return true;
    }());
    final RBTree<Value> tree = _fromSortedList(sortedList, 0, sortedList.length, false);
    assert(tree.debugCheckNoRedViolation);
    return tree;
  }

  /// The int key of this node.
  final int key;

  /// The value this node carries.
  final Value value;

  /// Whether the root node of this [RBTree] is black.
  final bool isBlack;

  /// The number of black nodes in each path of this subtree.
  final int height;

  final RBTree<Value>? left;
  final RBTree<Value>? right;

  /// The node with the smallest key in this [RBTree].
  ///
  /// O(log(N)) for the initial invocation and the value is cached.
  late final RBTree<Value> _minNode = left?._minNode ?? this;

  /// The node with the largest key in this [RBTree].
  ///
  /// O(log(N)) for the initial invocation and the value is cached.
  late final RBTree<Value> _maxNode = right?._maxNode ?? this;

  /// Retrives the node in the tree with the largest key that is less than or
  /// equal to the given `key`.
  ///
  /// O(log(N)).
  RBTree<Value>? getNodeLessThanOrEqualTo(int key) => switch (key.compareTo(this.key)) {
    == 0 => this,
    <  0 => left?.getNodeLessThanOrEqualTo(key),
    _    => right?.getNodeLessThanOrEqualTo(key) ?? this,
  };

  /// Retrives the node in the tree with the smallest key that's greater than
  /// the given `key`.
  ///
  /// O(log(N)).
  RBTree<Value>? getNodeGreaterThan(int key) => switch (key.compareTo(this.key)) {
    == 0 => right?._minNode,
    <  0 => left?.getNodeGreaterThan(key) ?? this,
    _    => right?.getNodeGreaterThan(key),
  };

  // Replaces [left] with the given `leftTree`, and fix any red-black violations
  // if `this` is a black node.
  RBTree<Value> _balanceLeft(RBTree<Value> leftTree) => switch (leftTree) {
    _ when identical(leftTree, left) => this,
    RBTree<Value>(isBlack: false, key: final int xKey, value: final xValue,
      left: final RBTree<Value>? a,
      right: RBTree<Value>(isBlack: false, key: final int yKey, value: final yValue,
        left: final RBTree<Value>? b,
        right: final RBTree<Value>? c,
      ),
    ) ||
    RBTree<Value>(isBlack: false, key: final int yKey, value: final yValue,
      left: RBTree<Value>(isBlack: false, key: final int xKey, value: final xValue,
        left: final RBTree<Value>? a,
        right: final RBTree<Value>? b,
      ),
      right: final RBTree<Value>? c,
    ) => RBTree<Value>.red(yKey, yValue,
        left: RBTree<Value>.black(xKey, xValue, left: a, right: b),
        right: RBTree<Value>.black(key, value, left: c, right: right),
      ),
    _ => RBTree<Value>._(key, value, isBlack, height, leftTree, right),
  };

  // Replaces [right] with the given `rightTree`, and fix any red-black
  // violations.
  //
  // See _balanceLeft for details.
  RBTree<Value> _balanceRight(RBTree<Value> rightTree) => switch (rightTree) {
    _ when identical(rightTree, right) => this,
    RBTree<Value>(isBlack: false, key: final int yKey, value: final yValue,
      left: final RBTree<Value>? b,
      right: RBTree<Value>(isBlack: false, key: final int zKey, value: final zValue,
        left: final RBTree<Value>? c,
        right: final RBTree<Value>? d
      )
    ) ||
    RBTree<Value>(isBlack: false, key: final int zKey, value: final zValue,
      left: RBTree<Value>(isBlack: false, key: final int yKey, value: final yValue,
        left: final RBTree<Value>? b,
        right: final RBTree<Value>? c
      ),
      right: final RBTree<Value>? d
    ) => RBTree<Value>.red(yKey, yValue,
           left: RBTree<Value>.black(key, value, left: left, right: b),
           right: RBTree<Value>.black(zKey, zValue, left: c, right: d),
         ),
    _ => RBTree<Value>._(key, value, isBlack, height, left, rightTree),
  };

  RBTree<Value> _insert(int key, Value value) => switch (key.compareTo(this.key)) {
    < 0 => _balanceLeft(left?._insert(key, value) ?? RBTree<Value>.red(key, value)),
    > 0 => _balanceRight(right?._insert(key, value) ?? RBTree<Value>.red(key, value)),
    _   => RBTree<Value>._(key, value, isBlack, height, left, right),
  };

  @pragma('vm:prefer-inline')
  RBTree<Value> _turnBlack() => !isBlack ? RBTree<Value>.black(key, value, left: left, right: right) : this;

  @pragma('vm:prefer-inline')
  RBTree<Value> insert(int key, Value value) => _insert(key, value)._turnBlack();

  RBTree<Value> _joinTaller(RBTree<Value>? tallerRightTree, int key, Value value) {
    if (tallerRightTree == null) {
      return insert(key, value);
    }
    assert(height <= tallerRightTree.height);
    return height == tallerRightTree.height
      ? RBTree<Value>.red(key, value, left: this, right: tallerRightTree)
      : tallerRightTree._balanceLeft(_joinTaller(tallerRightTree.left, key, value));
  }

  RBTree<Value> _joinShorter(RBTree<Value>? shorterRightTree, int key, Value value) {
    if (shorterRightTree == null) {
      return insert(key, value);
    }
    assert(height < shorterRightTree.height);
    return height == shorterRightTree.height
      ? RBTree<Value>.red(key, value, left: this, right: shorterRightTree)
      : _balanceRight(right!._joinShorter(shorterRightTree, key, value));
  }

  @pragma('vm:prefer-inline')
  RBTree<Value> join(RBTree<Value> rightTree, int key, Value value) => (height < rightTree.height ? _joinTaller(rightTree, key, value) : _joinShorter(rightTree, key, value))._turnBlack();

  RBTree<Value>? _takeLessThan(int key) {
    if (this.key == key) {
      return left?._turnBlack();
    }
    if (key < this.key) {
      return left?._takeLessThan(key);
    }
    final RBTree<Value>? newRightSubtree = right?._takeLessThan(key);
    return newRightSubtree == null
      ? _turnBlack()
      : left?.join(newRightSubtree, key, value) ?? newRightSubtree.insert(key, value);
  }

  RBTree<Value>? _skipUntil(int key) {
    if (this.key == key) {
      return this.right?.insert(key, value)._turnBlack() ?? RBTree<Value>.black(key, value);
    }
    if (key > this.key) {
      return this.right?._skipUntil(key);
    }
    final RBTree<Value>? right = this.right;
    return right == null
      ? null
      : left?._skipUntil(key)?.join(right, key, value) ?? right.insert(key, value);
  }

  // When end is null, it is treated as +∞ and is special cased to enable faster
  // processing.
  RBTree<Value> insertRange(int start, int? end, int key, Value value) {
    // Split this tree into two rb trees.
    // In the first tree keys are always less than `start`.
    final RBTree<Value>? leftTree = start == 0 ? null : _takeLessThan(start);
    // In the second tree keys are always greater than or equal to than `end`.
    final RBTree<Value>? rightTreeWithoutEnd = end == null ? null : _skipUntil(end);

    final RBTree<Value>? nodeAtEnd = end == null ? null : getNodeLessThanOrEqualTo(end);
    final RBTree<Value>? rightTree = nodeAtEnd == null || nodeAtEnd.key == end
      ? rightTreeWithoutEnd
      : rightTreeWithoutEnd?.insert(end!, nodeAtEnd.value) ?? RBTree<Value>.black(end!, nodeAtEnd.value);

    return leftTree != null && rightTree != null
      ? leftTree.join(rightTree, start, value)
      : (leftTree ?? rightTree)?.insert(start, value) ?? RBTree<Value>.black(start, value);
  }

  // O(N)
  bool visitAscending(RBTreeVisitor<Value> visitor, [int startingKey = 0]) {
    return (startingKey < key && (left?.visitAscending(visitor, startingKey) ?? false))
        || (startingKey <= key && visitor(this))
        || (right?.visitAscending(visitor, startingKey) ?? false);
  }

  bool get debugCheckNoRedViolation {
    final RBTree<Value>? left = this.left;
    final RBTree<Value>? right = this.right;
    final bool leftValid = left == null
                        || (left.debugCheckNoRedViolation && (isBlack || left.isBlack));
    final bool rightValid = right == null
                        || (right.debugCheckNoRedViolation && (isBlack || right.isBlack));
    return leftValid && rightValid;
  }

//  // O(N)
//  void visitAllAscending(void Function(_Node) visitor) {
//    left?.visitAllAscending(visitor);
//    visitor(this);
//    right?.visitAllAscending(visitor);
//  }
//
//  late final List<_Node> ascending = _getAscending();
//  _Iterator get ascendingIterator => _Iterator(ascending);
//
//  List<_Node> _getAscending() {
//    final List<_Node> nodes = <_Node>[];
//    visitAllAscending(nodes.add);
//    return nodes;
//  }
//}
 @override
  String toString() => '${isBlack ? "black" : "red"}: $key, $height';

}
