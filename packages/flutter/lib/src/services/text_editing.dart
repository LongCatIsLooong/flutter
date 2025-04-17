// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show TextAffinity, TextPosition, TextRange, TextSelection;

import 'package:flutter/foundation.dart';

export 'dart:ui' show TextAffinity, TextPosition, TextSelection;

/// A range of text that represents a selection.
extension X on TextSelection {
  /// Returns the smallest [TextSelection] that this could expand to in order to
  /// include the given [TextPosition].
  ///
  /// If the given [TextPosition] is already inside of the selection, then
  /// returns `this` without change.
  ///
  /// The returned selection will always be a strict superset of the current
  /// selection. In other words, the selection grows to include the given
  /// [TextPosition].
  ///
  /// If extentAtIndex is true, then the [TextSelection.extentOffset] will be
  /// placed at the given index regardless of the original order of it and
  /// [TextSelection.baseOffset]. Otherwise, their order will be preserved.
  ///
  /// ## Difference with [extendTo]
  /// In contrast with this method, [extendTo] is a pivot; it holds
  /// [TextSelection.baseOffset] fixed while moving [TextSelection.extentOffset]
  /// to the given [TextPosition]. It doesn't strictly grow the selection and
  /// may collapse it or flip its order.
  TextSelection expandTo(TextPosition position, [bool extentAtIndex = false]) {
    // If position is already within in the selection, there's nothing to do.
    if (position.offset >= start && position.offset <= end) {
      return this;
    }

    final bool normalized = baseOffset <= extentOffset;
    if (position.offset <= start) {
      // Here the position is somewhere before the selection: ..|..[...]....
      if (extentAtIndex) {
        return copyWith(
          baseOffset: end,
          extentOffset: position.offset,
          affinity: position.affinity,
        );
      }
      return copyWith(
        baseOffset: normalized ? position.offset : baseOffset,
        extentOffset: normalized ? extentOffset : position.offset,
      );
    }
    // Here the position is somewhere after the selection: ....[...]..|..
    if (extentAtIndex) {
      return copyWith(
        baseOffset: start,
        extentOffset: position.offset,
        affinity: position.affinity,
      );
    }
    return copyWith(
      baseOffset: normalized ? baseOffset : position.offset,
      extentOffset: normalized ? position.offset : extentOffset,
    );
  }

  /// Keeping the selection's [TextSelection.baseOffset] fixed, pivot the
  /// [TextSelection.extentOffset] to the given [TextPosition].
  ///
  /// In some cases, the [TextSelection.baseOffset] and
  /// [TextSelection.extentOffset] may flip during this operation, and/or the
  /// size of the selection may shrink.
  ///
  /// ## Difference with [expandTo]
  /// In contrast with this method, [expandTo] is strictly growth; the
  /// selection is grown to include the given [TextPosition] and will never
  /// shrink.
  TextSelection extendTo(TextPosition position) {
    // If the selection's extent is at the position already, then nothing
    // happens.
    if (extent == position) {
      return this;
    }

    return copyWith(extentOffset: position.offset, affinity: position.affinity);
  }
}
