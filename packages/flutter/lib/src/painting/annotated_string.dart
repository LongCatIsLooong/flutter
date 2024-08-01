// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs (REMOVE)
// ignore_for_file: always_specify_types (REMOVE)
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/src/painting/basic_types.dart';
import 'package:flutter/src/painting/text_painter.dart';
import 'package:flutter/src/painting/text_scaler.dart';
import 'package:flutter/src/painting/text_style.dart';
import 'package:meta/meta.dart';

import 'inline_span.dart';
import 'text_style_attributes.dart';

// ### NOTES
// 1. TextSpan interop
// 2. Font matching / Shaping / Layout / Paint subsystems
// 3. Hit-testing
// 4. Semantics

//class _EmptyIterator<E> implements Iterator<E> {
//  const _EmptyIterator();
//  @override
//  bool moveNext() => false;
//  @override
//  E get current => throw FlutterError('unreachable');
//}


/// An immutable representation of
@immutable
class AnnotatedString extends DiagnosticableTree implements InlineSpan {
  const AnnotatedString(this.string) : _attributeStorage = const PersistentHashMap<Type, Object?>.empty();
  const AnnotatedString._(this.string, this._attributeStorage);
  AnnotatedString.fromAnnotatedString(AnnotatedString string) :
    string = string.string,
    _attributeStorage = string._attributeStorage;

  final String string;

  // The PersistentHashMap class currently does not have a delete method.
  final PersistentHashMap<Type, Object?> _attributeStorage;

  // Read annotations of a specific type.
  T? getAnnotationOfType<T extends Object>() => _attributeStorage[T] as T?;

  /// Update annotations of a specific type `T` and return a new [AnnotatedString].
  ///
  /// The static type `T` is used as the key instead of the runtime type of
  /// newAnnotations, in case newAnnotations is null (and for consistency too).
  AnnotatedString setAnnotation<T extends Object>(T newAnnotations) {
    return AnnotatedString._(string, _attributeStorage.put(newAnnotations.runtimeType, newAnnotations));
  }

  @override
  void build(ui.ParagraphBuilder builder, {TextScaler textScaler = TextScaler.noScaling, List<PlaceholderDimensions>? dimensions}) {
    final _TextStyleAnnotations? annotations = getAnnotationOfType();
    final iterator = annotations?.getRunsEndAfter(0);

    int styleStartIndex = 0;
    TextStyleAttributeSet? styleToApply;
    while(iterator != null && iterator.moveNext()) {
      final (int nextStartIndex, TextStyleAttributeSet? nextStyle) = iterator.current;
      assert(nextStartIndex > styleStartIndex || (nextStartIndex == 0 && styleStartIndex == 0), '$nextStartIndex > $styleStartIndex');
      if (nextStartIndex != styleStartIndex) {
        if (styleToApply != null) {
          builder.pushStyle(styleToApply.toTextStyle(const TextStyle()).getTextStyle(textScaler: textScaler));
        }
        builder.addText(string.substring(styleStartIndex, nextStartIndex));
        if (styleToApply != null) {
          builder.pop();
        }
      }
      styleStartIndex = nextStartIndex;
      styleToApply = nextStyle;
    }
    if (styleStartIndex < string.length) {
      if (styleToApply != null) {
        builder.pushStyle(styleToApply.toTextStyle(const TextStyle()).getTextStyle(textScaler: textScaler));
      }
      builder.addText(string.substring(styleStartIndex, string.length));
    }
  }

  @override
  AnnotatedString buildAnnotations(int offset, Map<Object, int> childrenLength, AnnotatedString? annotatedString) {
    assert(annotatedString == null);
    assert(offset == 0);
    return this;
  }

  @override
  int? codeUnitAt(int index) => string.codeUnitAt(index);

  @override
  RenderComparison compareTo(InlineSpan other) {
    throw UnimplementedError();
  }

  @override
  Never codeUnitAtVisitor(int index, Accumulator offset) => throw FlutterError('No');

  @override
  Never computeSemanticsInformation(List<InlineSpanSemanticsInformation> collector) => throw FlutterError('No');

  @override
  Never computeToPlainText(StringBuffer buffer, {bool includeSemanticsLabels = true, bool includePlaceholders = true}) => throw FlutterError('No');

  @override
  Never getSpanForPositionVisitor(ui.TextPosition position, Accumulator offset)  => throw FlutterError('No');

  @override
  bool debugAssertIsValid() => true;

  @override
  int getContentLength(Map<Object, int> childrenLength) => string.length;

  @override
  List<InlineSpanSemanticsInformation> getSemanticsInformation() {
    final _SemanticsAnnotations? annotations = getAnnotationOfType();
    if (annotations == null) {
      return const <InlineSpanSemanticsInformation>[];
    }
    final iterator = annotations.getSemanticsInformation(0);
    return <InlineSpanSemanticsInformation>[
      //for(;iterator.moveNext();) iterator.current,
    ];
  }

  @override
  InlineSpan? getSpanForPosition(ui.TextPosition position) => this;

  @override
  TextStyle? get style => getAnnotationOfType<_TextStyleAnnotations>()?.baseStyle;

  @override
  bool visitChildren(InlineSpanVisitor visitor) => string.isEmpty || visitor(this);

  @override
  bool visitDirectChildren(InlineSpanVisitor visitor) => true;

  @override
  String toPlainText({bool includeSemanticsLabels = true, bool includePlaceholders = true}) {
    final bool addSemanticsLabels = includeSemanticsLabels || false;
    final bool removePlaceholders = !includePlaceholders || false;
    if (!addSemanticsLabels && !removePlaceholders) {
      return string;
    }
    throw UnimplementedError();
  }
}


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
class _RunIteratorWithDefaults<T extends Object> implements Iterator<(int, T?)> {
  _RunIteratorWithDefaults(this.startingIndex, this.defaultValue, this.baseRun)
    : assert(startingIndex >= 0);
  final int startingIndex;
  final T? defaultValue;
  final Iterator<(int, T?)>? baseRun;

  _RunIteratorState state = _RunIteratorState.initial;
  @override
  (int, T?) get current {
    return switch (state) {
      _RunIteratorState.initial => throw StateError('call moveNext() first'),
      _RunIteratorState.defaultValue || _RunIteratorState.defaultValueAndEnd => (0, defaultValue),
      _RunIteratorState.baseRun => (baseRun!.current.$1, baseRun!.current.$2 ?? defaultValue),
    };
  }

  @override
  bool moveNext() {
    switch (state) {
      case _RunIteratorState.initial when baseRun?.moveNext() ?? false:
        state = startingIndex >= baseRun!.current.$1 ? _RunIteratorState.baseRun : _RunIteratorState.defaultValue;
        return true;
      case _RunIteratorState.initial:
        state = _RunIteratorState.defaultValueAndEnd;
        return true;
      case _RunIteratorState.defaultValue:
        state = _RunIteratorState.baseRun;
        return true;
      case _RunIteratorState.defaultValueAndEnd || _RunIteratorState.baseRun:
        return baseRun?.moveNext() ?? false;
    }
  }
}

typedef _TextStyleAttributeSetter = ValueSetter<_MutableTextStyleAttributeSet>;
typedef _AttributeRunsToMerge = List<Iterator<(int, _TextStyleAttributeSetter)>?>;
final class _TextStyleMergingIterator extends RunMergingIterator<_MutableTextStyleAttributeSet, _TextStyleAttributeSetter> {
  _TextStyleMergingIterator(super.attributes, super.baseStyle);

  @override
  _MutableTextStyleAttributeSet fold(_TextStyleAttributeSetter value, _MutableTextStyleAttributeSet accumulatedValue) {
    value(accumulatedValue);
    return accumulatedValue;
  }
}

bool _defaultEquality(Object? a, Object? b) => a == b;
extension _InsertRange<Value extends Object> on RBTree<Value?>? {

  RBTree<Value?> _joinWithPivot(RBTree<Value?>? rightTree, int pivotKey, Value? pivotValue) {
    final leftTree = this;
    return leftTree != null && rightTree != null
      ? leftTree.join(rightTree, pivotKey, pivotValue)
      : (leftTree ?? rightTree)?.insert(pivotKey, pivotValue) ?? RBTree.black(pivotKey, pivotValue);
  }

  // When end is null, it is treated as +∞ and is special cased to enable faster processing.
  RBTree<Value?>? insertRange(int start, int? end, Value? value, { _Equality<Value?> equality = _defaultEquality, }) {
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
    final bool skipStartNode = equality(leftSubtree?.maxNode.value, value);
    if (end == null) {
      return skipStartNode ? leftSubtree : leftSubtree?.insert(start, value) ?? RBTree.black(start, value);
    }

    final RBTree<Value?>? nodeBeforeEnd = tree.getNodeLessThanOrEqualTo(end);
    final RBTree<Value?>? rightSubtree = tree.skipUntil(end + 1);
    // If true, the [end] node doesn't have to be added.
    final bool skipEndNode = equality(value, nodeBeforeEnd?.value);
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

typedef TextStyleAttributeGetter<T extends Object> = _AttributeIterable<T>;
class _AttributeIterable<Attribute extends Object> {
  const _AttributeIterable(this.storage, this.defaultValue, this.setter);

  final RBTree<Attribute?>? storage;
  final Attribute? defaultValue;
  final _MutableTextStyleAttributeSet Function(_MutableTextStyleAttributeSet, Attribute?) setter;

  Iterator<(int, Attribute?)> getRunsEndAfter(int index) {
    return _RunIteratorWithDefaults(index, defaultValue, storage?.getRunsEndAfter(index));
  }

  _TextStyleAttributeSetter _partiallyApply(Attribute? value) {
    return (_MutableTextStyleAttributeSet style) => setter(style, value ?? defaultValue);
  }

  Iterator<(int, _TextStyleAttributeSetter)>? _getTextStyleRunsEndAfter(int index) {
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
Either<ui.Color, ui.Paint>? _getForeground(TextStyle textStyle) => textStyle.color.flatMap(Left.new) ?? textStyle.foreground.flatMap(Right.new);

_MutableTextStyleAttributeSet _setBackground(_MutableTextStyleAttributeSet style, Either<ui.Color, ui.Paint>? input) => style..background = input;
Either<ui.Color, ui.Paint>? _getBackground(TextStyle textStyle) => textStyle.backgroundColor.flatMap(Left.new) ?? textStyle.background.flatMap(Right.new);

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
  }) : fontFamilies = _AttributeIterable(fontFamilies, baseStyle.flatMap(_getFontFamilies), _setFontFamilies),
       locale = _AttributeIterable(locale, baseStyle?.locale, _setLocale),
       fontSize = _AttributeIterable(fontSize, baseStyle?.fontSize, _setFontSize),
       fontWeight = _AttributeIterable(fontWeight, baseStyle?.fontWeight, _setFontWeight),
       fontStyle = _AttributeIterable(fontStyle, baseStyle?.fontStyle, _setFontStyle),
       fontFeatures = _AttributeIterable(fontFeatures, baseStyle?.fontFeatures, _setFontFeatures),
       fontVariations = _AttributeIterable(fontVariations, baseStyle?.fontVariations, _setFontVariations),
       leadingDistribution = _AttributeIterable(leadingDistribution, baseStyle?.leadingDistribution, _setLeadingDistribution),
       height = _AttributeIterable(height, baseStyle?.height, _setHeight),
       textBaseline = _AttributeIterable(textBaseline, baseStyle?.textBaseline, _setTextBaseline),
       letterSpacing = _AttributeIterable(letterSpacing, baseStyle?.letterSpacing, _setLetterSpacing),
       wordSpacing = _AttributeIterable(wordSpacing, baseStyle?.wordSpacing, _setWordSpacing),
       foreground = _AttributeIterable(foreground, baseStyle.flatMap(_getForeground), _setForeground),
       background = _AttributeIterable(background, baseStyle.flatMap(_getBackground), _setBackground),
       underline = _AttributeIterable(underline, baseStyle.flatMap(_getUnderline), _setUnderline),
       overline = _AttributeIterable(overline, baseStyle.flatMap(_getOverline), _setOverline),
       lineThrough = _AttributeIterable(lineThrough, baseStyle.flatMap(_getLineThrough), _setLineThrough),
       decorationColor = _AttributeIterable(decorationColor, baseStyle?.decorationColor, _setDecorationColor),
       decorationStyle = _AttributeIterable(decorationStyle, baseStyle?.decorationStyle, _setDecorationStyle),
       decorationThickness = _AttributeIterable(decorationThickness, baseStyle?.decorationThickness, _setDecorationThickness),
       shadows = _AttributeIterable<List<ui.Shadow>>(shadows, baseStyle?.shadows, _setShadows);

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
  }) : fontFamilies = _AttributeIterable(fontFamilies, baseStyle.flatMap(_getFontFamilies), _setFontFamilies),
       locale = _AttributeIterable(locale, baseStyle?.locale, _setLocale),
       fontSize = _AttributeIterable(fontSize, baseStyle?.fontSize, _setFontSize),
       fontWeight = _AttributeIterable(fontWeight, baseStyle?.fontWeight, _setFontWeight),
       fontStyle = _AttributeIterable(fontStyle, baseStyle?.fontStyle, _setFontStyle),
       fontFeatures = _AttributeIterable(fontFeatures, baseStyle?.fontFeatures, _setFontFeatures),
       fontVariations = _AttributeIterable(fontVariations, baseStyle?.fontVariations, _setFontVariations),
       leadingDistribution = _AttributeIterable(leadingDistribution, baseStyle?.leadingDistribution, _setLeadingDistribution),
       height = _AttributeIterable(height, baseStyle?.height, _setHeight),
       textBaseline = _AttributeIterable(textBaseline, baseStyle?.textBaseline, _setTextBaseline),
       letterSpacing = _AttributeIterable(letterSpacing, baseStyle?.letterSpacing, _setLetterSpacing),
       wordSpacing = _AttributeIterable(wordSpacing, baseStyle?.wordSpacing, _setWordSpacing),
       foreground = _AttributeIterable(foreground, baseStyle.flatMap(_getForeground), _setForeground),
       background = _AttributeIterable(background, baseStyle.flatMap(_getBackground), _setBackground),
       underline = _AttributeIterable(underline, baseStyle.flatMap(_getUnderline), _setUnderline),
       overline = _AttributeIterable(overline, baseStyle.flatMap(_getOverline), _setOverline),
       lineThrough = _AttributeIterable(lineThrough, baseStyle.flatMap(_getLineThrough), _setLineThrough),
       decorationColor = _AttributeIterable(decorationColor, baseStyle?.decorationColor, _setDecorationColor),
       decorationStyle = _AttributeIterable(decorationStyle, baseStyle?.decorationStyle, _setDecorationStyle),
       decorationThickness = _AttributeIterable(decorationThickness, baseStyle?.decorationThickness, _setDecorationThickness),
       shadows = _AttributeIterable<List<ui.Shadow>>(shadows, baseStyle?.shadows, _setShadows);

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
      ..[12] = foreground._getTextStyleRunsEndAfter(index)
      ..[13] = background._getTextStyleRunsEndAfter(index)

      ..[14] = underline._getTextStyleRunsEndAfter(index)
      ..[15] = overline._getTextStyleRunsEndAfter(index)
      ..[16] = lineThrough._getTextStyleRunsEndAfter(index)

      ..[17] = decorationColor._getTextStyleRunsEndAfter(index)
      ..[18] = decorationStyle._getTextStyleRunsEndAfter(index)
      ..[19] = decorationThickness._getTextStyleRunsEndAfter(index)
      ..[20] = shadows._getTextStyleRunsEndAfter(index);
    return _TextStyleMergingIterator(runsToMerge, _MutableTextStyleAttributeSet.fromTextStyle(baseStyle ?? const TextStyle()));
  }

  _TextStyleAnnotations overwrite(int start, int? end, TextStyleAttributeSet annotationsToOverwrite) {
    _AttributeIterable<Value> update<Value extends Object>(Value? newAttribute, _AttributeIterable<Value> tree) {
      return _AttributeIterable(tree.storage.insertRange(start, end, newAttribute), tree.defaultValue, tree.setter);
    }

    return _TextStyleAnnotations._(
      update(annotationsToOverwrite.fontFamilies, fontFamilies),
      update(annotationsToOverwrite.locale, locale),
      update(annotationsToOverwrite.fontWeight, fontWeight),
      update(annotationsToOverwrite.fontStyle, fontStyle),
      update(annotationsToOverwrite.fontFeatures, fontFeatures),
      update(annotationsToOverwrite.fontVariations, fontVariations),
      update(annotationsToOverwrite.textBaseline, textBaseline),
      update(annotationsToOverwrite.leadingDistribution, leadingDistribution),
      update(annotationsToOverwrite.fontSize, fontSize),
      update(annotationsToOverwrite.height, height),
      update(annotationsToOverwrite.letterSpacing, letterSpacing),
      update(annotationsToOverwrite.wordSpacing, wordSpacing),

      update(annotationsToOverwrite.foreground, foreground),
      update(annotationsToOverwrite.background, background),
      update(annotationsToOverwrite.underline, underline),
      update(annotationsToOverwrite.overline, overline),
      update(annotationsToOverwrite.lineThrough, lineThrough),
      update(annotationsToOverwrite.decorationColor, decorationColor),
      update(annotationsToOverwrite.decorationStyle, decorationStyle),
      update(annotationsToOverwrite.decorationThickness, decorationThickness),
      update(annotationsToOverwrite.shadows, shadows),
      baseStyle,
    );
  }
}

extension TextStyleAnnotatedString on AnnotatedString {
  @useResult
  AnnotatedString applyTextStyle(TextStyle style, ui.TextRange range) {
    assert(range.isNormalized);
    assert(!range.isCollapsed);
    assert(range.end <= string.length);
    final _TextStyleAnnotations? annotations = getAnnotationOfType();
    final TextStyle? baseStyle = annotations == null && range.start == 0 && range.end == string.length
      ? style
      : null;

    final newAnnotation = baseStyle != null
      ? _TextStyleAnnotations(baseStyle: baseStyle)
      : (annotations ?? _TextStyleAnnotations(baseStyle: null)).overwrite(range.start, range.end == string.length ? null : range.end, _MutableTextStyleAttributeSet.fromTextStyle(style));
    return setAnnotation(newAnnotation);
  }
}

/// An annotation type that represents the extra semantics information of the text.
class _SemanticsAnnotations {
  const _SemanticsAnnotations(this.semanticsLabels, this.spellOut, this.gestureCallbacks, this.textLength);

  final RBTree<String?>? semanticsLabels;
  final RBTree<bool?>? spellOut;
  // Either onTap callbacks or onLongPress callbacks.
  final RBTree<Either<VoidCallback, VoidCallback>?>? gestureCallbacks;
  final int textLength;

  Iterator<SemanticsAttributeSet> getSemanticsInformation(int codeUnitOffset) {
    // TODO: implement getSemanticsInformation
    throw UnimplementedError();
  }

  _SemanticsAnnotations overwrite(ui.TextRange range, SemanticsAttributeSet newAttribute) {
    final int? end = range.end >= textLength ? null : range.end;

    RBTree<Value?>? update<Value extends Object>(Value? newAttribute, RBTree<Value?>? tree) {
      return newAttribute == null ? tree : tree.insertRange(range.start, end, newAttribute);
    }

    return _SemanticsAnnotations(
      update(newAttribute.semanticsLabel, semanticsLabels),
      update(newAttribute.spellOut, spellOut),
      update(newAttribute.gestureCallback, gestureCallbacks),
      textLength,
    );
  }
}

class _TextHitTestAnnotations {
  const _TextHitTestAnnotations(this._hitTestTargets);

  final RBTree<Iterable<HitTestTarget>>? _hitTestTargets;

  Iterable<HitTestTarget> getHitTestTargets(int codeUnitOffset) {
    final Iterator<(int, Iterable<HitTestTarget>)>? iterator = _hitTestTargets?.getRunsEndAfter(codeUnitOffset);
    return iterator != null && iterator.moveNext() ? iterator.current.$2 : const <HitTestTarget>[];
  }

  TextHitTestAnnotations overwrite(ui.TextRange range, List<HitTestTarget> newAttribute) {
    throw UnimplementedError();
  }
}
