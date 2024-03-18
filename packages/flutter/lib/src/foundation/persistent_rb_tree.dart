// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart' show immutable;

/// Signature for visiting a [RBTree].
///
/// Returns false to stop traversing.
typedef RBTreeVisitor<Value> = bool Function(RBTree<Value> node);

// Creates a RBTree from the range [startIndex, endIndex) of the given sorted
// association list. All nodes will be black except for some leaves to avoid
// introducing red violations.
RBTree<Value> _fromSortedList<Value>(List<(int, Value)> sortedList, int startIndex, int endIndex, bool paintDeepestLeavesRed) {
  assert(startIndex >= 0);
  assert(endIndex <= sortedList.length);
  assert(startIndex + 1 <= endIndex);
  final int midIndex = (endIndex + startIndex) ~/ 2;
  final (int key, Value value) = sortedList[midIndex];

  // This is a leaf. The balanced tree is left-biased: if there's no left node
  // there's no right node.
  if (midIndex == startIndex) {
    assert(endIndex == startIndex + 1);
    return paintDeepestLeavesRed ? RBTree<Value>.red(key, value) : RBTree<Value>.black(key, value);
  }

  // Whether the left branch and the right branch have the same cardinality.
  // This is a left-biased RB tree where the cardinality of left/right branches
  // differ by at most 1. This allows us to check whether we are in a "tall"
  // branch where the deepest leaves needs to be red nodes to keep the tree
  // black-height balanced:
  // The left branch is in a tall branch iff `isBalanced` is false, or `paintDeepestLeavesRed` is true.
  // The right branch is in a tall branch iff `isBalanced` is true and `paintDeepestLeavesRed` is true.
  final bool isBalanced = midIndex - startIndex == endIndex - midIndex - 1;

  final bool hasRightChild = midIndex + 1 < endIndex;
  final RBTree<Value>? right = hasRightChild
    ? _fromSortedList(sortedList, midIndex + 1, endIndex, paintDeepestLeavesRed && isBalanced)
    : null;
  final RBTree<Value> left = _fromSortedList(sortedList, startIndex, midIndex, !isBalanced || paintDeepestLeavesRed);
  assert(left.blackHeight == (right?.blackHeight ?? 0));
  return RBTree<Value>.black(key, value, left: left, right: right);
}

/// The upward path from the [end] node to the root node of the binary tree.
///
/// This class is used for tree traversal.
class _TreePath<Value> {
  _TreePath(this.end, this.path, this.minKey)
    : assert(path == null || path.end.left == end || path.end.right == end),
      key = end.key;
      //key = end.key + (path?.key ?? 0);

  // Creates the path to the node with the smallest key greater than or equal to
  // `minKey` in the given tree, and concatenates that path after the given
  // `prefix` path.
  static _TreePath<T>? noLessThan<T>(RBTree<T>? root, int minKey, { _TreePath<T>? prefix }) {
    if (root == null) {
      return prefix;
    }
    return switch (root.key.compareTo(minKey)) {
      -1 => _TreePath.noLessThan(root.right, minKey, prefix: prefix),
      0  => _TreePath.noLessThan(root.right, minKey, prefix: _TreePath<T>(root, prefix, minKey)),
      _  => _TreePath.noLessThan(root.left, minKey, prefix: _TreePath<T>(root, prefix, minKey)),
    };
  }

  // Creates the path to the node with the largest key less than or equal to
  // `minKey` in the given tree, and concatenates that path after the given
  // `prefix` path.
  static _TreePath<T>? noGreaterThan<T>(RBTree<T>? root, int minKey, { _TreePath<T>? prefix }) {
    if (root == null) {
      return prefix;
    }
    return switch (root.key.compareTo(minKey)) {
      -1 => _TreePath.noGreaterThan(root.right, minKey, prefix: prefix),
      0  => _TreePath<T>(root, prefix, minKey),
      _  => _TreePath.noGreaterThan(root.left, minKey, prefix: _TreePath<T>(root, prefix, minKey)),
    };
  }

  final int minKey;

  final int key;

  /// The lowest (one with the largest depth) node in the path.
  final RBTree<Value> end;

  /// The path from [end]'s parent to the root node.
  final _TreePath<Value>? path;

  _TreePath<Value>? get firstLeftAncestor {
    final _TreePath<Value>? path = this.path;
    if (path == null) {
      return null;
    }
    assert(path.end.left == end || path.end.right == end);
    return path.end.left == end ? path : path.firstLeftAncestor;
  }

  /// The path to the next node (in ascending order) in the tree.
  _TreePath<Value>? get next {
    final RBTree<Value>? right = end.right;
    if (right != null) {
      // Search the right branch for the next node
      return noLessThan(right, minKey, prefix: this);
    }
    final _TreePath<Value>? ancestor = firstLeftAncestor;
    return ancestor != null && ancestor.end.key < minKey ? ancestor.next : ancestor;
  }
}

class _TreeWalker<Value> implements Iterator<(int, Value)> {
  _TreeWalker(this.root, this.startingIndex);

  final RBTree<Value> root;
  final int startingIndex;

  bool moveNextCalled = false;
  _TreePath<Value>? _path;

  @override
  (int, Value) get current {
    final _TreePath<Value> path = _path!;
    return (path.key, path.end.value);
  }

  @override
  bool moveNext() {
    _path = moveNextCalled ? _path!.next : _TreePath.noLessThan(root, startingIndex);
    moveNextCalled = true;
    return _path != null;
  }
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
/// This red-black tree implementation does not allow key duplicates.
@immutable
class RBTree<Value> {
  /// Creates a [RBTree].
  RBTree._(this.key, this.value, this.isBlack, this.blackHeight, this.left, this.right)
   : assert(left == null || left.key < key),
     assert(right == null || key < right.key),
     assert((left?.blackHeight ?? 0) == (right?.blackHeight ?? 0)),
     assert(blackHeight == (left?.blackHeight ?? 0) + (isBlack ? 1 : 0));

  /// Creates a [RBTree] with a red root node.
  ///
  /// {@template flutter.foundation.rbtree.constructor_invariants}
  /// In debug mode, this constructor asserts if the resulting tree is not a
  /// valid BST, or there are black violations. But it currently does not check
  /// for red violations, as oprations such as insertion may involve temporarily
  /// violating invariant 1.
  ///
  /// Consider using [debugCheckNoRedViolations] in debug mode after finish
  /// updating the tree to make sure all invariants are maintained.
  /// {@endtemplate}
  RBTree.red(this.key, this.value, { this.left, this.right })
   : assert(left == null || left.key < key),
     assert(right == null || key < right.key),
     assert((left?.blackHeight ?? 0) == (right?.blackHeight ?? 0)),
     isBlack = false,
     blackHeight = left?.blackHeight ?? 0;

  /// Creates a [RBTree] with a black root node.
  ///
  /// {@macro flutter.foundation.rbtree.constructor_invariants}
  RBTree.black(this.key, this.value, { this.left, this.right })
   : assert(left == null || left.key < key),
     assert(right == null || key < right.key),
     assert((left?.blackHeight ?? 0) == (right?.blackHeight ?? 0), '$left and $right do not have the same black height.'),
     isBlack = true,
     blackHeight = (left?.blackHeight ?? 0) + 1;

  /// Creates a [RBTree] from a sorted, non-empty association [List].
  factory RBTree.fromSortedList(List<(int, Value)> sortedList) {
    assert(sortedList.isNotEmpty);
    assert(() {
      for (int i = 1; i < sortedList.length; i++) {
        assert(sortedList[i - 1].$1 < sortedList[i].$1);
      }
      return true;
    }());
    final RBTree<Value> tree = _fromSortedList(sortedList, 0, sortedList.length, false);
    assert(tree.debugCheckNoRedViolations);
    return tree;
  }

  /// The int key of this node.
  final int key;

  /// The value this node carries.
  final Value value;

  /// Whether the root node of this [RBTree] is black.
  final bool isBlack;

  /// The number of black nodes in each path from this node to a leaf in this
  /// subtree.
  final int blackHeight;

  /// The left subtree.
  final RBTree<Value>? left;

  /// The right subtree.
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

  /// Replaces [left] with the given `leftTree`, and fix any red violations if
  /// `this` is a black node.
  RBTree<Value> _balanceLeft(RBTree<Value> leftTree) {
    assert(debugCheckNoRedViolations);
    assert(leftTree.blackHeight == (right?.blackHeight ?? 0));
    assert(leftTree.key < key);
    if (identical(leftTree, left)) {
      return this;
    }
    if (!isBlack) {
      return RBTree<Value>.red(key, value, left: leftTree, right: right);
    }
    return switch (leftTree) {
      RBTree<Value>(isBlack: false, key: final int xKey, value: final Value xValue,
        left: final RBTree<Value>? a,
        right: RBTree<Value>(isBlack: false, key: final int yKey, value: final Value yValue,
          left: final RBTree<Value>? b,
          right: final RBTree<Value>? c,
        ),
      ) ||
      RBTree<Value>(isBlack: false, key: final int yKey, value: final Value yValue,
        left: RBTree<Value>(isBlack: false, key: final int xKey, value: final Value xValue,
          left: final RBTree<Value>? a,
          right: final RBTree<Value>? b,
        ),
        right: final RBTree<Value>? c,
      ) => RBTree<Value>.red(yKey, yValue,
          left: RBTree<Value>.black(xKey, xValue, left: a, right: b),
          right: RBTree<Value>.black(key, value, left: c, right: right),
        ),
      _ => RBTree<Value>.black(key, value, left: leftTree, right: right),
    };
  }

  /// Replaces [right] with the given `rightTree`, and fix any red violations if
  /// `this` is a black node.
  RBTree<Value> _balanceRight(RBTree<Value> rightTree) {
    assert(debugCheckNoRedViolations);
    assert(rightTree.blackHeight == (left?.blackHeight ?? 0));
    assert(rightTree.key > key);
    if (identical(rightTree, right)) {
      return this;
    }
    if (!isBlack) {
      return RBTree<Value>.red(key, value, left: left, right: rightTree);
    }
    return switch (rightTree) {
      RBTree<Value>(isBlack: false, key: final int yKey, value: final Value yValue,
        left: final RBTree<Value>? b,
        right: RBTree<Value>(isBlack: false, key: final int zKey, value: final Value zValue,
          left: final RBTree<Value>? c,
          right: final RBTree<Value>? d
        )
      ) ||
      RBTree<Value>(isBlack: false, key: final int zKey, value: final Value zValue,
        left: RBTree<Value>(isBlack: false, key: final int yKey, value: final Value yValue,
          left: final RBTree<Value>? b,
          right: final RBTree<Value>? c
        ),
        right: final RBTree<Value>? d
      ) => RBTree<Value>.red(yKey, yValue,
            left: RBTree<Value>.black(key, value, left: left, right: b),
            right: RBTree<Value>.black(zKey, zValue, left: c, right: d),
          ),
      _ => RBTree<Value>.black(key, value, left: left, right: rightTree),
    };
  }

  RBTree<Value> _insert(int key, Value value) => switch (key.compareTo(this.key)) {
    < 0 => _balanceLeft(left?._insert(key, value) ?? RBTree<Value>.red(key, value)),
    > 0 => _balanceRight(right?._insert(key, value) ?? RBTree<Value>.red(key, value)),
    _   => value == this.value ? this : RBTree<Value>._(key, value, isBlack, blackHeight, left, right),
  };

  @pragma('vm:prefer-inline')
  RBTree<Value> _turnBlack() => !isBlack ? RBTree<Value>.black(key, value, left: left, right: right) : this;

  /// Inserts the given key value pair to the [RBTree] and returns the resulting
  /// new [RBTree].
  ///
  /// O(log(N)) where N is the number of nodes in the tree.
  @pragma('vm:prefer-inline')
  RBTree<Value> insert(int key, Value value) {
    final RBTree<Value> tree = _insert(key, value)._turnBlack();
    assert(tree.debugCheckNoRedViolations);
    return tree;
  }

  RBTree<Value> _joinTaller(RBTree<Value>? tallerRightTree, int key, Value value) {
    if (tallerRightTree == null) {
      return insert(key, value);
    }
    assert(blackHeight <= tallerRightTree.blackHeight);
    return blackHeight == tallerRightTree.blackHeight
      ? RBTree<Value>.red(key, value, left: this, right: tallerRightTree)
      : tallerRightTree._balanceLeft(_joinTaller(tallerRightTree.left, key, value));
  }

  RBTree<Value> _joinShorter(RBTree<Value>? shorterRightTree, int key, Value value) {
    if (shorterRightTree == null) {
      return insert(key, value);
    }
    assert(shorterRightTree.blackHeight <= blackHeight);
    if (blackHeight == shorterRightTree.blackHeight) {
      return RBTree<Value>.red(key, value, left: this, right: shorterRightTree);
    }
    assert(right != null || (isBlack && blackHeight == 1 && shorterRightTree.blackHeight == 0));
    return _balanceRight(right?._joinShorter(shorterRightTree, key, value) ?? RBTree<Value>.red(key, value, right: shorterRightTree));
  }

  /// Right joins the given [RBTree] and the give key value pair to the [RBTree],
  /// and returns the resulting [RBTree].
  ///
  /// The given key must be greater than the largest key in this [RBTree], and
  /// less than the smallest key in the given `rightTree`.
  ///
  /// O(log(N)).
  @pragma('vm:prefer-inline')
  RBTree<Value> join(RBTree<Value> rightTree, int key, Value value) {
    assert(debugCheckNoRedViolations);
    assert(rightTree.debugCheckNoRedViolations);
    assert(_maxNode.key < key);
    assert(key < rightTree._minNode.key);
    final RBTree<Value> tree = blackHeight < rightTree.blackHeight
      ? _joinTaller(rightTree, key, value)._turnBlack()
      : _joinShorter(rightTree, key, value)._turnBlack();
    assert(tree.debugCheckNoRedViolations);
    return tree;
  }

  /// Returns a [RBTree] containing the nodes from this [RBTree] that are less
  /// than the given `threshold`.
  ///
  /// O(log(N)).
  RBTree<Value>? takeLessThan(int threshold) {
    if (key == threshold) {
      return left;
    }
    if (threshold < key) {
      return left?.takeLessThan(threshold);
    }
    final RBTree<Value>? newRightSubtree = right?.takeLessThan(threshold);
    return newRightSubtree == null
      ? left?.insert(key, value) ?? this
      : left?.join(newRightSubtree, key, value) ?? newRightSubtree.insert(key, value);
  }

  /// Returns a [RBTree] containing the nodes from this [RBTree] that are greater
  /// than or equal to the given `key`.
  ///
  /// O(log(N)).
  RBTree<Value>? skipUntil(int threshold) {
    final RBTree<Value>? right = this.right;
    if (key == threshold) {
      return right?.insert(threshold, value) ?? RBTree<Value>._(key, value, isBlack, blackHeight, null, null);
    }
    if (key < threshold) {
      return right?.skipUntil(threshold);
    }
    return right == null
      ? left?.skipUntil(threshold)?.insert(key, value) ?? this
      : left?.skipUntil(threshold)?.join(right, key, value) ?? right.insert(key, value);
  }

  bool get debugCheckNoRedViolations {
    final RBTree<Value>? left = this.left;
    final RBTree<Value>? right = this.right;
    final bool leftValid = left == null
                        || (left.debugCheckNoRedViolations && (isBlack || left.isBlack));
    final bool rightValid = right == null
                        || (right.debugCheckNoRedViolations && (isBlack || right.isBlack));
    return leftValid && rightValid;
  }

  //List<int> get keys {
  //  final List<int> list = [];
  //  final Iterator<(int, Value)> iter = getRunsEndAfter(0);
  //  while (iter.moveNext()) {
  //    list.add(iter.current.$1);
  //  }
  //  return list;
  //}

  @override
  String toString() => '${isBlack ? "black" : "red"}: $key, $blackHeight';
}

enum _TreeWalkerState {
  initial, // moveNext hasn't been called
  startedWithDefaultValue, // emitting the defaultValue instead of walking the tree
  treeWalk, // walking the tree
}

class _TreeWalkerWithDefaults<Value extends Object> implements Iterator<(int, Value?)> {
  _TreeWalkerWithDefaults(this.root, this.startingIndex, this.defaultValue) : _current = (0, defaultValue);

  final RBTree<Value?> root;
  final int startingIndex;
  final Value? defaultValue;

  _TreeWalkerState state = _TreeWalkerState.initial;
  _TreePath<Value?>? _path;

  @override
  (int, Value?) get current => _current;
  (int, Value?) _current;

  _TreePath<Value?>? _advanceState() {
    switch (state) {
      case _TreeWalkerState.startedWithDefaultValue:
        state = _TreeWalkerState.treeWalk;
        return _path;
      case _TreeWalkerState.treeWalk:
        state = _TreeWalkerState.treeWalk;
        return _path?.next;
      case _TreeWalkerState.initial when defaultValue == null:
        assert(_path == null);
        state = _TreeWalkerState.treeWalk;
        return _TreePath.noGreaterThan(root, startingIndex);
      case _TreeWalkerState.initial:
        assert(_path == null);
        final _TreePath<Value?>? path = _TreePath.noGreaterThan(root, startingIndex);
        state = path != null && path.end.key <= startingIndex
          ? _TreeWalkerState.startedWithDefaultValue
          : _TreeWalkerState.treeWalk;
        return path;
    }
  }

  @override
  bool moveNext() {
    final _TreePath<Value?>? path = _path = _advanceState();
    switch (state) {
      case _TreeWalkerState.initial:
        assert(false);
        return false;
      case _TreeWalkerState.startedWithDefaultValue:
        assert(_current == (0, defaultValue));
        return true;
      case _TreeWalkerState.treeWalk:
        if (path == null) {
          return false;
        } else {
          _current = (path.end.key, path.end.value ?? defaultValue);
          return true;
        }
    }
  }
}

extension type RBTreeTextRun<Value extends Object>(RBTree<Value?> tree) implements Object {
  /// Returns an [Iterator] that emits `(int, Value)` from this tree in ascending
  /// order, starting from the largest node that is no greater than `startingKey`.
  ///
  /// O(N).
  Iterator<(int, Value?)> getRunsEndAfter(int startingKey, Value? defaultValue) => _TreeWalkerWithDefaults<Value>(tree, startingKey, defaultValue);
}
