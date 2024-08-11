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
  T? getAnnotation<T extends Object>() {
    return _attributeStorage[T] as T?;
  }

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
    ui.TextStyle? styleToApply;
    if (baseStyle != null) {
      builder.pushStyle(baseStyle!.getTextStyle(textScaler: textScaler));
    }
    while(iterator != null && iterator.moveNext()) {
      final (int nextStartIndex, TextStyleAttributeSet? nextStyle) = iterator.current;
      assert(nextStartIndex > styleStartIndex || (nextStartIndex == 0 && styleStartIndex == 0), '$nextStartIndex > $styleStartIndex');
      if (nextStartIndex > styleStartIndex) {
        if (styleToApply != null) {
          builder.pushStyle(styleToApply);
        }
        builder.addText(string.substring(styleStartIndex, nextStartIndex));
        if (styleToApply != null) {
          builder.pop();
        }
      }
      styleStartIndex = nextStartIndex;
      styleToApply = nextStyle?.getTextStyle(textScaler: textScaler);
    }
    if (styleStartIndex < string.length) {
      if (styleToApply != null) {
        builder.pushStyle(styleToApply);
      }
      builder.addText(string.substring(styleStartIndex, string.length));
    }
  }

  @override
  AnnotatedString buildAnnotations(int offset, AnnotatedString? annotatedString) {
    assert(annotatedString == null);
    assert(offset == 0);
    return this;
  }

  @override
  int? codeUnitAt(int index) => string.codeUnitAt(index);

  @override
  RenderComparison compareTo(InlineSpan other) {
    if (identical(this, other)) {
      return RenderComparison.identical;
    }
    if (other is! AnnotatedString) {
      return RenderComparison.layout;
    }
    // TODO
    return RenderComparison.layout;
  }

  @override
  int? codeUnitAtVisitor(int index, Accumulator offset) {
    final int localOffset = index - offset.value;
    assert(localOffset >= 0);
    offset.increment(string.length);
    return localOffset < string.length ? string.codeUnitAt(localOffset) : null;
  }

  @override
  void computeSemanticsInformation(List<InlineSpanSemanticsInformation> collector) {
    // ??
    collector.addAll(getCombinedSemanticsInfo());
  }

  @override
  String computeToPlainText(StringBuffer buffer, {bool includeSemanticsLabels = true, bool includePlaceholders = true}) {
    final bool addSemanticsLabels = includeSemanticsLabels || false;
    final bool removePlaceholders = !includePlaceholders || false;
    if (!addSemanticsLabels && !removePlaceholders) {
      return string;
    }
    throw UnimplementedError();
  }

  @override
  AnnotatedString? getSpanForPositionVisitor(ui.TextPosition position, Accumulator offset) {
    final int localOffset = position.offset - offset.value;
    offset.increment(string.length);
    return 0 <= localOffset && localOffset < string.length ? this : null;
  }

  @override
  bool debugAssertIsValid() => true;

  @override
  int get contentLength => string.length;

  @override
  TextStyle? get style => baseStyle;

  @override
  bool visitChildren(InlineSpanVisitor visitor) => string.isEmpty || visitor(this);

  @override
  bool visitDirectChildren(InlineSpanVisitor visitor) => true;

  @override
  List<InlineSpanSemanticsInformation> getSemanticsInformation() => getCombinedSemanticsInfo();

  @override
  AnnotatedString? getSpanForPosition(TextPosition position) {
    return 0 <= position.offset && position.offset < string.length ? this : null;
  }

  @override
  String toPlainText({bool includeSemanticsLabels = true, bool includePlaceholders = true}) {
    return computeToPlainText(StringBuffer());
  }
}
