// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs (REMOVE)
// ignore_for_file: always_specify_types (REMOVE)

/// @docImport 'dart:ui';
///
/// @docImport 'package:flutter/material.dart';
///
/// @docImport 'placeholder_span.dart';
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'annotated_string.dart';
import 'basic_types.dart';
import 'text_painter.dart';
import 'text_scaler.dart';
import 'text_style.dart';
import 'text_style_attributes.dart';

// Examples can assume:
// late InlineSpan myInlineSpan;

/// Mutable wrapper of an integer that can be passed by reference to track a
/// value across a recursive stack.
class Accumulator {
  /// [Accumulator] may be initialized with a specified value, otherwise, it will
  /// initialize to zero.
  Accumulator([this._value = 0]);

  /// The integer stored in this [Accumulator].
  int get value => _value;
  int _value;

  /// Increases the [value] by the `addend`.
  void increment(int addend) {
    assert(addend >= 0);
    _value += addend;
  }
}
/// Called on each span as [InlineSpan.visitChildren] walks the [InlineSpan] tree.
///
/// Returns true when the walk should continue, and false to stop visiting further
/// [InlineSpan]s.
typedef InlineSpanVisitor = bool Function(InlineSpan span);

/// The textual and semantic label information for an [InlineSpan].
///
/// For [PlaceholderSpan]s, [InlineSpanSemanticsInformation.placeholder] is used by default.
///
/// See also:
///
///  * [InlineSpan.getSemanticsInformation]
@immutable
class InlineSpanSemanticsInformation {
  /// Constructs an object that holds the text and semantics label values of an
  /// [InlineSpan].
  ///
  /// Use [InlineSpanSemanticsInformation.placeholder] instead of directly setting
  /// [isPlaceholder].
  const InlineSpanSemanticsInformation(
    String text, {
    String? semanticsLabel,
    List<ui.StringAttribute> stringAttributes = const <ui.StringAttribute>[],
    GestureRecognizer? recognizer,
  }) : this._(text, isPlaceholder: true, semanticsLabel: semanticsLabel, stringAttributes: stringAttributes, recognizer: recognizer);

  const InlineSpanSemanticsInformation._(
    this.text, {
    this.isPlaceholder = false,
    this.semanticsLabel,
    this.stringAttributes = const <ui.StringAttribute>[],
    this.recognizer,
  }) : assert(!isPlaceholder || (text == '\uFFFC' && semanticsLabel == null && recognizer == null));

  /// The text info for a [PlaceholderSpan].
  static const InlineSpanSemanticsInformation placeholder = InlineSpanSemanticsInformation._('\uFFFC', isPlaceholder: true);

  /// The text value, if any. For [PlaceholderSpan]s, this will be the unicode
  /// placeholder value.
  final String text;

  /// The semanticsLabel, if any.
  final String? semanticsLabel;

  /// The gesture recognizer, if any, for this span.
  final GestureRecognizer? recognizer;

  /// Whether this is for a placeholder span.
  final bool isPlaceholder;

  /// True if this configuration should get its own semantics node.
  ///
  /// This will be the case of the [recognizer] is not null, of if
  /// [isPlaceholder] is true.
  bool get requiresOwnNode => isPlaceholder || recognizer != null;

  /// The string attributes attached to this semantics information
  final List<ui.StringAttribute> stringAttributes;

  @override
  bool operator ==(Object other) {
    return other is InlineSpanSemanticsInformation
        && other.text == text
        && other.semanticsLabel == semanticsLabel
        && other.recognizer == recognizer
        && other.isPlaceholder == isPlaceholder
        && listEquals<ui.StringAttribute>(other.stringAttributes, stringAttributes);
  }

  @override
  int get hashCode => Object.hash(text, semanticsLabel, recognizer, isPlaceholder);

  @override
  String toString() => '${objectRuntimeType(this, 'InlineSpanSemanticsInformation')}{text: $text, semanticsLabel: $semanticsLabel, recognizer: $recognizer}';
}

/// Combines _semanticsInfo entries where permissible.
///
/// Consecutive inline spans can be combined if their
/// [InlineSpanSemanticsInformation.requiresOwnNode] return false.
List<InlineSpanSemanticsInformation> combineSemanticsInfo(List<InlineSpanSemanticsInformation> infoList) {
  final List<InlineSpanSemanticsInformation> combined = <InlineSpanSemanticsInformation>[];
  String workingText = '';
  String workingLabel = '';
  List<ui.StringAttribute> workingAttributes = <ui.StringAttribute>[];
  for (final InlineSpanSemanticsInformation info in infoList) {
    if (info.requiresOwnNode) {
      combined.add(InlineSpanSemanticsInformation(
        workingText,
        semanticsLabel: workingLabel,
        stringAttributes: workingAttributes,
      ));
      workingText = '';
      workingLabel = '';
      workingAttributes = <ui.StringAttribute>[];
      combined.add(info);
    } else {
      workingText += info.text;
      final String effectiveLabel = info.semanticsLabel ?? info.text;
      for (final ui.StringAttribute infoAttribute in info.stringAttributes) {
        workingAttributes.add(
          infoAttribute.copy(
            range: TextRange(
              start: infoAttribute.range.start + workingLabel.length,
              end: infoAttribute.range.end + workingLabel.length,
            ),
          ),
        );
      }
      workingLabel += effectiveLabel;

    }
  }
  combined.add(InlineSpanSemanticsInformation(
    workingText,
    semanticsLabel: workingLabel,
    stringAttributes: workingAttributes,
  ));
  return combined;
}

/// An immutable span of inline content which forms part of a paragraph.
///
///  * The subclass [TextSpan] specifies text and may contain child [InlineSpan]s.
///  * The subclass [PlaceholderSpan] represents a placeholder that may be
///    filled with non-text content. [PlaceholderSpan] itself defines a
///    [PlaceholderAlignment] and a [TextBaseline]. To be useful,
///    [PlaceholderSpan] must be extended to define content. An instance of
///    this is the [WidgetSpan] class in the widgets library.
///  * The subclass [WidgetSpan] specifies embedded inline widgets.
///
/// {@tool snippet}
///
/// This example shows a tree of [InlineSpan]s that make a query asking for a
/// name with a [TextField] embedded inline.
///
/// ```dart
/// Text.rich(
///   TextSpan(
///     text: 'My name is ',
///     style: const TextStyle(color: Colors.black),
///     children: <InlineSpan>[
///       WidgetSpan(
///         alignment: PlaceholderAlignment.baseline,
///         baseline: TextBaseline.alphabetic,
///         child: ConstrainedBox(
///           constraints: const BoxConstraints(maxWidth: 100),
///           child: const TextField(),
///         )
///       ),
///       const TextSpan(
///         text: '.',
///       ),
///     ],
///   ),
/// )
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [Text], a widget for showing uniformly-styled text.
///  * [RichText], a widget for finer control of text rendering.
///  * [TextPainter], a class for painting [InlineSpan] objects on a [Canvas].
@immutable
abstract class InlineSpan extends DiagnosticableTree implements AnnotatedString {
  /// Creates an [InlineSpan] with the given values.
  const InlineSpan({
    this.style,
  });

  /// The [TextStyle] to apply to this span.
  ///
  /// The [style] is also applied to any child spans when this is an instance
  /// of [TextSpan].
  final TextStyle? style;

  /// Apply the properties of this object to the given [ParagraphBuilder], from
  /// which a [Paragraph] can be obtained.
  ///
  /// The `textScaler` parameter specifies a [TextScaler] that the text and
  /// placeholders will be scaled by. The scaling is performed before layout,
  /// so the text will be laid out with the scaled glyphs and placeholders.
  ///
  /// The `dimensions` parameter specifies the sizes of the placeholders.
  /// Each [PlaceholderSpan] must be paired with a [PlaceholderDimensions]
  /// in the same order as defined in the [InlineSpan] tree.
  ///
  /// [Paragraph] objects can be drawn on [Canvas] objects.
  void build(ui.ParagraphBuilder builder, {
    TextScaler textScaler = TextScaler.noScaling,
    List<PlaceholderDimensions>? dimensions,
  });

  /// Walks this [InlineSpan] and any descendants in pre-order and calls `visitor`
  /// for each span that has content.
  ///
  /// When `visitor` returns true, the walk will continue. When `visitor` returns
  /// false, then the walk will end.
  ///
  /// See also:
  ///
  ///  * [visitDirectChildren], which preforms `build`-order traversal on the
  ///    immediate children of this [InlineSpan], regardless of whether they
  ///    have content.
  bool visitChildren(InlineSpanVisitor visitor);

  /// Calls `visitor` for each immediate child of this [InlineSpan].
  ///
  /// The immediate children are visited in the same order they are added to
  /// a [ui.ParagraphBuilder] in the [build] method, which is also the logical
  /// order of the child [InlineSpan]s in the text.
  ///
  /// The traversal stops when all immediate children are visited, or when the
  /// `visitor` callback returns `false` on an immediate child. This method
  /// itself returns a `bool` indicating whether the visitor callback returned
  /// `true` on all immediate children.
  ///
  /// See also:
  ///
  ///  * [visitChildren], which performs preorder traversal on this [InlineSpan]
  ///    if it has content, and all its descendants with content.
  bool visitDirectChildren(InlineSpanVisitor visitor);

  /// Returns the [InlineSpan] that contains the given position in the text.
  InlineSpan? getSpanForPosition(TextPosition position) {
    assert(debugAssertIsValid());
    final Accumulator offset = Accumulator();
    InlineSpan? result;
    visitChildren((InlineSpan span) {
      result = span.getSpanForPositionVisitor(position, offset);
      return result == null;
    });
    return result;
  }

  /// Performs the check at each [InlineSpan] for if the `position` falls within the range
  /// of the span and returns the span if it does.
  ///
  /// The `offset` parameter tracks the current index offset in the text buffer formed
  /// if the contents of the [InlineSpan] tree were concatenated together starting
  /// from the root [InlineSpan].
  ///
  /// This method should not be directly called. Use [getSpanForPosition] instead.
  @protected
  InlineSpan? getSpanForPositionVisitor(TextPosition position, Accumulator offset);

  /// Flattens the [InlineSpan] tree into a single string.
  ///
  /// Styles are not honored in this process. If `includeSemanticsLabels` is
  /// true, then the text returned will include the [TextSpan.semanticsLabel]s
  /// instead of the text contents for [TextSpan]s.
  ///
  /// When `includePlaceholders` is true, [PlaceholderSpan]s in the tree will be
  /// represented as a 0xFFFC 'object replacement character'.
  String toPlainText({bool includeSemanticsLabels = true, bool includePlaceholders = true}) {
    final StringBuffer buffer = StringBuffer();
    computeToPlainText(buffer, includeSemanticsLabels: includeSemanticsLabels, includePlaceholders: includePlaceholders);
    return buffer.toString();
  }

  /// Flattens the [InlineSpan] tree to a list of
  /// [InlineSpanSemanticsInformation] objects.
  ///
  /// [PlaceholderSpan]s in the tree will be represented with a
  /// [InlineSpanSemanticsInformation.placeholder] value.
  List<InlineSpanSemanticsInformation> getSemanticsInformation() {
    final List<InlineSpanSemanticsInformation> collector = <InlineSpanSemanticsInformation>[];
    computeSemanticsInformation(collector);
    return collector;
  }

  /// Walks the [InlineSpan] tree and accumulates a list of
  /// [InlineSpanSemanticsInformation] objects.
  ///
  /// This method should not be directly called. Use
  /// [getSemanticsInformation] instead.
  ///
  /// [PlaceholderSpan]s in the tree will be represented with a
  /// [InlineSpanSemanticsInformation.placeholder] value.
  @protected
  void computeSemanticsInformation(List<InlineSpanSemanticsInformation> collector);

  /// Walks the [InlineSpan] tree and writes the plain text representation to `buffer`.
  ///
  /// This method should not be directly called. Use [toPlainText] instead.
  ///
  /// Styles are not honored in this process. If `includeSemanticsLabels` is
  /// true, then the text returned will include the [TextSpan.semanticsLabel]s
  /// instead of the text contents for [TextSpan]s.
  ///
  /// When `includePlaceholders` is true, [PlaceholderSpan]s in the tree will be
  /// represented as a 0xFFFC 'object replacement character'.
  ///
  /// The plain-text representation of this [InlineSpan] is written into the `buffer`.
  /// This method will then recursively call [computeToPlainText] on its children
  /// [InlineSpan]s if available.
  @protected
  void computeToPlainText(StringBuffer buffer, {bool includeSemanticsLabels = true, bool includePlaceholders = true});

  /// Returns the UTF-16 code unit at the given `index` in the flattened string.
  ///
  /// This only accounts for the [TextSpan.text] values and ignores [PlaceholderSpan]s.
  ///
  /// Returns null if the `index` is out of bounds.
  int? codeUnitAt(int index) {
    if (index < 0) {
      return null;
    }
    final Accumulator offset = Accumulator();
    int? result;
    visitChildren((InlineSpan span) {
      result = span.codeUnitAtVisitor(index, offset);
      return result == null;
    });
    return result;
  }

  /// Performs the check at each [InlineSpan] for if the `index` falls within the range
  /// of the span and returns the corresponding code unit. Returns null otherwise.
  ///
  /// The `offset` parameter tracks the current index offset in the text buffer formed
  /// if the contents of the [InlineSpan] tree were concatenated together starting
  /// from the root [InlineSpan].
  ///
  /// This method should not be directly called. Use [codeUnitAt] instead.
  @protected
  int? codeUnitAtVisitor(int index, Accumulator offset);

  /// In debug mode, throws an exception if the object is not in a
  /// valid configuration. Otherwise, returns true.
  ///
  /// This is intended to be used as follows:
  ///
  /// ```dart
  /// assert(myInlineSpan.debugAssertIsValid());
  /// ```
  bool debugAssertIsValid() => true;

  /// Describe the difference between this span and another, in terms of
  /// how much damage it will make to the rendering. The comparison is deep.
  ///
  /// Comparing [InlineSpan] objects of different types, for example, comparing
  /// a [TextSpan] to a [WidgetSpan], always results in [RenderComparison.layout].
  ///
  /// See also:
  ///
  ///  * [TextStyle.compareTo], which does the same thing for [TextStyle]s.
  RenderComparison compareTo(InlineSpan other);

  @override
  String get string => toPlainText(includeSemanticsLabels: false);

  @override
  T? getAnnotationOfType<T extends Object>() {
    if (identical(T, _TextStyleAnnotations)) {
      return _TextStyleAnnotations(baseStyle: style) as T;
    }
    return null;
  }

  @override
  AnnotatedString setAnnotation<T extends Object>(T newAnnotations) {
    return buildAnnotations(0, const <Object, int>{}, null).setAnnotation(newAnnotations);
  }

  @visibleForOverriding
  AnnotatedString buildAnnotations(int offset, Map<Object, int> childrenLength, AnnotatedString? annotatedString);

  int getContentLength(Map<Object, int> childrenLength);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is InlineSpan
        && other.style == style;
  }

  @override
  int get hashCode => style.hashCode;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.defaultDiagnosticsTreeStyle = DiagnosticsTreeStyle.whitespace;
    style?.debugFillProperties(properties);
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
    final RBTree<Value?>? rightSubtree = tree.getNodeGreaterThan(end);
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
        final RBTree<Value?> newRightTree = rightSubtree?.insert(end, nodeBeforeEnd?.value)
          ?? RBTree.black(end, nodeBeforeEnd?.value);
        return leftSubtree?.join(newRightTree, start, value) ?? newRightTree.insert(start, value);
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
  AnnotatedString applyTextStyle(TextStyle style, ui.TextRange range) {
    assert(range.isNormalized);
    assert(!range.isCollapsed);
    assert(range.end <= string.length);
    final _TextStyleAnnotations? annotations = getAnnotationOfType();
    final TextStyleAttributeSet newStyleSet = _MutableTextStyleAttributeSet.fromTextStyle(style);
    final newAnnotation = (annotations ?? _TextStyleAnnotations(baseStyle: null))
      .overwrite(range.start, range.end == string.length ? null : range.end, newStyleSet);
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

  Iterable<SemanticsAttributeSet> getSemanticsInformation(int codeUnitOffset) {
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
