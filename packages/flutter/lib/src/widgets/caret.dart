// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'dart:ui';

import 'package:flutter/services.dart' show RawFloatingCursorPoint;
import 'package:flutter/src/rendering/editableNew.dart';
import 'framework.dart';
import 'ticker_provider.dart';

mixin FloatingCaretPaint on TickerProviderStateMixin {
  RenderEditableNew? renderEditable;

  // The time it takes for the floating cursor to snap to the text aligned
  // cursor position after the user has finished placing it.
  static const Duration _floatingCursorResetTime = Duration(milliseconds: 125);

  late AnimationController _floatingCursorResetController;

  // The last known Rect of the iOS force touch floating cursor, in this
  Rect? _startCaretRect;	  // widget's local coordinate system.
  Rect? _previousFloatingCursorRect;

  // The last known Offset of the iOS force touch floating cursor, as reported
  // by the iOS text input plugin. The Offset has an unknown (but consistent)
  // Cartesian coordinate system, so it's only useful for calculating the diff
  // between touch events.
  Offset? _previousForceTouchOffset;

  void updateFloatingCursor(RawFloatingCursorPoint point) {
  }
}

@immutable
class CaretConfiguration {
  final Offset paintOrigin;
  final RenderEditablePainter painter;

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is CaretConfiguration
        && paintOrigin == other.paintOrigin
        && painter == other.painter;
  }

  @override
  // TODO: implement hashCode
  int get hashCode => super.hashCode;

}

// class Caret extends InheritedWidget {
//
//   final State<CaretInfor configuration;
//
//   @override
//   bool updateShouldNotify(CaretInformation oldWidget) => oldWidget.configuration != configuration;
// }

class Caret extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {}
}

class CaretState extends State<Caret> {

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }

}
