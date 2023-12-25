// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'text_style.dart';

/// A node in a persistent red-black tree.
///
/// A red-black tree is binary search tree that maintains the following
/// invariants, in addition to the BST invariant:
///
///  1. A red node can only have black children.
///  2. Every path from the a node to a leaf node must have the same number of
///     black nodes.
final class _Node {
  _Node(this.key, this.value, this.isBlack, this.height, this.left, this.right);

  _Node.red(this.key, this.value, { this.left, this.right })
    : isBlack = false,
      height = left?.height ?? 0;
  _Node.black(this.key, this.value, { this.left, this.right })
    : isBlack = true,
      height = (left?.height ?? 0) + 1;

  final int key;
  final Object? value;
  final bool isBlack;
  // The number of black nodes in each path of this subtree.
  final int height;

  final _Node? left;
  final _Node? right;

  // Retrives the node in the tree with the largest key that is less than or
  // equal to the given `key`.
  _Node? getNodeLessThanOrEqualTo(int key) => switch (key.compareTo(this.key)) {
    == 0 => this,
    <  0 => left?.getNodeLessThanOrEqualTo(key),
    _    => right?.getNodeLessThanOrEqualTo(key) ?? this,
  };

  /// Retrives the node in the tree with the smallest key that's greater than
  /// the given `key`.
  _Node? getNodeGreaterThan(int key) => switch (key.compareTo(this.key)) {
    == 0 => right?.minNode,
    <  0 => left?.getNodeGreaterThan(key) ?? this,
    _    => right?.getNodeGreaterThan(key),
  };

  // The node with the smallest key in the subtree.
  late final _Node? minNode = left?.minNode ?? this;

  // Replaces [left] with the given `leftTree`, and fix any red-black violations
  // if `this` is a black node.
  _Node _balanceLeft(_Node leftTree) => switch (leftTree) {
    _ when identical(leftTree, left) => this,
    _Node(isBlack: false, key: final int xKey, value: final Object? xValue,
      left: final _Node? a,
      right: _Node(isBlack: false, key: final int yKey, value: final Object? yValue,
        left: final _Node? b,
        right: final _Node? c,
      ),
    ) ||
    _Node(isBlack: false, key: final int yKey, value: final Object? yValue,
      left: _Node(isBlack: false, key: final int xKey, value: final Object? xValue,
        left: final _Node? a,
        right: final _Node? b,
      ),
      right: final _Node? c,
    ) => _Node.red(yKey, yValue,
        left: _Node.black(xKey, xValue, left: a, right: b),
        right: _Node.black(key, value, left: c, right: right),
      ),
    _ => _Node(key, value, isBlack, height, leftTree, right),
  };

  // Replaces [right] with the given `rightTree`, and fix any red-black
  // violations.
  //
  // See _balanceLeft for details.
  _Node _balanceRight(_Node rightTree) => switch (rightTree) {
    _ when identical(rightTree, right) => this,
    _Node(isBlack: false, key: final int yKey, value: final Object? yValue,
      left: final _Node? b,
      right: _Node(isBlack: false, key: final int zKey, value: final Object? zValue,
        left: final _Node? c,
        right: final _Node? d
      )
    ) ||
    _Node(isBlack: false, key: final int zKey, value: final Object? zValue,
      left: _Node(isBlack: false, key: final int yKey, value: final Object? yValue,
        left: final _Node? b,
        right: final _Node? c
      ),
      right: final _Node? d
    ) => _Node.red(yKey, yValue,
           left: _Node.black(key, value, left: left, right: b),
           right: _Node.black(zKey, zValue, left: c, right: d),
         ),
    _ => _Node(key, value, isBlack, height, left, rightTree),
  };

  _Node _insert(int key, Object? value) => switch (key.compareTo(this.key)) {
    < 0 => _balanceLeft(left?._insert(key, value) ?? _Node.red(key, value)),
    > 0 => _balanceRight(right?._insert(key, value) ?? _Node.red(key, value)),
    _   => _Node(key, value, isBlack, height, left, right),
  };

  @pragma('vm:prefer-inline')
  _Node _turnBlack() => !isBlack ? _Node.black(key, value, left: left, right: right) : this;
  @pragma('vm:prefer-inline')
  _Node insert(int key, Object? value) => _insert(key, value)._turnBlack();

  _Node _joinTaller(_Node? tallerRightTree, int key, Object? value) {
    if (tallerRightTree == null) {
      return insert(key, value);
    }
    assert(height <= tallerRightTree.height);
    return height == tallerRightTree.height
      ? _Node.red(key, value, left: this, right: tallerRightTree)
      : tallerRightTree._balanceLeft(_joinTaller(tallerRightTree.left, key, value));
  }

  _Node _joinShorter(_Node? shorterRightTree, int key, Object? value) {
    if (shorterRightTree == null) {
      return insert(key, value);
    }
    assert(height < shorterRightTree.height);
    return height == shorterRightTree.height
      ? _Node.red(key, value, left: this, right: shorterRightTree)
      : _balanceRight(right!._joinShorter(shorterRightTree, key, value));
  }

  @pragma('vm:prefer-inline')
  _Node joinRight(_Node rightTree, int key, Object? value) => (height < rightTree.height ? _joinTaller(rightTree, key, value) : _joinShorter(rightTree, key, value))._turnBlack();

  _Node? _takeLessThan(int key) {
    if (this.key == key) {
      return left?._turnBlack();
    }
    if (key < this.key) {
      return left?._takeLessThan(key);
    }
    final _Node? newRightSubtree = right?._takeLessThan(key);
    return newRightSubtree == null
      ? _turnBlack()
      : left?.joinRight(newRightSubtree, key, value) ?? newRightSubtree.insert(key, value);
  }

  _Node? _skipUntil(int key) {
    if (this.key == key) {
      return this.right?.insert(key, value)._turnBlack() ?? _Node.black(key, value);
    }
    if (key > this.key) {
      return this.right?._skipUntil(key);
    }
    final _Node? right = this.right;
    return right == null
      ? null
      : left?._skipUntil(key)?.joinRight(right, key, value) ?? right.insert(key, value);
  }

  // When end is null, it is treated as +∞ and is special cased to enable faster
  // processing.
  _Node insertRange(int start, int? end, Object? value) {
    // Split this tree into two rb trees.
    // In the first tree keys are always less than `start`.
    final _Node? leftTree = start == 0 ? null : _takeLessThan(start);
    // In the second tree keys are always greater than or equal to than `end`.
    final _Node? rightTreeWithoutEnd = end == null ? null : _skipUntil(end);

    final _Node? nodeAtEnd = end == null ? null : getNodeLessThanOrEqualTo(end);
    final _Node? rightTree = nodeAtEnd == null || nodeAtEnd.key == end
      ? rightTreeWithoutEnd
      : rightTreeWithoutEnd?.insert(nodeAtEnd.key, nodeAtEnd.value) ?? _Node.black(nodeAtEnd.key, nodeAtEnd.value);

    return leftTree != null && rightTree != null
      ? leftTree.joinRight(rightTree, start, value)
      : (leftTree ?? rightTree)?.insert(start, value) ?? _Node.black(start, value);
  }

  // O(N)
  void visitAllAscending(void Function(_Node) visitor) {
    left?.visitAllAscending(visitor);
    visitor(this);
    right?.visitAllAscending(visitor);
  }

  late final List<_Node> ascending = _getAscending();
  _Iterator get ascendingIterator => _Iterator(ascending);

  List<_Node> _getAscending() {
    final List<_Node> nodes = <_Node>[];
    visitAllAscending(nodes.add);
    return nodes;
  }
}

final class _Iterator {
  _Iterator(this._nodes) : assert(_nodes.isNotEmpty);
  final List<_Node> _nodes;
  int _currentIndex = 0;

  _Node? get current => _currentIndex >= _nodes.length ? null : _nodes[_currentIndex];

  // If the iterator is at the given runStartIndex, returns the associated
  // value and move the iterator forward.
  //
  // This method returns null if the given the attribute does not change at the
  // given index.
  T? emitStyleForRunAndIncrement<T extends Object>(int runStartIndex) {
    final _Node? current = this.current;
    if (current == null || current.key != runStartIndex) {
      return null;
    }
    _currentIndex += 1;
    // For TextStyles there's no point in setting node.value to null (in which
    // case the style attribute defaults to the corresponding attribute from the
    // "base" style).
    // setting )
    return (current.value! as _TextStyleAttribute<T>).value;
  }
}

/// An immutable
class AttributedText {
  const AttributedText._(this.text, [this._attributeStorage = const PersistentHashMap<Type, _Node>.empty()]);

  final String text;

  (int, T?) getAttributeAt<T extends TextAttribute>(int index) {
    final _Node? attribute = _attributeStorage[T]?.getNodeLessThanOrEqualTo(index);
    return attribute == null
      ? (0, null)
      : (attribute.key, attribute.value as T?);
  }

  (int, T?)? getAttributeAfter<T extends TextAttribute>(int index) {

  }

  static PersistentHashMap<Type, _Node?> _addAttribute(PersistentHashMap<Type, _Node?> storage, TextAttribute attribute, int start, int? end) {
    assert(end == null || end > start);
    final Type runtimeType = attribute.runtimeType;
    final _Node node = storage[runtimeType]?.insertRange(start, end, attribute)
                    ?? _Node.black(start, attribute, left: end == null ? null : _Node.red(end, null));
    return storage.put(runtimeType, node);
  }

  AttributedText addAttribute(TextAttribute attribute, { required ui.TextRange forRange }) {
    assert(forRange.isValid);
    assert(forRange.isNormalized);
    assert(forRange.end <= text.length);
    if (forRange.isCollapsed) {
      return this;
    }
    final int? end = forRange.end == text.length ? null : forRange.end;
    return AttributedText._(text, _addAttribute(_attributeStorage, attribute, forRange.start, end));
  }

  AttributedText addAttributes(Iterable<TextAttribute> attributes, { required ui.TextRange forRange }) {
    assert(forRange.isValid);
    assert(forRange.isNormalized);
    assert(forRange.end <= text.length);

    if (forRange.isCollapsed) {
      return this;
    }
    final int start = forRange.start;
    final int? end = forRange.end == text.length ? null : forRange.end;
    PersistentHashMap<Type, _Node?> addAttribute(PersistentHashMap<Type, _Node?> storage, TextAttribute attribute) {
      return _addAttribute(storage, attribute, start, end);
    }
    return AttributedText._(text, attributes.fold(_attributeStorage, addAttribute));
  }

  // TextDecoration is additive.
  AttributedText addTextStyle(TextStyle textStyle, { required ui.TextRange forRange }) {
    assert(forRange.isValid);
    assert(forRange.isNormalized);
    assert(forRange.end <= text.length);
    return forRange.isCollapsed ? this : addAttributes(TextStyleAttribute._fromTextStyle(textStyle), forRange: forRange);
  }

  /// Retrives the sequence of TextStyle runs, given the base [TextStyle].
  ///
  /// A [TextStyle] run is a subsequnce of the text within which the [TextStyle]
  /// stays the same. Attributes in the [TextStyle] may be left unspecified, if
  /// the
  Iterable<(int, TextStyle)> getStyles(TextStyle baseStyle) {
    if (text.isEmpty) {
      return const <(int, TextStyle)>[];
    }
    final List<(int, TextStyle)> styles = <(int, TextStyle)>[ (0, baseStyle) ];
    const List<Type> types = <Type>[
      _Color, _TextDecorationColor, _TextDecorationStyle, _TextDecorationThickness, _TextDecorationUnderline,
      _TextDecorationOverline, _TextDecorationLineThrough, _FontWeight, _FontStyle, _TextBaseline,
      _LeadingDistribution, _FontFamily, _FontFamilyFallback, _FontSize, _LetterSpacing,
      _WordSpacing, _Height, _Locale, _Foreground, _Background,
      _Shadows, _FontFeatures, _FontVariations,
    ];

    final List<_Iterator?> iterators = <_Iterator?>[
      for (final Type type in types) _attributeStorage[type]?.ascendingIterator,
    ];

    int? findStyleRunStartIndex() {
      return iterators.fold(null, (int? currentMin, _Iterator? iterator) {
        final int? startIndex = iterator?.current?.key;
        return (startIndex == null || currentMin == null)
          ? (startIndex ?? currentMin)
          : math.min(startIndex, currentMin);
      });
    }

    bool underline = baseStyle.decoration?.contains(ui.TextDecoration.underline) ?? false;
    bool overline = baseStyle.decoration?.contains(ui.TextDecoration.overline) ?? false;
    bool lineThrough = baseStyle.decoration?.contains(ui.TextDecoration.overline) ?? false;

    for (int? runStartIndex = findStyleRunStartIndex(); runStartIndex != null; runStartIndex = findStyleRunStartIndex()) {
      final bool? newUnderline = iterators[4]?.emitStyleForRunAndIncrement(runStartIndex);
      final bool? newOverline = iterators[5]?.emitStyleForRunAndIncrement(runStartIndex);
      final bool? newLineThrough = iterators[6]?.emitStyleForRunAndIncrement(runStartIndex);
      final ui.TextDecoration? decoration;
      if (newUnderline != null || newOverline != null || newLineThrough != null) {
        underline = newUnderline ?? underline;
        overline = newOverline ?? overline;
        lineThrough = newLineThrough ?? lineThrough;
        decoration = ui.TextDecoration.combine(<ui.TextDecoration>[
          if (underline) ui.TextDecoration.underline,
          if (overline) ui.TextDecoration.overline,
          if (lineThrough) ui.TextDecoration.lineThrough,
        ]);
      } else {
        decoration = null;
      }

      final TextStyle styleToPush = TextStyle(
        color: iterators[0]?.emitStyleForRunAndIncrement(runStartIndex),
        decorationColor: iterators[1]?.emitStyleForRunAndIncrement(runStartIndex),
        decorationStyle: iterators[2]?.emitStyleForRunAndIncrement(runStartIndex),
        decorationThickness: iterators[3]?.emitStyleForRunAndIncrement(runStartIndex),
        decoration: decoration,
        fontWeight: iterators[7]?.emitStyleForRunAndIncrement(runStartIndex),
        fontStyle: iterators[8]?.emitStyleForRunAndIncrement(runStartIndex),
        textBaseline: iterators[9]?.emitStyleForRunAndIncrement(runStartIndex),
        leadingDistribution: iterators[10]?.emitStyleForRunAndIncrement(runStartIndex),
        fontFamily: iterators[11]?.emitStyleForRunAndIncrement(runStartIndex),
        fontFamilyFallback: iterators[12]?.emitStyleForRunAndIncrement(runStartIndex),
        fontSize: iterators[13]?.emitStyleForRunAndIncrement(runStartIndex),
        letterSpacing: iterators[14]?.emitStyleForRunAndIncrement(runStartIndex),
        wordSpacing: iterators[15]?.emitStyleForRunAndIncrement(runStartIndex),
        height: iterators[16]?.emitStyleForRunAndIncrement(runStartIndex),
        locale: iterators[17]?.emitStyleForRunAndIncrement(runStartIndex),
        foreground: iterators[18]?.emitStyleForRunAndIncrement(runStartIndex),
        background: iterators[19]?.emitStyleForRunAndIncrement(runStartIndex),
        shadows: iterators[20]?.emitStyleForRunAndIncrement(runStartIndex),
        fontFeatures: iterators[21]?.emitStyleForRunAndIncrement(runStartIndex),
        fontVariations: iterators[22]?.emitStyleForRunAndIncrement(runStartIndex),
      );
      styles.add((runStartIndex, styleToPush));
    }

    return styles;
  }

  final PersistentHashMap<Type, _Node?> _attributeStorage;
}

// A piece of data that annotates an [AttributedText] object, or part of it.
//
// This class is open for customization.
//
// Things like the selected range can be added to the text as a subclass.
@immutable
abstract class TextAttribute {
  //RenderComparison compare(covariant TextAttribute other);

  @protected
  Object get key => runtimeType;
}
