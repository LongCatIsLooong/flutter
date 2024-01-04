// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A node in a int-keyed persistent red-black tree.
///
/// A red-black tree is a self-balancing binary search tree that maintains the
/// following invariants to assist with tree rebalancing after an update:
///
///  1. A red node can only have black children.
///  2. Every path from the a node to a leaf node must have the same number of
///     black nodes.
class RBTreeNode<Value> {
  const RBTreeNode(this.key, this.value, this.isBlack, this.height, this.left, this.right);

  RBTreeNode.red(this.key, this.value, { this.left, this.right })
    : isBlack = false,
      height = left?.height ?? 0;
  RBTreeNode.black(this.key, this.value, { this.left, this.right })
    : isBlack = true,
      height = (left?.height ?? 0) + 1;

  //_Node.fromSortedList(List<(int, Value)> sortedList);

  final int key;
  final Value value;
  final bool isBlack;
  // The number of black nodes in each path of this subtree.
  final int height;

  final RBTreeNode<Value>? left;
  final RBTreeNode<Value>? right;

  // Retrives the node in the tree with the largest key that is less than or
  // equal to the given `key`.
  RBTreeNode<Value>? getNodeLessThanOrEqualTo(int key) => switch (key.compareTo(this.key)) {
    == 0 => this,
    < 0  => left?.getNodeLessThanOrEqualTo(key),
    _    => right?.getNodeLessThanOrEqualTo(key) ?? this,
  };

  // Replaces [left] with the given `leftTree`, and fix any red-black violations
  // if `this` is a black node.
  RBTreeNode<Value> _balanceLeft(RBTreeNode<Value> leftTree) => switch (leftTree) {
    _ when identical(leftTree, left) => this,
    RBTreeNode<Value>(isBlack: false, key: final int xKey, value: final xValue,
      left: final RBTreeNode<Value>? a,
      right: RBTreeNode<Value>(isBlack: false, key: final int yKey, value: final yValue,
        left: final RBTreeNode<Value>? b,
        right: final RBTreeNode<Value>? c,
      ),
    ) ||
    RBTreeNode<Value>(isBlack: false, key: final int yKey, value: final yValue,
      left: RBTreeNode<Value>(isBlack: false, key: final int xKey, value: final xValue,
        left: final RBTreeNode<Value>? a,
        right: final RBTreeNode<Value>? b,
      ),
      right: final RBTreeNode<Value>? c,
    ) => RBTreeNode<Value>.red(yKey, yValue,
        left: RBTreeNode<Value>.black(xKey, xValue, left: a, right: b),
        right: RBTreeNode<Value>.black(key, value, left: c, right: right),
      ),
    _ => RBTreeNode<Value>(key, value, isBlack, height, leftTree, right),
  };

  // Replaces [right] with the given `rightTree`, and fix any red-black
  // violations.
  //
  // See _balanceLeft for details.
  RBTreeNode<Value> _balanceRight(RBTreeNode<Value> rightTree) => switch (rightTree) {
    _ when identical(rightTree, right) => this,
    RBTreeNode<Value>(isBlack: false, key: final int yKey, value: final yValue,
      left: final RBTreeNode<Value>? b,
      right: RBTreeNode<Value>(isBlack: false, key: final int zKey, value: final zValue,
        left: final RBTreeNode<Value>? c,
        right: final RBTreeNode<Value>? d
      )
    ) ||
    RBTreeNode<Value>(isBlack: false, key: final int zKey, value: final zValue,
      left: RBTreeNode<Value>(isBlack: false, key: final int yKey, value: final yValue,
        left: final RBTreeNode<Value>? b,
        right: final RBTreeNode<Value>? c
      ),
      right: final RBTreeNode<Value>? d
    ) => RBTreeNode<Value>.red(yKey, yValue,
           left: RBTreeNode<Value>.black(key, value, left: left, right: b),
           right: RBTreeNode<Value>.black(zKey, zValue, left: c, right: d),
         ),
    _ => RBTreeNode<Value>(key, value, isBlack, height, left, rightTree),
  };

  RBTreeNode<Value> _insert(int key, Value value) => switch (key.compareTo(this.key)) {
    < 0 => _balanceLeft(left?._insert(key, value) ?? RBTreeNode<Value>.red(key, value)),
    > 0 => _balanceRight(right?._insert(key, value) ?? RBTreeNode<Value>.red(key, value)),
    _   => RBTreeNode<Value>(key, value, isBlack, height, left, right),
  };

  @pragma('vm:prefer-inline')
  RBTreeNode<Value> _turnBlack() => !isBlack ? RBTreeNode<Value>.black(key, value, left: left, right: right) : this;

  @pragma('vm:prefer-inline')
  RBTreeNode<Value> insert(int key, Value value) => _insert(key, value)._turnBlack();

  RBTreeNode<Value> _joinTaller(RBTreeNode<Value>? tallerRightTree, int key, Value value) {
    if (tallerRightTree == null) {
      return insert(key, value);
    }
    assert(height <= tallerRightTree.height);
    return height == tallerRightTree.height
      ? RBTreeNode<Value>.red(key, value, left: this, right: tallerRightTree)
      : tallerRightTree._balanceLeft(_joinTaller(tallerRightTree.left, key, value));
  }

  RBTreeNode<Value> _joinShorter(RBTreeNode<Value>? shorterRightTree, int key, Value value) {
    if (shorterRightTree == null) {
      return insert(key, value);
    }
    assert(height < shorterRightTree.height);
    return height == shorterRightTree.height
      ? RBTreeNode<Value>.red(key, value, left: this, right: shorterRightTree)
      : _balanceRight(right!._joinShorter(shorterRightTree, key, value));
  }

  @pragma('vm:prefer-inline')
  RBTreeNode<Value> join(RBTreeNode<Value> rightTree, int key, Value value) => (height < rightTree.height ? _joinTaller(rightTree, key, value) : _joinShorter(rightTree, key, value))._turnBlack();

  RBTreeNode<Value>? _takeLessThan(int key) {
    if (this.key == key) {
      return left?._turnBlack();
    }
    if (key < this.key) {
      return left?._takeLessThan(key);
    }
    final RBTreeNode<Value>? newRightSubtree = right?._takeLessThan(key);
    return newRightSubtree == null
      ? _turnBlack()
      : left?.join(newRightSubtree, key, value) ?? newRightSubtree.insert(key, value);
  }

  RBTreeNode<Value>? _skipUntil(int key) {
    if (this.key == key) {
      return this.right?.insert(key, value)._turnBlack() ?? RBTreeNode<Value>.black(key, value);
    }
    if (key > this.key) {
      return this.right?._skipUntil(key);
    }
    final RBTreeNode<Value>? right = this.right;
    return right == null
      ? null
      : left?._skipUntil(key)?.join(right, key, value) ?? right.insert(key, value);
  }

  // When end is null, it is treated as +∞ and is special cased to enable faster
  // processing.
  RBTreeNode<Value> insertRange(int start, int? end, int key, Value value) {
    // Split this tree into two rb trees.
    // In the first tree keys are always less than `start`.
    final RBTreeNode<Value>? leftTree = start == 0 ? null : _takeLessThan(start);
    // In the second tree keys are always greater than or equal to than `end`.
    final RBTreeNode<Value>? rightTreeWithoutEnd = end == null ? null : _skipUntil(end);

    final RBTreeNode<Value>? nodeAtEnd = end == null ? null : getNodeLessThanOrEqualTo(end);
    final RBTreeNode<Value>? rightTree = nodeAtEnd == null || nodeAtEnd.key == end
      ? rightTreeWithoutEnd
      : rightTreeWithoutEnd?.insert(end!, nodeAtEnd.value) ?? RBTreeNode<Value>.black(end!, nodeAtEnd.value);

    return leftTree != null && rightTree != null
      ? leftTree.join(rightTree, start, value)
      : (leftTree ?? rightTree)?.insert(start, value) ?? RBTreeNode<Value>.black(start, value);
  }
}
