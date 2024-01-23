// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'text_style.dart';

// TODO: dedup
// When end is null, it is treated as +∞ and is special cased to enable faster
// processing.
RBTree<Value?>? _insertRange<Value extends Object>(RBTree<Value?>? tree, int start, int? end, Value? value) {
  assert(start >= 0);
  assert(end == null || end > start);
  if (tree == null) {
    return value == null
      ? null
      : RBTree<Value?>.fromSortedList(<(int, Value?)>[
          (start, value),
          if (end != null) (end, null),
      ]);
  }
  // Split this tree into two rb trees: in the first tree keys are always less
  // than `start`, and in the second tree keys are always greater than or equal
  // to than `end`.
  final RBTree<Value?>? leftTree = start == 0 ? null : tree.takeLessThan(start);
  final RBTree<Value?>? rightTreeWithoutEnd = end == null ? null : tree.skipUntil(end);

  final RBTree<Value?>? nodeAtEnd = end == null ? null : tree.getNodeLessThanOrEqualTo(end);
  final RBTree<Value?>? rightTree = nodeAtEnd == null || nodeAtEnd.key == end
    ? rightTreeWithoutEnd
    : rightTreeWithoutEnd?.insert(end!, nodeAtEnd.value) ?? RBTree<Value?>.black(end!, nodeAtEnd.value);

  return leftTree != null && rightTree != null
    ? leftTree.join(rightTree, start, value)
    : (leftTree ?? rightTree)?.insert(start, value) ?? RBTree<Value?>.black(start, value);
}

class TextAttributeIterable<T extends Object> {
  TextAttributeIterable._(this._storage, this._defaultValue, this._lift);

  final RBTree<T?>? _storage;
  final T _defaultValue;
  final TextStyle Function(T) _lift;

  (int, T) _map((int, T?) pair) => (pair.$1, pair.$2 ?? _defaultValue);

  Iterator<(int, T)> getRunsEndAfter(int index) {
    final storage = _storage;
    return storage == null
      ? _EmptyIterator<(int, T)>()
      : _MapIterator<(int, T?), (int, T)>(storage.getRunsEndAfter(index), _map);
  }

  (int, TextStyle) _liftToTextStyle((int, T?) pair) => (pair.$1, _lift(pair.$2 ?? _defaultValue));

  _RunIterator<TextStyle> _getTextStyleRunsEndAfter(int index) {
    final storage = _storage;
    final innerIterator = storage == null
      ? const _EmptyIterator<(int, TextStyle)>()
      : _MapIterator<(int, T?), (int, TextStyle)>(storage.getRunsEndAfter(index), _liftToTextStyle);
    return _RunIterator<TextStyle>(innerIterator);
  }
}

/// For font features, font variations.
///
/// The TextStyle.merge method can't merge 2 TextStyles with different
class _DynamicAttributeIterable<T extends Object> { //implements TextAttributeIterable<List<(String, T)>>
  _DynamicAttributeIterable(this._storage, this._defaultValue, this._lift);

  final PersistentHashMap<String, RBTree<T?>?> _storage;
  final Map<String, T> _defaultValue;
  final TextStyle Function(Map<String, T>) _lift;

  //Iterator<(int, Iterable<String, T>)> getRunsEndAfter(int index) {
  //  return _MapIterator<RBTree<T?>, (int, T)>(_storage.getRunsEndAfter(index), _map);
  //}

  (int, TextStyle) _liftSnd((int, Map<String, T>) pair) => (pair.$1, _lift(pair.$2));

  _RunIterator<TextStyle> _getTextStyleRunsEndAfter(int index) {
    final List<_RunIterator<(String, T?)>> attributes = _storage.entries.map((MapEntry<String, RBTree<T?>?> e) {
      (int, (String, T?)) transform((int, T?) pair) => (pair.$1, (e.key, pair.$2));
      final storage = e.value;
      final innerIterator = storage == null
        ? _EmptyIterator<(int, (String, T?))>()
        : _MapIterator<(int, T?), (int, (String, T?))>(storage.getRunsEndAfter(index), transform);
      return _RunIterator<(String, T?)>(innerIterator);
    }).toList(growable: false);

    final _AccumulativeMergedRunIterator<T> merged = _AccumulativeMergedRunIterator<T>(attributes, _defaultValue);
    return _RunIterator<TextStyle>(_MapIterator(merged, _liftSnd));
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

@immutable
class TextStyleAnnotations {
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
    this._textLength,
    this.defaults,
  );

  static TextStyle _liftFontFamilies(List<String> input) => switch (input) {
    [] => TextStyle(),
    [final fontFamily, ...final fontFamilyFallback] => TextStyle(fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback),
  };
  static TextStyle _liftLocale(ui.Locale input) => TextStyle(locale: input);
  static TextStyle _liftFontSize(double input) => TextStyle(fontSize: input);
  static TextStyle _liftFontWeight(ui.FontWeight input) => TextStyle(fontWeight: input);
  static TextStyle _liftFontStyle(ui.FontStyle input) => TextStyle(fontStyle: input);
  static TextStyle _liftHeight(double input) => TextStyle(height: input);
  static TextStyle _liftLeadingDistribution(ui.TextLeadingDistribution input) => TextStyle(leadingDistribution: input);
  static TextStyle _liftTextBaseline(ui.TextBaseline input) => TextStyle(textBaseline: input);
  static TextStyle _liftWordSpacing(double input) => TextStyle(wordSpacing: input);
  static TextStyle _liftLetterSpacing(double input) => TextStyle(letterSpacing: input);

  static Map<String, double> _fontVariationsToMap(List<ui.FontVariation>? input) {
    return input == null
      ? const <String, double>{}
      : Map<String, double>.fromEntries(input.map((ui.FontVariation e) => MapEntry<String, double>(e.axis, e.value)));
  }
  static Map<String, int> _fontFeaturesToMap(List<ui.FontFeature>? input) {
    return input == null
      ? const <String, int>{}
      : Map<String, int>.fromEntries(input.map((e) => MapEntry<String, int>(e.feature, e.value)));
  }
  static TextStyle _liftFontVariations(Map<String, double> input) => TextStyle(fontVariations: input.entries.map((MapEntry<String, double> entry) => ui.FontVariation(entry.key, entry.value)).toList(growable: false));
  static TextStyle _liftFontFeatures(Map<String, int> input) => TextStyle(fontFeatures: input.entries.map((MapEntry<String, int> entry) => ui.FontFeature(entry.key, entry.value)).toList(growable: false));
  static List<String> _getFontFamilies(TextStyle textStyle) {
    final String? fontFamily = textStyle.fontFamily;
    return <String>[
      if (fontFamily != null) fontFamily,
      ...?textStyle.fontFamilyFallback,
    ];
  }

  final TextStyle defaults;
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
  late final TextAttributeIterable<List<String>> fontFamilies = TextAttributeIterable<List<String>>._(_fontFamilies, _getFontFamilies(defaults), _liftFontFamilies);

  final RBTree<ui.Locale?>? _locale;
  late final TextAttributeIterable<ui.Locale> locale = TextAttributeIterable<ui.Locale>._(_locale, defaults.locale!, _liftLocale);

  final RBTree<double?>? _fontSize;
  late final TextAttributeIterable<double> fontSize = TextAttributeIterable<double>._(_fontSize, defaults.fontSize!, _liftFontSize);

  final RBTree<ui.FontWeight?>? _fontWeight;
  late final TextAttributeIterable<ui.FontWeight> fontWeight = TextAttributeIterable<ui.FontWeight>._(_fontWeight, defaults.fontWeight!, _liftFontWeight);

  final RBTree<ui.FontStyle?>? _fontStyle;
  late final TextAttributeIterable<ui.FontStyle> fontStyle = TextAttributeIterable<ui.FontStyle>._(_fontStyle, defaults.fontStyle!, _liftFontStyle);

  final PersistentHashMap<String, RBTree<int?>?> _fontFeatures;
  late final _DynamicAttributeIterable<int> fontFeatures = _DynamicAttributeIterable(_fontFeatures, _fontFeaturesToMap(defaults.fontFeatures), _liftFontFeatures);

  final PersistentHashMap<String, RBTree<double?>?> _fontVariations;
  late final _DynamicAttributeIterable<double> fontVariations = _DynamicAttributeIterable(_fontVariations, _fontVariationsToMap(defaults.fontVariations), _liftFontVariations);

  final RBTree<ui.TextLeadingDistribution?>? _leadingDistribution;
  late final TextAttributeIterable<ui.TextLeadingDistribution> leadingDistribution = TextAttributeIterable<ui.TextLeadingDistribution>._(_leadingDistribution, defaults.leadingDistribution!, _liftLeadingDistribution);

  final RBTree<double?>? _height;
  late final TextAttributeIterable<double> height = TextAttributeIterable<double>._(_height, defaults.height!, _liftHeight);

  final RBTree<ui.TextBaseline?>? _textBaseline;
  late final TextAttributeIterable<ui.TextBaseline> textBaseline = TextAttributeIterable<ui.TextBaseline>._(_textBaseline, defaults.textBaseline!, _liftTextBaseline);

  final RBTree<double?>? _letterSpacing;
  late final TextAttributeIterable<double> letterSpacing = TextAttributeIterable<double>._(_letterSpacing, defaults.letterSpacing!, _liftLetterSpacing);
  final RBTree<double?>? _wordSpacing;
  late final TextAttributeIterable<double> wordSpacing = TextAttributeIterable<double>._(_wordSpacing, defaults.wordSpacing!, _liftWordSpacing);

  TextStyle getAnnotationAt(int index) {
    final TextStyle textStyle = TextStyle(
      locale: _locale?.getNodeLessThanOrEqualTo(index)?.value,

      fontWeight: _fontWeight?.getNodeLessThanOrEqualTo(index)?.value,
      fontStyle: _fontStyle?.getNodeLessThanOrEqualTo(index)?.value,

      textBaseline: _textBaseline?.getNodeLessThanOrEqualTo(index)?.value,
      leadingDistribution: _leadingDistribution?.getNodeLessThanOrEqualTo(index)?.value,

      fontSize: _fontSize?.getNodeLessThanOrEqualTo(index)?.value,
      height: _height?.getNodeLessThanOrEqualTo(index)?.value,
      letterSpacing: _letterSpacing?.getNodeLessThanOrEqualTo(index)?.value,
      wordSpacing: _wordSpacing?.getNodeLessThanOrEqualTo(index)?.value,
    );
    return defaults.merge(textStyle);
  }

  Iterator<(int, TextStyle)> getRunsEndAfter(int index) {
    final _RunIterator<TextStyle> fontFamiliesRuns = fontFamilies._getTextStyleRunsEndAfter(index);
    final List<_RunIterator<TextStyle>> runsToMerge = List<_RunIterator<TextStyle>>.filled(12, fontFamiliesRuns)
      ..[1] = locale._getTextStyleRunsEndAfter(index)
      ..[2] = fontSize._getTextStyleRunsEndAfter(index)
      ..[3] = fontWeight._getTextStyleRunsEndAfter(index)
      ..[4] = fontStyle._getTextStyleRunsEndAfter(index)
      ..[5] = height._getTextStyleRunsEndAfter(index)
      ..[6] = leadingDistribution._getTextStyleRunsEndAfter(index)
      ..[7] = textBaseline._getTextStyleRunsEndAfter(index)
      ..[8] = wordSpacing._getTextStyleRunsEndAfter(index)
      ..[9] = letterSpacing._getTextStyleRunsEndAfter(index)
      ..[10] = fontVariations._getTextStyleRunsEndAfter(index)
      ..[11] = fontFeatures._getTextStyleRunsEndAfter(index);
    return _TextStyleMergingIterator(runsToMerge);
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
      annotationsToOverwrite.fontFeatures.entries.fold(_fontFeatures, updateMap),
      annotationsToOverwrite.fontVariations.entries.fold(_fontVariations, updateMap),
      update(annotationsToOverwrite.textBaseline, _textBaseline),
      update(annotationsToOverwrite.textLeadingDistribution, _leadingDistribution),
      update(annotationsToOverwrite.fontSize, _fontSize),
      update(annotationsToOverwrite.height, _height),
      update(annotationsToOverwrite.letterSpacing, _letterSpacing),
      update(annotationsToOverwrite.wordSpacing, _wordSpacing),
      _textLength,
      defaults,
    );
  }

  // Resets TextStyle attributes with non-null values to baseTextStyle.
  // I'm not sure this is really needed. Added for duality.
  TextStyleAnnotations erase(ui.TextRange range, TextStyleAttributeSet annotationsToErase) {
    final int? end = range.end >= _textLength ? null : range.end;

    RBTree<Value?>? erase<Value extends Object>(Value? newAttribute, RBTree<Value?>? tree) {
      return newAttribute == null ? tree : _insertRange(tree, range.start, end, null);
    }

    PersistentHashMap<String, RBTree<Value?>?> eraseFromMap<Value extends Object>(PersistentHashMap<String, RBTree<Value?>?> map, MapEntry<String, Value?> newAttribute) {
      final key = newAttribute.key;
      final newValue = newAttribute.value;
      if (newValue == null) {
        return map;
      }
      final tree = map[key];
      final newTree = _insertRange<Value>(tree, range.start, end, null);
      return identical(tree, newTree) ? map : map.put(key, newTree);
    }

    return TextStyleAnnotations._(
      erase(annotationsToErase.fontFamilies, _fontFamilies),
      erase(annotationsToErase.locale, _locale),
      erase(annotationsToErase.fontWeight, _fontWeight),
      erase(annotationsToErase.fontStyle, _fontStyle),
      annotationsToErase.fontFeatures.entries.fold(_fontFeatures, eraseFromMap),
      annotationsToErase.fontVariations.entries.fold(_fontVariations, eraseFromMap),
      erase(annotationsToErase.textBaseline, _textBaseline),
      erase(annotationsToErase.textLeadingDistribution, _leadingDistribution),
      erase(annotationsToErase.fontSize, _fontSize),
      erase(annotationsToErase.height, _height),
      erase(annotationsToErase.letterSpacing, _letterSpacing),
      erase(annotationsToErase.wordSpacing, _wordSpacing),
      _textLength,
      defaults,
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
    this.fontFeatures = const <String, int?>{},
    this.fontVariations = const <String, double?>{},
    this.height,
    this.textLeadingDistribution,
    this.textBaseline,
    this.wordSpacing,
    this.letterSpacing,
  });

  final List<String>? fontFamilies;
  final ui.Locale? locale;
  final double? fontSize;
  final ui.FontWeight? fontWeight;
  final ui.FontStyle? fontStyle;

  final Map<String, int?> fontFeatures;
  final Map<String, double?> fontVariations;

  final double? height;
  final ui.TextLeadingDistribution? textLeadingDistribution;
  final ui.TextBaseline? textBaseline;

  final double? wordSpacing;
  final double? letterSpacing;
}

final class TextPaintAnnotations {
  TextPaintAnnotations._(
    this.underline,
    this.overline,
    this.lineThrough,
    this.decorationColor,
    this.decorationStyle,
    this.decorationThickness,
    this.shadow,
  );

  final RBTree<bool> underline;
  final RBTree<bool> overline;
  final RBTree<bool> lineThrough;

  final RBTree<ui.Color> decorationColor;
  final RBTree<ui.TextDecorationStyle> decorationStyle;
  final RBTree<double> decorationThickness;

  final RBTree<ui.Shadow> shadow;
}

final class TextPaintAttributionSet {
  const TextPaintAttributionSet({
    this.foregroundColor,
    this.backgroundColor,
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

  final ui.Color? foregroundColor;
  final ui.Color? backgroundColor;
  // How do we compare ui.Paint objects?
  final ui.Paint? foreground;
  final ui.Paint? background;
  final List<ui.Shadow>? shadows;

  final bool? underline;
  final bool? overline;
  final bool? lineThrough;

  final ui.Color? decorationColor;
  final ui.TextDecorationStyle? decorationStyle;
  final double? decorationThickness;
}
