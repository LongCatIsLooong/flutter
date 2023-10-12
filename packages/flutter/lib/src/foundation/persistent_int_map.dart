// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

class PersistentIntMap<V> {
}

sealed class _TriNode {
  const _TriNode(this.prefix);

  static _TriNode? _branch(int prefix, int mask, _TriNode? left, _TriNode? right) {
    return switch ((left, right)) {
      (final l, null) => l,
      (null, final r) => r,
      (final l?, final r?) => _Branch(prefix, mask, l, r),
    };
  }

  @pragma('vm:prefer-inline')
  static int highestBitmask(int key) => throw UnimplementedError();

  // Clears the less significant bits of key, up to (including )the switching bit
  // `mask`.
  @pragma('vm:prefer-inline')
  static int _mask(int key, int mask) {
    // assert mask's popcount = 1.
    return key & ((-mask) ^ mask);
  }

  @pragma('vm:prefer-inline')
  static int _branchingMaskFrom(int prefix1, int prefix2) => highestBitmask(prefix1 ^ prefix2);

  //@pragma('vm:prefer-inline')
  //static _TriNode _joinWithMask(int mask, int prefix1, _TriNode tree1, _TriNode tree2) {
  //  final int prefix = _mask(prefix1, mask);
  //  return switch (mask & prefix1) {
  //      0 => _Branch(prefix, mask, tree1, tree2),
  //      _ => _Branch(prefix, mask, tree2, tree1),
  //    };
  //}

  @pragma('vm:prefer-inline')
  @nonVirtual
  _TriNode join(int prefixOther, _TriNode treeOther) {
    //assert(prefix1 & prefix2 != prefix1);
    //assert(prefix1 & prefix2 != prefix2);
    assert(treeOther.prefix == prefixOther);
    final int mask = _branchingMaskFrom(prefixOther, this.prefix);
    final int prefix = _mask(prefixOther, mask);
    return switch (mask & prefixOther) {
        0 => _Branch(prefix, mask, treeOther, this),
        _ => _Branch(prefix, mask, this, treeOther),
      };
  }

  // The longest common prefix shared by both the left and the right node, and
  // all keys in the subtree. For leaf nodes this is the key.
  final int prefix;

  _TriNode insert(int key, Object? value);
  _TriNode insertRange(int keyStart, int keyEnd, Object? value);
}

final class _Branch extends _TriNode {
  const _Branch(super.prefix, this.mask, this.left, this.right);

  // The most significant bit between the left node and the right node's prefixes.
  //
  // For example, if the left node's prefix is 0 (0b0000), and the right's prefix
  // is 10 (0b1010), then the mask is (0b1000).
  //
  // This is also known as the branching (or switching) mask. It is always a
  // power of 2.
  final int mask;

  final _TriNode left;
  final _TriNode right;

  @override
  _TriNode insert(int key, Object? value) {
    if (_TriNode._mask(key, mask) != prefix) {
      return join(key, _Leaf(key, value));
    }

    return (key & mask == 0)
      ? _Branch(prefix, mask, left.insert(key, value), right)
      : _Branch(prefix, mask, left, right.insert(key, value));
  }

@override
  _TriNode insertRange(int keyStart, int keyEnd, Object? value) {
    assert(keyStart < keyEnd);
    // ???

    final int rangePrefix = keyStart ^ keyEnd;
    throw UnimplementedError();
  }
}

final class _Leaf extends _TriNode {
  const _Leaf(super.prefix, this.value);

  final Object? value;

  @override
  _TriNode insert(int key, Object? value) {
    final _Leaf newLeaf = _Leaf(key, value);
    return key == prefix ? newLeaf : join(key, newLeaf);
  }

  @override
  _TriNode insertRange(int keyStart, int keyEnd, Object? value) {
    assert(keyStart < keyEnd);
    if (keyEnd == prefix) {
      return insert(keyStart, value);
    }
    if (keyEnd < prefix) {
      return insert(keyStart, value).insert(keyEnd, null);
    }
    if (prefix <= keyStart) {
      return insert(keyStart, value).insert(keyEnd, this.value);
    }
    return _Leaf(keyStart, value).insert(keyEnd, this.value);
  }
}

//final class _Empty implements _TriNode {
//  const _Empty();
//
//  @override
//  _TriNode insert(int key, Object? value) => _Leaf(key, value);
//}
