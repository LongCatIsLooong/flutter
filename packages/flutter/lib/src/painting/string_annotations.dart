// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs (REMOVE)
// ignore_for_file: always_specify_types (REMOVE)

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:meta/meta.dart';

import 'annotated_string.dart';
import 'inline_span.dart';
import 'text_style.dart';
import 'text_style_attributes.dart';

typedef _Equality<Value> = bool Function(Value, Value);

extension _FlatMap<T extends Object> on T? {
  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  V? flatMap<V extends Object>(V? Function(T) transform) {
    final huh = this;
    return huh == null ? null : transform(huh);
  }
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

/// Transforms the values emitted by an nullable indexed iterator using the given `transform` function.
extension _IteratorMap<T> on Iterator<(int, T)> {
  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  Iterator<(int, V)>? map<V>(V Function(T) transform) => _TransformedIndexedIterator<T, V>(this, transform);
}

enum _RunIteratorState {
  initial,
  defaultValue,
  defaultValueAndEnd,
  baseRun,
}

// A Run iterator that replaces null values with the given defaultValue.
class _RunIteratorWithDefaults<T> implements Iterator<(int, T)> {
  _RunIteratorWithDefaults(this.startingIndex, this.defaultValue, this.innerRun)
    : assert(startingIndex >= 0);
  final int startingIndex;
  final T defaultValue;
  final Iterator<(int, T)>? innerRun;

  _RunIteratorState state = _RunIteratorState.initial;
  @override
  (int, T) get current {
    return switch (state) {
      _RunIteratorState.initial => throw StateError('call moveNext() first'),
      _RunIteratorState.defaultValue || _RunIteratorState.defaultValueAndEnd => (0, defaultValue),
      _RunIteratorState.baseRun => (innerRun!.current.$1, innerRun!.current.$2 ?? defaultValue),
    };
  }

  @override
  bool moveNext() {
    switch (state) {
      case _RunIteratorState.initial when innerRun?.moveNext() ?? false:
        state = innerRun!.current.$1 <= startingIndex ? _RunIteratorState.baseRun : _RunIteratorState.defaultValue;
        return true;
      case _RunIteratorState.initial:
        state = _RunIteratorState.defaultValueAndEnd;
        return true;
      case _RunIteratorState.defaultValue:
        state = _RunIteratorState.baseRun;
        return true;
      case _RunIteratorState.defaultValueAndEnd || _RunIteratorState.baseRun:
        return innerRun?.moveNext() ?? false;
    }
  }
}

typedef _AttributeRunsToMerge<ProductType extends Object> = List<Iterator<(int, ValueSetter<ProductType>)>?>;
typedef _AttributeMerger<ProductType extends Object> = UnionSortedIterator<(int, ValueSetter<ProductType>), (int, ProductType)>;

extension _Update<Value extends Object, ProductType extends Object> on _AttributeIterable<Value, ProductType> {
  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  _AttributeIterable<Value, ProductType> update(int start, int? end, Value? newValue, _Equality<Value?>? equality) {
    return _AttributeIterable<Value, ProductType>(storage.insertRange(start, end, newValue, equality), setter);
  }
}

extension _InsertRange<Value extends Object> on RBTree<Value?>? {
  RBTree<Value?> _joinWithPivot(RBTree<Value?>? rightTree, int pivotKey, Value? pivotValue) {
    final leftTree = this;
    return leftTree != null && rightTree != null
      ? leftTree.join(rightTree, pivotKey, pivotValue)
      : (leftTree ?? rightTree)?.insert(pivotKey, pivotValue) ?? RBTree.black(pivotKey, pivotValue);
  }

  // When end is null, it is treated as +∞ and is special cased to enable faster processing.
  RBTree<Value?>? insertRange(int start, int? end, Value? value, _Equality<Value?>? equality ) {
    assert(start >= 0);
    assert(end == null || end > start);
    final tree = this;
    if (tree == null) {
      return value == null
        ? null
        : RBTree.black(start, value, right: end == null ? null : RBTree.red(end, null));
    }

    // Range insertion works by splitting this tree into two subtrees: a left
    // subtree within which all keys are less than `start`, and a right subtree
    // with keys > `end`, and then concatenating left + new nodes + right.
    // We would also like to dedup to make sure the process does not produce
    // adjacent nodes that have the same `value`.
    //
    // Let left tree = [n0 ... n_l], right tree = [n_r ... n_last], then we have
    // n_l.key < start < end < n_r.key, and the final tree is:
    // [n0 ... n_l] + [start] + [end] + [n_r ... n_last]
    //
    // The `start` node is not needed if `value` is the same as n_l.value.
    // The `end` node is not needed if its value is same as `value`.
    // The `n_r` node is not needed if its value is the same as `end` - impossible?

    final RBTree<Value?>? leftSubtree = tree.takeLessThan(start);
    // If true, the [start] node doesn't have to be added.
    final bool skipStartNode = equality?.call(leftSubtree?.maxNode.value, value) ?? false;
    if (end == null) {
      return skipStartNode ? leftSubtree : leftSubtree?.insert(start, value) ?? RBTree.black(start, value);
    }

    final RBTree<Value?>? nodeBeforeEnd = tree.getNodeLessThanOrEqualTo(end);
    final RBTree<Value?>? rightSubtree = tree.skipUntil(end + 1);
    // If true, the [end] node doesn't have to be added.
    final bool skipEndNode = equality?.call(value, nodeBeforeEnd?.value) ?? false;
    switch ((skipStartNode, skipEndNode)) {
      case (true, true):
        return rightSubtree != null
          ? leftSubtree?.merge(rightSubtree) ?? rightSubtree
          : leftSubtree;
      case (true, false):
        return _joinWithPivot(rightSubtree, end, nodeBeforeEnd?.value);
      case (false, true):
        return _joinWithPivot(rightSubtree, start, value);
      case (false, false):
        final RBTree<Value?>? newRightTree = rightSubtree?.insert(end, nodeBeforeEnd?.value);
        return newRightTree == null
          ? leftSubtree?.insert(start, value).insert(end, nodeBeforeEnd?.value) ?? RBTree.black(start, value, right: RBTree.red(end, nodeBeforeEnd?.value))
          : leftSubtree?.join(newRightTree, start, value) ?? newRightTree.insert(start, value);
    }
  }
}


class _AttributeIterable<Attribute extends Object, ProductType extends Object> {
  const _AttributeIterable(this.storage, this.setter);

  final RBTree<Attribute?>? storage;
  final ProductType Function(ProductType, Attribute?) setter;

  ValueSetter<ProductType> _partiallyApply(Attribute? value) {
    return (ProductType style) => setter(style, value);
  }

  Iterator<(int, ValueSetter<ProductType>)>? _getProductRunsEndAfter(int index) {
    return storage?.getRunsEndAfter(index).map(_partiallyApply);
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

_MutableTextStyleAttributeSet _setFontSize(_MutableTextStyleAttributeSet style, double? input) => style..fontSize = input;

_MutableTextStyleAttributeSet _setFontWeight(_MutableTextStyleAttributeSet style, ui.FontWeight? input) => style..fontWeight = input;

_MutableTextStyleAttributeSet _setFontStyle(_MutableTextStyleAttributeSet style, ui.FontStyle? input) => style..fontStyle = input;

_MutableTextStyleAttributeSet _setFontFeatures(_MutableTextStyleAttributeSet style, List<ui.FontFeature>? input) => style..fontFeatures = input;

_MutableTextStyleAttributeSet _setFontVariations(_MutableTextStyleAttributeSet style, List<ui.FontVariation>? input) => style..fontVariations = input;

_MutableTextStyleAttributeSet _setHeight(_MutableTextStyleAttributeSet style, double? input) => style..height = input;

_MutableTextStyleAttributeSet _setLeadingDistribution(_MutableTextStyleAttributeSet style, ui.TextLeadingDistribution? input) => style..leadingDistribution = input;

_MutableTextStyleAttributeSet _setTextBaseline(_MutableTextStyleAttributeSet style, ui.TextBaseline? input) => style..textBaseline = input;

_MutableTextStyleAttributeSet _setWordSpacing(_MutableTextStyleAttributeSet style, double? input) => style..wordSpacing = input;

_MutableTextStyleAttributeSet _setLetterSpacing(_MutableTextStyleAttributeSet style, double? input) => style..letterSpacing = input;

_MutableTextStyleAttributeSet _setForeground(_MutableTextStyleAttributeSet style, Either<ui.Color, ui.Paint>? input) => style..foreground = input;
_MutableTextStyleAttributeSet _setBackground(_MutableTextStyleAttributeSet style, Either<ui.Color, ui.Paint>? input) => style..background = input;

_MutableTextStyleAttributeSet _setDecorationColor(_MutableTextStyleAttributeSet style, ui.Color? input) => style..decorationColor = input;
_MutableTextStyleAttributeSet _setDecorationStyle(_MutableTextStyleAttributeSet style, ui.TextDecorationStyle? input) => style..decorationStyle = input;
_MutableTextStyleAttributeSet _setDecorationThickness(_MutableTextStyleAttributeSet style, double? input) => style..decorationThickness = input;

_MutableTextStyleAttributeSet _setShadows(_MutableTextStyleAttributeSet style, List<ui.Shadow>? input) => style..shadows = input;

_MutableTextStyleAttributeSet _setUnderline(_MutableTextStyleAttributeSet style, bool? input) => style..underline = input;
_MutableTextStyleAttributeSet _setOverline(_MutableTextStyleAttributeSet style, bool? input) => style..overline = input;
_MutableTextStyleAttributeSet _setLineThrough(_MutableTextStyleAttributeSet style, bool? input) => style..lineThrough = input;

final class _MutableTextStyleAttributeSet implements TextStyleAttributeSet {
  _MutableTextStyleAttributeSet.fromTextStyle(TextStyle textStyle)
   : fontFamilies = _getFontFamilies(textStyle),
     locale = textStyle.locale,
     fontSize = textStyle.fontSize,
     fontWeight = textStyle.fontWeight,
     fontStyle = textStyle.fontStyle,
     fontFeatures = textStyle.fontFeatures,
     fontVariations = textStyle.fontVariations,
     height = textStyle.height,
     leadingDistribution = textStyle.leadingDistribution,
     textBaseline = textStyle.textBaseline,
     wordSpacing = textStyle.wordSpacing,
     letterSpacing = textStyle.letterSpacing,
     foreground = textStyle.color.flatMap(Left.new) ?? textStyle.foreground.flatMap(Right.new),
     background = textStyle.backgroundColor.flatMap(Left.new) ?? textStyle.background.flatMap(Right.new),
     shadows = textStyle.shadows,
     underline = textStyle.decoration?.contains(ui.TextDecoration.underline),
     overline = textStyle.decoration?.contains(ui.TextDecoration.overline),
     lineThrough = textStyle.decoration?.contains(ui.TextDecoration.lineThrough),
     decorationColor = textStyle.decorationColor,
     decorationStyle = textStyle.decorationStyle,
     decorationThickness = textStyle.decorationThickness;

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

  @override
  String toString() => toTextStyle(const TextStyle()).toString();
}

final class _StyleRunMerger extends _AttributeMerger<_MutableTextStyleAttributeSet> {
  _StyleRunMerger(super.inputs, this.mutableCurrent);

  final _MutableTextStyleAttributeSet mutableCurrent;

  // The compiler should inline this.
  @override
  int compare((int, ValueSetter<_MutableTextStyleAttributeSet>) a, (int, ValueSetter<_MutableTextStyleAttributeSet>) b) => a.$1 - b.$1;

  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @override
  (int, _MutableTextStyleAttributeSet) union((int, _MutableTextStyleAttributeSet)? accumulated, (int, ValueSetter<_MutableTextStyleAttributeSet>) value) {
    assert(accumulated == null || accumulated.$1 == value.$1);
    value.$2(mutableCurrent);
    return (value.$1, mutableCurrent);
  }
}

typedef TextStyleAttributeGetter<T extends Object> = _AttributeIterable<T, _MutableTextStyleAttributeSet>;
@immutable
class _TextStyleAnnotations {
  _TextStyleAnnotations({
    RBTree<List<String>?>? fontFamilies,
    RBTree<ui.Locale?>? locale,
    RBTree<ui.FontWeight?>? fontWeight,
    RBTree<ui.FontStyle?>? fontStyle,
    RBTree<List<ui.FontFeature>?>? fontFeatures,
    RBTree<List<ui.FontVariation>?>? fontVariations,
    RBTree<ui.TextBaseline?>? textBaseline,
    RBTree<ui.TextLeadingDistribution?>? leadingDistribution,
    RBTree<double?>? fontSize,
    RBTree<double?>? height,
    RBTree<double?>? letterSpacing,
    RBTree<double?>? wordSpacing,
    RBTree<Either<ui.Color, ui.Paint>?>?  foreground,
    RBTree<Either<ui.Color, ui.Paint>?>?  background,
    RBTree<bool?>? underline,
    RBTree<bool?>? overline,
    RBTree<bool?>? lineThrough,
    RBTree<ui.Color?>? decorationColor,
    RBTree<ui.TextDecorationStyle?>? decorationStyle,
    RBTree<double?>? decorationThickness,
    RBTree<List<ui.Shadow>?>? shadows,

    required this.baseStyle,
  }) : fontFamilies = _AttributeIterable(fontFamilies, _setFontFamilies),
       locale = _AttributeIterable(locale, _setLocale),
       fontSize = _AttributeIterable(fontSize, _setFontSize),
       fontWeight = _AttributeIterable(fontWeight, _setFontWeight),
       fontStyle = _AttributeIterable(fontStyle, _setFontStyle),
       fontFeatures = _AttributeIterable(fontFeatures, _setFontFeatures),
       fontVariations = _AttributeIterable(fontVariations, _setFontVariations),
       leadingDistribution = _AttributeIterable(leadingDistribution, _setLeadingDistribution),
       height = _AttributeIterable(height, _setHeight),
       textBaseline = _AttributeIterable(textBaseline, _setTextBaseline),
       letterSpacing = _AttributeIterable(letterSpacing, _setLetterSpacing),
       wordSpacing = _AttributeIterable(wordSpacing, _setWordSpacing),
       foreground = _AttributeIterable(foreground, _setForeground),
       background = _AttributeIterable(background, _setBackground),
       underline = _AttributeIterable(underline, _setUnderline),
       overline = _AttributeIterable(overline, _setOverline),
       lineThrough = _AttributeIterable(lineThrough, _setLineThrough),
       decorationColor = _AttributeIterable(decorationColor, _setDecorationColor),
       decorationStyle = _AttributeIterable(decorationStyle, _setDecorationStyle),
       decorationThickness = _AttributeIterable(decorationThickness, _setDecorationThickness),
       shadows = _AttributeIterable(shadows, _setShadows);

  _TextStyleAnnotations.allRequired({
    required RBTree<List<String>?>? fontFamilies,
    required RBTree<ui.Locale?>? locale,
    required RBTree<ui.FontWeight?>? fontWeight,
    required RBTree<ui.FontStyle?>? fontStyle,
    required RBTree<List<ui.FontFeature>?>? fontFeatures,
    required RBTree<List<ui.FontVariation>?>? fontVariations,
    required RBTree<ui.TextBaseline?>? textBaseline,
    required RBTree<ui.TextLeadingDistribution?>? leadingDistribution,
    required RBTree<double?>? fontSize,
    required RBTree<double?>? height,
    required RBTree<double?>? letterSpacing,
    required RBTree<double?>? wordSpacing,
    required RBTree<Either<ui.Color, ui.Paint>?>?  foreground,
    required RBTree<Either<ui.Color, ui.Paint>?>?  background,
    required RBTree<bool?>? underline,
    required RBTree<bool?>? overline,
    required RBTree<bool?>? lineThrough,
    required RBTree<ui.Color?>? decorationColor,
    required RBTree<ui.TextDecorationStyle?>? decorationStyle,
    required RBTree<double?>? decorationThickness,
    required RBTree<List<ui.Shadow>?>? shadows,

    required this.baseStyle,
  }) : fontFamilies = _AttributeIterable(fontFamilies, _setFontFamilies),
       locale = _AttributeIterable(locale, _setLocale),
       fontSize = _AttributeIterable(fontSize, _setFontSize),
       fontWeight = _AttributeIterable(fontWeight, _setFontWeight),
       fontStyle = _AttributeIterable(fontStyle, _setFontStyle),
       fontFeatures = _AttributeIterable(fontFeatures, _setFontFeatures),
       fontVariations = _AttributeIterable(fontVariations, _setFontVariations),
       leadingDistribution = _AttributeIterable(leadingDistribution, _setLeadingDistribution),
       height = _AttributeIterable(height, _setHeight),
       textBaseline = _AttributeIterable(textBaseline, _setTextBaseline),
       letterSpacing = _AttributeIterable(letterSpacing, _setLetterSpacing),
       wordSpacing = _AttributeIterable(wordSpacing, _setWordSpacing),
       foreground = _AttributeIterable(foreground, _setForeground),
       background = _AttributeIterable(background, _setBackground),
       underline = _AttributeIterable(underline, _setUnderline),
       overline = _AttributeIterable(overline, _setOverline),
       lineThrough = _AttributeIterable(lineThrough, _setLineThrough),
       decorationColor = _AttributeIterable(decorationColor, _setDecorationColor),
       decorationStyle = _AttributeIterable(decorationStyle, _setDecorationStyle),
       decorationThickness = _AttributeIterable(decorationThickness, _setDecorationThickness),
       shadows = _AttributeIterable(shadows, _setShadows);

  const _TextStyleAnnotations._(
    this.fontFamilies,
    this.locale,
    this.fontWeight,
    this.fontStyle,
    this.fontFeatures,
    this.fontVariations,
    this.textBaseline,
    this.leadingDistribution,
    this.fontSize,
    this.height,
    this.letterSpacing,
    this.wordSpacing,
    this.foreground,
    this.background,
    this.underline,
    this.overline,
    this.lineThrough,
    this.decorationColor,
    this.decorationStyle,
    this.decorationThickness,
    this.shadows,

    this.baseStyle,
  );

  final TextStyle? baseStyle;

  _TextStyleAnnotations updateBaseTextStyle(TextStyle baseAnnotations) {
    return _TextStyleAnnotations.allRequired(
      fontFamilies: fontFamilies.storage,
      locale: locale.storage,
      fontWeight: fontWeight.storage,
      fontStyle: fontStyle.storage,
      fontFeatures: fontFeatures.storage,
      fontVariations: fontVariations.storage,
      textBaseline: textBaseline.storage,
      leadingDistribution: leadingDistribution.storage,
      fontSize: fontSize.storage,
      height: height.storage,
      letterSpacing: letterSpacing.storage,
      wordSpacing: wordSpacing.storage,

      foreground: foreground.storage,
      background: background.storage,
      underline: underline.storage,
      overline: overline.storage,
      lineThrough: lineThrough.storage,
      decorationColor: decorationColor.storage,
      decorationStyle: decorationStyle.storage,
      decorationThickness: decorationThickness.storage,
      shadows: shadows.storage,
      baseStyle: baseAnnotations,
    );
  }

  final TextStyleAttributeGetter<List<String>> fontFamilies;
  final TextStyleAttributeGetter<ui.Locale> locale;
  final TextStyleAttributeGetter<double> fontSize;
  final TextStyleAttributeGetter<ui.FontWeight> fontWeight;
  final TextStyleAttributeGetter<ui.FontStyle> fontStyle;
  final TextStyleAttributeGetter<List<ui.FontFeature>> fontFeatures;
  final TextStyleAttributeGetter<List<ui.FontVariation>> fontVariations;
  final TextStyleAttributeGetter<ui.TextLeadingDistribution> leadingDistribution;
  final TextStyleAttributeGetter<double> height;
  final TextStyleAttributeGetter<ui.TextBaseline> textBaseline;
  final TextStyleAttributeGetter<double> letterSpacing;
  final TextStyleAttributeGetter<double> wordSpacing;

  final TextStyleAttributeGetter<Either<ui.Color, ui.Paint>> foreground;
  final TextStyleAttributeGetter<Either<ui.Color, ui.Paint>> background;

  final TextStyleAttributeGetter<bool> underline;
  final TextStyleAttributeGetter<bool> overline;
  final TextStyleAttributeGetter<bool> lineThrough;
  final TextStyleAttributeGetter<ui.Color> decorationColor;
  final TextStyleAttributeGetter<ui.TextDecorationStyle> decorationStyle;
  final TextStyleAttributeGetter<double> decorationThickness;
  final TextStyleAttributeGetter<List<ui.Shadow>> shadows;

  Iterator<(int, TextStyleAttributeSet?)> getRunsEndAfter(int index) {
    final _AttributeRunsToMerge<_MutableTextStyleAttributeSet> runsToMerge = _AttributeRunsToMerge<_MutableTextStyleAttributeSet>.filled(21, null)
      ..[0] = fontFamilies._getProductRunsEndAfter(index)
      ..[1] = locale._getProductRunsEndAfter(index)
      ..[2] = fontSize._getProductRunsEndAfter(index)
      ..[3] = fontWeight._getProductRunsEndAfter(index)
      ..[4] = fontStyle._getProductRunsEndAfter(index)
      ..[5] = fontVariations._getProductRunsEndAfter(index)
      ..[6] = fontFeatures._getProductRunsEndAfter(index)
      ..[7] = height._getProductRunsEndAfter(index)
      ..[8] = leadingDistribution._getProductRunsEndAfter(index)
      ..[9] = textBaseline._getProductRunsEndAfter(index)
      ..[10] = wordSpacing._getProductRunsEndAfter(index)
      ..[11] = letterSpacing._getProductRunsEndAfter(index)
        // Painting Attributes
      ..[12] = foreground._getProductRunsEndAfter(index)
      ..[13] = background._getProductRunsEndAfter(index)

      ..[14] = underline._getProductRunsEndAfter(index)
      ..[15] = overline._getProductRunsEndAfter(index)
      ..[16] = lineThrough._getProductRunsEndAfter(index)

      ..[17] = decorationColor._getProductRunsEndAfter(index)
      ..[18] = decorationStyle._getProductRunsEndAfter(index)
      ..[19] = decorationThickness._getProductRunsEndAfter(index)
      ..[20] = shadows._getProductRunsEndAfter(index);
    final effectiveBaseStyle = _MutableTextStyleAttributeSet.fromTextStyle(baseStyle ?? const TextStyle());
    final merged = _StyleRunMerger(runsToMerge, effectiveBaseStyle);
    //return _RunIteratorWithDefaults(index, _MutableTextStyleAttributeSet.fromTextStyle(baseStyle ?? const TextStyle()), merged);
    return merged;
  }

  static bool defaultEqual(Object? a, Object? b) => a == b;

  _TextStyleAnnotations overwrite(int start, int? end, TextStyleAttributeSet annotationsToOverwrite) {
    return _TextStyleAnnotations._(
      fontFamilies.update(start, end, annotationsToOverwrite.fontFamilies, defaultEqual),
      locale.update(start, end, annotationsToOverwrite.locale, defaultEqual),
      fontWeight.update(start, end, annotationsToOverwrite.fontWeight, defaultEqual),
      fontStyle.update(start, end, annotationsToOverwrite.fontStyle, defaultEqual),
      fontFeatures.update(start, end, annotationsToOverwrite.fontFeatures, defaultEqual),
      fontVariations.update(start, end, annotationsToOverwrite.fontVariations, defaultEqual),
      textBaseline.update(start, end, annotationsToOverwrite.textBaseline, defaultEqual),
      leadingDistribution.update(start, end, annotationsToOverwrite.leadingDistribution, defaultEqual),
      fontSize.update(start, end, annotationsToOverwrite.fontSize, identical),
      height.update(start, end, annotationsToOverwrite.height, identical),
      letterSpacing.update(start, end, annotationsToOverwrite.letterSpacing, identical),
      wordSpacing.update(start, end, annotationsToOverwrite.wordSpacing, identical),

      foreground.update(start, end, annotationsToOverwrite.foreground, defaultEqual),
      background.update(start, end, annotationsToOverwrite.background, defaultEqual),
      underline.update(start, end, annotationsToOverwrite.underline, identical),
      overline.update(start, end, annotationsToOverwrite.overline, identical),
      lineThrough.update(start, end, annotationsToOverwrite.lineThrough, identical),
      decorationColor.update(start, end, annotationsToOverwrite.decorationColor, defaultEqual),
      decorationStyle.update(start, end, annotationsToOverwrite.decorationStyle, defaultEqual),
      decorationThickness.update(start, end, annotationsToOverwrite.decorationThickness, identical),
      shadows.update(start, end, annotationsToOverwrite.shadows, defaultEqual),
      baseStyle,
    );
  }
}

extension TextStyleAnnotatedString on AnnotatedString {
  TextStyle? get baseStyle => getAnnotation<_TextStyleAnnotations>()?.baseStyle;

  @useResult
  AnnotatedString overwriteTextStyle(TextStyle style, ui.TextRange range) {
    assert(range.isNormalized);
    assert(!range.isCollapsed);
    assert(range.end <= text.length);
    final _TextStyleAnnotations? annotations = getAnnotation();
    final TextStyle? baseStyle = annotations == null && range.start == 0 && range.end == text.length
      ? style
      : null;
    final _TextStyleAnnotations newAnnotation = baseStyle != null
      ? _TextStyleAnnotations(baseStyle: baseStyle)
      : (annotations ?? _TextStyleAnnotations(baseStyle: null)).overwrite(range.start, range.end == text.length ? null : range.end, _MutableTextStyleAttributeSet.fromTextStyle(style));
    return setAnnotation(newAnnotation);
  }

  Iterator<(int, TextStyleAttributeSet?)>? getTextStyleRunsEndAfter(int codeUnitIndex) {
    final _TextStyleAnnotations? annotations = getAnnotation();
    return annotations?.getRunsEndAfter(codeUnitIndex);
  }
}

/// # Semantics
extension type const SemanticsAttributeSet._((bool? spellOut, ui.Locale? locale, String? semanticsLabel, int? placeholderTag, GestureRecognizer? gestureRecognizer) _value) implements Object {
  SemanticsAttributeSet({
    bool? spellOut,
    ui.Locale? locale,
    String? semanticsLabel,
    int? placeholderTag,
    GestureRecognizer? gestureRecognizer,
  }) : this._((spellOut, locale, semanticsLabel, placeholderTag, gestureRecognizer));

  const SemanticsAttributeSet.empty() : this._((null, null, null, null, null));

  bool? get spellOut => _value.$1;
  ui.Locale? get locale => _value.$2;
  String? get semanticsLabel => _value.$3;
  int? get placeholderTag => _value.$4;
  GestureRecognizer? get gestureRecognizer => _value.$5;

  bool get requiresOwnNode => placeholderTag != null || gestureRecognizer != null;
}

/// An annotation type that represents the extra semantics information of the text.
class _SemanticsAnnotations {
  const _SemanticsAnnotations(this.spellOut, this.locale, this.semanticsLabels, this.placeholderTags, this.gestureCallbacks);

  final _AttributeIterable<String, SemanticsAttributeSet>? semanticsLabels;
  final _AttributeIterable<ui.Locale, SemanticsAttributeSet>? locale;
  final _AttributeIterable<bool, SemanticsAttributeSet>? spellOut;
  final _AttributeIterable<int, SemanticsAttributeSet>? placeholderTags;
  // TODO: Ideally _TextHitTestAnnotations should be the source of truth?
  final _AttributeIterable<GestureRecognizer, SemanticsAttributeSet>? gestureCallbacks;

  static bool defaultEqual(Object? a, Object? b) => a == b;
  _SemanticsAnnotations overwrite(int start, int? end, SemanticsAttributeSet newAttribute) {
    assert(() {
      if (newAttribute.semanticsLabel != null) {
        return true;
      }
      final iter = semanticsLabels?.storage?.getRunsEndAfter(start);
      if (iter == null) {
        return true;
      }
      final runs = List<(int, String?)?>.filled(2, null);
      for (int i = 0; i < 2 && iter.moveNext(); i += 1) {
        runs[i] = iter.current;
      }
      return switch (runs) {
        [(final int run1, final String _), _] => throw FlutterError('[$start, $end) overlaps an existing label at $run1'),
        [_, (final int run2, final String _)] when end == null || run2 < end => throw FlutterError('[$start, $end) overlaps an existing label at $run2'),
        _ => true,
      };
    }());

    return _SemanticsAnnotations(
      spellOut?.update(start, end, newAttribute.spellOut, identical),
      locale?.update(start, end, newAttribute.locale, defaultEqual),
      semanticsLabels?.update(start, end, newAttribute.semanticsLabel, defaultEqual),
      placeholderTags?.update(start, end, newAttribute.placeholderTag, identical),
      gestureCallbacks?.update(start, end, newAttribute.gestureRecognizer, defaultEqual),
    );
  }
}

final class _SemanticsRunMerger extends _AttributeMerger<SemanticsAttributeSet> {
  _SemanticsRunMerger(super.inputs, this.mutableCurrent);

  final SemanticsAttributeSet mutableCurrent;

  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @override
  int compare((int, ValueSetter<SemanticsAttributeSet>) a, (int, ValueSetter<SemanticsAttributeSet>) b) => a.$1 - b.$1;

  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @override
  (int, SemanticsAttributeSet) union((int, SemanticsAttributeSet)? accumulated, (int, ValueSetter<SemanticsAttributeSet>) value) {
    assert(accumulated == null || accumulated.$1 == value.$1);
    value.$2(mutableCurrent);
    return (value.$1, mutableCurrent);
  }
}

extension SemanticsAnnotatedString on AnnotatedString {
  @useResult
  AnnotatedString overwriteSemanticsAttributes(SemanticsAttributeSet attributes, ui.TextRange range) {
    assert(range.isNormalized);
    assert(!range.isCollapsed);
    assert(range.end <= text.length);
    final _SemanticsAnnotations annotations = getAnnotation() ?? const _SemanticsAnnotations(null, null, null, null, null);
    // TODO: verify non overlapping?
    return setAnnotation(annotations.overwrite(range.start, range.end == text.length ? null : range.end, attributes));
  }

  List<InlineSpanSemanticsInformation> getCombinedSemanticsInfo() {
    final _SemanticsAnnotations? annotations = getAnnotation();
    final _TextHitTestAnnotations? hitTestAnnotations = getAnnotation();
    // TODO: recognizers.
    if (annotations == null) {
      return const <InlineSpanSemanticsInformation>[];
    }
    final attributeIterator = _RunIteratorWithDefaults(
      0,
      const SemanticsAttributeSet.empty(),
      _SemanticsRunMerger(
      List.filled(5, null)
        ..[0] = annotations.spellOut?._getProductRunsEndAfter(0)
        ..[1] = annotations.locale?._getProductRunsEndAfter(0)
        ..[2] = annotations.gestureCallbacks?._getProductRunsEndAfter(0)
        ..[3] = annotations.placeholderTags?._getProductRunsEndAfter(0)
        ..[4] = annotations.semanticsLabels?._getProductRunsEndAfter(0),
      const SemanticsAttributeSet.empty(),
      )
    );

    int currentRunStartIndex = 0;
    final List<InlineSpanSemanticsInformation> runs = <InlineSpanSemanticsInformation>[];

    List<ui.StringAttribute> stringAttributeRuns = <ui.StringAttribute>[];
    String labelRun = '';
    SemanticsAttributeSet? previousValue;

    // These 2 runs are relative to the current InlineSpanSemanticsInformation.
    (ui.Locale, int)? localeRun;
    int? spellOutRunStart;

    // GestureRecognizers and Placeholders each needs its own [InlineSpanSemanticsInformation].
    // Assumption: GestureRecognizers and Placeholders are mutually exclusive.
    // No other Placeholders or GestureRecognizers within the range of a GestureRecognizer, or a Placeholder.
    while (attributeIterator.moveNext()) {
      final (newRunStartIndex, value) = attributeIterator.current;
      if (previousValue != null && previousValue.requiresOwnNode) {
        assert(labelRun.isNotEmpty);
        if (spellOutRunStart != null) {
          stringAttributeRuns.add(ui.SpellOutStringAttribute(range: ui.TextRange(start: spellOutRunStart, end: labelRun.length)));
          spellOutRunStart = null;
        }
        if (localeRun != null) {
          stringAttributeRuns.add(ui.LocaleStringAttribute(locale: localeRun.$1, range: ui.TextRange(start: localeRun.$2, end: labelRun.length)));
          localeRun = null;
        }
        runs.add(InlineSpanSemanticsInformation(
          text.substring(currentRunStartIndex, newRunStartIndex),
          semanticsLabel: labelRun,
          stringAttributes: stringAttributeRuns,
          recognizer: previousValue.gestureRecognizer,
        ));
        stringAttributeRuns = <ui.StringAttribute>[];
        labelRun = '';
        spellOutRunStart = null;
      }
      if (value.locale case final locale?) {
        localeRun ??= (locale, labelRun.length);
      } else if (localeRun != null) {
        stringAttributeRuns.add(ui.LocaleStringAttribute(locale: localeRun.$1, range: ui.TextRange(start: localeRun.$2, end: labelRun.length)));
        localeRun = null;
      }
      if (value.spellOut ?? false) {
        spellOutRunStart ??= labelRun.length;
      } else if (spellOutRunStart != null) {
        stringAttributeRuns.add(ui.SpellOutStringAttribute(range: ui.TextRange(start: spellOutRunStart, end: labelRun.length)));
        spellOutRunStart = null;
      }

      // Assumption: a semanticsLabel can never span multiple runs.
      labelRun += value.semanticsLabel ?? text.substring(currentRunStartIndex, newRunStartIndex);

      previousValue = value;
      currentRunStartIndex = newRunStartIndex;
    }

    // Commits the last run.
    if (currentRunStartIndex < text.length) {
      labelRun += text.substring(currentRunStartIndex, text.length);
      if (spellOutRunStart != null) {
        stringAttributeRuns.add(ui.SpellOutStringAttribute(range: ui.TextRange(start: spellOutRunStart, end: labelRun.length)));
      }
      if (localeRun != null) {
        stringAttributeRuns.add(ui.LocaleStringAttribute(locale: localeRun.$1, range: ui.TextRange(start: localeRun.$2, end: labelRun.length)));
      }
      runs.add(InlineSpanSemanticsInformation(
        text.substring(currentRunStartIndex, text.length),
        semanticsLabel: labelRun,
        stringAttributes: stringAttributeRuns,
      ));
    }
    return runs;
  }
}

/// # Hit-Testing

extension HitTestAnnotatedString on AnnotatedString {
  HitTestTarget? getHitTestTargetAt(int codeUnitOffset) {
    final _TextHitTestAnnotations? annotations = getAnnotation();
    final PersistentHashMap<Type, RBTree<GestureRecognizer?>>? recognizers = annotations?.recognizers;
    return recognizers == null ? null : _HitTestTarget(codeUnitOffset, recognizers);
  }

  @useResult
  AnnotatedString overwriteGestureRecognizer(ui.TextRange range, GestureRecognizer recognizer) {
    assert(range.isNormalized);
    assert(!range.isCollapsed);
    assert(range.end <= text.length);
    final int? end = range.end >= text.length ? null : range.end;
    final _TextHitTestAnnotations? annotations = getAnnotation();
    final Type runtimeType = recognizer.runtimeType;


    final RBTree<GestureRecognizer?>? oldRBTree = annotations?.recognizers?[runtimeType];
    final RBTree<GestureRecognizer?>? newRBTree = oldRBTree.insertRange(range.start, end, recognizer, identical);
    return newRBTree == null
      ? this
      : setAnnotation(_TextHitTestAnnotations((annotations?.recognizers ?? const PersistentHashMap<Type, RBTree<GestureRecognizer?>>.empty()).put(recognizer.runtimeType, newRBTree)));
  }
}

class _TextHitTestAnnotations {
  const _TextHitTestAnnotations(this.recognizers);

  final PersistentHashMap<Type, RBTree<GestureRecognizer?>>? recognizers;
}

final class _HitTestTarget implements HitTestTarget {
  _HitTestTarget(this.codeUnitOffset ,this.recognizers);

  final int codeUnitOffset;
  final PersistentHashMap<Type, RBTree<GestureRecognizer?>> recognizers;

  @override
  void handleEvent(PointerEvent event, HitTestEntry<HitTestTarget> entry) {
    if (event is PointerDownEvent) {
      for (final entry in recognizers.entries) {
        entry.value.getNodeLessThanOrEqualTo(codeUnitOffset)?.value?.addPointer(event);
      }
    }
  }
}
