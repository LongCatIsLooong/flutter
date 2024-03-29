// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show MouseCursor;

import 'inline_span.dart';
import 'placeholder_span.dart';
import 'text_span.dart';
import 'text_style.dart';
import 'text_style_attributes.dart';

// ### NOTES
// 1. TextSpan interop
// 2. Font matching / Shaping / Layout / Paint subsystems
// 3. Hit-testing
// 4. Semantics


//typedef _TextStyleAttributeSetter<Attribute> = (void Function(_MutableTextStyleAttributeSet, Attribute), Attribute);
typedef _TextStyleAttributeSetter = ValueSetter<_MutableTextStyleAttributeSet>;

extension type FlatMap<T extends Object>(T? nullable) {
  @pragma('vm:prefer-inline')
  V? flatMap<V extends Object>(V? Function(T) transform) {
    final T? why = nullable;
    return why == null ? null : transform(why);
  }
}

// TODO: dedup
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
  final FlatMap<int> nullableEnd = FlatMap<int>(end);
  final RBTree<Value?>? rightTreeWithoutEnd = nullableEnd.flatMap(tree.skipUntil);
  final RBTree<Value?>? nodeAtEnd = nullableEnd.flatMap(tree.getNodeLessThanOrEqualTo);
  final RBTree<Value?>? rightTree = nodeAtEnd == null || nodeAtEnd.key == end
    ? rightTreeWithoutEnd
    : rightTreeWithoutEnd?.insert(nodeAtEnd.key, nodeAtEnd.value) ?? RBTree<Value?>.black(nodeAtEnd.key, nodeAtEnd.value);

  return leftTree != null && rightTree != null
    ? leftTree.join(rightTree, start, value)
    : (leftTree ?? rightTree)?.insert(start, value) ?? RBTree<Value?>.black(start, value);
}

abstract class Run<T> {
  Iterator<(int, T?)> getRunsEndAfter(int index);
}


extension type _RBTreeRun<Value extends Object>({ RBTree<Value?> tree }) implements Object {
}

class _RBTreeRun<T extends Object> implements Run<T> {
  _RBTreeRun(this.attributeRuns, this.defaultValue);

  final RBTree<T?>? attributeRuns;
  final T? defaultValue;

  @override
  Iterator<(int, T?)> getRunsEndAfter(int index) {
    return FlatMap(attributeRuns).flatMap(RBTreeTextRun.new)?.getRunsEndAfter(index, defaultValue)
      ?? const _EmptyIterator<(int, T)>();
  }
}

abstract class TextStyleAttributeGetter<T extends Object> {
  Iterator<(int, T?)> getRunsEndAfter(int index);
  Iterator<(int, _TextStyleAttributeSetter)>? _getTextStyleRunsEndAfter(int index);
}

class _AttributeIterable<Attribute extends Object> implements TextStyleAttributeGetter<Attribute> {
  _AttributeIterable(this.storage, this.defaultValue, this.setter);

  final RBTree<Attribute?>? storage;
  final Attribute? defaultValue;
  final _MutableTextStyleAttributeSet Function(_MutableTextStyleAttributeSet, Attribute?) setter;

  Attribute? _transform(Attribute? value) => value ?? defaultValue;

  @override
  Iterator<(int, Attribute?)> getRunsEndAfter(int index) {
    return _map(_transform, storage?.getRunsEndAfter(index))
        ?? const _EmptyIterator<(int, Attribute)>();
  }

  _TextStyleAttributeSetter _partiallyApply(Attribute? value) {
    return (_MutableTextStyleAttributeSet style) => setter(style, value ?? defaultValue);
  }

  @override
  Iterator<(int, _TextStyleAttributeSetter)>? _getTextStyleRunsEndAfter(int index) {
    return _map(_partiallyApply, storage?.getRunsEndAfter(index));
  }
}

class _EmptyIterator<T> implements Iterator<T> {
  const _EmptyIterator();
  @override
  bool moveNext() => false;
  @override
  T get current => throw FlutterError('unreachable');
}

/// Transforms the values emitted by an nullable indexed iterator using the given `transform` function.
@pragma('vm:prefer-inline')
Iterator<(int, V)>? _map<T, V>(V Function(T) transform, Iterator<(int, T)>? inner) {
  return inner == null ? null : _TransformedIndexedIterator<T, V>(inner, transform);
}

class _RunIteratorWithDefaultValue<T> implements Iterator<(int, T)> {
  _RunIteratorWithDefaultValue(this.inner, this.defaultValue)
    : _current = (0, defaultValue);

  final RBTree<(int, T)>? inner;
  final T defaultValue;

  bool pastIndexZero = false;
  (int, T) _current;
  @override
  (int, T) get current => _current;

  bool moveInnerNext() {
    final Iterator<(int, T)>? inner = this.inner;
    if (inner != null && inner.moveNext()) {
      final (int index, T value) = inner.current;
      _current = (index, value ?? defaultValue);
      return true;
    }

  }

  @override
  bool moveNext() {
    if (!pastIndexZero) {
      pastIndexZero = true;
      final Iterator<(int, T)>? inner = this.inner;
      if (inner != null && inner.moveNext()) {
        final (int index, T value) = inner.current;
        _current = (index, value ?? defaultValue);
        return true;
      }
      return defaultValue != null;
    }
    if (inner != null && inner.moveNext()) {
      final (int index, T value) = inner.current;
      _current = (index, transform(value));
      return true;
    }

  }
  return false;
}

class _TransformedIndexedIterator<T, V> implements Iterator<(int, V)> {
  _TransformedIndexedIterator(this.inner, this.transform);

  final Iterator<(int, T)> inner;
  final V Function(T) transform;

  late (int, V) _current;
  @override
  (int, V) get current => _current;

  @override
  bool moveNext() {
    if (inner.moveNext()) {
      final (int index, T value) = inner.current;
      _current = (index, transform(value));
      return true;
    }
    return false;
  }
}

typedef _AttributeRunsToMerge = List<Iterator<(int, _TextStyleAttributeSetter)>?>;
final class _TextStyleMergingIterator extends RunMergingIterator<_MutableTextStyleAttributeSet, _TextStyleAttributeSetter> {
  _TextStyleMergingIterator(super.attributes, super.baseStyle);

  @override
  _MutableTextStyleAttributeSet fold(_TextStyleAttributeSetter value, _MutableTextStyleAttributeSet accumulatedValue) {
    value(accumulatedValue);
    return accumulatedValue;
  }
}

_MutableTextStyleAttributeSet _setFontFamilies(_MutableTextStyleAttributeSet style, List<String>? input) => style..fontFamilies = input;
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

_MutableTextStyleAttributeSet _setLocale(_MutableTextStyleAttributeSet style, ui.Locale? input) => style..locale = input;
ui.Locale? _getLocale(TextStyle textStyle) => textStyle.locale;

_MutableTextStyleAttributeSet _setFontSize(_MutableTextStyleAttributeSet style, double? input) => style..fontSize = input;
double? _getFontSize(TextStyle textStyle) => textStyle.fontSize;

_MutableTextStyleAttributeSet _setFontWeight(_MutableTextStyleAttributeSet style, ui.FontWeight? input) => style..fontWeight = input;
ui.FontWeight?_getFontWeight(TextStyle textStyle) => textStyle.fontWeight;

_MutableTextStyleAttributeSet _setFontStyle(_MutableTextStyleAttributeSet style, ui.FontStyle? input) => style..fontStyle = input;
ui.FontStyle?_getFontStyle(TextStyle textStyle) => textStyle.fontStyle;

_MutableTextStyleAttributeSet _setFontFeatures(_MutableTextStyleAttributeSet style, List<ui.FontFeature>? input) => style..fontFeatures = input;
List<ui.FontFeature>?_getFontFeatures(TextStyle textStyle) => textStyle.fontFeatures;

_MutableTextStyleAttributeSet _setFontVariations(_MutableTextStyleAttributeSet style, List<ui.FontVariation>? input) => style..fontVariations = input;
List<ui.FontVariation>?_getFontVariations(TextStyle textStyle) => textStyle.fontVariations;

_MutableTextStyleAttributeSet _setHeight(_MutableTextStyleAttributeSet style, double? input) => style..height = input;
double? _getHeight(TextStyle textStyle) => textStyle.height;

_MutableTextStyleAttributeSet _setLeadingDistribution(_MutableTextStyleAttributeSet style, ui.TextLeadingDistribution? input) => style..leadingDistribution = input;
ui.TextLeadingDistribution? _getLeadingDistribution(TextStyle textStyle) => textStyle.leadingDistribution;

_MutableTextStyleAttributeSet _setTextBaseline(_MutableTextStyleAttributeSet style, ui.TextBaseline? input) => style..textBaseline = input;
ui.TextBaseline? _getTextBaseline(TextStyle textStyle) => textStyle.textBaseline;

_MutableTextStyleAttributeSet _setWordSpacing(_MutableTextStyleAttributeSet style, double? input) => style..wordSpacing = input;
double? _getWordSpacing(TextStyle textStyle) => textStyle.wordSpacing;

_MutableTextStyleAttributeSet _setLetterSpacing(_MutableTextStyleAttributeSet style, double? input) => style..letterSpacing = input;
double? _getLetterSpacing(TextStyle textStyle) => textStyle.letterSpacing;

_MutableTextStyleAttributeSet _setForeground(_MutableTextStyleAttributeSet style, Either<ui.Color, ui.Paint>? input) => style..foreground = input;
Either<ui.Color, ui.Paint>? _getForeground(TextStyle textStyle) => FlatMap(textStyle.color).flatMap(Left.new) ?? FlatMap(textStyle.foreground).flatMap(Right.new);

_MutableTextStyleAttributeSet _setBackground(_MutableTextStyleAttributeSet style, Either<ui.Color, ui.Paint>? input) => style..background = input;
Either<ui.Color, ui.Paint>? _getBackground(TextStyle textStyle) => FlatMap(textStyle.backgroundColor).flatMap(Left.new) ?? FlatMap(textStyle.background).flatMap(Right.new);

_MutableTextStyleAttributeSet _setDecorationColor(_MutableTextStyleAttributeSet style, ui.Color? input) => style..decorationColor = input;
ui.Color? _getDecorationColor(TextStyle textStyle) => textStyle.decorationColor;

_MutableTextStyleAttributeSet _setDecorationStyle(_MutableTextStyleAttributeSet style, ui.TextDecorationStyle? input) => style..decorationStyle = input;
ui.TextDecorationStyle? _getDecorationStyle(TextStyle textStyle) => textStyle.decorationStyle;

_MutableTextStyleAttributeSet _setDecorationThickness(_MutableTextStyleAttributeSet style, double? input) => style..decorationThickness = input;
double? _getDecorationThickness(TextStyle textStyle) => textStyle.decorationThickness;

List<ui.Shadow>? _getShadows(TextStyle textStyle) => textStyle.shadows;
_MutableTextStyleAttributeSet _setShadows(_MutableTextStyleAttributeSet style, List<ui.Shadow>? input) => style..shadows = input;

_MutableTextStyleAttributeSet _setUnderline(_MutableTextStyleAttributeSet style, bool? input) => style..underline = input;
_MutableTextStyleAttributeSet _setOverline(_MutableTextStyleAttributeSet style, bool? input) => style..overline = input;
_MutableTextStyleAttributeSet _setLineThrough(_MutableTextStyleAttributeSet style, bool? input) => style..lineThrough = input;

bool? _getUnderline(TextStyle textStyle) => textStyle.decoration?.contains(ui.TextDecoration.underline);
bool? _getOverline(TextStyle textStyle) => textStyle.decoration?.contains(ui.TextDecoration.overline);
bool? _getLineThrough(TextStyle textStyle) => textStyle.decoration?.contains(ui.TextDecoration.lineThrough);

final class _MutableTextStyleAttributeSet implements TextStyleAttributeSet {
  _MutableTextStyleAttributeSet({
    this.fontFamilies,
    this.locale,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.fontFeatures,
    this.fontVariations,
    this.height,
    this.leadingDistribution,
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

  _MutableTextStyleAttributeSet.fromTextStyle(TextStyle textStyle)
   : fontFamilies = _getFontFamilies(textStyle),
     locale = _getLocale(textStyle),
     fontSize = _getFontSize(textStyle),
     fontWeight = _getFontWeight(textStyle),
     fontStyle = _getFontStyle(textStyle),
     fontFeatures = _getFontFeatures(textStyle),
     fontVariations = _getFontVariations(textStyle),
     height = _getHeight(textStyle),
     leadingDistribution = _getLeadingDistribution(textStyle),
     textBaseline = _getTextBaseline(textStyle),
     wordSpacing = _getWordSpacing(textStyle),
     letterSpacing = _getLetterSpacing(textStyle),
     foreground = _getForeground(textStyle),
     background = _getBackground(textStyle),
     shadows = _getShadows(textStyle),
     underline = _getUnderline(textStyle),
     overline = _getOverline(textStyle),
     lineThrough = _getLineThrough(textStyle),
     decorationColor = _getDecorationColor(textStyle),
     decorationStyle = _getDecorationStyle(textStyle),
     decorationThickness = _getDecorationThickness(textStyle);

  @override
  List<String>? fontFamilies;
  @override
  ui.Locale? locale;
  @override
  double? fontSize;
  @override
  ui.FontWeight? fontWeight;
  @override
  ui.FontStyle? fontStyle;

  @override
  List<ui.FontFeature>? fontFeatures;
  @override
  List<ui.FontVariation>? fontVariations;

  @override
  double? height;
  @override
  ui.TextLeadingDistribution? leadingDistribution;
  @override
  ui.TextBaseline? textBaseline;

  @override
  double? wordSpacing;
  @override
  double? letterSpacing;

  @override
  Either<ui.Color, ui.Paint>? foreground;
  @override
  Either<ui.Color, ui.Paint>? background;
  @override
  List<ui.Shadow>? shadows;

  @override
  bool? underline;
  @override
  bool? overline;
  @override
  bool? lineThrough;

  @override
  ui.Color? decorationColor;
  @override
  ui.TextDecorationStyle? decorationStyle;
  @override
  double? decorationThickness;
}

@immutable
class TextStyleAnnotations implements BasicTextStyleAnnotations {
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

  factory TextStyleAnnotations.fromInlineSpan(InlineSpan span) {
    int debugStringLength = -1;
    assert(() {
      debugStringLength = span.string.length;
      return true;
    }());
    return _convertTextStyleAttributes(span, debugStringLength);
  }

  //static _AttributeIterable<Value> _AttributeIterable<Value extends Object>(
  //  RBTree<Value?>? storage,
  //  Value defaultValue,
  //  _MutableTextStyleAttributeSet Function(_MutableTextStyleAttributeSet, Value?) setter,
  //) {
  //  return _AttributeIterable<Value>(storage, defaultValue, setter);
  //}

  @override
  final TextStyle baseStyle;
  @override
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

      _foreground,
      _background,
      _underline,
      _overline,
      _lineThrough,
      _decorationColor,
      _decorationStyle,
      _decorationThickness,
      _shadows,

      _textLength,
      baseAnnotations,
    );
  }

  final int _textLength;

  final RBTree<List<String>?>? _fontFamilies;
  late final TextStyleAttributeGetter<List<String>> fontFamilies = _AttributeIterable(_fontFamilies, _getFontFamilies(baseStyle), _setFontFamilies);

  final RBTree<ui.Locale?>? _locale;
  late final TextStyleAttributeGetter<ui.Locale> locale = _AttributeIterable(_locale, baseStyle.locale, _setLocale);

  final RBTree<double?>? _fontSize;
  late final TextStyleAttributeGetter<double> fontSize = _AttributeIterable(_fontSize, baseStyle.fontSize, _setFontSize);

  final RBTree<ui.FontWeight?>? _fontWeight;
  late final TextStyleAttributeGetter<ui.FontWeight> fontWeight = _AttributeIterable(_fontWeight, baseStyle.fontWeight, _setFontWeight);

  final RBTree<ui.FontStyle?>? _fontStyle;
  late final TextStyleAttributeGetter<ui.FontStyle> fontStyle = _AttributeIterable(_fontStyle, baseStyle.fontStyle, _setFontStyle);

  final RBTree<List<ui.FontFeature>?>? _fontFeatures;
  late final TextStyleAttributeGetter<List<ui.FontFeature>> fontFeatures = _AttributeIterable(_fontFeatures, baseStyle.fontFeatures, _setFontFeatures);

  final RBTree<List<ui.FontVariation>?>? _fontVariations;
  late final TextStyleAttributeGetter<List<ui.FontVariation>> fontVariations = _AttributeIterable(_fontVariations, baseStyle.fontVariations, _setFontVariations);

  final RBTree<ui.TextLeadingDistribution?>? _leadingDistribution;
  late final TextStyleAttributeGetter<ui.TextLeadingDistribution> leadingDistribution = _AttributeIterable(_leadingDistribution, baseStyle.leadingDistribution, _setLeadingDistribution);

  final RBTree<double?>? _height;
  late final TextStyleAttributeGetter<double> height = _AttributeIterable(_height, baseStyle.height, _setHeight);

  final RBTree<ui.TextBaseline?>? _textBaseline;
  late final TextStyleAttributeGetter<ui.TextBaseline> textBaseline = _AttributeIterable(_textBaseline, baseStyle.textBaseline, _setTextBaseline);

  final RBTree<double?>? _letterSpacing;
  late final TextStyleAttributeGetter<double> letterSpacing = _AttributeIterable(_letterSpacing, baseStyle.letterSpacing, _setLetterSpacing);
  final RBTree<double?>? _wordSpacing;
  late final TextStyleAttributeGetter<double> wordSpacing = _AttributeIterable(_wordSpacing, baseStyle.wordSpacing, _setWordSpacing);

  final RBTree<Either<ui.Color, ui.Paint>?>? _foreground;
  late final TextStyleAttributeGetter<Either<ui.Color, ui.Paint>> foregorund = _AttributeIterable(_foreground, _getForeground(baseStyle), _setForeground);
  final RBTree<Either<ui.Color, ui.Paint>?>? _background;
  late final TextStyleAttributeGetter<Either<ui.Color, ui.Paint>> background = _AttributeIterable(_background, _getBackground(baseStyle), _setBackground);

  final RBTree<bool?>? _underline;
  late final TextStyleAttributeGetter<bool> underline = _AttributeIterable(_underline, _getUnderline(baseStyle), _setUnderline);
  final RBTree<bool?>? _overline;
  late final TextStyleAttributeGetter<bool> overline = _AttributeIterable(_overline, _getOverline(baseStyle), _setOverline);
  final RBTree<bool?>? _lineThrough;
  late final TextStyleAttributeGetter<bool> lineThrough = _AttributeIterable(_lineThrough, _getLineThrough(baseStyle), _setLineThrough);

  final RBTree<ui.Color?>? _decorationColor;
  late final TextStyleAttributeGetter<ui.Color> decorationColor = _AttributeIterable(_decorationColor, baseStyle.decorationColor, _setDecorationColor);
  final RBTree<ui.TextDecorationStyle?>? _decorationStyle;
  late final TextStyleAttributeGetter<ui.TextDecorationStyle> decorationStyle = _AttributeIterable(_decorationStyle, baseStyle.decorationStyle, _setDecorationStyle);
  final RBTree<double?>? _decorationThickness;
  late final TextStyleAttributeGetter<double> decorationThickness = _AttributeIterable(_decorationThickness, baseStyle.decorationThickness, _setDecorationThickness);

  final RBTree<List<ui.Shadow>?>? _shadows;
  late final TextStyleAttributeGetter<List<ui.Shadow>> shadows = _AttributeIterable<List<ui.Shadow>>(_shadows, baseStyle.shadows, _setShadows);

  Iterator<(int, TextStyleAttributeSet)> getRunsEndAfter(int index) {
    final _AttributeRunsToMerge runsToMerge = _AttributeRunsToMerge.filled(21, null)
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
      ..[11] = letterSpacing._getTextStyleRunsEndAfter(index)
        // Painting Attributes
      ..[12] = foregorund._getTextStyleRunsEndAfter(index)
      ..[13] = background._getTextStyleRunsEndAfter(index)

      ..[14] = underline._getTextStyleRunsEndAfter(index)
      ..[15] = overline._getTextStyleRunsEndAfter(index)
      ..[16] = lineThrough._getTextStyleRunsEndAfter(index)

      ..[17] = decorationColor._getTextStyleRunsEndAfter(index)
      ..[18] = decorationStyle._getTextStyleRunsEndAfter(index)
      ..[19] = decorationThickness._getTextStyleRunsEndAfter(index)
      ..[20] = shadows._getTextStyleRunsEndAfter(index);
    return _TextStyleMergingIterator(runsToMerge, _MutableTextStyleAttributeSet.fromTextStyle(baseStyle));
  }

  @override
  TextStyleAnnotations overwrite(ui.TextRange range, TextStyleAttributeSet annotationsToOverwrite) {
    final int? end = range.end >= _textLength ? null : range.end;

    RBTree<Value?>? update<Value extends Object>(Value? newAttribute, RBTree<Value?>? tree) {
      return newAttribute == null ? tree : _insertRange(tree, range.start, end, newAttribute);
    }

    return TextStyleAnnotations._(
      update(annotationsToOverwrite.fontFamilies, _fontFamilies),
      update(annotationsToOverwrite.locale, _locale),
      update(annotationsToOverwrite.fontWeight, _fontWeight),
      update(annotationsToOverwrite.fontStyle, _fontStyle),
      update(annotationsToOverwrite.fontFeatures, _fontFeatures),
      update(annotationsToOverwrite.fontVariations, _fontVariations),
      update(annotationsToOverwrite.textBaseline, _textBaseline),
      update(annotationsToOverwrite.leadingDistribution, _leadingDistribution),
      update(annotationsToOverwrite.fontSize, _fontSize),
      update(annotationsToOverwrite.height, _height),
      update(annotationsToOverwrite.letterSpacing, _letterSpacing),
      update(annotationsToOverwrite.wordSpacing, _wordSpacing),

      update(annotationsToOverwrite.foreground, _foreground),
      update(annotationsToOverwrite.background, _background),
      update(annotationsToOverwrite.underline, _underline),
      update(annotationsToOverwrite.overline, _overline),
      update(annotationsToOverwrite.lineThrough, _lineThrough),
      update(annotationsToOverwrite.decorationColor, _decorationColor),
      update(annotationsToOverwrite.decorationStyle, _decorationStyle),
      update(annotationsToOverwrite.decorationThickness, _decorationThickness),
      update(annotationsToOverwrite.shadows, _shadows),
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
      erase(annotationsToErase.leadingDistribution, _leadingDistribution),
      erase(annotationsToErase.fontSize, _fontSize),
      erase(annotationsToErase.height, _height),
      erase(annotationsToErase.letterSpacing, _letterSpacing),
      erase(annotationsToErase.wordSpacing, _wordSpacing),

      erase(annotationsToErase.foreground, _foreground),
      erase(annotationsToErase.background, _background),
      erase(annotationsToErase.underline, _underline),
      erase(annotationsToErase.overline, _overline),
      erase(annotationsToErase.lineThrough, _lineThrough),
      erase(annotationsToErase.decorationColor, _decorationColor),
      erase(annotationsToErase.decorationStyle, _decorationStyle),
      erase(annotationsToErase.decorationThickness, _decorationThickness),
      erase(annotationsToErase.shadows, _shadows),

      _textLength,
      baseStyle,
    );
  }

  @override
  ui.Paragraph toParagraph() {
    // TODO: implement toParagraph
    throw UnimplementedError();
  }
}

class _TextHitTestAnnotations implements TextHitTestAnnotations {
  const _TextHitTestAnnotations(this._hitTestTargets);

  final RBTree<Iterable<HitTestTarget>>? _hitTestTargets;

  @override
  Iterable<HitTestTarget> getHitTestTargets(int codeUnitOffset) {
    final Iterator<(int, Iterable<HitTestTarget>)>? iterator = _hitTestTargets?.getRunsEndAfter(codeUnitOffset);
    return iterator != null && iterator.moveNext() ? iterator.current.$2 : const <HitTestTarget>[];
  }

  @override
  TextHitTestAnnotations overwrite(ui.TextRange range, List<HitTestTarget> newAttribute) {
    throw UnimplementedError();
  }
}

/// An annotation type that represents the extra semantics information of the text.
class _SemanticsAnnotations implements SemanticsAnnotations {
  const _SemanticsAnnotations(this.semanticsLabels, this.spellOut, this.gestureCallbacks, this.textLength);

  final RBTree<String?>? semanticsLabels;
  final RBTree<bool?>? spellOut;
  // Either onTap callbacks or onLongPress callbacks.
  final RBTree<Either<VoidCallback, VoidCallback>?>? gestureCallbacks;
  final int textLength;

  @override
  Iterable<SemanticsAttributeSet> getSemanticsInformation(int codeUnitOffset) {
    // TODO: implement getSemanticsInformation
    throw UnimplementedError();
  }

  @override
  SemanticsAnnotations overwrite(ui.TextRange range, SemanticsAttributeSet newAttribute) {
    final int? end = range.end >= textLength ? null : range.end;

    RBTree<Value?>? update<Value extends Object>(Value? newAttribute, RBTree<Value?>? tree) {
      return newAttribute == null ? tree : _insertRange(tree, range.start, end, newAttribute);
    }

    return _SemanticsAnnotations(
      update(newAttribute.semanticsLabel, semanticsLabels),
      update(newAttribute.spellOut, spellOut),
      update(newAttribute.gestureCallback, gestureCallbacks),
      textLength,
    );
  }
}

/// InlineSpan to AnnotatedString Conversion

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
    final Attribute? newAttribute = FlatMap(textStyle).flatMap(getAttribute);
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

TextStyleAnnotations _convertTextStyleAttributes(InlineSpan span, int stringLength) {
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
      for (final _TextStyleAttributeRunBuilder<Object> attribute in attributes) {
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

  // Only extract styles.
  span.visitChildren(visitSpan);
  return TextStyleAnnotations._(
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

    stringLength,
    span.style ?? const TextStyle(),
  );
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
            tryPush(semanticGestureCallbacks, Left(onTap));
          case LongPressGestureRecognizer(:final VoidCallback onLongPress):
            tryPush(semanticGestureCallbacks, Right(onLongPress));
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
  final TextHitTestAnnotations textHitTestAnnotations = _TextHitTestAnnotations(hitTests.build());

  final _SemanticsAnnotations semanticsAnnotations = _SemanticsAnnotations(
    semanticsLabels.build(),
    spellOuts.build(),
    semanticGestureCallbacks.build(),
    string.length,
  );

  return AnnotatedString._(string, const PersistentHashMap<Type, StringAnnotation<Object>?>.empty())
    .setAnnotationOfType(textHitTestAnnotations)
    .setAnnotationOfType(semanticsAnnotations);
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
