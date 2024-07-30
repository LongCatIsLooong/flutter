// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs (REMOVE)
// ignore_for_file: always_specify_types (REMOVE)
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'text_style_attributes.dart';

// ### NOTES
// 1. TextSpan interop
// 2. Font matching / Shaping / Layout / Paint subsystems
// 3. Hit-testing
// 4. Semantics

//typedef _TextStyleAttributeSetter<Attribute> = (void Function(_MutableTextStyleAttributeSet, Attribute), Attribute);


//class _EmptyIterator<E> implements Iterator<E> {
//  const _EmptyIterator();
//  @override
//  bool moveNext() => false;
//  @override
//  E get current => throw FlutterError('unreachable');
//}

class _TextHitTestAnnotations implements TextHitTestAnnotations {
  const _TextHitTestAnnotations(this._hitTestTargets);

  final RBTree<Iterable<HitTestTarget>>? _hitTestTargets;

  @override
  Iterable<HitTestTarget> getHitTestTargets(int codeUnitOffset) {
    final Iterator<(int, Iterable<HitTestTarget>)>? iterator = _hitTestTargets?.getRunsEndAfter(codeUnitOffset);
    return iterator != null && iterator.moveNext() ? iterator.current.$2 : const <HitTestTarget>[];
  }

  TextHitTestAnnotations overwrite(ui.TextRange range, List<HitTestTarget> newAttribute) {
    throw UnimplementedError();
  }
}

/// InlineSpan to AnnotatedString Conversion

// A class for extracting attribute (such as the font size) runs from an
// InlineSpan tree.
//
// Each attribute run is a pair of the starting index of the attribute in the
// string, and value of the attribute. For instance if the font size runs are
// [(0, 10), (5, 20)], it means the text starts with a font size of 10 and
// starting from the 5th code unit the font size changes to 20.
abstract class _AttributeRunBuilder<Source, Attribute> {
  final List<(int, Attribute)> runs = <(int, Attribute)>[];
  int runStartIndex = 0;

  bool tryPush(Source attribute);
  void pop();
  void commitText(int length);
  RBTree<Attribute>? build() => runs.isEmpty ? null : RBTree<Attribute>.fromSortedList(runs);
}

mixin _NonOverlappingAttributeRunMixin<Source, Attribute> on _AttributeRunBuilder<Source, Attribute> {
  final List<Attribute> attributeStack = <Attribute>[];

  @override
  void pop() {
    assert(attributeStack.isNotEmpty);
    attributeStack.removeLast();
  }

  @override
  void commitText(int length) {
    assert(length > 0);
    final Attribute? currentRunAttribute = runs.isEmpty ? null : runs.last.$2;
    // Start a new run only if the attributes are different.
    if (attributeStack.isNotEmpty && currentRunAttribute != attributeStack.last) {
      runs.add((runStartIndex, attributeStack.last));
    }
    runStartIndex += length;
  }
}

/// An immutable representation of
@immutable
class AnnotatedString {
  const AnnotatedString(this.string) : _attributeStorage = const PersistentHashMap<Type, Object?>.empty();
  const AnnotatedString._(this.string, this._attributeStorage);
  AnnotatedString.fromAnnotatedString(AnnotatedString string) :
    string = string.string,
    _attributeStorage = string._attributeStorage;

  final String string;

  // The PersistentHashMap class currently does not have a delete method.
  final PersistentHashMap<Type, Object?> _attributeStorage;

  // Read annotations of a specific type.
  T? getAnnotationOfType<T extends Object>() => _attributeStorage[T] as T?;

  /// Update annotations of a specific type `T` and return a new [AnnotatedString].
  ///
  /// The static type `T` is used as the key instead of the runtime type of
  /// newAnnotations, in case newAnnotations is null (and for consistency too).
  AnnotatedString setAnnotation<T extends Object>(T newAnnotations) {
    return AnnotatedString._(string, _attributeStorage.put(newAnnotations.runtimeType, newAnnotations));
  }
}

//AnnotatedString _inlineSpanToTextStyleAnnotations(InlineSpan span, String string) {
//  // Hit test
//  final hitTests = _HitTestTargetRunBuilder();
//
//  // Semantics
//  final semanticsLabels = _PlainAttributeRunBuilder<String>();
//  final spellOuts = _PlainAttributeRunBuilder<bool>();
//  final semanticGestureCallbacks = _PlainAttributeRunBuilder<Either<VoidCallback, VoidCallback>>();
//
//  bool visitSpan(InlineSpan span) {
//    List<_AttributeRunBuilder<Object?, Object?>>? buildersToPop;
//    void tryPush<Source>(_AttributeRunBuilder<Source, Object?> builder, Source newValue) {
//      if (builder.tryPush(newValue)) {
//        if (buildersToPop == null) {
//          buildersToPop = [builder];
//        } else {
//          buildersToPop!.add(builder);
//        }
//      }
//    }
//
//    switch (span) {
//      case TextSpan(:final String? text, :final semanticsLabel, :final spellOut, :final recognizer):
//        tryPush(semanticsLabels, semanticsLabel);
//        tryPush(spellOuts, spellOut);
//        tryPush(hitTests, span);
//        switch (recognizer) {
//          case TapGestureRecognizer(:final VoidCallback onTap) || DoubleTapGestureRecognizer(onDoubleTap: final VoidCallback onTap):
//            tryPush(semanticGestureCallbacks, Left(onTap));
//          case LongPressGestureRecognizer(:final VoidCallback onLongPress):
//            tryPush(semanticGestureCallbacks, Right(onLongPress));
//          case _:
//            break;
//        }
//
//        final textLength = text?.length ?? 0;
//        if (textLength > 0) {
//          semanticsLabels.commitText(textLength);
//          spellOuts.commitText(textLength);
//          semanticGestureCallbacks.commitText(textLength);
//        }
//
//      case PlaceholderSpan():
//        // Ignore styles?
//        semanticsLabels.commitText(1);
//        spellOuts.commitText(1);
//        semanticGestureCallbacks.commitText(1);
//        hitTests.commitText(1);
//      default:
//        assert(false, 'unknown span type: $span');
//    }
//
//    span.visitDirectChildren(visitSpan);
//    final toPop = buildersToPop;
//    if (toPop != null) {
//      for (int i = 0; i < toPop.length; i += 1) {
//        toPop[i].pop();
//      }
//    }
//    return true;
//  }
//
//  visitSpan(span);
//  final TextHitTestAnnotations textHitTestAnnotations = _TextHitTestAnnotations(hitTests.build());
//
//  final _SemanticsAnnotations semanticsAnnotations = _SemanticsAnnotations(
//    semanticsLabels.build(),
//    spellOuts.build(),
//    semanticGestureCallbacks.build(),
//    string.length,
//  );
//
//  return AnnotatedString._(string, const PersistentHashMap<Type, Object?>.empty())
//    .setAnnotation(textHitTestAnnotations)
//    .setAnnotation(semanticsAnnotations);
//}
//
//AnnotatedString _extractFromInlineSpan(InlineSpan span) {
//  final String string = span.toPlainText(includeSemanticsLabels: false);
//  return _inlineSpanToTextStyleAnnotations(span, string);
//}

//class _TextStyleAttributeRunBuilder<Attribute extends Object> extends _AttributeRunBuilder<TextStyle?, Attribute> with _NonOverlappingAttributeRunMixin<TextStyle?, Attribute> {
//  _TextStyleAttributeRunBuilder(this.getAttribute);
//  final Attribute? Function(TextStyle) getAttribute;
//  @override
//  bool tryPush(TextStyle? textStyle) {
//    final Attribute? newAttribute = textStyle.flatMap(getAttribute);
//    final bool pushToStack = newAttribute != null && (attributeStack.isEmpty || newAttribute != attributeStack.last);
//    if (pushToStack) {
//      attributeStack.add(newAttribute);
//    }
//    return pushToStack;
//  }
//}
//
//class _PlainAttributeRunBuilder<Attribute extends Object> extends _AttributeRunBuilder<Attribute?, Attribute> with _NonOverlappingAttributeRunMixin<Attribute?, Attribute> {
//  @override
//  bool tryPush(Attribute? attribute) {
//    final bool pushToStack = attribute != null && (attributeStack.isEmpty || attribute != attributeStack.last);
//    if (pushToStack) {
//      attributeStack.add(attribute);
//    }
//    return pushToStack;
//  }
//}
//
//class _HitTestTargetRunBuilder extends _AttributeRunBuilder<TextSpan, Iterable<TextSpan>> {
//  final List<TextSpan> attributeStack = <TextSpan>[];
//
//  @override
//  bool tryPush(TextSpan span) {
//    final TextSpan? topOfStack = attributeStack.isEmpty ? null : attributeStack.last;
//    final bool pushToStack = (span.recognizer != null && span.recognizer != topOfStack?.recognizer)
//                          || (span.onEnter != null && span.onEnter != topOfStack?.onEnter)
//                          || (span.onExit != null && span.onExit != topOfStack?.onExit)
//                          || (!identical(span.mouseCursor, MouseCursor.defer) && !identical(span.mouseCursor, topOfStack?.mouseCursor));
//    if (pushToStack) {
//      attributeStack.add(span);
//    }
//    return pushToStack;
//  }
//
//  @override
//  void pop() {
//    assert(attributeStack.isNotEmpty);
//    attributeStack.removeLast();
//  }
//  @override
//  void commitText(int length) {
//    assert(length > 0);
//    final TextSpan? currentSpan = runs.isEmpty ? null : runs.last.$2.last;
//    // Start a new run only if the attributes are different.
//    if (attributeStack.isNotEmpty && currentSpan != attributeStack.last) {
//      runs.add((runStartIndex, attributeStack));
//    }
//    runStartIndex += length;
//  }
//}
//
//_TextStyleAnnotations _convertTextStyleAttributes(InlineSpan span, int stringLength) {
//  final fontFamilies = _TextStyleAttributeRunBuilder<List<String>>(_getFontFamilies);
//  final locale = _TextStyleAttributeRunBuilder<ui.Locale>(_getLocale);
//  final fontWeight = _TextStyleAttributeRunBuilder<ui.FontWeight>(_getFontWeight);
//  final fontStyle = _TextStyleAttributeRunBuilder<ui.FontStyle>(_getFontStyle);
//  final fontFeatures = _TextStyleAttributeRunBuilder<List<ui.FontFeature>>(_getFontFeatures);
//  final fontVariations = _TextStyleAttributeRunBuilder<List<ui.FontVariation>>(_getFontVariations);
//  final textBaseline = _TextStyleAttributeRunBuilder<ui.TextBaseline>(_getTextBaseline);
//  final leadingDistribution = _TextStyleAttributeRunBuilder<ui.TextLeadingDistribution>(_getLeadingDistribution);
//  final fontSize = _TextStyleAttributeRunBuilder<double>(_getFontSize);
//  final height = _TextStyleAttributeRunBuilder<double>(_getHeight);
//  final letterSpacing = _TextStyleAttributeRunBuilder<double>(_getLetterSpacing);
//  final wordSpacing = _TextStyleAttributeRunBuilder<double>(_getWordSpacing);
//
//  final foreground = _TextStyleAttributeRunBuilder<Either<ui.Color, ui.Paint>>(_getForeground);
//  final background = _TextStyleAttributeRunBuilder<Either<ui.Color, ui.Paint>>(_getBackground);
//  final underline = _TextStyleAttributeRunBuilder<bool>(_getUnderline);
//  final overline = _TextStyleAttributeRunBuilder<bool>(_getOverline);
//  final lineThrough = _TextStyleAttributeRunBuilder<bool>(_getLineThrough);
//  final decorationColor = _TextStyleAttributeRunBuilder<ui.Color>(_getDecorationColor);
//  final decorationStyle = _TextStyleAttributeRunBuilder<ui.TextDecorationStyle>(_getDecorationStyle);
//  final decorationThickness = _TextStyleAttributeRunBuilder<double>(_getDecorationThickness);
//  final shadows = _TextStyleAttributeRunBuilder<List<ui.Shadow>>(_getShadows);
//
//  final List<_TextStyleAttributeRunBuilder<Object>> attributes = <_TextStyleAttributeRunBuilder<Object>>[
//    fontFamilies,
//    locale,
//    fontWeight,
//    fontStyle,
//    fontFeatures,
//    fontVariations,
//    textBaseline,
//    leadingDistribution,
//    fontSize,
//    height,
//    letterSpacing,
//    wordSpacing,
//
//    foreground,
//    background,
//    underline,
//    overline,
//    lineThrough,
//    decorationColor,
//    decorationStyle,
//    decorationThickness,
//    shadows,
//  ];
//
//  bool visitSpan(InlineSpan span) {
//    List<_AttributeRunBuilder<Object?, Object?>>? buildersToPop;
//    final TextStyle? style = span.style;
//    if (style != null) {
//      for (final _TextStyleAttributeRunBuilder<Object> attribute in attributes) {
//        if (attribute.tryPush(style)) {
//          (buildersToPop ??= <_AttributeRunBuilder<Object?, Object?>>[]).add(attribute);
//        }
//      }
//    }
//    final int textLength = switch (span) {
//      TextSpan(:final String? text) => text?.length ?? 0,
//      PlaceholderSpan() => 1,
//      _ => 0,
//    };
//    if (textLength > 0) {
//      for (final _TextStyleAttributeRunBuilder<Object> attribute in attributes) {
//        attribute.commitText(textLength);
//      }
//    }
//    span.visitDirectChildren(visitSpan);
//    if (buildersToPop != null) {
//      for (int i = 0; i < buildersToPop.length; i += 1) {
//        buildersToPop[i].pop();
//      }
//    }
//    return true;
//  }
//
//  // Only extract styles.
//  span.visitChildren(visitSpan);
//  return _TextStyleAnnotations.allRequired(
//    fontFamilies: fontFamilies.build(),
//    locale: locale.build(),
//    fontWeight: fontWeight.build(),
//    fontStyle: fontStyle.build(),
//    fontFeatures: fontFeatures.build(),
//    fontVariations: fontVariations.build(),
//    textBaseline: textBaseline.build(),
//    leadingDistribution: leadingDistribution.build(),
//    fontSize: fontSize.build(),
//    height: height.build(),
//    letterSpacing: letterSpacing.build(),
//    wordSpacing: wordSpacing.build(),
//    foreground: foreground.build(),
//    background: background.build(),
//    underline: underline.build(),
//    overline: overline.build(),
//    lineThrough: lineThrough.build(),
//    decorationColor: decorationColor.build(),
//    decorationStyle: decorationStyle.build(),
//    decorationThickness: decorationThickness.build(),
//    shadows: shadows.build(),
//
//    baseStyle: span.style ?? const TextStyle(),
//  );
//}
