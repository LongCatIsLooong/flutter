// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart' show immutable, useResult;

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
    return paintDeepestLeavesRed ? RBTree.red(key, value) : RBTree.black(key, value);
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
  return RBTree.black(key, value, left: left, right: right);
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
  //static _TreePath<T>? noGreaterThan<T>(RBTree<T>? root, int minKey, { _TreePath<T>? prefix }) {
  //  if (root == null) {
  //    return prefix;
  //  }
  //  return switch (root.key.compareTo(minKey)) {
  //    -1 => _TreePath.noGreaterThan(root.right, minKey, prefix: prefix),
  //    0  => _TreePath<T>(root, prefix, minKey),
  //    _  => _TreePath.noGreaterThan(root.left, minKey, prefix: _TreePath<T>(root, prefix, minKey)),
  //  };
  //}

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

/// A [RBTree] with a red root node, constructed using [RBTree.red].
extension type RedNode<Value>._(RBTree<Value> node) implements RBTree<Value>, _UnsafeNode<Value> {
  RedNode._construct(int key, Value value, { BlackNode<Value>? left, BlackNode<Value>? right })
   : node = RBTree<Value>._(key, value, false, left?.blackHeight ?? 0, left, right);
}

/// A [RBTree] with a black root node, constructed using [RBTree.black].
extension type BlackNode<Value>._(RBTree<Value> node) implements _UnsafeNode<Value>, RBTree<Value> {
  BlackNode._construct(int key, Value value, { RBTree<Value>? left, RBTree<Value>? right })
   : node = RBTree<Value>._(key, value, true, (left?.blackHeight ?? 0) + 1, left, right);
}

extension type _UnsafeNode<Value>._(RBTree<Value> node) {
  /// Creates a red node that may have red children (but the children must not
  /// have red violations themselves).
  ///
  /// This [_UnsafeNode] type are generally created by operations that may
  /// temporarily introduce a red violation to keep the height invariant when
  /// modifying the tree (such as insertion).
  ///
  /// A [_UnsafeNode] is typically converted back to a "safe" [RBTree] node by
  /// using `_balance` and then `_turnBlack` at the root.
  _UnsafeNode._unsafeRed(int key, Value value, { RBTree<Value>? left, RBTree<Value>? right })
   : assert(left?._debugCheckNoRedViolations ?? true),
     assert(right?._debugCheckNoRedViolations ?? true),
     node = RBTree<Value>._(key, value, false, left?.blackHeight ?? 0, left, right);

  /// Creates a [_UnsafeNode] from a [RBTree] that has no red violations (i.e. safe).
  _UnsafeNode.safe(this.node) : assert(node._debugCheckNoRedViolations);

   // Returns node.
   //
   // In debug mode, this getter also verifies the subtree has no red violations.
   RBTree<Value> get ensureSafe {
     assert(node._debugCheckNoRedViolations);
     return node;
   }

  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  BlackNode<Value> _turnBlack() {
    return node.isBlack
      ? BlackNode<Value>._(node)
      : RBTree.black(node.key, node.value, left: node.left, right: node.right);
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
final class RBTree<Value> {
  /// Creates a [RBTree].
  RBTree._(this.key, this.value, this.isBlack, this.blackHeight, this.left, this.right)
   : assert(left == null || left.key < key),
     assert(right == null || key < right.key),
     assert((left?.blackHeight ?? 0) == (right?.blackHeight ?? 0), '$left and $right do not have the same height.'),
     assert(blackHeight == (left?.blackHeight ?? 0) + (isBlack ? 1 : 0)),
     _minNode = left?.minNode,
     _maxNode = right?.maxNode;

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
    assert(tree._debugCheckNoRedViolations);
    return tree;
  }

  /// Creates a [RBTree] with a red root node.
  static RedNode<Value> red<Value>(int key, Value value, { BlackNode<Value>? left, BlackNode<Value>? right }) {
    return RedNode<Value>._construct(key, value, left: left, right:right);
  }

  /// Creates a [RBTree] with a black root node.
  static BlackNode<Value> black<Value>(int key, Value value, { RBTree<Value>? left, RBTree<Value>? right }) {
    return BlackNode<Value>._construct(key, value, left: left, right:right);
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
  /// The value is cached. O(1).
  RBTree<Value> get minNode => _minNode ?? this;
  final RBTree<Value>? _minNode;

  /// The node with the largest key in this [RBTree].
  ///
  /// The value is cached. O(1).
  RBTree<Value> get maxNode => _maxNode ?? this;
  final RBTree<Value>? _maxNode;

  /// Retrieves the node in the tree with the largest key that is less than or
  /// equal to the given `key`.
  ///
  /// O(log(N)).
  //RBTree<Value>? getNodeLessThanOrEqualTo(int maxKey) {
  //  if (maxKey <= minNode.key) {
  //    return maxKey == minNode.key ? minNode : null;
  //  } else if (maxNode.key <= maxKey ) {
  //    return maxNode;
  //  }
  //  return switch (maxKey.compareTo(this.key)) {
  //    == 0 => this,
  //    >  0 => right?.getNodeLessThanOrEqualTo(maxKey) ?? this,
  //    _    => left!.getNodeLessThanOrEqualTo(maxKey),
  //  };
  //}
  RBTree<Value>? getNodeLessThanOrEqualTo(int maxKey) {
    if (maxKey <= minNode.key) {
      return maxKey == minNode.key ? minNode : null;
    } else if (maxNode.key <= maxKey ) {
      return maxNode;
    }
    RBTree<Value> node = this;
    while (node.key != maxKey) {
      final RBTree<Value>? next = maxKey < node.key ? node.left : node.right;
      if (next == null) {
        return node;
      }
      node = next;
    }
    return node;
  }

  /// Retrieves the node in the tree with the smallest key that's greater than
  /// the given `key`.
  ///
  /// O(log(N)).
  RBTree<Value>? getNodeGreaterThan(int minKey) {
    if (maxNode.key <= minKey) {
      return null;
    } else if (minKey < minNode.key) {
      return minNode;
    }
    RBTree<Value> node = this;
    while (node.key != minKey) {
      final RBTree<Value>? next = minKey < node.key ? node.left : node.right;
      if (next == null) {
        return node;
      }
      node = next;
    }
    return node.right?.minNode ?? node;
  }

  /// Replaces [left] with the given `leftTree`, and fix any red violations if
  /// `this` is a black node.
  _UnsafeNode<Value> _balanceLeft(_UnsafeNode<Value> leftTree) {
    assert(_debugCheckNoRedViolations);
    assert(leftTree.node.blackHeight == (right?.blackHeight ?? 0));
    assert(leftTree.node.key < key);
    if (identical(leftTree, left)) {
      return _UnsafeNode<Value>.safe(this);
    }
    if (!isBlack) {
      // Only attempt to fix red violations at black nodes.
      return _UnsafeNode<Value>._unsafeRed(key, value, left: leftTree.ensureSafe, right: right);
    }
    final RBTree<Value> safe = switch (leftTree) {
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
      ) => RBTree.red(yKey, yValue,
          left: RBTree.black(xKey, xValue, left: a, right: b),
          right: RBTree.black(key, value, left: c, right: right),
        ),
      _ => RBTree.black(key, value, left: leftTree.ensureSafe, right: right),
    };
    return _UnsafeNode<Value>.safe(safe);
  }

  /// Replaces [right] with the given `rightTree`, and fix any red violations if
  /// `this` is a black node.
  _UnsafeNode<Value> _balanceRight(_UnsafeNode<Value> rightTree) {
    assert(_debugCheckNoRedViolations);
    assert(rightTree.node.blackHeight == (left?.blackHeight ?? 0));
    assert(rightTree.node.key > key);
    if (identical(rightTree, right)) {
      return _UnsafeNode<Value>.safe(this);
    }
    if (!isBlack) {
      return _UnsafeNode<Value>._unsafeRed(key, value, left: left, right: rightTree.ensureSafe);
    }
    final RBTree<Value> safe = switch (rightTree) {
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
      ) => red(yKey, yValue,
            left: RBTree.black(key, value, left: left, right: b),
            right: RBTree.black(zKey, zValue, left: c, right: d),
          ),
      _ => black(key, value, left: left, right: rightTree.ensureSafe),
    };
    return _UnsafeNode<Value>.safe(safe);
  }

  _UnsafeNode<Value> _insert(int key, Value value) => switch (key.compareTo(this.key)) {
    < 0 => _balanceLeft(left?._insert(key, value) ?? _UnsafeNode<Value>.safe(red(key, value))),
    > 0 => _balanceRight(right?._insert(key, value) ?? _UnsafeNode<Value>.safe(red(key, value))),
    _   => _UnsafeNode<Value>.safe(value == this.value ? this : RBTree<Value>._(key, value, isBlack, blackHeight, left, right)),
  };

  /// Inserts the given key value pair to the [RBTree] and returns the resulting
  /// new [RBTree].
  ///
  /// O(log(N)) where N is the number of nodes in the tree.
  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @useResult
  BlackNode<Value> insert(int key, Value value) {
    final BlackNode<Value> tree = _insert(key, value)._turnBlack();
    assert(tree._debugCheckNoRedViolations);
    return tree;
  }

  _UnsafeNode<Value> _joinTaller(RBTree<Value>? tallerRightTree, int key, Value value) {
    if (tallerRightTree == null) {
      return insert(key, value);
    }
    assert(blackHeight <= tallerRightTree.blackHeight);
    return blackHeight == tallerRightTree.blackHeight
      ? _UnsafeNode<Value>._unsafeRed(key, value, left: this, right: tallerRightTree)
      : tallerRightTree._balanceLeft(_joinTaller(tallerRightTree.left, key, value));
  }

  _UnsafeNode<Value> _joinShorter(RBTree<Value>? shorterRightTree, int key, Value value) {
    if (shorterRightTree == null) {
      return insert(key, value);
    }
    assert(shorterRightTree.blackHeight <= blackHeight);
    if (blackHeight == shorterRightTree.blackHeight) {
      // Calling _redUnsafe here is fine: it will be fixed by _balanceRight in _joinShorter, or _turnBlack in join.
      return _UnsafeNode<Value>._unsafeRed(key, value, left: this, right: shorterRightTree);
    }
    assert(right != null || (isBlack && blackHeight == 1 && shorterRightTree.blackHeight == 0));
    return _balanceRight(right?._joinShorter(shorterRightTree, key, value) ?? _UnsafeNode<Value>._unsafeRed(key, value, right: shorterRightTree));
  }

  /// Right joins the given [RBTree] and the give key value pair to the [RBTree],
  /// and returns the resulting [RBTree].
  ///
  /// The given key must be greater than the largest key in this [RBTree], and
  /// less than the smallest key in the given `rightTree`.
  ///
  /// O(log(N)).
  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @useResult
  BlackNode<Value> join(RBTree<Value> rightTree, int key, Value value) {
    assert(_debugCheckNoRedViolations);
    assert(rightTree._debugCheckNoRedViolations);
    assert(maxNode.key < key);
    assert(key < rightTree.minNode.key);
    final BlackNode<Value> tree = blackHeight < rightTree.blackHeight
      ? _joinTaller(rightTree, key, value)._turnBlack()
      : _joinShorter(rightTree, key, value)._turnBlack();
    assert(tree._debugCheckNoRedViolations);
    return tree;
  }


  /// Right joins the given [RBTree] this [RBTree], and returns the resulting
  /// [RBTree].
  ///
  /// Every node from `rightTree` must be greater than the largest key in this
  /// [RBTree].
  ///
  /// O(log(N)).
  @useResult
  RBTree<Value> merge(RBTree<Value> rightTree) {
    assert(_debugCheckNoRedViolations);
    assert(rightTree._debugCheckNoRedViolations);
    assert(maxNode.key < rightTree.minNode.key);
    final RBTree<Value> rightMin = rightTree.minNode;
    final RBTree<Value>? rightWithoutMin = rightTree.skipUntil(rightMin.key + 1);
    final RBTree<Value> tree = rightWithoutMin == null
      ? insert(rightMin.key, rightMin.value)
      : join(rightWithoutMin, rightMin.key, rightMin.value);
    assert(tree._debugCheckNoRedViolations);
    return tree;
  }

  /// Returns a [RBTree] containing the nodes from this [RBTree] whose `key`s
  /// are less than the given `threshold`.
  ///
  /// O(log(N)).
  RBTree<Value>? takeLessThan(int threshold) {
    if (maxNode.key < threshold) {
      return this;
    }
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

  /// Returns a [RBTree] containing the nodes from this [RBTree] whose `key`s
  /// are greater than or equal to the given `key`.
  ///
  /// O(log(N)).
  RBTree<Value>? skipUntil(int threshold) {
    if (minNode.key >= threshold) {
      return this;
    }
    final RBTree<Value>? right = this.right;
    if (key == threshold) {
      return right?.insert(threshold, value) ?? RBTree<Value>._(key, value, isBlack, blackHeight, null, null);
    }
    if (key < threshold) {
      return right?.skipUntil(threshold);
    }
    return right == null
      ? left?.skipUntil(threshold)?.insert(key, value) ?? RBTree<Value>._(key, value, isBlack, blackHeight, null, null)
      : left?.skipUntil(threshold)?.join(right, key, value) ?? right.insert(key, value);
  }

  /// Returns an [Iterator] that emits `(int, Value)` from this tree in ascending
  /// order, starting from the largest node that is no greater than `startingKey`.
  ///
  /// O(N).
  Iterator<(int, Value)> getRunsEndAfter(int startingKey) => _TreeWalker<Value>(this, startingKey);

  bool get _debugCheckNoRedViolations {
    final RBTree<Value>? left = this.left;
    final RBTree<Value>? right = this.right;
    final bool leftValid = left == null
                        || (left._debugCheckNoRedViolations && (isBlack || left.isBlack));
    final bool rightValid = right == null
                        || (right._debugCheckNoRedViolations && (isBlack || right.isBlack));
    return leftValid && rightValid;
  }

  @override
  String toString() => '${isBlack ? "black" : "red"}: $key, $blackHeight';
}

//enum _TreeWalkerState {
//  initial, // moveNext hasn't been called
//  startedWithDefaultValue, // emitting the defaultValue instead of walking the tree
//  treeWalk, // walking the tree
//}
//
//class _TreeWalkerWithDefaults<Value extends Object> implements Iterator<(int, Value?)> {
//  _TreeWalkerWithDefaults(this.root, this.startingIndex, this.defaultValue) : _current = (0, defaultValue);
//
//  final RBTree<Value?> root;
//  final int startingIndex;
//  final Value? defaultValue;
//
//  _TreeWalkerState state = _TreeWalkerState.initial;
//  _TreePath<Value?>? _path;
//
//  @override
//  (int, Value?) get current => _current;
//  (int, Value?) _current;
//
//  _TreePath<Value?>? _advanceState() {
//    switch (state) {
//      case _TreeWalkerState.startedWithDefaultValue:
//        state = _TreeWalkerState.treeWalk;
//        return _path;
//      case _TreeWalkerState.treeWalk:
//        state = _TreeWalkerState.treeWalk;
//        return _path?.next;
//      case _TreeWalkerState.initial when defaultValue == null:
//        assert(_path == null);
//        state = _TreeWalkerState.treeWalk;
//        return _TreePath.noGreaterThan(root, startingIndex);
//      case _TreeWalkerState.initial:
//        assert(_path == null);
//        final _TreePath<Value?>? path = _TreePath.noGreaterThan(root, startingIndex);
//        state = path != null && path.end.key <= startingIndex
//          ? _TreeWalkerState.startedWithDefaultValue
//          : _TreeWalkerState.treeWalk;
//        return path;
//    }
//  }
//
//  @override
//  bool moveNext() {
//    final _TreePath<Value?>? path = _path = _advanceState();
//    switch (state) {
//      case _TreeWalkerState.initial:
//        assert(false);
//        return false;
//      case _TreeWalkerState.startedWithDefaultValue:
//        assert(_current == (0, defaultValue));
//        return true;
//      case _TreeWalkerState.treeWalk:
//        if (path == null) {
//          return false;
//        } else {
//          _current = (path.end.key, path.end.value ?? defaultValue);
//          return true;
//        }
//    }
//  }
//}

//extension type RBTreeTextRun<Value extends Object>(RBTree<Value?> tree) implements Object {
//  /// Returns an [Iterator] that emits `(int, Value)` from this tree in ascending
//  /// order, starting from the largest node that is no greater than `startingKey`.
//  ///
//  /// O(N).
//  Iterator<(int, Value?)> getRunsEndAfter(int startingKey, Value? defaultValue) => _TreeWalkerWithDefaults<Value>(tree, startingKey, defaultValue);
//}
