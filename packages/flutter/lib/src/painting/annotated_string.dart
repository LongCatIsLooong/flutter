// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'inline_span.dart';
import 'string_annotations.dart';
import 'text_painter.dart';
import 'text_scaler.dart';
import 'text_style.dart';
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

  /// Retrieve annotations of a specific type.
  @pragma('dart2js:as:trust')
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
    final Iterator<(int, TextStyleAttributeSet?)>? iterator = getTextStyleRunsEndAfter(0);

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
  List<InlineSpanSemanticsInformation> getSemanticsInformation() => getCombinedSemanticsInfo();

  @override
  InlineSpan? getSpanForPosition(ui.TextPosition position) => this;

  @override
  TextStyle? get style => baseStyle;

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
