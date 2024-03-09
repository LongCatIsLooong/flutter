// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'annotated_string.dart';
import 'text_style.dart';

interface class StringAnnotation<Key extends Object> {}

abstract class OverwritableStringAttribute<Self extends OverwritableStringAttribute<Self, Attribute>, Attribute> {
  Self overwrite(ui.TextRange range, Attribute newAttribute);
}

abstract final class _HitTestAnnotationKey {}
abstract class TextHitTestAnnotations implements StringAnnotation<_HitTestAnnotationKey>, OverwritableStringAttribute<TextHitTestAnnotations, List<HitTestTarget>> {
  Iterable<HitTestTarget> getHitTestTargets(int codeUnitOffset);
}

@immutable
final class SemanticsAttributeSet {
  const SemanticsAttributeSet({
    this.semanticsLabel,
    this.spellOut,
    this.gestureCallback,
  });

  final String? semanticsLabel;
  final bool? spellOut;
  final Either<VoidCallback, VoidCallback>? gestureCallback;
}

abstract final class _SemanticsAnnotationKey {}
/// An annotation type that represents the extra semantics information of the text.
abstract class SemanticsAnnotations implements StringAnnotation<_SemanticsAnnotationKey>, OverwritableStringAttribute<SemanticsAnnotations, SemanticsAttributeSet> {
  Iterable<SemanticsAttributeSet> getSemanticsInformation(int codeUnitOffset);
}
abstract final class _TextStyleAnnotationKey { }

abstract class BasicTextStyleAnnotations implements StringAnnotation<_TextStyleAnnotationKey>, OverwritableStringAttribute<TextStyleAnnotations, TextStyleAttributeSet> {
  ui.Paragraph toParagraph();

  TextStyle? get baseStyle;
  BasicTextStyleAnnotations updateBaseTextStyle(TextStyle baseAnnotations);
}

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
}

abstract class TextStyleAttributeSet {
  const factory TextStyleAttributeSet({
    List<String>? fontFamilies,
    ui.Locale? locale,
    double? fontSize,
    ui.FontWeight? fontWeight,
    ui.FontStyle? fontStyle,
    List<ui.FontFeature>? fontFeatures,
    List<ui.FontVariation>? fontVariations,
    double? height,
    ui.TextLeadingDistribution? leadingDistribution,
    ui.TextBaseline? textBaseline,
    double? wordSpacing,
    double? letterSpacing,
    Either<ui.Color, ui.Paint>? foreground,
    Either<ui.Color, ui.Paint>? background,
    List<ui.Shadow>? shadows,
    bool? underline,
    bool? overline,
    bool? lineThrough,
    ui.Color? decorationColor,
    ui.TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) = _TextStyleAttributeSet.new;

  List<String>? get fontFamilies;
  ui.Locale? get locale;
  double? get fontSize;
  ui.FontWeight? get fontWeight;
  ui.FontStyle? get fontStyle;

  List<ui.FontFeature>? get fontFeatures;
  List<ui.FontVariation>? get fontVariations;

  double? get height;
  ui.TextLeadingDistribution? get leadingDistribution;
  ui.TextBaseline? get textBaseline;

  double? get wordSpacing;
  double? get letterSpacing;

  // How do we compare ui.Paint objects?
  Either<ui.Color, ui.Paint>? get foreground;
  Either<ui.Color, ui.Paint>? get background;
  List<ui.Shadow>? get shadows;

  bool? get underline;
  bool? get overline;
  bool? get lineThrough;

  ui.Color? get decorationColor;
  ui.TextDecorationStyle? get decorationStyle;
  double? get decorationThickness;
}

final class _TextStyleAttributeSet implements TextStyleAttributeSet {
  const _TextStyleAttributeSet({
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
