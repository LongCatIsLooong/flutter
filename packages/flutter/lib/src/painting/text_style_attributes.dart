// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show MouseCursor;

import 'basic_types.dart';
import 'inline_span.dart';
import 'placeholder_span.dart';
import 'text_span.dart';
import 'text_style.dart';

@pragma('vm:prefer-inline')
V? _applyNullable<T extends Object, V extends Object>(V? Function(T) transform, T? nullable) {
  return nullable == null ? null : transform(nullable);
}

// TODO: dedup
// TODO: rename lift
//
// When end is null, it is treated as +∞ and is special cased to enable faster
// processing.
RBTree<Value?>? _insertRange<Value extends Object>(RBTree<Value?>? tree, int start, int? end, Value? value) {
  assert(start >= 0);
  assert(end == null || end > start);
  if (tree == null) {
    return value == null
      ? null
      : RBTree<Value?>.black(start, value, right: end == null ? null : RBTree<Value?>.red(end, null));
  }
  // Split this tree into two rb trees: in the first tree keys are always less
  // than `start`, and in the second tree keys are always greater than or equal
  // to than `end`.
  final RBTree<Value?>? leftTree = start == 0 ? null : tree.takeLessThan(start);
  final RBTree<Value?>? rightTreeWithoutEnd = _applyNullable(tree.skipUntil, end);

  final RBTree<Value?>? nodeAtEnd = _applyNullable(tree.getNodeLessThanOrEqualTo, end);
  final RBTree<Value?>? rightTree = nodeAtEnd == null || nodeAtEnd.key == end
    ? rightTreeWithoutEnd
    : rightTreeWithoutEnd?.insert(end!, nodeAtEnd.value) ?? RBTree<Value?>.black(end!, nodeAtEnd.value);

  return leftTree != null && rightTree != null
    ? leftTree.join(rightTree, start, value)
    : (leftTree ?? rightTree)?.insert(start, value) ?? RBTree<Value?>.black(start, value);
}

abstract class TextStyleAttributeGetter<T extends Object> {
  Iterator<(int, T)> getRunsEndAfter(int index);
  _RunIterator<TextStyle> _getTextStyleRunsEndAfter(int index);
}

class _AttributeIterable<T extends Object, Output extends Object> implements TextStyleAttributeGetter<T> {
  _AttributeIterable._(this._storage, this._defaultValue, this._lift);

  final RBTree<T?>? _storage;
  final T _defaultValue;
  final TextStyle Function(T) _lift;

  (int, T) _transform((int, T?) pair) => (pair.$1, pair.$2 ?? _defaultValue);

  Iterator<(int, T)> getRunsEndAfter(int index) {
    final storage = _storage;
    return storage == null
      ? _EmptyIterator<(int, T)>()
      : _map(storage.getRunsEndAfter(index), _transform);
  }

  (int, TextStyle) _liftToTextStyle((int, T?) pair) => (pair.$1, _lift(pair.$2 ?? _defaultValue));

  _RunIterator<TextStyle> _getTextStyleRunsEndAfter(int index) {
    final storage = _storage;
    final innerIterator = storage == null
      ? const _EmptyIterator<(int, TextStyle)>()
      : _map(storage.getRunsEndAfter(index), _liftToTextStyle);
    return _RunIterator<TextStyle>(innerIterator);
  }
}

class _EmptyIterator<T> implements Iterator<T> {
  const _EmptyIterator();
  @override
  bool moveNext() => false;
  @override
  T get current => throw FlutterError('unreachable');
}

/// A wrapper iterator that allows safely querying the current value, without
/// calling [moveNext].
class _RunIterator<T> {
  _RunIterator(this.inner);

  bool? _canMoveNext;
  bool get canMoveNext => _canMoveNext ??= moveNext();
  final Iterator<(int, T)> inner;

  (int, T)? get current => canMoveNext ? _current : null;
  (int, T)? _current;

  bool moveNext() {
    _current = (_canMoveNext = inner.moveNext())
      ? inner.current
      : null;
    return _current != null;
  }
}

@pragma('vm:prefer-inline')
Iterator<V> _map<T, V>(Iterator<T> inner, V Function(T) transform) => _MapIterator<T, V>(inner, transform);
class _MapIterator<T, V> implements Iterator<V> {
  _MapIterator(this.inner, this.transform);

  final Iterator<T> inner;
  final V Function(T) transform;
  @override
  V get current => transform(inner.current);
  @override
  bool moveNext() => inner.moveNext();
}

abstract base class _MergedRunIterator<T, Attribute> implements Iterator<(int, T)> {
  _MergedRunIterator(this.attributes) : remainingLength = cleanUpEmptyAttributes(attributes, attributes.length);

  final List<_RunIterator<Attribute>> attributes;
  // The number of attributes in [attributes] that has not reached end. This
  // value being 0 indicates that this iterator has reached end.
  int remainingLength;

  // Throw exhausted attributes out of the list bounds. Returns the new list length.
  static int cleanUpEmptyAttributes<T>(List<_RunIterator<T>> attributes, int length) {
    int end = length - 1;
    for (int i = 0; i <= end; i += 1) {
      if (attributes[i].current != null) {
        continue;
      }
      while (attributes[end].current == null) {
        if (end <= i + 1) {
          return i;
        }
        end -= 1;
      }
      assert(attributes[end].current != null);
      // Throws the current i-th attribute away.
      attributes[i] = attributes[end];
    }
    return end + 1;
  }

  // Move _RunIterators in the attributes list with the smallest starting index
  // to the start of the attributes list.
  int moveNextAttributesToHead() {
    assert(remainingLength > 0);
    int runStartIndex = -1;
    // The number of attributes that currently start at runStartIndex.
    int numberOfAttributes = 0;

    for (int i = 0; i < remainingLength; i += 1) {
      final _RunIterator<Attribute> attribute = attributes[i];
      final int index = attribute.current!.$1;
      if (numberOfAttributes > 0 && runStartIndex < index) {
        // This attribute has a larger startIndex than the current runStartIndex.
        continue;
      }
      if (index != runStartIndex) {
        assert(numberOfAttributes == 0 || runStartIndex > index);
        // This attribute has a smaller startIndex than the current runStartIndex.
        runStartIndex = index;
        numberOfAttributes = 1;
      } else {
        numberOfAttributes += 1;
      }
      // Move the attribute to the head of the list.
      assert(numberOfAttributes - 1 <= i);
      if (numberOfAttributes - 1 != i) {
        // Swap locations to make sure the attributes with the smallest start
        // index are relocated to the head of the list.
        attributes[i] = attributes[numberOfAttributes - 1];
        attributes[numberOfAttributes - 1] = attribute;
      }
    }
    assert(numberOfAttributes > 0);
    return numberOfAttributes;
  }
}

final class _TextStyleMergingIterator extends _MergedRunIterator<TextStyle, TextStyle> {
  _TextStyleMergingIterator(super.attributes);

  @override
  late (int, TextStyle) current;

  @override
  bool moveNext() {
    if (remainingLength <= 0) {
      return false;
    }
    final int numberOfAttributes = moveNextAttributesToHead();
    final int runStartIndex = attributes[0].current!.$1;
    TextStyle? result;
    for (int i = numberOfAttributes - 1; i >= 0; i -= 1) {
      final _RunIterator<TextStyle> attribute = attributes[i];
      final TextStyle value = attribute.current!.$2;
      assert(attribute.current?.$1 == runStartIndex);
      result = value.merge(result);
      if (!attribute.moveNext()) {
        // This attribute has no more starting indices, throw it out.
        attributes[i] = attributes[remainingLength -= 1];
      }
    }
    current = (runStartIndex, result!);
    return remainingLength > 0;
  }
}

final class _DecorationFlagsMergingIterator extends _MergedRunIterator<int, (int, bool)> {
  _DecorationFlagsMergingIterator(super.attributes, int baseDecorationMask)
    : assert(baseDecorationMask >= 0),
      assert(baseDecorationMask < 1 << 4),
      current = (0, baseDecorationMask);

  @override
  (int, int) current;

  @override
  bool moveNext() {
    if (remainingLength <= 0) {
      return false;
    }
    final int numberOfAttributes = moveNextAttributesToHead();
    final int runStartIndex = attributes[0].current!.$1;
    int currentFlags = current.$2;
    for (int i = numberOfAttributes - 1; i >= 0; i -= 1) {
      final _RunIterator<(int, bool)> attribute = attributes[i];
      final (int mask, bool isSet) = attribute.current!.$2;
      assert(attribute.current?.$1 == runStartIndex);
      // Set the bit specified current value
      final bool needsFlipping = (currentFlags & mask != 0) != isSet;
      if (needsFlipping) {
        currentFlags ^= mask;
      }
      if (!attribute.moveNext()) {
        // This attribute has no more starting indices, throw it out.
        attributes[i] = attributes[remainingLength -= 1];
      }
    }
    current = (runStartIndex, currentFlags);
    return remainingLength > 0;
  }
}

final class _AccumulativeMergedRunIterator<T extends Object> extends _MergedRunIterator<Map<String, T>, (String, T?)> {
  _AccumulativeMergedRunIterator(super.attributes, Map<String, T> defaultValue)
    : current = (0, defaultValue);

  @override
  (int, Map<String, T>) current;

  @override
  bool moveNext() {
    if (remainingLength <= 0) {
      return false;
    }
    final int numberOfAttributes = moveNextAttributesToHead();
    final int runStartIndex = attributes[0].current!.$1;
    for (int i = numberOfAttributes - 1; i >= 0; i -= 1) {
      final _RunIterator<(String, T?)> attribute = attributes[i];
      final (String key, T? value) = attribute.current!.$2;
      final Map<String, T> currentMap = current.$2;
      if (value == null) {
        currentMap.remove(key);
      } else {
        currentMap[key] = value;
      }
      assert(attribute.current?.$1 == runStartIndex);
      if (!attribute.moveNext()) {
        attributes[i] = attributes[remainingLength -= 1];
      }
    }
    return remainingLength > 0;
  }
}

//const TextStyle defaultTypographicAnnotation = (
//  fontWeight: ui.FontWeight.w400,
//  fontStyle: ui.FontStyle.normal,
//  fontFeatures: [],
//  fontVariations: [],
//
//  textBaseline: ui.TextBaseline.alphabetic,
//  textLeadingDistribution: ui.TextLeadingDistribution.proportional,
//
//  fontFamilies: <String>[''],
//  locale: '',
//
//  fontSize: 14.0,
//  height: null,
//  letterSpacing: 0.0,
//  wordSpacing: 0.0,
//);

TextStyle _liftFontFamilies(List<String> input) => switch (input) {
  [] => const TextStyle(),
  [final fontFamily, ...final fontFamilyFallback] => TextStyle(fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback),
};
List<String>? _getFontFamilies(TextStyle textStyle) {
  final String? fontFamily = textStyle.fontFamily;
  final List<String>? fontFamilyFallback = textStyle.fontFamilyFallback;
  return fontFamily == null && fontFamilyFallback == null
    ? null
    : <String>[
      if (fontFamily != null) fontFamily,
      ...?textStyle.fontFamilyFallback,
    ];
}

TextStyle _liftLocale(ui.Locale input) => TextStyle(locale: input);
ui.Locale?_getLocale(TextStyle textStyle) => textStyle.locale;
TextStyle _liftFontSize(double input) => TextStyle(fontSize: input);
double? _getFontSize(TextStyle textStyle) => textStyle.fontSize;
TextStyle _liftFontWeight(ui.FontWeight input) => TextStyle(fontWeight: input);
ui.FontWeight?_getFontWeight(TextStyle textStyle) => textStyle.fontWeight;
TextStyle _liftFontStyle(ui.FontStyle input) => TextStyle(fontStyle: input);
ui.FontStyle?_getFontStyle(TextStyle textStyle) => textStyle.fontStyle;
TextStyle _liftFontFeatures(List<ui.FontFeature> input) => TextStyle(fontFeatures: input);
List<ui.FontFeature>?_getFontFeatures(TextStyle textStyle) => textStyle.fontFeatures;
TextStyle _liftFontVariations(List<ui.FontVariation> input) => TextStyle(fontVariations: input);
List<ui.FontVariation>?_getFontVariations(TextStyle textStyle) => textStyle.fontVariations;
TextStyle _liftHeight(double input) => TextStyle(height: input);
double? _getHeight(TextStyle textStyle) => textStyle.height;
TextStyle _liftLeadingDistribution(ui.TextLeadingDistribution input) => TextStyle(leadingDistribution: input);
ui.TextLeadingDistribution? _getLeadingDistribution(TextStyle textStyle) => textStyle.leadingDistribution;
TextStyle _liftTextBaseline(ui.TextBaseline input) => TextStyle(textBaseline: input);
ui.TextBaseline? _getTextBaseline(TextStyle textStyle) => textStyle.textBaseline;
TextStyle _liftWordSpacing(double input) => TextStyle(wordSpacing: input);
double? _getWordSpacing(TextStyle textStyle) => textStyle.wordSpacing;
TextStyle _liftLetterSpacing(double input) => TextStyle(letterSpacing: input);
double? _getLetterSpacing(TextStyle textStyle) => textStyle.letterSpacing;

Either<ui.Color, ui.Paint>? _getForeground(TextStyle textStyle) => _applyNullable(Either.left, textStyle.color) ?? _applyNullable(Either.right, textStyle.foreground);
Either<ui.Color, ui.Paint>? _getBackground(TextStyle textStyle) => _applyNullable(Either.left, textStyle.backgroundColor) ?? _applyNullable(Either.right, textStyle.background);
ui.Color? _getDecorationColor(TextStyle textStyle) => textStyle.decorationColor;
ui.TextDecorationStyle? _getDecorationStyle(TextStyle textStyle) => textStyle.decorationStyle;
double? _getDecorationThickness(TextStyle textStyle) => textStyle.decorationThickness;
List<ui.Shadow>? _getShadows(TextStyle textStyle) => textStyle.shadows;

final ui.TextDecoration _underlineOverline = ui.TextDecoration.combine(const [ui.TextDecoration.underline, ui.TextDecoration.overline]);
final ui.TextDecoration _underlineLineThrough = ui.TextDecoration.combine(const [ui.TextDecoration.underline, ui.TextDecoration.lineThrough]);
final ui.TextDecoration _overlineLineThrough = ui.TextDecoration.combine(const [ui.TextDecoration.overline, ui.TextDecoration.lineThrough]);
final ui.TextDecoration _allDecorations = ui.TextDecoration.combine(const [ui.TextDecoration.underline, ui.TextDecoration.overline, ui.TextDecoration.lineThrough]);

const int _underlineMask = 1 << 0;
const int _overlineMask = 1 << 1;
const int _lineThroughMask = 1 << 2;

bool? _getUnderline(TextStyle textStyle) => textStyle.decoration?.contains(TextDecoration.underline);
bool? _getOverline(TextStyle textStyle) => textStyle.decoration?.contains(TextDecoration.overline);
bool? _getLineThrough(TextStyle textStyle) => textStyle.decoration?.contains(TextDecoration.lineThrough);

abstract final class _TextStyleAnnotationKey { }

@immutable
class TextStyleAnnotations implements StringAnnotation<_TextStyleAnnotationKey> {
  TextStyleAnnotations._(
    this._fontFamilies,
    this._locale,
    this._fontWeight,
    this._fontStyle,
    this._fontFeatures,
    this._fontVariations,
    this._textBaseline,
    this._leadingDistribution,
    this._fontSize,
    this._height,
    this._letterSpacing,
    this._wordSpacing,
    this._foreground,
    this._background,
    this._underline,
    this._overline,
    this._lineThrough,
    this._decorationColor,
    this._decorationStyle,
    this._decorationThickness,
    this._shadows,

    this._textLength,
    this.baseStyle,
  );

  static _AttributeIterable<Value, TextStyle> _createAttribute<Value extends Object>(RBTree<Value?>? storage, Value defaultValue, TextStyle Function(Value) lift) {
    return _AttributeIterable<Value, TextStyle>._(storage, defaultValue, lift);
  }

  final TextStyle baseStyle;
  TextStyleAnnotations updateBaseTextStyle(TextStyle baseAnnotations) {
    return TextStyleAnnotations._(
      _fontFamilies,
      _locale,
      _fontWeight,
      _fontStyle,
      _fontFeatures,
      _fontVariations,
      _textBaseline,
      _leadingDistribution,
      _fontSize,
      _height,
      _letterSpacing,
      _wordSpacing,
      _textLength,
      baseAnnotations,
    );
  }

  final int _textLength;

  final RBTree<List<String>?>? _fontFamilies;
  late final TextStyleAttributeGetter<List<String>> fontFamilies = _createAttribute(_fontFamilies, _getFontFamilies(baseStyle)!, _liftFontFamilies);

  final RBTree<ui.Locale?>? _locale;
  late final TextStyleAttributeGetter<ui.Locale> locale = _createAttribute(_locale, baseStyle.locale!, _liftLocale);

  final RBTree<double?>? _fontSize;
  late final TextStyleAttributeGetter<double> fontSize = _createAttribute(_fontSize, baseStyle.fontSize!, _liftFontSize);

  final RBTree<ui.FontWeight?>? _fontWeight;
  late final TextStyleAttributeGetter<ui.FontWeight> fontWeight = _createAttribute(_fontWeight, baseStyle.fontWeight!, _liftFontWeight);

  final RBTree<ui.FontStyle?>? _fontStyle;
  late final TextStyleAttributeGetter<ui.FontStyle> fontStyle = _createAttribute(_fontStyle, baseStyle.fontStyle!, _liftFontStyle);

  final RBTree<List<ui.FontFeature>?>? _fontFeatures;
  late final TextStyleAttributeGetter<List<ui.FontFeature>> fontFeatures = _createAttribute(_fontFeatures, baseStyle.fontFeatures!, _liftFontFeatures);

  final RBTree<List<ui.FontVariation>?>? _fontVariations;
  late final TextStyleAttributeGetter<List<ui.FontVariation>> fontVariations = _createAttribute(_fontVariations, baseStyle.fontVariations!, _liftFontVariations);

  final RBTree<ui.TextLeadingDistribution?>? _leadingDistribution;
  late final TextStyleAttributeGetter<ui.TextLeadingDistribution> leadingDistribution = _createAttribute(_leadingDistribution, baseStyle.leadingDistribution!, _liftLeadingDistribution);

  final RBTree<double?>? _height;
  late final TextStyleAttributeGetter<double> height = _createAttribute(_height, baseStyle.height!, _liftHeight);

  final RBTree<ui.TextBaseline?>? _textBaseline;
  late final TextStyleAttributeGetter<ui.TextBaseline> textBaseline = _createAttribute(_textBaseline, baseStyle.textBaseline!, _liftTextBaseline);

  final RBTree<double?>? _letterSpacing;
  late final TextStyleAttributeGetter<double> letterSpacing = _createAttribute(_letterSpacing, baseStyle.letterSpacing!, _liftLetterSpacing);
  final RBTree<double?>? _wordSpacing;
  late final TextStyleAttributeGetter<double> wordSpacing = _createAttribute(_wordSpacing, baseStyle.wordSpacing!, _liftWordSpacing);

  final RBTree<Either<ui.Color, ui.Paint>?>? _foreground;
  final RBTree<Either<ui.Color, ui.Paint>?>? _background;

  final RBTree<bool?>? _underline;
  late final TextStyleAttributeGetter<bool> hasUnderline = _createAttribute(_underline, baseStyle.decoration?.contains(ui.TextDecoration.underline), _liftWordSpacing);
  final RBTree<bool?>? _overline;
  final RBTree<bool?>? _lineThrough;

  final RBTree<ui.Color?>? _decorationColor;
  final RBTree<ui.TextDecorationStyle?>? _decorationStyle;
  final RBTree<double?>? _decorationThickness;

  final RBTree<List<ui.Shadow>?>? _shadows;

  TextStyle getAnnotationAt(int index) {
    final underline = _underline?.getNodeGreaterThan(index)?.value ?? baseStyle.decoration?.contains(ui.TextDecoration.underline) ?? false;
    final overline = _overline?.getNodeGreaterThan(index)?.value ?? baseStyle.decoration?.contains(ui.TextDecoration.underline) ?? false;
    final lineThrough = _lineThrough?.getNodeGreaterThan(index)?.value ?? baseStyle.decoration?.contains(ui.TextDecoration.underline) ?? false;
    final ui.TextDecoration? decoration = underline || overline || lineThrough
      ? null
      : ui.TextDecoration.combine([
          if (underline) ui.TextDecoration.underline,
          if (overline) ui.TextDecoration.overline,
          if (lineThrough) ui.TextDecoration.lineThrough,
        ]);
    final foreground = _foreground?.getNodeGreaterThan(index)?.value;
    final background = _background?.getNodeGreaterThan(index)?.value;

    final (String? fontFamily, List<String>? fallback) = switch (_fontFamilies?.getNodeLessThanOrEqualTo(index)?.value) {
      null => (null, null),
      [] => ('', const []),
      [final fontFamily, ...final fallback] => (fontFamily, fallback)
    };

    final TextStyle textStyle = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      locale: _locale?.getNodeLessThanOrEqualTo(index)?.value,

      fontWeight: _fontWeight?.getNodeLessThanOrEqualTo(index)?.value,
      fontStyle: _fontStyle?.getNodeLessThanOrEqualTo(index)?.value,

      fontFeatures: _fontFeatures?.getNodeGreaterThan(index)?.value,
      fontVariations: _fontVariations?.getNodeGreaterThan(index)?.value,

      leadingDistribution: _leadingDistribution?.getNodeLessThanOrEqualTo(index)?.value,
      height: _height?.getNodeLessThanOrEqualTo(index)?.value,
      textBaseline: _textBaseline?.getNodeLessThanOrEqualTo(index)?.value,

      fontSize: _fontSize?.getNodeLessThanOrEqualTo(index)?.value,
      letterSpacing: _letterSpacing?.getNodeLessThanOrEqualTo(index)?.value,
      wordSpacing: _wordSpacing?.getNodeLessThanOrEqualTo(index)?.value,

      color: foreground?.maybeLeft,
      foreground: foreground?.maybeRight,
      backgroundColor: background?.maybeLeft,
      background: background?.maybeRight,
      decoration: decoration,
      decorationColor: _decorationColor?.getNodeLessThanOrEqualTo(index)?.value,
      decorationStyle: _decorationStyle?.getNodeLessThanOrEqualTo(index)?.value,
      decorationThickness: _decorationThickness?.getNodeLessThanOrEqualTo(index)?.value,
      shadows: _shadows?.getNodeLessThanOrEqualTo(index)?.value,
    );
    return baseStyle.merge(textStyle);
  }

  Iterator<(int, TextStyle)> getRunsEndAfter(int index) {
    final List<_RunIterator<ui.TextDecoration>?>? decorationsToMerge;
    switch ((_underline, _overline, _lineThrough)) {
      case (null, null, null):
        decorationsToMerge = null;
      case (final underline?, null, null):
        decorationsToMerge = _map(underline.getRunsEndAfter(index), (bool?));

    }
    final bool noDecoration = _underline == null && _overline == null && _lineThrough == null;

    final List<_RunIterator<TextStyle>?> runsToMerge = List<_RunIterator<TextStyle>?>.filled(12, null)
      ..[0] = fontFamilies._getTextStyleRunsEndAfter(index)
      ..[1] = locale._getTextStyleRunsEndAfter(index)
      ..[2] = fontSize._getTextStyleRunsEndAfter(index)
      ..[3] = fontWeight._getTextStyleRunsEndAfter(index)
      ..[4] = fontStyle._getTextStyleRunsEndAfter(index)
      ..[5] = fontVariations._getTextStyleRunsEndAfter(index)
      ..[6] = fontFeatures._getTextStyleRunsEndAfter(index)
      ..[7] = height._getTextStyleRunsEndAfter(index)
      ..[8] = leadingDistribution._getTextStyleRunsEndAfter(index)
      ..[9] = textBaseline._getTextStyleRunsEndAfter(index)
      ..[10] = wordSpacing._getTextStyleRunsEndAfter(index)
      ..[11] = letterSpacing._getTextStyleRunsEndAfter(index);
      ..[11] = letterSpacing._getTextStyleRunsEndAfter(index)
      ..[11] = letterSpacing._getTextStyleRunsEndAfter(index)
      ..[11] = letterSpacing._getTextStyleRunsEndAfter(index);
    return _TextStyleMergingIterator(runsToMerge as List<_RunIterator<TextStyle>>);
  }

  TextStyleAnnotations overwrite(ui.TextRange range, TextStyleAttributeSet annotationsToOverwrite) {
    final int? end = range.end >= _textLength ? null : range.end;

    RBTree<Value?>? update<Value extends Object>(Value? newAttribute, RBTree<Value?>? tree) {
      return newAttribute == null ? tree : _insertRange(tree, range.start, end, newAttribute);
    }

    PersistentHashMap<String, RBTree<Value?>?> updateMap<Value extends Object>(PersistentHashMap<String, RBTree<Value?>?> map, MapEntry<String, Value?> newAttribute) {
      final key = newAttribute.key;
      final newValue = newAttribute.value;
      final tree = map[key];
      final newTree = _insertRange(tree, range.start, end, newValue);
      return identical(tree, newTree) ? map : map.put(key, newTree);
    }

    return TextStyleAnnotations._(
      update(annotationsToOverwrite.fontFamilies, _fontFamilies),
      update(annotationsToOverwrite.locale, _locale),
      update(annotationsToOverwrite.fontWeight, _fontWeight),
      update(annotationsToOverwrite.fontStyle, _fontStyle),
      update(annotationsToOverwrite.fontFeatures, _fontFeatures),
      update(annotationsToOverwrite.fontVariations, _fontVariations),
      update(annotationsToOverwrite.textBaseline, _textBaseline),
      update(annotationsToOverwrite.textLeadingDistribution, _leadingDistribution),
      update(annotationsToOverwrite.fontSize, _fontSize),
      update(annotationsToOverwrite.height, _height),
      update(annotationsToOverwrite.letterSpacing, _letterSpacing),
      update(annotationsToOverwrite.wordSpacing, _wordSpacing),

      _textLength,
      baseStyle,
    );
  }

  // Resets TextStyle attributes with non-null values to baseTextStyle.
  // I'm not sure this is really needed. Added for duality.
  TextStyleAnnotations erase(ui.TextRange range, TextStyleAttributeSet annotationsToErase) {
    final int? end = range.end >= _textLength ? null : range.end;

    RBTree<Value?>? erase<Value extends Object>(Value? newAttribute, RBTree<Value?>? tree) {
      return newAttribute == null ? tree : _insertRange(tree, range.start, end, null);
    }

    return TextStyleAnnotations._(
      erase(annotationsToErase.fontFamilies, _fontFamilies),
      erase(annotationsToErase.locale, _locale),
      erase(annotationsToErase.fontWeight, _fontWeight),
      erase(annotationsToErase.fontStyle, _fontStyle),
      erase(annotationsToErase.fontFeatures, _fontFeatures),
      erase(annotationsToErase.fontVariations, _fontVariations),
      erase(annotationsToErase.textBaseline, _textBaseline),
      erase(annotationsToErase.textLeadingDistribution, _leadingDistribution),
      erase(annotationsToErase.fontSize, _fontSize),
      erase(annotationsToErase.height, _height),
      erase(annotationsToErase.letterSpacing, _letterSpacing),
      erase(annotationsToErase.wordSpacing, _wordSpacing),
      _textLength,
      baseStyle,
    );
  }
}

final class TextStyleAttributeSet {
  const TextStyleAttributeSet({
    this.fontFamilies,
    this.locale,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.fontFeatures,
    this.fontVariations,
    this.height,
    this.textLeadingDistribution,
    this.textBaseline,
    this.wordSpacing,
    this.letterSpacing,

    this.foreground,
    this.background,
    this.shadows,
    this.underline,
    this.overline,
    this.lineThrough,
    this.decorationColor,
    this.decorationStyle,
    this.decorationThickness,
  });

  final List<String>? fontFamilies;
  final ui.Locale? locale;
  final double? fontSize;
  final ui.FontWeight? fontWeight;
  final ui.FontStyle? fontStyle;

  final List<ui.FontFeature>? fontFeatures;
  final List<ui.FontVariation>? fontVariations;

  final double? height;
  final ui.TextLeadingDistribution? textLeadingDistribution;
  final ui.TextBaseline? textBaseline;

  final double? wordSpacing;
  final double? letterSpacing;

  // How do we compare ui.Paint objects?
  final Either<ui.Color, ui.Paint>? foreground;
  final Either<ui.Color, ui.Paint>? background;
  final List<ui.Shadow>? shadows;

  final bool? underline;
  final bool? overline;
  final bool? lineThrough;

  final ui.Color? decorationColor;
  final ui.TextDecorationStyle? decorationStyle;
  final double? decorationThickness;
}

abstract final class _HitTestAnnotationKey {}
class TextHitTestAnnotations implements StringAnnotation<_HitTestAnnotationKey> {
  const TextHitTestAnnotations._(this._hitTestTargets);

  final RBTree<Iterable<HitTestTarget>>? _hitTestTargets;

  Iterable<HitTestTarget> getHitTestTargets(int codeUnitOffset) {
    final iterator = _hitTestTargets?.getRunsEndAfter(codeUnitOffset);
    return iterator != null && iterator.moveNext() ? iterator.current.$2 : const <HitTestTarget>[];
  }
}

abstract final class _SemanticsAnnotationKey {}
/// An annotation type that represents the extra semantics information of the text.
class SemanticsAnnotations implements StringAnnotation<_SemanticsAnnotationKey> {
  const SemanticsAnnotations._(this._semanticsLabels, this._spellout, this._gestureCallbacks);

  final RBTree<String?>? _semanticsLabels;
  final RBTree<bool?>? _spellout;
  // Either onTap callbacks or onLongPress callbacks.
  final RBTree<Either<VoidCallback, VoidCallback>?>? _gestureCallbacks;
}

/// InlineSpan to AnnotatedString Conversion

//class _AttributeStackEntry<Value extends Object> {
//  _AttributeStackEntry(this.value);
//  final Value value;
//  int repeatCount = 1;
//}

// A class for extracting attribute (such as the font size) runs from an
// InlineSpan tree.
//
// Each attribute run is a pair of the starting index of the attribute in the
// string, and value of the attribute. For instance if the font size runs are
// [(0, 10), (5, 20)], it means the text starts with a font size of 10 and
// starting from the 5th code unit the font size changes to 20.
abstract class _AttributeRunBuilder<Source, Attribute> {
  final List<(int, Attribute)> runs = <(int, Attribute)>[];
  int runStartIndex = 0;

  bool tryPush(Source attribute);
  void pop();
  void commitText(int length);
  RBTree<Attribute>? build() => runs.isEmpty ? null : RBTree<Attribute>.fromSortedList(runs);
}

mixin _NonOverlappingAttributeRunMixin<Source, Attribute> on _AttributeRunBuilder<Source, Attribute> {
  final List<Attribute> attributeStack = <Attribute>[];

  @override
  void pop() {
    assert(attributeStack.isNotEmpty);
    attributeStack.removeLast();
  }

  @override
  void commitText(int length) {
    assert(length > 0);
    final Attribute? currentRunAttribute = runs.isEmpty ? null : runs.last.$2;
    // Start a new run only if the attributes are different.
    if (attributeStack.isNotEmpty && currentRunAttribute != attributeStack.last) {
      runs.add((runStartIndex, attributeStack.last));
    }
    runStartIndex += length;
  }
}

class _TextStyleAttributeRunBuilder<Attribute extends Object> extends _AttributeRunBuilder<TextStyle?, Attribute> with _NonOverlappingAttributeRunMixin<TextStyle?, Attribute> {
  _TextStyleAttributeRunBuilder(this.getAttribute);
  final Attribute? Function(TextStyle) getAttribute;
  @override
  bool tryPush(TextStyle? textStyle) {
    final Attribute? newAttribute = _applyNullable(getAttribute, textStyle);
    final bool pushToStack = newAttribute != null && (attributeStack.isEmpty || newAttribute != attributeStack.last);
    if (pushToStack) {
      attributeStack.add(newAttribute);
    }
    return pushToStack;
  }
}

class _PlainAttributeRunBuilder<Attribute extends Object> extends _AttributeRunBuilder<Attribute?, Attribute> with _NonOverlappingAttributeRunMixin<Attribute?, Attribute> {
  @override
  bool tryPush(Attribute? attribute) {
    final bool pushToStack = attribute != null && (attributeStack.isEmpty || attribute != attributeStack.last);
    if (pushToStack) {
      attributeStack.add(attribute);
    }
    return pushToStack;
  }
}

class _HitTestTargetRunBuilder extends _AttributeRunBuilder<TextSpan, Iterable<TextSpan>> {
  final List<TextSpan> attributeStack = <TextSpan>[];

  @override
  bool tryPush(TextSpan span) {
    final TextSpan? topOfStack = attributeStack.isEmpty ? null : attributeStack.last;
    final bool pushToStack = (span.recognizer != null && span.recognizer != topOfStack?.recognizer)
                          || (span.onEnter != null && span.onEnter != topOfStack?.onEnter)
                          || (span.onExit != null && span.onExit != topOfStack?.onExit)
                          || (!identical(span.mouseCursor, MouseCursor.defer) && !identical(span.mouseCursor, topOfStack?.mouseCursor));
    if (pushToStack) {
      attributeStack.add(span);
    }
    return pushToStack;
  }

  @override
  void pop() {
    assert(attributeStack.isNotEmpty);
    attributeStack.removeLast();
  }
  @override
  void commitText(int length) {
    assert(length > 0);
    final TextSpan? currentSpan = runs.isEmpty ? null : runs.last.$2.last;
    // Start a new run only if the attributes are different.
    if (attributeStack.isNotEmpty && currentSpan != attributeStack.last) {
      runs.add((runStartIndex, attributeStack));
    }
    runStartIndex += length;
  }
}

AnnotatedString _convertTextStyleAttributes(InlineSpan span, AnnotatedString string) {
  final fontFamilies = _TextStyleAttributeRunBuilder<List<String>>(_getFontFamilies);
  final locale = _TextStyleAttributeRunBuilder<ui.Locale>(_getLocale);
  final fontWeight = _TextStyleAttributeRunBuilder<ui.FontWeight>(_getFontWeight);
  final fontStyle = _TextStyleAttributeRunBuilder<ui.FontStyle>(_getFontStyle);
  final fontFeatures = _TextStyleAttributeRunBuilder<List<ui.FontFeature>>(_getFontFeatures);
  final fontVariations = _TextStyleAttributeRunBuilder<List<ui.FontVariation>>(_getFontVariations);
  final textBaseline = _TextStyleAttributeRunBuilder<ui.TextBaseline>(_getTextBaseline);
  final leadingDistribution = _TextStyleAttributeRunBuilder<ui.TextLeadingDistribution>(_getLeadingDistribution);
  final fontSize = _TextStyleAttributeRunBuilder<double>(_getFontSize);
  final height = _TextStyleAttributeRunBuilder<double>(_getHeight);
  final letterSpacing = _TextStyleAttributeRunBuilder<double>(_getLetterSpacing);
  final wordSpacing = _TextStyleAttributeRunBuilder<double>(_getWordSpacing);

  final foreground = _TextStyleAttributeRunBuilder<Either<ui.Color, ui.Paint>>(_getForeground);
  final background = _TextStyleAttributeRunBuilder<Either<ui.Color, ui.Paint>>(_getBackground);
  final underline = _TextStyleAttributeRunBuilder<bool>(_getUnderline);
  final overline = _TextStyleAttributeRunBuilder<bool>(_getOverline);
  final lineThrough = _TextStyleAttributeRunBuilder<bool>(_getLineThrough);
  final decorationColor = _TextStyleAttributeRunBuilder<ui.Color>(_getDecorationColor);
  final decorationStyle = _TextStyleAttributeRunBuilder<ui.TextDecorationStyle>(_getDecorationStyle);
  final decorationThickness = _TextStyleAttributeRunBuilder<double>(_getDecorationThickness);
  final shadows = _TextStyleAttributeRunBuilder<List<ui.Shadow>>(_getShadows);

  final List<_TextStyleAttributeRunBuilder<Object>> attributes = <_TextStyleAttributeRunBuilder<Object>>[
    fontFamilies,
    locale,
    fontWeight,
    fontStyle,
    fontFeatures,
    fontVariations,
    textBaseline,
    leadingDistribution,
    fontSize,
    height,
    letterSpacing,
    wordSpacing,

    foreground,
    background,
    underline,
    overline,
    lineThrough,
    decorationColor,
    decorationStyle,
    decorationThickness,
    shadows,
  ];

  bool visitSpan(InlineSpan span) {
    List<_AttributeRunBuilder<Object?, Object?>>? buildersToPop;
    final TextStyle? style = span.style;
    if (style != null) {
      for (final attribute in attributes) {
        if (attribute.tryPush(style)) {
          (buildersToPop ??= <_AttributeRunBuilder<Object?, Object?>>[]).add(attribute);
        }
      }
    }
    final int textLength = switch (span) {
      TextSpan(:final String? text) => text?.length ?? 0,
      PlaceholderSpan() => 1,
      _ => 0,
    };
    if (textLength > 0) {
      for (final _TextStyleAttributeRunBuilder<Object> attribute in attributes) {
        attribute.commitText(textLength);
      }
    }
    span.visitDirectChildren(visitSpan);
    if (buildersToPop != null) {
      for (int i = 0; i < buildersToPop.length; i += 1) {
        buildersToPop[i].pop();
      }
    }
    return true;
  }

  // Only extract
  span.visitChildren(visitSpan);
  final TextStyleAnnotations textStyleAnnotations = TextStyleAnnotations._(
    fontFamilies.build(),
    locale.build(),
    fontWeight.build(),
    fontStyle.build(),
    fontFeatures.build(),
    fontVariations.build(),
    textBaseline.build(),
    leadingDistribution.build(),
    fontSize.build(),
    height.build(),
    letterSpacing.build(),
    wordSpacing.build(),
    foreground.build(),
    background.build(),
    underline.build(),
    overline.build(),
    lineThrough.build(),
    decorationColor.build(),
    decorationStyle.build(),
    decorationThickness.build(),
    shadows.build(),

    string.string.length,
    span.style ?? const TextStyle(),
  );

  return string.setAnnotationOfType(textStyleAnnotations);
}

AnnotatedString _inlineSpanToTextStyleAnnotations(InlineSpan span, String string) {

  // Hit test
  final hitTests = _HitTestTargetRunBuilder();

  // Semantics
  final semanticsLabels = _PlainAttributeRunBuilder<String>();
  final spellOuts = _PlainAttributeRunBuilder<bool>();
  final semanticGestureCallbacks = _PlainAttributeRunBuilder<Either<VoidCallback, VoidCallback>>();

  bool visitSpan(InlineSpan span) {
    List<_AttributeRunBuilder<Object?, Object?>>? buildersToPop;
    void tryPush<Source>(_AttributeRunBuilder<Source, Object?> builder, Source newValue) {
      if (builder.tryPush(newValue)) {
        if (buildersToPop == null) {
          buildersToPop = [builder];
        } else {
          buildersToPop!.add(builder);
        }
      }
    }

    switch (span) {
      case TextSpan(:final String? text, :final style, :final semanticsLabel, :final spellOut, :final recognizer):
        tryPush(semanticsLabels, semanticsLabel);
        tryPush(spellOuts, spellOut);
        tryPush(hitTests, span);
        switch (recognizer) {
          case TapGestureRecognizer(:final VoidCallback onTap) || DoubleTapGestureRecognizer(onDoubleTap: final VoidCallback onTap):
            tryPush(semanticGestureCallbacks, Either.left(onTap));
          case LongPressGestureRecognizer(:final VoidCallback onLongPress):
            tryPush(semanticGestureCallbacks, Either.right(onLongPress));
          case _:
            break;
        }

        final textLength = text?.length ?? 0;
        if (textLength > 0) {
          semanticsLabels.commitText(textLength);
          spellOuts.commitText(textLength);
          semanticGestureCallbacks.commitText(textLength);
        }

      case PlaceholderSpan():
        // Ignore styles?
        semanticsLabels.commitText(1);
        spellOuts.commitText(1);
        semanticGestureCallbacks.commitText(1);
        hitTests.commitText(1);
      default:
        assert(false, 'unknown span type: $span');
    }

    span.visitDirectChildren(visitSpan);
    final toPop = buildersToPop;
    if (toPop != null) {
      for (int i = 0; i < toPop.length; i += 1) {
        toPop[i].pop();
      }
    }
    return true;
  }

  visitSpan(span);
  final TextHitTestAnnotations textHitTestAnnotations = TextHitTestAnnotations._(hitTests.build());

  final semanticsAnnotations = SemanticsAnnotations._(
    semanticsLabels.build(),
    spellOuts.build(),
    semanticGestureCallbacks.build(),
  );

  final storage = const PersistentHashMap<Type, StringAnnotation<Object>?>.empty()
    .put(_HitTestAnnotationKey, textHitTestAnnotations)
    .put(_SemanticsAnnotationKey, semanticsAnnotations);

  return AnnotatedString._(string, storage);
}

AnnotatedString _extractFromInlineSpan(InlineSpan span) {
  final String string = span.toPlainText(includeSemanticsLabels: false);
  return _inlineSpanToTextStyleAnnotations(span, string);
}

/// An immutable represetation of
@immutable
class AnnotatedString {
  const AnnotatedString._(this.string, this._attributeStorage);

  AnnotatedString._fromAnnotatedString(AnnotatedString string) :
    string = string.string,
    _attributeStorage = string._attributeStorage;

  AnnotatedString.fromInlineSpan(InlineSpan span) : this._fromAnnotatedString(_extractFromInlineSpan(span));

  final String string;

  // The PersistentHashMap class currently does not have a delete method.
  final PersistentHashMap<Type, StringAnnotation<Object>?> _attributeStorage;

  // Read annotations of a specific type.
  T? getAnnotationOfType<T extends StringAnnotation<Key>, Key extends Object>() => _attributeStorage[Key] as T?;

  /// Update annotations of a specific type `T` and return a new [AnnotatedString].
  ///
  /// The static type `T` is used as the key insead of the runtime type of
  /// newAnnotations, in case newAnnotations is null (and for consistency too).
  AnnotatedString setAnnotationOfType<T extends StringAnnotation<Key>, Key extends Object>(T? newAnnotations) {
    return AnnotatedString._(string, _attributeStorage.put(Key, newAnnotations));
  }
}

interface class StringAnnotation<Key extends Object> { }
