// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

import 'inline_span.dart';
import 'placeholder_span.dart';
import 'text_painter.dart';

/// An immutable
@immutable
class AnnotatedString {
  const AnnotatedString._(this.string, [this._attributeStorage = const PersistentHashMap<Type, Object?>.empty()]);

  AnnotatedString._fromAnnotatedString(AnnotatedString string) :
    string = string.string,
    _attributeStorage = string._attributeStorage;

  AnnotatedString.fromInlineSpan(InlineSpan span) : this._fromAnnotatedString(_spanToAnnotatedString(span));

  final String string;

  // The PersistentHashMap class currently does not have a delete method.
  final PersistentHashMap<Type, Object?> _attributeStorage;

  // Read annotations of a specific type.
  T? getAnnotationOfType<T extends Object>() => _attributeStorage[T] as T?;

  /// Update annotations of a specific type `T` and return a new [AnnotatedString].
  ///
  /// The static type `T` is used as the key insead of the runtime type of
  /// newAnnotations, in case newAnnotations is null (and for consistency too).
  AnnotatedString setAnnotationOfType<T extends Object>(T? newAnnotations) {
    return AnnotatedString._(string, _attributeStorage.put(T, newAnnotations));
  }

  AnnotatedString get toAnnotatedString => this;
}

class _AnnotatedStringBuilder implements ui.ParagraphBuilder {
  final StringBuffer buffer = StringBuffer();
  final List<int> placeholderAnnotations = <int>[];

  final List<ui.TextStyle> styleStack = <ui.TextStyle>[];
  final List<(int, ui.TextStyle?)> styles = <(int, ui.TextStyle)>[];

  @override
  void addPlaceholder(double width, double height, ui.PlaceholderAlignment alignment, {double scale = 1.0, double? baselineOffset, ui.TextBaseline? baseline}) {
    placeholderAnnotations.add(buffer.length);
    commitText(String.fromCharCode(PlaceholderSpan.placeholderCodeUnit));
  }

  @override
  void addText(String text) => commitText(text);

  @override
  void pop() {
    styleStack.removeLast();
  }

  @override
  void pushStyle(ui.TextStyle style) {
    styleStack.add(style);
  }

  void commitText(String text) {
    if (text.isEmpty) {
      return;
    }
    final ui.TextStyle? style = styleStack.isEmpty ? null : styleStack.last;
    styles.add((buffer.length, style));
    buffer.write(text);
  }

  @override
  ui.Paragraph build() => throw UnimplementedError();
  @override
  int get placeholderCount => throw UnimplementedError();
  @override
  List<double> get placeholderScales => throw UnimplementedError();
}

AnnotatedString _spanToAnnotatedString(InlineSpan span) {
  int placeholderCount = 0;
  span.visitChildren((InlineSpan span) {
    if (span is PlaceholderSpan) {
      placeholderCount += 1;
    }
    return true;
  });
  final List<PlaceholderDimensions>? dimensions = placeholderCount == 0 ? null : List<PlaceholderDimensions>.filled(placeholderCount, PlaceholderDimensions.empty);
  final _AnnotatedStringBuilder builder = _AnnotatedStringBuilder();
  span.build(builder, dimensions: dimensions);
  final PersistentHashMap<Type, Object?> storage = const PersistentHashMap<Type, Object?>.empty();
    //.put(, value);

  return AnnotatedString._(builder.buffer.toString(), storage);
}
