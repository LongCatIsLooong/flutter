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
