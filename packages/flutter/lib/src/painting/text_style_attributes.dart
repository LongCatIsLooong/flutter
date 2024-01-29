// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/src/painting/basic_types.dart';

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

class TextAttributeIterable<T extends Object> implements TextStyleAttributeGetter<T> {
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

Either<ui.Color, ui.Paint>? _getForeground(TextStyle textStyle) => _applyNullable(Left.new, textStyle.color) ?? _applyNullable(Right.new, textStyle.foreground);
Either<ui.Color, ui.Paint>? _getBackground(TextStyle textStyle) => _applyNullable(Left.new, textStyle.backgroundColor) ?? _applyNullable(Right.new, textStyle.background);
bool? _getUnderline(TextStyle textStyle) => textStyle.decoration?.contains(TextDecoration.underline);
bool? _getOverline(TextStyle textStyle) => textStyle.decoration?.contains(TextDecoration.overline);
bool? _getLineThrough(TextStyle textStyle) => textStyle.decoration?.contains(TextDecoration.lineThrough);
ui.Color? _getDecorationColor(TextStyle textStyle) => textStyle.decorationColor;
ui.TextDecorationStyle? _getDecorationStyle(TextStyle textStyle) => textStyle.decorationStyle;
double? _getDecorationThickness(TextStyle textStyle) => textStyle.decorationThickness;
List<ui.Shadow>? _getShadows(TextStyle textStyle) => textStyle.shadows;


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
    this._textLength,
    this.defaults,
  );

  static TextAttributeIterable<Value> _createAttribute<Value extends Object>(RBTree<Value?>? storage, Value defaultValue, TextStyle Function(Value) lift) {
    return TextAttributeIterable<Value>._(storage, defaultValue, lift);
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
  late final TextAttributeIterable<List<String>> fontFamilies = _createAttribute(_fontFamilies, _getFontFamilies(defaults)!, _liftFontFamilies);

  final RBTree<ui.Locale?>? _locale;
  late final TextAttributeIterable<ui.Locale> locale = _createAttribute(_locale, defaults.locale!, _liftLocale);

  final RBTree<double?>? _fontSize;
  late final TextAttributeIterable<double> fontSize = _createAttribute(_fontSize, defaults.fontSize!, _liftFontSize);

  final RBTree<ui.FontWeight?>? _fontWeight;
  late final TextAttributeIterable<ui.FontWeight> fontWeight = _createAttribute(_fontWeight, defaults.fontWeight!, _liftFontWeight);

  final RBTree<ui.FontStyle?>? _fontStyle;
  late final TextAttributeIterable<ui.FontStyle> fontStyle = _createAttribute(_fontStyle, defaults.fontStyle!, _liftFontStyle);

  final RBTree<List<ui.FontFeature>?>? _fontFeatures;
  late final TextAttributeIterable<List<ui.FontFeature>> fontFeatures = _createAttribute(_fontFeatures, defaults.fontFeatures!, _liftFontFeatures);

  final RBTree<List<ui.FontVariation>?>? _fontVariations;
  late final TextAttributeIterable<List<ui.FontVariation>> fontVariations = _createAttribute(_fontVariations, defaults.fontVariations!, _liftFontVariations);

  final RBTree<ui.TextLeadingDistribution?>? _leadingDistribution;
  late final TextAttributeIterable<ui.TextLeadingDistribution> leadingDistribution = _createAttribute(_leadingDistribution, defaults.leadingDistribution!, _liftLeadingDistribution);

  final RBTree<double?>? _height;
  late final TextAttributeIterable<double> height = _createAttribute(_height, defaults.height!, _liftHeight);

  final RBTree<ui.TextBaseline?>? _textBaseline;
  late final TextAttributeIterable<ui.TextBaseline> textBaseline = _createAttribute(_textBaseline, defaults.textBaseline!, _liftTextBaseline);

  final RBTree<double?>? _letterSpacing;
  late final TextAttributeIterable<double> letterSpacing = _createAttribute(_letterSpacing, defaults.letterSpacing!, _liftLetterSpacing);
  final RBTree<double?>? _wordSpacing;
  late final TextAttributeIterable<double> wordSpacing = _createAttribute(_wordSpacing, defaults.wordSpacing!, _liftWordSpacing);

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
      ..[5] = fontVariations._getTextStyleRunsEndAfter(index)
      ..[6] = fontFeatures._getTextStyleRunsEndAfter(index)
      ..[7] = height._getTextStyleRunsEndAfter(index)
      ..[8] = leadingDistribution._getTextStyleRunsEndAfter(index)
      ..[9] = textBaseline._getTextStyleRunsEndAfter(index)
      ..[10] = wordSpacing._getTextStyleRunsEndAfter(index)
      ..[11] = letterSpacing._getTextStyleRunsEndAfter(index);
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
      update(annotationsToOverwrite.fontFeatures, _fontFeatures),
      update(annotationsToOverwrite.fontVariations, _fontVariations),
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
    this.fontFeatures,
    this.fontVariations,
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

  final List<ui.FontFeature>? fontFeatures;
  final List<ui.FontVariation>? fontVariations;

  final double? height;
  final ui.TextLeadingDistribution? textLeadingDistribution;
  final ui.TextBaseline? textBaseline;

  final double? wordSpacing;
  final double? letterSpacing;
}

abstract final class _TextPaintAnnotationKey { }

@immutable
final class TextPaintAnnotations implements StringAnnotation<_TextPaintAnnotationKey> {
  TextPaintAnnotations._(
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
    this.baseAnnotations,
  );

  final RBTree<Either<ui.Color, ui.Paint>?>? _foreground;
  final RBTree<Either<ui.Color, ui.Paint>?>? _background;

  final RBTree<bool?>? _underline;
  final RBTree<bool?>? _overline;
  final RBTree<bool?>? _lineThrough;

  final RBTree<ui.Color?>? _decorationColor;
  final RBTree<ui.TextDecorationStyle?>? _decorationStyle;
  final RBTree<double?>? _decorationThickness;

  final RBTree<List<ui.Shadow>?>? _shadows;

  final TextStyle baseAnnotations;
  final int _textLength;
}

final class TextPaintAttributionSet {
  const TextPaintAttributionSet({
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

  final RBTree<List<HitTestTarget>> _hitTestTargets;

  Iterable<HitTestTarget> getHitTestTargets(int codeUnitOffset) {
    final iterator = _hitTestTargets.getRunsEndAfter(codeUnitOffset);
    return iterator.moveNext() ? iterator.current.$2 : const <HitTestTarget>[];
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

class _AttributeStackEntry<Value extends Object> {
  _AttributeStackEntry(this.value);
  final Value value;
  int repeatCount = 1;
}

// A class for extracting attribute (such as the font size) runs from an InlineSpan.
//
// Each attribute run is a pair of the starting index of the attribute in the
// string, and value of the attribute. For instance if the font size runs are
// [(0, 10), (5, 20)], it means the text starts with a font size of 10 and
// starting from the 5th code unit the font size changes to 20.

abstract class _AttributeRunBuilder<Source extends Object, Attribute extends Object> {
  final List<_AttributeStackEntry<Attribute>> attributeStack = <_AttributeStackEntry<Attribute>>[];
  final List<(int, Attribute)> runs = <(int, Attribute)>[];
  int runStartIndex = 0;

  void push(Source? attribute);
  void pop() {
    if (attributeStack.isEmpty) {
      return;
    }
    final _AttributeStackEntry<Attribute> topOfStack = attributeStack.last;
    if (topOfStack.repeatCount > 1) {
      topOfStack.repeatCount -= 1;
    } else {
      attributeStack.removeLast();
    }
  }
  void commitText(int length) {
    if (length == 0) {
      return;
    }
    final Attribute? currentRunAttribute = runs.isEmpty ? null : runs.last.$2;
    // Start a new run only if the attributes are different.
    if (attributeStack.isNotEmpty && currentRunAttribute != attributeStack.last.value) {
      runs.add((runStartIndex, attributeStack.last.value));
    }
    runStartIndex += length;
  }
  RBTree<Attribute?> build() => RBTree<Attribute?>.fromSortedList(runs);
}

class _TextStyleAttributeRunBuilder<Attribute extends Object> extends _AttributeRunBuilder<TextStyle, Attribute> {
  _TextStyleAttributeRunBuilder(this.getAttribute);
  final Attribute? Function(TextStyle) getAttribute;
  @override
  void push(TextStyle? textStyle) {
    if (textStyle == null) {
      return;
    }
    final Attribute? newAttribute = getAttribute(textStyle);
    final _AttributeStackEntry<Attribute>? topOfStack = attributeStack.isEmpty ? null : attributeStack.last;
    if (newAttribute == null || newAttribute == topOfStack?.value) {
      topOfStack?.repeatCount += 1;
    } else {
      attributeStack.add(_AttributeStackEntry<Attribute>(newAttribute));
    }
  }
}

class _PlainAttributeRunBuilder<Attribute extends Object> extends _AttributeRunBuilder<Attribute, Attribute> {
  _PlainAttributeRunBuilder();

  @override
  void push(Attribute? attribute) {
    if (attribute == null) {
      return;
    }
    final _AttributeStackEntry<Attribute>? topOfStack = attributeStack.isEmpty ? null : attributeStack.last;
    if (attribute == topOfStack?.value) {
      topOfStack?.repeatCount += 1;
    } else {
      attributeStack.add(_AttributeStackEntry<Attribute>(attribute));
    }
  }
}

AnnotatedString _inlineSpanToTextStyleAnnotations(InlineSpan span, String string) {
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

  // Semantics
  final semanticsLabels = _PlainAttributeRunBuilder<String>();
  final spellOuts = _PlainAttributeRunBuilder<bool>();
  final semanticGestureCallbacks = _PlainAttributeRunBuilder<Either<VoidCallback, VoidCallback>>();

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
    final int textLength;
    final bool hasSemanticsLabel;
    final bool hasSpellOut;
    final bool hasSemanticsGestureCallback;
    switch (span) {
      case TextSpan(: final String? text, :final semanticsLabel, :final spellOut, :final recognizer):
        textLength = text?.length ?? 0;
        hasSemanticsLabel = semanticsLabel != null;
        hasSpellOut = spellOut != null;
        spellOuts.push(spellOut);
        semanticsLabels.push(semanticsLabel);
        switch (recognizer) {
          case TapGestureRecognizer(:final VoidCallback onTap) || DoubleTapGestureRecognizer(onDoubleTap: final VoidCallback onTap):
            hasSemanticsGestureCallback = true;
            semanticGestureCallbacks.push(Left(onTap));
          case LongPressGestureRecognizer(:final VoidCallback onLongPress):
            hasSemanticsGestureCallback = true;
            semanticGestureCallbacks.push(Right(onLongPress));
          case _:
            hasSemanticsGestureCallback = false;
        }

      case PlaceholderSpan():
        textLength = 1;
        hasSemanticsLabel = false;
        hasSpellOut = false;
        hasSemanticsGestureCallback = false;
      default:
        assert(false, 'unknown span type: $span');
        textLength = 0;
        hasSemanticsLabel = false;
        hasSpellOut = false;
        hasSemanticsGestureCallback = false;
    }

    final styleToPush = span.style;
    if (styleToPush != null || textLength > 0) {
      for (final attribute in attributes) {
        attribute.push(styleToPush);
        semanticsLabels.commitText(textLength);
        spellOuts.commitText(textLength);
        attribute.commitText(textLength);
        semanticGestureCallbacks.commitText(textLength);
      }
    }

    span.visitDirectChildren(visitSpan);
    if (styleToPush != null) {
      for (final attribute in attributes) {
        attribute.pop();
      }
    }
    if (hasSpellOut) {
      spellOuts.pop();
    }
    if (hasSemanticsLabel) {
      semanticsLabels.pop();
    }
    if (hasSemanticsGestureCallback) {
      semanticGestureCallbacks.pop();
    }

    return true;
  }

  visitSpan(span);
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
    string.length,
    const TextStyle(),
  );
  final TextPaintAnnotations textPaintAnnotations = TextPaintAnnotations._(
    foreground.build(),
    background.build(),
    underline.build(),
    overline.build(),
    lineThrough.build(),
    decorationColor.build(),
    decorationStyle.build(),
    decorationThickness.build(),
    shadows.build(),
    string.length,
    const TextStyle(),
  );

  final TextHitTestAnnotations textHitTestAnnotations = TextHitTestAnnotations._(
  );

  final semanticsAnnotations = SemanticsAnnotations._(
    semanticsLabels.build(),
    spellOuts.build(),
    semanticGestureCallbacks.build(),
  );

  final storage = const PersistentHashMap<Type, StringAnnotation<Object>?>.empty()
    .put(_TextPaintAnnotationKey, textPaintAnnotations)
    .put(_TextStyleAnnotationKey, textStyleAnnotations)
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
