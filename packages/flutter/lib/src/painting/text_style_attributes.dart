// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math show max;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'attributed_text.dart';
import 'text_style.dart';

sealed class TextStyleAttribute<T extends Object> implements TextAttribute {
  TextStyleAttribute(this.value);

  final T value;

  static List<TextStyleAttribute<Object>> _fromTextStyle(TextStyle style) {
    final ui.Paint? background = switch ((style.background, style.backgroundColor)) {
      (final ui.Paint paint, _) => paint,
      (_, final ui.Color color) => ui.Paint()..color = color,
      _ => null,
    };

    final ui.TextDecoration? decoration = style.decoration;
    final List<TextStyleAttribute<Object>>? decorations = switch (decoration) {
      null => null,
      ui.TextDecoration.none => <TextStyleAttribute<Object>>[
        TextDecorationAttribute.noLineThrough,
        TextDecorationAttribute.noUnderline,
        TextDecorationAttribute.noOverline,
      ],
      _ => <TextStyleAttribute<Object>>[
        if (decoration.contains(ui.TextDecoration.underline)) TextDecorationAttribute.underline,
        if (decoration.contains(ui.TextDecoration.overline)) TextDecorationAttribute.overline,
        if (decoration.contains(ui.TextDecoration.lineThrough)) TextDecorationAttribute.lineThrough,
      ],
    };

    return <TextStyleAttribute<Object>>[
      if (style.color != null) _Color(style.color!),
      // Make sure the TextDecorations are additive.
      if (decorations != null) ...decorations,
      if (style.decorationColor != null) _TextDecorationColor(style.decorationColor!),
      if (style.decorationStyle != null) _TextDecorationStyle(style.decorationStyle!),
      if (style.decorationThickness != null) _TextDecorationThickness(style.decorationThickness!),
      if (style.fontWeight != null) _FontWeight(style.fontWeight!),
      if (style.fontStyle != null) _FontStyle(style.fontStyle!),
      if (style.textBaseline != null) _TextBaseline(style.textBaseline!),
      if (style.leadingDistribution != null) _LeadingDistribution(style.leadingDistribution!),
      if (style.fontFamily != null) _FontFamily(style.fontFamily!),
      if (style.fontFamilyFallback != null) _FontFamilyFallback(style.fontFamilyFallback!),
      if (style.fontSize != null) _FontSize(style.fontSize!),
      if (style.letterSpacing != null) _LetterSpacing(style.letterSpacing!),
      if (style.wordSpacing != null) _WordSpacing(style.wordSpacing!),
      if (style.height != null) _Height(style.height!),
      if (style.locale != null) _Locale(style.locale!),
      if (style.foreground != null) _Foreground(style.foreground!),
      if (background != null) _Background(background),
      if (style.shadows != null) _Shadows(style.shadows!),
      if (style.fontFeatures != null) _FontFeatures(style.fontFeatures!),
      if (style.fontVariations != null) _FontVariations(style.fontVariations!),
    ];
  }


  @pragma('vm:prefer-inline')
  T? _getStyleAttributeOfType<T extends TextAttribute>(int index, void Function(int? key) callback) {
    final _Node? node = _attributeStorage[T]?.getNodeLessThanOrEqualTo(index);
    if (node == null) {
      return null;
    }
    callback(node.key);
    return node.value as T?;
  }

  // not a good API?
  (int, TextStyle) getTextStyleAt(int index) {
    assert(0 <= index);
    assert(index < text.length);

    int startIndex = 0;
    void updateIndex(int? key) {
      if (key != null) {
        startIndex = math.max(key, startIndex);
      }
    }
    final bool? lineThrough = _getStyleAttributeOfType<_TextDecorationLineThrough>(startIndex, updateIndex)?.value;
    final bool? overline = _getStyleAttributeOfType<_TextDecorationOverline>(startIndex, updateIndex)?.value;
    final bool? underline = _getStyleAttributeOfType<_TextDecorationUnderline>(startIndex, updateIndex)?.value;
    final ui.TextDecoration decoration = ui.TextDecoration.combine(<ui.TextDecoration>[
    ]);

    final TextStyle textStyle = TextStyle(
      color: _getStyleAttributeOfType<_Color>(startIndex, updateIndex)?.value,
      decorationColor: _getStyleAttributeOfType<_TextDecorationColor>(startIndex, updateIndex)?.value,
      decorationStyle: _getStyleAttributeOfType<_TextDecorationStyle>(startIndex, updateIndex)?.value,
      decorationThickness: _getStyleAttributeOfType<_TextDecorationThickness>(startIndex, updateIndex)?.value,
      //decoration: ui.T,
      fontWeight: _getStyleAttributeOfType<_FontWeight>(startIndex, updateIndex)?.value,
      fontStyle: _getStyleAttributeOfType<_FontStyle>(startIndex, updateIndex)?.value,
      textBaseline: _getStyleAttributeOfType<_TextBaseline>(startIndex, updateIndex)?.value,
      leadingDistribution: _getStyleAttributeOfType<_LeadingDistribution>(startIndex, updateIndex)?.value,
      fontFamily: _getStyleAttributeOfType<_FontFamily>(startIndex, updateIndex)?.value,
      fontFamilyFallback: _getStyleAttributeOfType<_FontFamilyFallback>(startIndex, updateIndex)?.value,
      fontSize: _getStyleAttributeOfType<_FontSize>(startIndex, updateIndex)?.value,
      letterSpacing: _getStyleAttributeOfType<_LetterSpacing>(startIndex, updateIndex)?.value,
      wordSpacing: _getStyleAttributeOfType<_WordSpacing>(startIndex, updateIndex)?.value,
      height: _getStyleAttributeOfType<_Height>(startIndex, updateIndex)?.value,
      locale: _getStyleAttributeOfType<_Locale>(startIndex, updateIndex)?.value,
      foreground: _getStyleAttributeOfType<_Foreground>(startIndex, updateIndex)?.value,
      background: _getStyleAttributeOfType<_Background>(startIndex, updateIndex)?.value,
      shadows: _getStyleAttributeOfType<_Shadows>(startIndex, updateIndex)?.value,
      fontFeatures: _getStyleAttributeOfType<_FontFeatures>(startIndex, updateIndex)?.value,
      fontVariations: _getStyleAttributeOfType<_FontVariations>(startIndex, updateIndex)?.value,
    );
    return (startIndex, textStyle);
  }

  @protected
  @override
  late final Object key = runtimeType;
}

final class _FontWeight extends TextStyleAttribute<ui.FontWeight> {
  _FontWeight(super.value);
}

final class _FontStyle extends TextStyleAttribute<ui.FontStyle> {
  _FontStyle(super.value);
}

final class _TextBaseline extends TextStyleAttribute<ui.TextBaseline> {
  _TextBaseline(super.value);
}

final class _LeadingDistribution extends TextStyleAttribute<ui.TextLeadingDistribution> {
  _LeadingDistribution(super.value);
}

final class _FontFamily extends TextStyleAttribute<String> {
  _FontFamily(super.value);
}

final class _FontFamilyFallback extends TextStyleAttribute<List<String>> {
  _FontFamilyFallback(super.value);
}

final class _FontSize extends TextStyleAttribute<double> {
  _FontSize(super.value);
}

final class _LetterSpacing extends TextStyleAttribute<double> {
  _LetterSpacing(super.value);
}

final class _WordSpacing extends TextStyleAttribute<double> {
  _WordSpacing(super.value);
}

final class _Height extends TextStyleAttribute<double> {
  _Height(super.value);
}

final class _FontFeatures extends TextStyleAttribute<List<ui.FontFeature>> {
  _FontFeatures(super.value);
}

final class _FontVariations extends TextStyleAttribute<List<ui.FontVariation>> {
  _FontVariations(super.value);
}

final class _Color extends TextStyleAttribute<ui.Color> {
  _Color(super.value);
}

sealed class TextDecorationAttribute extends TextStyleAttribute<bool> {
  TextDecorationAttribute._(super.value);

  static final TextDecorationAttribute underline = _TextDecorationUnderline(true);
  static final TextDecorationAttribute noUnderline = _TextDecorationUnderline(false);
  static final TextDecorationAttribute overline = _TextDecorationOverline(true);
  static final TextDecorationAttribute noOverline = _TextDecorationOverline(false);
  static final TextDecorationAttribute lineThrough = _TextDecorationLineThrough(true);
  static final TextDecorationAttribute noLineThrough = _TextDecorationLineThrough(false);
}

final class _TextDecorationUnderline extends TextDecorationAttribute {
  _TextDecorationUnderline(super._enabled) : super._();
}
final class _TextDecorationOverline extends TextDecorationAttribute {
  _TextDecorationOverline(super._enabled) : super._();
}
final class _TextDecorationLineThrough extends TextDecorationAttribute {
  _TextDecorationLineThrough(super._enabled) : super._();
}

final class _TextDecorationColor extends TextStyleAttribute<ui.Color> {
  _TextDecorationColor(super.value);
}

final class _TextDecorationStyle extends TextStyleAttribute<ui.TextDecorationStyle> {
  _TextDecorationStyle(super.value);
}

final class _TextDecorationThickness extends TextStyleAttribute<double> {
  _TextDecorationThickness(super.value);
}

final class _Foreground extends TextStyleAttribute<ui.Paint> {
  _Foreground(super.value);
}

final class _Background extends TextStyleAttribute<ui.Paint> {
  _Background(super.value);
}

final class _Shadows extends TextStyleAttribute<List<ui.Shadow>> {
  _Shadows(super.value);
}

sealed class SemanticsAttribute implements TextAttribute {
  factory SemanticsAttribute.locale(ui.Locale locale) = _Locale;

  static const SemanticsAttribute spellOut = _SpellOut();
}

final class _SpellOut implements SemanticsAttribute {
  const _SpellOut();

  @override
  Object get key => runtimeType;
}

final class _Locale implements SemanticsAttribute, TextStyleAttribute<ui.Locale> {
  const _Locale(this.value);

  @override
  final ui.Locale value;

  @override
  Object get key => runtimeType;
}

//final class PlaceholderStyleAttribute extends _TextStyleAttribute {
//}

class HitTestableText implements SemanticsAttribute, HitTestTarget {
  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
  }

  @override
  Object get key => runtimeType;
}
