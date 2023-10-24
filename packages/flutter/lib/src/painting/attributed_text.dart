// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'basic_types.dart' show RenderComparison;
import 'text_style.dart';

/// A node in a persistent red-black tree.
///
/// A red-black tree is binary search tree that maintains the following
/// additional invariants:
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
  _Node join(_Node rightTree, int key, Object? value) => (height < rightTree.height ? _joinTaller(rightTree, key, value) : _joinShorter(rightTree, key, value))._turnBlack();

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
      : left?.join(newRightSubtree, key, value) ?? newRightSubtree.insert(key, value);
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
      : left?._skipUntil(key)?.join(right, key, value) ?? right.insert(key, value);
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
      : rightTreeWithoutEnd?.insert(end!, nodeAtEnd.value) ?? _Node.black(end!, nodeAtEnd.value);

    return leftTree != null && rightTree != null
      ? leftTree.join(rightTree, start, value)
      : (leftTree ?? rightTree)?.insert(start, value) ?? _Node.black(start, value);
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

  static PersistentHashMap<Type, _Node> _addAttribute(PersistentHashMap<Type, _Node> storage, TextAttribute attribute, int start, int? end) {
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
    final PersistentHashMap<Type, _Node> storage = attributes.fold(
      _attributeStorage,
      (PersistentHashMap<Type, _Node> storage, TextAttribute attribute) => _addAttribute(storage, attribute, start, end),
    );
    return AttributedText._(text, storage);
  }


  AttributedText addTextStyle(TextStyle textStyle, { required ui.TextRange forRange }) {
    return addAttributes(_TextStyleAttribute.fromTextStyle(textStyle), forRange: forRange);
  }

  (int, TextStyle?) getTextStyleAt(int index) {
  }

  Iterable<(int, TextStyle)> getStyles() {

  }

  final PersistentHashMap<Type, _Node> _attributeStorage;
}

// A piece of data that annotates an [AttributedText] object, or part of it.
//
// This class is open for customization.
//
// Things like the selected range can be added to the text as a subclass.
@immutable
abstract class TextAttribute {
  //RenderComparison compare(covariant TextAttribute other);
}

sealed class _TextStyleAttribute implements TextAttribute {
  static List<_TextStyleAttribute> fromTextStyle(TextStyle style) {
    final ui.Paint? background = switch ((style.background, style.backgroundColor)) {
      (final ui.Paint paint, _) => paint,
      (_, final ui.Color color) => ui.Paint()..color = color,
      _ => null,
    };
    return <_TextStyleAttribute>[
      if (style.color != null) _Color(style.color!),
      if (style.decoration != null) _TextDecoration(style.decoration!),
      if (style.decorationColor != null) _TextDecorationColor(style.decorationColor!),
      if (style.decorationStyle != null) _TextDecorationStyle(style.decorationStyle!),
      if (style.decorationThickness != null) _TextDecorationThickness(style.decorationThickness!),
      if (style.fontWeight != null) _FontWeight(style.fontWeight!),
      if (style.fontStyle != null) _FontStyle(style.fontStyle!),
      if (style.textBaseline != null) _TextBaseline(style.textBaseline!),
      if (style.leadingDistribution != null) _LeadingDistribution(style.leadingDistribution!),
      if (style.fontFamily != null) _FontFamily(style.fontFamily!),
      if (style.fontFamilyFallback != null) _FontFamilyFallback(style.fontFamilyFallback!),
      if (style.fontSize != null) _FontSize(style.fontSize!),
      if (style.letterSpacing != null) _LetterSpacing(style.letterSpacing!),
      if (style.wordSpacing != null) _WordSpacing(style.wordSpacing!),
      if (style.height != null) _Height(style.height!),
      if (style.locale != null) _Locale(style.locale!),
      if (style.foreground != null) _Foreground(style.foreground!),
      if (background != null) _Background(background),
      if (style.shadows != null) _Shadows(style.shadows!),
      if (style.fontFeatures != null) _FontFeatures(style.fontFeatures!),
      if (style.fontVariations != null) _FontVariations(style.fontVariations!),
    ];
  }
}

final class _FontWeight implements _TextStyleAttribute {
  const _FontWeight(this.fontWeight);
  final ui.FontWeight fontWeight;
}

final class _FontStyle implements _TextStyleAttribute {
  const _FontStyle(this.fontStyle);
  final ui.FontStyle fontStyle;
}

final class _TextBaseline implements _TextStyleAttribute {
  const _TextBaseline(this.textBaseline);
  final ui.TextBaseline textBaseline;
}

final class _LeadingDistribution implements _TextStyleAttribute {
  const _LeadingDistribution(this.leadingDistribution);
  final ui.TextLeadingDistribution leadingDistribution;
}

final class _FontFamily implements _TextStyleAttribute {
  const _FontFamily(this.fontFamily);
  final String fontFamily;
}

final class _FontFamilyFallback implements _TextStyleAttribute {
  const _FontFamilyFallback(this.fontFamilyFallback);
  final List<String> fontFamilyFallback;
}

final class _FontSize implements _TextStyleAttribute {
  const _FontSize(this.fontSize);
  final double fontSize;
}

final class _LetterSpacing implements _TextStyleAttribute {
  const _LetterSpacing(this.letterSpacing);
  final double letterSpacing;
}

final class _WordSpacing implements _TextStyleAttribute {
  const _WordSpacing(this.wordSpacing);
  final double wordSpacing;
}

final class _Height implements _TextStyleAttribute {
  const _Height(this.height);
  final double height;
}

final class _FontFeatures implements _TextStyleAttribute {
  const _FontFeatures(this.fontFeatures);
  final List<ui.FontFeature> fontFeatures;
}

final class _FontVariations implements _TextStyleAttribute {
  const _FontVariations(this.fontVariations);
  final List<ui.FontVariation> fontVariations;
}

final class _Color implements _TextStyleAttribute {
  const _Color(this.color);
  final ui.Color color;
}

final class _TextDecoration implements _TextStyleAttribute {
  const _TextDecoration(this.decoration);
  final ui.TextDecoration decoration;
}

final class _TextDecorationColor implements _TextStyleAttribute {
  const _TextDecorationColor(this.decorationColor);
  final ui.Color decorationColor;
}

final class _TextDecorationStyle implements _TextStyleAttribute {
  const _TextDecorationStyle(this.decorationStyle);
  final ui.TextDecorationStyle decorationStyle;
}

final class _TextDecorationThickness implements _TextStyleAttribute {
  const _TextDecorationThickness(this.decorationThickness);
  final double decorationThickness;
}

final class _Foreground implements _TextStyleAttribute {
  const _Foreground(this.foreground);
  final ui.Paint foreground;
}

final class _Background implements _TextStyleAttribute {
  const _Background(this.background);
  final ui.Paint background;
}

final class _Shadows implements _TextStyleAttribute {
  const _Shadows(this.shadows);
  final List<ui.Shadow> shadows;
}

sealed class SemanticsAttribute extends TextAttribute {
  const factory SemanticsAttribute.locale(ui.Locale locale) = _Locale;
  static const SemanticsAttribute spellOut = _SpellOut();
}

final class _SpellOut implements SemanticsAttribute {
  const _SpellOut();

  @override
  RenderComparison compare(_Locale other) => RenderComparison.identical;
}

final class _Locale implements SemanticsAttribute, _TextStyleAttribute {
  const _Locale(this.locale);

  final ui.Locale locale;

  @override
  RenderComparison compare(_Locale other) {
    return identical(this, other) || locale == other.locale
      ? RenderComparison.identical
      : RenderComparison.metadata;
  }
}


final class PlaceholderStyleAttribute implements _TextStyleAttribute {
  @override
  RenderComparison compare(PlaceholderStyleAttribute other) {
    return identical(this, other)
      ? RenderComparison.identical
      : RenderComparison.metadata;
  }
}

class HitTestableText implements SemanticsAttribute, HitTestTarget {
  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
  }
}
