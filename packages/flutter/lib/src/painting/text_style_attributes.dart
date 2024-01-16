// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math show min, max;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/src/foundation/persistent_rb_tree.dart';

import 'text_style.dart';

typedef _TextStyleAttribute<T extends Object> = ({
  RBTree<T?> attribute,
  TextStyle Function(T attribute) lift,
});

class _IndexedTextStyleIterator {
  _IndexedTextStyleIterator(this.list) : assert(list.isNotEmpty);
  final List<(int, TextStyle)> list;
  // Being negative means this has reached end.
  int nextIndex = 0;
  (int, TextStyle)? get currentValue => nextIndex >= 0 ? list[nextIndex] : null;

  TextStyle? consume(int index) {
    final currentValue = this.currentValue;
    if (currentValue == null) {
      return null;
    }
    final (int nextStart, TextStyle style) = currentValue;
    if (nextStart > index) {
      return null;
    }
    assert(nextStart == index);
    nextIndex += 1;
    if (nextStart >= list.length) {
      nextIndex = -1;
    }
    return style;
  }
}

const TypographicAnnotation defaultTypographicAnnotation = (
  fontWeight: ui.FontWeight.w400,
  fontStyle: ui.FontStyle.normal,
  fontFeatures: [],
  fontVariations: [],

  textBaseline: ui.TextBaseline.alphabetic,
  textLeadingDistribution: ui.TextLeadingDistribution.proportional,

  fontFamilies: <String>[''],
  locale: '',

  fontSize: 14.0,
  height: null,
  letterSpacing: 0.0,
  wordSpacing: 0.0,
);

@immutable
class TypographicAnnotations {
  TypographicAnnotations._(
    this._fontFamilies,
    this._locale,
    this._fontWeight,
    this._fontStyle,
    this._fontFeatures,
    this._fontVariations,
    this._textBaseline,
    this._textLeadingDistribution,
    this._fontSize,
    this._height,
    this._letterSpacing,
    this._wordSpacing,
    this.defaults,
  );

  final TypographicAnnotation defaults;

  final _TextStyleAttribute<List<String>> _fontFamilies;
  final _TextStyleAttribute<ui.Locale> _locale;

  final _TextStyleAttribute<ui.FontWeight> _fontWeight;
  final _TextStyleAttribute<ui.FontStyle> _fontStyle;
  final PersistentHashMap<String, RBTree<int>> _fontFeatures;
  final PersistentHashMap<String, RBTree<double>> _fontVariations;

  final _TextStyleAttribute<ui.TextBaseline> _textBaseline;
  final _TextStyleAttribute<ui.TextLeadingDistribution> _textLeadingDistribution;

  final _TextStyleAttribute<double> _fontSize;
  final _TextStyleAttribute<double> _height;
  final _TextStyleAttribute<double> _letterSpacing;
  final _TextStyleAttribute<double> _wordSpacing;

  (int, TextStyle?) getAnnotationAt(int index) {
    (int, TextStyle?) lift<T extends Object>(_TextStyleAttribute<T> attribute) {
      final RBTree<T?>? value = attribute.attribute.getNodeLessThanOrEqualTo(index);
      final T? v = value?.value;
      final TextStyle? style = v == null ? null : attribute.lift(v);
      return (value?.key ?? 0, style);
    }
    final xs = [
      lift(_fontFamilies),
      lift(_locale),
      lift(_fontWeight),
      lift(_fontStyle),
      lift(_textBaseline),
      lift(_textLeadingDistribution),
      lift(_fontSize),
      lift(_height),
      lift(_letterSpacing),
      lift(_wordSpacing),
      //..._f
    ];
    int styleIndex = 0;
    TextStyle? textStyle;
    for (final (int index, TextStyle? style) in xs) {
      styleIndex = math.max(index, styleIndex);
      textStyle = textStyle?.merge(style) ?? style;
    }
    return (styleIndex, textStyle);
  }

  static List<(int, Value)> _serializeToList<Value>(RBTree<Value>? tree, int startingKey, [List<(int, Value)> list = const <(int, Value)>[]]) {
    if (tree == null) {
      return list;
    }
    if (startingKey < tree.key) {
      _serializeToList(tree.left, startingKey, list);
    }
    if (startingKey <= tree.key) {
      list.add((tree.key, tree.value));
    }
    _serializeToList(tree.right, startingKey, list);
    return list;
  }

  static List<(int, TextStyle?)> _merge(Iterable<_IndexedTextStyleIterator> iterators) {
    int? runStartIndex = 0;
    final List<(int, TextStyle?)> returnValue = <(int, TextStyle?)>[];
    while (runStartIndex != null) {
      int? nextRunStartIndex;
      TextStyle? runTextStyle;
      for (final iterator in iterators) {
        runTextStyle = iterator.consume(runStartIndex)?.merge(runTextStyle) ?? runTextStyle;
        final iteratorNextIndex = iterator.nextIndex;
        if (iteratorNextIndex >= 0 && (nextRunStartIndex == null || iteratorNextIndex < nextRunStartIndex)) {
          nextRunStartIndex = iteratorNextIndex;
        }
      }
      runStartIndex = nextRunStartIndex;
    }
    return returnValue;
  }

  List<(int, TextStyle?)> getIterable( [int startIndex = 0]) {
    Iterable<(int, TextStyle)> lift<T extends Object>(_TextStyleAttribute<T> attribute) {
      (int, TextStyle) mapEntry((int, T?) entry) {
        final T? value = entry.$2;
        return (entry.$1, value == null ? null : attribute.lift(value));
      }
      return _serializeToList(attribute.attribute, startIndex).map(mapEntry);
    }

    final xs = [
      //lift(_fontFamilies),
      lift(_locale),
      lift(_fontWeight),
      lift(_fontStyle),
      lift(_textBaseline),
      lift(_textLeadingDistribution),
      lift(_fontSize),
      lift(_height),
      lift(_letterSpacing),
      lift(_wordSpacing),
      //..._f
    ].where((element) => element.isNotEmpty).map((e) => e.toList()).map(_IndexedTextStyleIterator.new);
    return _merge(xs);
  }
}

final class TextPaintStyle {
  TextPaintStyle(
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

typedef TypographicAnnotation = ({
  ui.FontWeight fontWeight,
  ui.FontStyle fontStyle,
  PersistentHashMap<String, int> fontFeatures,
  PersistentHashMap<String, double> fontVariations,

  ui.TextBaseline textBaseline,
  ui.TextLeadingDistribution textLeadingDistribution,

  String fontFamily,
  List<String> fontFamilyFallback,
  ui.Locale locale,

  double fontSize,
  double height,
  double letterSpacing,
  double wordSpacing,
});


typedef TextPaintAnnotation = ({
  ui.Paint foregroundPainter,
  ui.Paint backgroundPainter,
  ui.Shadow shadows,

  ui.TextDecoration decorations,
  ui.Color decorationColor,
  ui.TextDecorationStyle decorationStyle,
  double decorationThickness,
});

