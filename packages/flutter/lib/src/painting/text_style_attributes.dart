// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math show max, min;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/src/foundation/persistent_rb_tree.dart';

import 'text_style.dart';

typedef _TextStyleAttribute<T extends Object> = ({
  RBTree<T?> attribute,
  TextStyle Function(T attribute) lift,
});

/// A wrapper iterator that allows safely querying the current value.
class _Run<T> {
  _Run(this.inner);

  bool? _canMoveNext;
  final Iterator<(int, T)> inner;

  (int, T)? get current => (_canMoveNext ??= moveNext()) ? inner.current : null;

  bool moveNext() => _canMoveNext = inner.moveNext();
}

class _MergedRunIterator<T> implements Iterator<(int, T)> {
  _MergedRunIterator(List<_Run<T>> runsToMerge, T Function(T, T) combine, T filler)
    : this._(runsToMerge.where((_Run<T> run) => run.current != null).toList(), combine, filler);

  _MergedRunIterator._(this.runs, this.combine, this.filler) : runsLength = runs.length;

  final List<_Run<T>> runs;
  int runsLength;

  final T Function(T, T) combine;

  final T filler;
  late final List<(T, _Run<T>?)> _buffer = List<(T, _Run<T>?)>.filled(runs.length, (filler, null));

  bool canMoveNext = true;

  @override
  late (int, T) current;

  @override
  bool moveNext() {
    if (runsLength <= 0) {
      return false;
    }
    int bufferLength = 0;
    int? index;

    for (int i = 0; i < runsLength; i += 1) {
      final _Run<T> run = runs[i];
      final (int newIndex, T newValue) = run.current!;
      if (index != null && index < newIndex) {
        continue;
      }
      if (newIndex != index) {
        assert(index == null || index > newIndex);
        bufferLength = 0;
      }
      index = newIndex;
      _buffer[bufferLength] = (newValue, run);
      bufferLength += 1;
    }

    if (index != null) {
      assert(bufferLength > 0);
      late T result;
      for (int j = 0; j < bufferLength; j += 1) {
        final (T value, _Run<T>? run) = _buffer[j];
        assert(run?.current != null);
        result = j == 0 ? value : combine(result, value);
        if (!run!.moveNext()) {
          runs
        }
      }
      current = (index, result);
      assert(canMoveNext);
      return true;
    }
    return canMoveNext = false;
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
    this._textLeadingDistribution,
    this._fontSize,
    this._height,
    this._letterSpacing,
    this._wordSpacing,
    this.defaults,
  );

  final TextStyle defaults;

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

  static List<(int, Value)> _serializeToList<Value>(RBTree<Value>? tree, int startingKey, List<(int, Value)> list) {
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

  Iterator<(int, TextStyle)> getIterable( [int startIndex = 0]) {
    Iterator<(int, TextStyle)> lift<T extends Object>(_TextStyleAttribute<T> attribute) {
      (int, TextStyle) mapEntry((int, T?) entry) {
        final T? value = entry.$2;
        return (entry.$1, value == null ? null : attribute.lift(value));
      }
      return attribute.attribute.getRunsEndAfter(startIndex);
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
    ].where((element) => element.isNotEmpty);
    return _MergedRunIterator(xs, (p0, p1) => null, const (0, TextStyle()));
  }
}

final class TextStyleAttributeSet {
  const TextStyleAttributeSet({
    this.fontWeight,
    this.fontStyle,
    this.fontFamilies,
    this.locale,
    this.fontSize,
    this.fontFeatures,
    this.fontVariations,
    this.height,
    this.textLeadingDistribution,
    this.textBaseline,
    this.wordSpacing,
    this.letterSpacing,
  });

  final ui.FontWeight? fontWeight;
  final ui.FontStyle? fontStyle;
  final List<String>? fontFamilies;
  final ui.Locale? locale;
  final double? fontSize;

  final Map<String, int>? fontFeatures;
  final Map<String, double>? fontVariations;

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
