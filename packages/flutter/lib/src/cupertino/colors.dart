// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show Color, Brightness;

import 'package:flutter/src/cupertino/trait_environment.dart' as prefix0;
import 'package:flutter/widgets.dart';

import 'trait_environment.dart';

/// A palette of [Color] constants that describe colors commonly used when
/// matching the iOS platform aesthetics.
class CupertinoColors {
  CupertinoColors._();

  /// iOS 10's default blue color. Used to indicate active elements such as
  /// buttons, selected tabs and your own chat bubbles.
  ///
  /// This is SystemBlue in the iOS palette.
  static const Color activeBlue = Color(0xFF007AFF);

  /// iOS 10's default green color. Used to indicate active accents such as
  /// the switch in its on state and some accent buttons such as the call button
  /// and Apple Map's 'Go' button.
  ///
  /// This is SystemGreen in the iOS palette.
  static const Color activeGreen = Color(0xFF4CD964);

  /// iOS 12's default dark mode color. Used in place of the [activeBlue] color
  /// as the default active elements' color when the theme's brightness is dark.
  ///
  /// This is SystemOrange in the iOS palette.
  static const Color activeOrange = Color(0xFFFF9500);

  /// Opaque white color. Used for backgrounds and fonts against dark backgrounds.
  ///
  /// This is SystemWhiteColor in the iOS palette.
  ///
  /// See also:
  ///
  ///  * [material.Colors.white], the same color, in the material design palette.
  ///  * [black], opaque black in the [CupertinoColors] palette.
  static const Color white = Color(0xFFFFFFFF);

  /// Opaque black color. Used for texts against light backgrounds.
  ///
  /// This is SystemBlackColor in the iOS palette.
  ///
  /// See also:
  ///
  ///  * [material.Colors.black], the same color, in the material design palette.
  ///  * [white], opaque white in the [CupertinoColors] palette.
  static const Color black = Color(0xFF000000);

  /// Used in iOS 10 for light background fills such as the chat bubble background.
  ///
  /// This is SystemLightGrayColor in the iOS palette.
  static const Color lightBackgroundGray = Color(0xFFE5E5EA);

  /// Used in iOS 12 for very light background fills in tables between cell groups.
  ///
  /// This is SystemExtraLightGrayColor in the iOS palette.
  static const Color extraLightBackgroundGray = Color(0xFFEFEFF4);

  /// Used in iOS 12 for very dark background fills in tables between cell groups
  /// in dark mode.
  // Value derived from screenshot from the dark themed Apple Watch app.
  static const Color darkBackgroundGray = Color(0xFF171717);

  /// Used in iOS 11 for unselected selectables such as tab bar items in their
  /// inactive state or de-emphasized subtitles and details text.
  ///
  /// Not the same gray as disabled buttons etc.
  ///
  /// This is SystemGrayColor in the iOS palette.
  static const Color inactiveGray = Color(0xFF8E8E93);

  /// Used for iOS 10 for destructive actions such as the delete actions in
  /// table view cells and dialogs.
  ///
  /// Not the same red as the camera shutter or springboard icon notifications
  /// or the foreground red theme in various native apps such as HealthKit.
  ///
  /// This is SystemRed in the iOS palette.
  static const Color destructiveRed = Color(0xFFFF3B30);
}

/*
class CupertinoDynamicColor extends ColorSwatch<CupertinoInterfaceTraitData> {
  CupertinoDynamicColor({
    @required Color defaultColor,
    Map<CupertinoInterfaceTraitData, Color> swatch,
  }) : assert(swatch.isNotEmpty),
       assert(defaultColor != null),
       super(defaultColor.value, swatch);

  @override
  Color operator [](CupertinoInterfaceTraitData index) => super[index] ?? this;
}
*/

class CupertinoDynamicColor {
  CupertinoDynamicColor.withResolver({
    @required Color Function(CupertinoInterfaceTraitData) resolver,
  }) : _resolver = resolver,
       assert(resolver != null);

  CupertinoDynamicColor({
    Color defaultColor,
    Color normalColor,
    Color darkColor,
    Color highContrastColor,
    Color darkHighContrastColor,
    Color elevatedColor,
    Color darkElevatedColor,
    Color elevatedHighContrastColor,
    Color darkElevatedHighContrastColor,
  }) : assert(defaultColor != null || normalColor != null
                                   && darkColor != null
                                   && elevatedColor != null
                                   && highContrastColor != null
                                   && darkElevatedColor != null
                                   && darkHighContrastColor != null
                                   && darkElevatedHighContrastColor != null
                                   && elevatedHighContrastColor != null),
      this._withOptionSet(
        defaultColor,
        <Color> [
          normalColor,
          darkColor,
          highContrastColor,
          darkHighContrastColor,
          elevatedColor,
          darkElevatedColor,
          elevatedHighContrastColor,
          darkElevatedHighContrastColor,
        ]
      );

  CupertinoDynamicColor._withOptionSet(
    Color defaultColor,
    List<Color> colorMap,
  ) : this.withResolver(
    resolver: (CupertinoInterfaceTraitData traitData) {
      int featureIndex = 0;

      switch (traitData.userInterfaceLevel) {
        case CupertinoInterfaceLevel.base:
          break;
        case CupertinoInterfaceLevel.elevated:
          featureIndex++;
          break;
      }
      featureIndex <<= 1;

      switch (traitData.accessibilityContrast) {
        case CupertinoAccessibilityContrast.normal:
          break;
        case CupertinoAccessibilityContrast.high:
          featureIndex++;
          break;
      }
      featureIndex <<= 1;

      switch (traitData.userInterfaceStyle) {
        case Brightness.light:
          break;
        case Brightness.dark:
          featureIndex++;
          break;
      }

      return colorMap[featureIndex] ?? defaultColor;
    },
  );

  Color Function(CupertinoInterfaceTraitData) _resolver;

  Color resolve({@required CupertinoInterfaceTraitData traitData}) {
    final Color resolvedColor = _resolver(traitData);
    assert(resolvedColor != null);
    return resolvedColor;
  }

  Color resolveFromContext(BuildContext context) => resolve(traitData: CupertinoTraitEnvironment.of(context));
}
