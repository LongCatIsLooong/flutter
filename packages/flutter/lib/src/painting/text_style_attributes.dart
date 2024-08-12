// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'annotated_string.dart';
import 'text_scaler.dart';
import 'text_style.dart';

extension Isomorphic on TextStyleAttributeSet {
  TextStyle toTextStyle(TextStyle baseStyle) {
    final (String? fontFamily, List<String>? fallback) = switch (fontFamilies) {
      null => (null, null),
      [] => ('', const <String>[]),
      [final String fontFamily, ...final List<String> fallback] => (fontFamily, fallback)
    };

    final ui.TextDecoration? decoration = underline == null && overline == null && lineThrough == null
      ? null
      : ui.TextDecoration.combine(<ui.TextDecoration>[
          if (underline ?? baseStyle.decoration?.contains(ui.TextDecoration.underline) ?? false) ui.TextDecoration.underline,
          if (overline ?? baseStyle.decoration?.contains(ui.TextDecoration.overline) ?? false) ui.TextDecoration.overline,
          if (lineThrough ?? baseStyle.decoration?.contains(ui.TextDecoration.lineThrough) ?? false) ui.TextDecoration.lineThrough,
        ]);

    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      locale: locale,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontFeatures: fontFeatures,
      fontVariations: fontVariations,
      height: height,
      leadingDistribution: leadingDistribution,
      textBaseline: textBaseline,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      color: foreground?.maybeLeft,
      foreground: foreground?.maybeRight,
      backgroundColor: background?.maybeLeft,
      background: background?.maybeRight,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      shadows: shadows,
    );
  }

  ui.TextStyle getTextStyle({
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final (String? fontFamily, List<String>? fallback) = switch (fontFamilies) {
      null => (null, null),
      [] => ('', const <String>[]),
      [final String fontFamily, ...final List<String> fallback] => (fontFamily, fallback)
    };

    final ui.TextDecoration? decoration = underline == null && overline == null && lineThrough == null
      ? null
      : ui.TextDecoration.combine(<ui.TextDecoration>[
          if (underline ?? false) ui.TextDecoration.underline,
          if (overline ?? false) ui.TextDecoration.overline,
          if (lineThrough ?? false) ui.TextDecoration.lineThrough,
        ]);

    final double? fontSize = switch (this.fontSize) {
      null => null,
      final double size => textScaler.scale(size),
    };
    return ui.TextStyle(
      color: foreground?.maybeLeft,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textBaseline: textBaseline,
      leadingDistribution: leadingDistribution,
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      locale: locale,
      foreground: foreground?.maybeRight,
      background: switch (background) {
        Right(:final value) => value,
        Left(:final value) => ui.Paint()..color = value,
        null => null,
      },
      shadows: shadows,
      fontFeatures: fontFeatures,
      fontVariations: fontVariations,
    );
  }
}

class TextStyleAttributeSet {
  const TextStyleAttributeSet({
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

  @override
  final List<String>? fontFamilies;
  @override
  final ui.Locale? locale;
  @override
  final double? fontSize;
  @override
  final ui.FontWeight? fontWeight;
  @override
  final ui.FontStyle? fontStyle;

  @override
  final List<ui.FontFeature>? fontFeatures;
  @override
  final List<ui.FontVariation>? fontVariations;

  @override
  final double? height;
  @override
  final ui.TextLeadingDistribution? leadingDistribution;
  @override
  final ui.TextBaseline? textBaseline;

  @override
  final double? wordSpacing;
  @override
  final double? letterSpacing;

  @override
  final Either<ui.Color, ui.Paint>? foreground;
  @override
  final Either<ui.Color, ui.Paint>? background;
  @override
  final List<ui.Shadow>? shadows;

  @override
  final bool? underline;
  @override
  final bool? overline;
  @override
  final bool? lineThrough;

  @override
  final ui.Color? decorationColor;
  @override
  final ui.TextDecorationStyle? decorationStyle;
  @override
  final double? decorationThickness;

}
