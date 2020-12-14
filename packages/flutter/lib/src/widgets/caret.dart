// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter/services.dart';
import 'package:flutter/src/rendering/editableNew.dart';
import 'framework.dart';
import 'ticker_provider.dart';

/// A floating cursor can be in one of these possible states:
/// 1. Dismissed: there's no floating cursor.
/// 2. Active: the floating cursor is showing and the user interaction that
///    drives the cursor is still active. Sub-states:
///    * The floating cursor starts.
///    * The floating cursor is floating near the text.
///    * The floating cursor is away from the text.
///
/// 3. Dismissing: the user interaction that drove the floating cursor has
///    ceased and the floating cursor is snapping to the text aligned cursor.
mixin FloatingCaretState on CaretState {
  // The time it takes for the floating cursor to snap to the text aligned
  // cursor position after the user has finished placing it.
  static const Duration _floatingCursorResetTime = Duration(milliseconds: 125);

  // The last known Rect of the iOS force touch floating cursor, in this
  // RenderEditable's coordinate system (not its viewport's).
  Rect? _lastFloatingCursorRect;

  // The last known Offset of the iOS force touch floating cursor, as reported
  // by the iOS text input plugin. The Offset is in a coordinate space with
  // unknown (but consistent) origin , so the offset is only useful when
  // calculating the diff between touch events.
  Offset? _previousForceTouchOffset;

  final BaseCaretPainter _floatingCursorPainter = BaseCaretPainter();

  // Controls the animation of reseting the floating cursor to the current text
  // selection, when floating caret stops (e.g. when force touch stops).
  late final AnimationController _floatingCursorResetController = AnimationController(vsync: this)
    ..addListener(_onFloatingCursorResetTick);

  // Called when the floating cursor painter may need visual updates.
  void _updatePainterFloatingCursor() {
    final RenderEditableNew? renderEditable = painter.renderEditable;
    final Rect? previousFloatingCursorRect = _lastFloatingCursorRect;
    if (renderEditable == null || !renderEditable.hasSize || previousFloatingCursorRect == null) {
      return;
    }

    final Rect updatedFloatingCursor = _clampFloatingCursorToSafeArea(
      floatingCursorRect: previousFloatingCursorRect,
      safeArea: floatingCursorAddedMargin.deflateRect(renderEditable.paintBounds),
    );
  }

  void _onFloatingCursorResetTick() {
    assert(mounted);
    assert(painter.renderEditable?.hasSize ?? false);

    if (_floatingCursorResetController.isCompleted) {
      _floatingCursorPainter.caretRect = null;
      _lastFloatingCursorRect = null;
    } else {
      _floatingCursorPainter.caretRect = Rect.lerp(
        _lastFloatingCursorRect,
        painter.renderEditable!.getLocalRectForCaret(),
        _floatingCursorResetController.value,
      );
    }
  }

  /// Called by the [TextInputClient] associated with the text field.
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    final RenderEditableNew? renderEditable = painter.renderEditable;

    // If we don't have a render object or the render object is new and has
    // never been laid out,
    if (renderEditable == null || !renderEditable.hasSize) {
      return;
    }

    if (_floatingCursorResetController.isAnimating) {
      _floatingCursorResetController.stop();
    }
    // The iOS text input plugin can easily get into a broken state when the
    // client changes. So make no assumption about what the current floating
    // cursor state the client is in.
    switch(point.state){
      case FloatingCursorDragState.Start:

        final TextSelection? selection= renderEditable.selection;
        if (selection == null)
          return;
        if (selection.start < 0)
          return;

        _previousForceTouchOffset = point.offset;
        // Force the snapping animation to finish.
        _floatingCursorResetController.reset();
        final TextPosition currentTextPosition = TextPosition(offset: selection.start);
        final Rect localCaretRect = painter.caretRectFor(currentTextPosition);
        _lastFloatingCursorRect = localCaretRect;

        _onFloatingCursorUpdate(currentTextPosition, localCaretRect, painter);
        _floatingCursorPainter.caretRect = localCaretRect;
        _floatingCursorResetController.reset();
        break;
      case FloatingCursorDragState.Update:
        final Offset? newTouchOffset = point.offset;
        assert(newTouchOffset != null);
        final Offset? previousOffset = _previousForceTouchOffset;
        final Rect? previousFloatingCursorRect = _lastFloatingCursorRect;
        if (previousOffset == null || previousFloatingCursorRect == null || newTouchOffset == null)
          return;

        final Offset delta = newTouchOffset - previousOffset;
        _previousForceTouchOffset = newTouchOffset;
        final Rect newFloatingCursorRect = _clampFloatingCursorToSafeArea(
          floatingCursorRect: previousFloatingCursorRect,
          delta: delta,
          safeArea: floatingCursorAddedMargin.deflateRect(renderEditable.paintBounds),
        );

        //_onFloatingCursorUpdate(
        //  renderEditable.getPositionForPoint(
        //    renderEditable.localToGlobal(newFloatingCursorRect.topLeft + _floatingCursorOffset),
        //  ),
        //  newFloatingCursorRect, caretPainter);

        _floatingCursorPainter.caretRect = newFloatingCursorRect;
        break;
      case FloatingCursorDragState.End:
        // We skip animation if no update has happened.
        if (_previousForceTouchOffset != null || _lastFloatingCursorRect != null) {
          _previousForceTouchOffset = null;
          _lastFloatingCursorRect = null;
          _floatingCursorResetController.value = 0.0;
          _floatingCursorResetController.animateTo(1.0, duration: _floatingCursorResetTime, curve: Curves.decelerate);
        }
        break;
    }
    _updatePainterFloatingCursor();
  }

  static Rect _clampFloatingCursorToSafeArea({
    required Rect floatingCursorRect,
    Offset delta = Offset.zero,
    required Rect safeArea,
  }) {
    final Rect safeOriginArea = EdgeInsets.only(right: floatingCursorRect.width, bottom: floatingCursorRect.height)
      .deflateRect(safeArea);
    final Offset newOrigin = floatingCursorRect.topLeft + delta;
    return Offset(
      safeArea.width <= 0 ? floatingCursorRect.left : newOrigin.dx.clamp(safeOriginArea.left, safeOriginArea.right),
      safeArea.height <= 0 ? floatingCursorRect.top : newOrigin.dy.clamp(safeOriginArea.top, safeOriginArea.bottom),
    ) & floatingCursorRect.size;
  }

  /// The padding applied to text field. Used to determine the bounds when
  /// moving the floating cursor.
  ///
  /// Defaults to a padding with left, top and right set to 4, bottom to 5.
  EdgeInsets get floatingCursorAddedMargin => _floatingCursorAddedMargin;
  EdgeInsets _floatingCursorAddedMargin = EdgeInsets.zero;
  set floatingCursorAddedMargin(EdgeInsets newValue) {
    if (_floatingCursorAddedMargin == newValue)
      return;
    _floatingCursorAddedMargin = newValue;
  }
}

//@immutable
//class CaretConfiguration {
//  final Offset paintOrigin;
//  final RenderEditablePainter painter;
//
//  @override
//  bool operator ==(Object other) {
//    if (identical(this, other))
//      return true;
//    if (other.runtimeType != runtimeType)
//      return false;
//    return other is CaretConfiguration
//        && paintOrigin == other.paintOrigin
//        && painter == other.painter;
//  }
//
//  @override
//  // TODO: implement hashCode
//  int get hashCode => super.hashCode;
//
//}


class BaseCaretPainter extends RenderEditablePainter {
  Rect? get caretRect => _caretRect;
  Rect? _caretRect;
  set caretRect(Rect? value) {
    if (_caretRect == value)
      return;
    _caretRect = value;
    notifyListeners();
  }


  Paint? cursorPaint;
  Color? get color => cursorPaint?.color;
  set color(Color? value) {
    if (color == value)
      return;

    if (value == null) {
      cursorPaint = null;
    } else {
      (cursorPaint ??= Paint())
        .color = value;
    }
    notifyListeners();
  }

  Radius? get cursorRadius => _cursorRadius;
  Radius? _cursorRadius;
  set cursorRadius(Radius? value) {
    if (_cursorRadius == value)
      return;
    _cursorRadius = value;
    notifyListeners();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Color? caretColor = color;
    final Rect? rect = caretRect;
    final Paint? paint = cursorPaint;
	  assert(renderEditable != null);
    if (caretColor == null || rect == null || paint == null)
      return;

    // If the floating cursor is enabled, the text cursor's color is [backgroundCursorColor] while
    // the floating cursor's color is _cursorColor;
    final Rect integralRect = renderEditable!.integralOffset(rect.topLeft) & rect.size;
    final Radius? radius = cursorRadius;
    if (radius == null) {
      canvas.drawRect(integralRect, paint);
    } else {
      final RRect caretRRect = RRect.fromRectAndRadius(integralRect, radius);
      canvas.drawRRect(caretRRect, paint);
    }
  }

  @override
  bool shouldRepaint(RenderEditablePainter oldPainter) {
    return !identical(this, oldPainter)
        && oldPainter is! BaseCaretPainter;
  }
}

class Caret extends StatefulWidget {
  const Caret(
    Key? key,
  ) : super(key: key);

  @override
  State<StatefulWidget> createState() => CaretState<Caret>();
}

class CaretState<T extends Caret> extends State<T> with TickerProviderStateMixin {
  final BaseCaretPainter painter = BaseCaretPainter();

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}
