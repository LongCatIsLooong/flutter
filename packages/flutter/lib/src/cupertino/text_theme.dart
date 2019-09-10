// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Brightness;
import 'package:flutter/widgets.dart';

import 'colors.dart';

// The CupertinoSystemColors.systemBlue fallback value.
const Color _kPrimaryColor = CupertinoDynamicColor.withBrightnessAndContrast(
  color: Color.fromARGB(255, 0, 122, 255),
  darkColor: Color.fromARGB(255, 10, 132, 255),
  highContrastColor: Color.fromARGB(255, 0, 64, 221),
  darkHighContrastColor: Color.fromARGB(255, 64, 156, 255),
);

// The CupertinoSystemColors.label fallback value.
const Color _kPrimaryContrastingColor = CupertinoDynamicColor(
  color: Color.fromARGB(255, 0, 0, 0),
  darkColor: Color.fromARGB(255, 255, 255, 255),
  highContrastColor: Color.fromARGB(255, 0, 0, 0),
  darkHighContrastColor: Color.fromARGB(255, 255, 255, 255),
  elevatedColor: Color.fromARGB(255, 0, 0, 0),
  darkElevatedColor: Color.fromARGB(255, 255, 255, 255),
  highContrastElevatedColor: Color.fromARGB(255, 0, 0, 0),
  darkHighContrastElevatedColor: Color.fromARGB(255, 255, 255, 255),
);

const Color _kBlackWhiteLabelColor = CupertinoDynamicColor.withBrightness(
  color: CupertinoColors.black,
  darkColor: CupertinoColors.white,
);

// Values derived from https://developer.apple.com/design/resources/.
const TextStyle _kDefaultTextStyle = TextStyle(
  inherit: false,
  fontFamily: '.SF Pro Text',
  fontSize: 17.0,
  letterSpacing: -0.41,
  color: _kPrimaryContrastingColor,
  decoration: TextDecoration.none,
);

// Values derived from https://developer.apple.com/design/resources/.
const TextStyle _kDefaultActionTextStyle = TextStyle(
  inherit: false,
  fontFamily: '.SF Pro Text',
  fontSize: 17.0,
  letterSpacing: -0.41,
  color: _kPrimaryColor,
  decoration: TextDecoration.none,
);

// Values derived from https://developer.apple.com/design/resources/.
const TextStyle _kDefaultTabLabelTextStyle = TextStyle(
  inherit: false,
  fontFamily: '.SF Pro Text',
  fontSize: 10.0,
  letterSpacing: -0.24,
  color: CupertinoColors.inactiveGray,
);

const TextStyle _kDefaultMiddleTitleTextStyle = TextStyle(
  inherit: false,
  fontFamily: '.SF Pro Text',
  fontSize: 17.0,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.41,
  color: _kBlackWhiteLabelColor,
);

const TextStyle _kDefaultLargeTitleTextStyle = TextStyle(
  inherit: false,
  fontFamily: '.SF Pro Display',
  fontSize: 34.0,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.41,
  color: _kBlackWhiteLabelColor,
);

// Inspected on iOS 13 simulator using "Debug View Hierarchy".
// Note that its font size is extracted from off-centered labels. Centered labels
// (the text that currently under the magnifier) have a font size of 23.5 pt.
const TextStyle _kDefaultPickerTextStyle = TextStyle(
  inherit: false,
  fontFamily: '.SF Pro Display',
  fontSize: 21.0,
  fontWeight: FontWeight.normal,
  letterSpacing: -0.41,
  color: _kBlackWhiteLabelColor,
);

// Inspected on iOS 13 simulator using "Debug View Hierarchy".
const TextStyle _kDefaultDateTimePickerTextStyle = _kDefaultPickerTextStyle;

/// Cupertino typography theme in a [CupertinoThemeData].
@immutable
class CupertinoTextThemeData extends Diagnosticable {
  /// Create a [CupertinoTextThemeData].
  ///
  /// The [primaryColor] and [isLight] parameters are used to derive TextStyle
  /// defaults of other attributes such as [textStyle] and [actionTextStyle]
  /// etc. The default value of [primaryColor] is [CupertinoColors.activeBlue]
  /// and the default value of [isLight] is true.
  ///
  /// Other [TextStyle] parameters default to default iOS text styles when
  /// unspecified.
  const CupertinoTextThemeData({
    Color primaryColor,
    Brightness brightness,
    TextStyle textStyle,
    TextStyle actionTextStyle,
    TextStyle tabLabelTextStyle,
    TextStyle navTitleTextStyle,
    TextStyle navLargeTitleTextStyle,
    TextStyle navActionTextStyle,
    TextStyle pickerTextStyle,
    TextStyle dateTimePickerTextStyle,
  }) : _primaryColor = primaryColor ?? _kPrimaryColor,
       _brightness = brightness,
       _textStyle = textStyle,
       _actionTextStyle = actionTextStyle,
       _tabLabelTextStyle = tabLabelTextStyle,
       _navTitleTextStyle = navTitleTextStyle,
       _navLargeTitleTextStyle = navLargeTitleTextStyle,
       _navActionTextStyle = navActionTextStyle,
       _pickerTextStyle = pickerTextStyle,
       _dateTimePickerTextStyle = dateTimePickerTextStyle;

  final Color _primaryColor;
  final Brightness _brightness;

  final TextStyle _textStyle;
  /// Typography of general text content for Cupertino widgets.
  TextStyle get textStyle => _textStyle ?? _kDefaultTextStyle;

  final TextStyle _actionTextStyle;
  /// Typography of interactive text content such as text in a button without background.
  TextStyle get actionTextStyle {
    return _actionTextStyle ?? _kDefaultActionTextStyle.copyWith(color: _primaryColor);
  }

  final TextStyle _tabLabelTextStyle;
  /// Typography of unselected tabs.
  TextStyle get tabLabelTextStyle => _tabLabelTextStyle ?? _kDefaultTabLabelTextStyle;

  final TextStyle _navTitleTextStyle;
  /// Typography of titles in standard navigation bars.
  TextStyle get navTitleTextStyle {
    return _navTitleTextStyle ?? _kDefaultMiddleTitleTextStyle;
  }

  final TextStyle _navLargeTitleTextStyle;
  /// Typography of large titles in sliver navigation bars.
  TextStyle get navLargeTitleTextStyle {
    return _navLargeTitleTextStyle ?? _kDefaultLargeTitleTextStyle;
  }

  final TextStyle _navActionTextStyle;
  /// Typography of interactive text content in navigation bars.
  TextStyle get navActionTextStyle {
    return _navActionTextStyle ?? _kDefaultActionTextStyle.copyWith(
      color: _primaryColor,
    );
  }

  final TextStyle _pickerTextStyle;
  /// Typography of pickers.
  TextStyle get pickerTextStyle {
    return _pickerTextStyle ?? _kDefaultPickerTextStyle;
  }

  final TextStyle _dateTimePickerTextStyle;
  /// Typography of date time pickers.
  TextStyle get dateTimePickerTextStyle {
    return _dateTimePickerTextStyle ?? _kDefaultDateTimePickerTextStyle;
  }

  /// Returns a copy of the current [CupertinoTextThemeData] with all the colors
  /// resolved against the given [BuildContext].
  CupertinoTextThemeData resolveFrom(BuildContext context, { bool nullOk = false }) {
    Color convertColor(Color color) => CupertinoDynamicColor.resolve(color, context, nullOk: nullOk);

    TextStyle resolveTextStyle(TextStyle textStyle) {
      return textStyle?.copyWith(
        color: convertColor(textStyle.color),
        backgroundColor: convertColor(textStyle.backgroundColor),
        decorationColor: convertColor(textStyle.decorationColor),
      );
    }

    return copyWith(
      primaryColor: convertColor(_primaryColor),
      textStyle: resolveTextStyle(_textStyle),
      actionTextStyle: resolveTextStyle(_actionTextStyle),
      tabLabelTextStyle: resolveTextStyle(_tabLabelTextStyle),
      navTitleTextStyle : resolveTextStyle(_navTitleTextStyle),
      navLargeTitleTextStyle: resolveTextStyle(_navLargeTitleTextStyle),
      navActionTextStyle: resolveTextStyle(_navActionTextStyle),
      pickerTextStyle: resolveTextStyle(_pickerTextStyle),
      dateTimePickerTextStyle: resolveTextStyle(_dateTimePickerTextStyle),
    );
  }

  /// Returns a copy of the current [CupertinoTextThemeData] instance with
  /// specified overrides.
  CupertinoTextThemeData copyWith({
    Color primaryColor,
    Brightness brightness,
    TextStyle textStyle,
    TextStyle actionTextStyle,
    TextStyle tabLabelTextStyle,
    TextStyle navTitleTextStyle,
    TextStyle navLargeTitleTextStyle,
    TextStyle navActionTextStyle,
    TextStyle pickerTextStyle,
    TextStyle dateTimePickerTextStyle,
  }) {
    return CupertinoTextThemeData(
      primaryColor: primaryColor ?? _primaryColor,
      brightness: brightness ?? _brightness,
      textStyle: textStyle ?? _textStyle,
      actionTextStyle: actionTextStyle ?? _actionTextStyle,
      tabLabelTextStyle: tabLabelTextStyle ?? _tabLabelTextStyle,
      navTitleTextStyle: navTitleTextStyle ?? _navTitleTextStyle,
      navLargeTitleTextStyle: navLargeTitleTextStyle ?? _navLargeTitleTextStyle,
      navActionTextStyle: navActionTextStyle ?? _navActionTextStyle,
      pickerTextStyle: pickerTextStyle ?? _pickerTextStyle,
      dateTimePickerTextStyle: dateTimePickerTextStyle ?? _dateTimePickerTextStyle,
    );
  }
}
