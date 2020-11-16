// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';


const double _kCaretHeightOffset = 2.0; // pixels
const int _iOSHorizontalCursorOffsetPixels = -2;

const EdgeInsets _kFloatingCaretSizeIncrease = EdgeInsets.symmetric(horizontal: 0.5, vertical: 1.0);

abstract class BaseCaretPainter extends RenderEditablePainter {
  BaseCaretPainter({
    Color? color,
    double? cursorHeight,
    Radius? cursorRadius,
  }) : _color = color,
       _cursorHeight = cursorHeight,
       _cursorRadius = cursorRadius;

  @protected
  final Paint cursorPaint = Paint();

  bool get isForeground => false;

  Color? get color => _color;
  Color? _color;
  set color(Color? newValue) {
    if (_color == newValue)
      return;
    _color = newValue;
    notifyListeners();
  }

  /// Don't override this.
  double get cursorWidth {
    assert(renderEditable != null);
    return renderEditable!.cursorWidth;
  }

  //double get cursorWidth => _cursorWidth;
  //double _cursorWidth;
  //set cursorWidth(double newValue) {
  //  if (_cursorWidth == newValue)
  //    return;
  //  _cursorWidth = newValue;
  //  notifyListeners();
  //}

  double? get cursorHeight => _cursorHeight;
  double? _cursorHeight;
  set cursorHeight(double? newValue) {
    if (_cursorHeight == newValue)
      return;
    _cursorHeight = newValue;
    notifyListeners();
  }

  Radius? get cursorRadius => _cursorRadius;
  Radius? _cursorRadius;
  set cursorRadius(Radius? newValue) {
    if (_cursorRadius == newValue)
      return;
    _cursorRadius = newValue;
    notifyListeners();
  }

  TextPosition? get textPosition => _textPosition;
  TextPosition? _textPosition;
  set textPosition(TextPosition? newValue) {
    if (_textPosition == newValue)
      return;
    _textPosition = newValue;
    notifyListeners();
  }

  @override
  Rect get caretPrototype {
    assert(renderEditable != null);
    return Offset.zero & Size(cursorWidth, cursorHeight ?? renderEditable!.preferredLineHeight);
  }

  Rect caretRectFor(TextPosition textPosition) {
    assert(renderEditable != null);
    return caretPrototype.shift(renderEditable!.getOffsetForCaret(textPosition, caretPrototype));
  }

  @protected
  void paintCaret(Canvas canvas, Size size, Rect caretRect) {
    final Radius? cursorRadius = this.cursorRadius;
    final Rect integralRect = renderEditable!.integralOffset(caretRect.topLeft) & caretRect.size;
    if (cursorRadius == null) {
      canvas.drawRect(integralRect, cursorPaint);
    } else {
      final RRect caretRRect = RRect.fromRectAndRadius(integralRect, cursorRadius);
      canvas.drawRRect(caretRRect, cursorPaint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Color? caretColor = color;
    final TextPosition? textPosition = this.textPosition;
    assert(renderEditable != null);
    if (caretColor == null || textPosition == null)
      return;

    // If the floating cursor is enabled, the text cursor's color is [backgroundCursorColor] while
    // the floating cursor's color is _cursorColor;
    cursorPaint.color = caretColor;
    paintCaret(canvas, size, caretRectFor(textPosition));
  }
}

class IOSCaretPainter extends BaseCaretPainter {
  IOSCaretPainter({
    Color? color,
    required Color floatingCursorPlaceholderColor,
    double? cursorHeight,
    Radius? cursorRadius,
    EdgeInsets floatingCursorAddedMargin = const EdgeInsets.fromLTRB(4, 4, 4, 5),
  }) : _floatingCursorAddedMargin = floatingCursorAddedMargin,
       _floatingCursorPlaceholderColor = floatingCursorPlaceholderColor,
      super(color: color, cursorHeight: cursorHeight, cursorRadius: cursorRadius);

  Rect newFloatingCursorRect(Offset delta, Rect previousFloatingCursorRect) {
    assert(renderEditable != null);
    assert(renderEditable!.hasSize);
    final Rect safeArea = floatingCursorAddedMargin.deflateRect(Offset.zero & renderEditable!.size);
    final Offset newFloatingCursorOrigin = previousFloatingCursorRect.topLeft + delta;
    final double maxOriginX = safeArea.right - previousFloatingCursorRect.width;
    final double maxOriginY = safeArea.bottom - previousFloatingCursorRect.height;

    return Offset(
      maxOriginX <= safeArea.left
        // Don't move horizontally if we don't have enough horizontal space.
        ? previousFloatingCursorRect.left
        : newFloatingCursorOrigin.dx.clamp(safeArea.left, maxOriginX),
      maxOriginY <= safeArea.top
        // Don't move vertically if we don't have enough vertical space.
        ? previousFloatingCursorRect.top
        : newFloatingCursorOrigin.dy.clamp(safeArea.top, maxOriginY),
    ) & previousFloatingCursorRect.size;
  }

  /// The padding applied to text field. Used to determine the bounds when
  /// moving the floating cursor.
  ///
  /// Defaults to a padding with left, top and right set to 4, bottom to 5.
  EdgeInsets get floatingCursorAddedMargin => _floatingCursorAddedMargin;
  EdgeInsets _floatingCursorAddedMargin;
  set floatingCursorAddedMargin(EdgeInsets newValue) {
    if (_floatingCursorAddedMargin == newValue)
      return;
    _floatingCursorAddedMargin = newValue;
    notifyListeners();
  }

  Rect? get floatingCursorRect => _floatingCursorRect;
  Rect? _floatingCursorRect;
  set floatingCursorRect(Rect? newValue) {
    if (_floatingCursorRect != newValue)
      return;
    _floatingCursorRect = newValue;
    notifyListeners();
  }

  double? get floatingCursorRestAnimationProgress => _floatingCursorAnimationProgress;
  double? _floatingCursorAnimationProgress;
  set floatingCursorRestAnimationProgress(double? newValue) {
    if (_floatingCursorAnimationProgress == newValue)
      return;
    _floatingCursorAnimationProgress = newValue;
    notifyListeners();
  }

  /// The color to use when painting the cursor aligned to the text while
  /// rendering the floating cursor.
  ///
  /// The default is light grey.
  Color get floatingCursorPlaceholderColor => _floatingCursorPlaceholderColor;
  Color _floatingCursorPlaceholderColor;
  set floatingCursorPlaceholderColor(Color newValue) {
    if (floatingCursorPlaceholderColor == newValue)
      return;
    _floatingCursorPlaceholderColor = newValue;
    notifyListeners();
  }

  @override
  Rect get caretPrototype => const EdgeInsets.only(right: 2).inflateRect(super.caretPrototype);

  @override
  void paintCaret(Canvas canvas, Size size, Rect caretRect) {
    final double? caretHeight = renderEditable!.getFullHeightForCaret(textPosition!, caretPrototype);
    final Offset cursorOffset = Offset(_iOSHorizontalCursorOffsetPixels / renderEditable!.devicePixelRatio, 0);
    final Rect adjustedCaret = caretHeight == null
      ? caretRect.shift(cursorOffset)
      : caretRect.shift(cursorOffset + Offset(0, (caretHeight - caretRect.height) / 2));

    final double? animationValue = floatingCursorRestAnimationProgress;
    final Rect? floatingCursorRect = this.floatingCursorRect;

    if (floatingCursorRect != null) {
      if (animationValue == null) {
        cursorPaint.color = floatingCursorPlaceholderColor;
        super.paintCaret(canvas, size, adjustedCaret);
      }

      final Rect effectiveFloatingCursorRect = Rect.lerp(
        floatingCursorRect,
        adjustedCaret,
        animationValue ?? 0,
      ) ?? floatingCursorRect;
      cursorPaint.color = color!.withOpacity(0.75);
      super.paintCaret(canvas, size, effectiveFloatingCursorRect);
    } else {
      //super.paintCaret(canvas, size, Offset.zero & Size(10, 10));
      super.paintCaret(canvas, size, adjustedCaret);
    }
  }

  @override
  bool shouldRepaint(RenderEditablePainter oldDelegate) {
    if (identical(this, oldDelegate))
      return false;

    return oldDelegate is! IOSCaretPainter;
  }
}

class CaretPainter extends BaseCaretPainter {
  @override
  void paintCaret(Canvas canvas, Size size, Rect caretRect) {
    final double? caretHeight = renderEditable!.getFullHeightForCaret(textPosition!, caretPrototype);
    final Rect adjustedCaret = caretHeight == null
      ? caretRect
      : Rect.fromLTWH(
            caretRect.left,
            caretRect.top - _kCaretHeightOffset,
            caretRect.width,
            caretHeight,
          );

    super.paintCaret(canvas, size, adjustedCaret);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  bool shouldRepaint(RenderEditablePainter oldDelegate) {
    if (identical(this, oldDelegate))
      return false;

    return oldDelegate is! CaretPainter;
  }
  //CaretPainter({ required Size cursorSize })
  //  : super(
  //    caretProtoType: Offset(0, _kCaretHeightOffset) & Size(cursorSize.width, cursorSize.height - 2.0 * _kCaretHeightOffset),
  //  );
}
