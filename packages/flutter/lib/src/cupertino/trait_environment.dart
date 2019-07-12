// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/framework.dart';
import 'theme.dart';

/// An interface that allows for serialization of the adoptor.
/// The adoptor of the interface may assume that the caller of [maskValue] knows
/// how the mask value is generated (how to intepret each bit?).
abstract class BitSet {
  int get maskValue;
}

/// Indicates the visual level for a piece of content.
enum CupertinoInterfaceLevel {
  /// The level for your window's main content.
  base,

  /// The level for content visually above [base].
  elevated,
}

/// Indicates the accessibility contrast setting.
enum CupertinoAccessibilityContrast {
  /// Normal contrast level should be used.
  normal,

  /// High contrast level should be used.
  high,
}

/// Cupertino-specific information about the current widget subtree.
///
/// For example, the [CupertinoInterfaceTraitData.accessibilityContrast] property
/// governs if the descendant widgets should display their foreground and background
/// content in high contrast.
///
/// To obtain the current [CupertinoInterfaceTraitData] for a given [BuildContext],
/// use the [CupertinoTraitEnvironment.of] function. For example, to obtain the
/// interface level of the current subtree, use `CupertinoTraitEnvironment.of(context).userInterfaceLevel`.
///
/// If no [CupertinoTraitEnvironment] is in scope then the [CupertinoTraitEnvironment.of]
/// method will throw an exception, unless the `nullOk` argument is set to true,
/// in which case it returns null.
///
/// See also:
///
/// * [MediaQueryData], which serves a similar purpose but provides more generic
///   information while [CupertinoInterfaceTraitData] provides only Cupertino-specific
///   information, and will only be consumed by Cupertino components.
@immutable
class CupertinoInterfaceTraitData implements BitSet {
  /// Creates data for a [CupertinoTraitEnvironment] with explicit values.
  const CupertinoInterfaceTraitData({
    @required this.userInterfaceLevel,
    @required this.accessibilityContrast,
    this.userInterfaceStyle,
  }) : assert(userInterfaceLevel != null),
       assert(accessibilityContrast != null);

  /// The elevation level of the interface.
  ///
  /// Must not be null.
  final CupertinoInterfaceLevel userInterfaceLevel;

  /// Whether the content should be in light mode or dark mode.
  ///
  /// Can be null, in which case it will defer to the closest [MediaQuery] ancestor's
  /// [MediaQueryData.platformBrightness].
  final Brightness userInterfaceStyle;

  /// TBD:
  /// Whether the user requested a high contrast between foreground and background
  /// content, in either:
  /// * Settings -> Accessibility -> Increase Contrast (iOS)
  /// * Settings -> Accessibility -> High contrast text (Android)
  final CupertinoAccessibilityContrast accessibilityContrast;

  @override
  int get maskValue {
    int mask = 0;

    switch (userInterfaceLevel) {
      case CupertinoInterfaceLevel.base:
      break;
      case CupertinoInterfaceLevel.elevated:
      mask++;
      break;
    }
    mask <<= 1;

    switch (accessibilityContrast) {
      case CupertinoAccessibilityContrast.normal:
      break;
      case CupertinoAccessibilityContrast.high:
      mask++;
      break;
    }
    mask <<= 1;

    switch (userInterfaceStyle) {
      case Brightness.light:
      break;
      case Brightness.dark:
      mask++;
      break;
    }

    return mask;
  }

  /// Creates a copy of this interface trait data but with the given fields replaced
  /// with the new values.
  CupertinoInterfaceTraitData copyWith({
    Brightness userInterfaceStyle,
    CupertinoInterfaceLevel userInterfaceLevel,
    CupertinoAccessibilityContrast accessibilityContrast,
  }) {
    return CupertinoInterfaceTraitData(
      userInterfaceStyle: this.userInterfaceStyle ?? userInterfaceStyle,
      userInterfaceLevel: this.userInterfaceLevel ?? userInterfaceLevel,
      accessibilityContrast: this.accessibilityContrast ?? accessibilityContrast,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    final CupertinoInterfaceTraitData typedOther = other;
    return typedOther.userInterfaceLevel == userInterfaceLevel
        && typedOther.accessibilityContrast == accessibilityContrast
        && typedOther.userInterfaceStyle == userInterfaceStyle;
  }

  @override
  int get hashCode => hashValues(userInterfaceLevel, accessibilityContrast, userInterfaceLevel);

  @override
  String toString() {
    return '$runtimeType('
             'userInterfaceLevel: $userInterfaceLevel, '
             'accessibilityContrast: $accessibilityContrast, '
           ')';
  }
}

/// Establishes a subtree in which [CupertinoTraitEnvironment.of] resolve to the given data.
///
/// For example, to learn the size of the current media (e.g., the window
/// containing your app), you can read the [MediaQueryData.size] property from
/// the [MediaQueryData] returned by [MediaQuery.of]:
/// `MediaQuery.of(context).size`.
///
/// Querying the current media using [MediaQuery.of] will cause your widget to
/// rebuild automatically whenever the [MediaQueryData] changes (e.g., if the
/// user rotates their device).
///
/// If no [MediaQuery] is in scope then the [MediaQuery.of] method will throw an
/// exception, unless the `nullOk` argument is set to true, in which case it
/// returns null.
///
/// See also:
///
///  * [WidgetsApp] and [MaterialApp], which introduce a [MediaQuery] and keep
///    it up to date with the current screen metrics as they change.
///  * [MediaQueryData], the data structure that represents the metrics.
class CupertinoTraitEnvironment extends InheritedWidget {
  /// Creates a widget that provides [CupertinoInterfaceTraitData] to its descendants.
  ///
  /// The [data] and [child] arguments must not be null.
  CupertinoTraitEnvironment({
    Key key,
    CupertinoInterfaceLevel userInterfaceLevel,
    CupertinoAccessibilityContrast accessibilityContrast,
    @required Widget child,
  }) : assert(child != null),
       _data = CupertinoInterfaceTraitData(
         userInterfaceLevel: userInterfaceLevel,
         accessibilityContrast: accessibilityContrast,
       ),
       super(key: key, child: child);

  final CupertinoInterfaceTraitData _data;

  /// The data from the closest instance of this class that encloses the given
  /// context.
  ///
  /// You can use this function to query the size an orientation of the screen.
  /// When that information changes, your widget will be scheduled to be rebuilt,
  /// keeping your widget up-to-date.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// CupertinoInterfaceTraitData data = CupertinoTraitEnvironment.of(context);
  /// ```
  ///
  /// If there is no [CupertinoTraitEnvironment] in scope, then this will throw
  /// an exception. To return null if there is no [CupertinoTraitEnvironment],
  /// then pass `nullOk: true`.
  ///
  /// If you use this from a widget (e.g. in its build function), consider
  /// calling [debugCheckHasTraitData].
  static CupertinoInterfaceTraitData of(BuildContext context, { bool nullOk = false }) {
    assert(context != null);
    assert(nullOk != null);
    final CupertinoThemeData themeData = CupertinoTheme.of(context).noDefault();
    final Brightness brightness = themeData.brightness
      ?? MediaQuery.of(context, nullOk: nullOk).platformBrightness;
    final CupertinoTraitEnvironment environment = context.inheritFromWidgetOfExactType(CupertinoTraitEnvironment);

    if (environment != null && brightness != null)
      return environment._data.copyWith(userInterfaceStyle: brightness);
    if (nullOk)
      return null;
    throw FlutterError(
      'CupertinoTraitEnvironment.of() called with a context that does not contain a CupertinoTraitEnvironment or a MediaQuery.\n'
      'No CupertinoTraitEnvironment ancestor could be found starting from the context that was passed '
      'to CupertinoTraitEnvironment.of(). This can happen because you do not have a WidgetsApp or '
      'CupertinoApp widget (those widgets introduce a CupertinoTraitEnvironment and a MediaQuery), or it can happen '
      'if the context you use comes from a widget above those widgets.\n'
      'The context used was:\n'
      '  $context'
    );
  }

  @override
  bool updateShouldNotify(CupertinoTraitEnvironment oldWidget) {
    return _data.accessibilityContrast != oldWidget._data.accessibilityContrast
        || _data.userInterfaceLevel != _data.userInterfaceLevel;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CupertinoInterfaceTraitData>('data', _data, showName: false));
  }
}

/// Asserts that the given context has a [CupertinoTraitEnvironment] ancestor.
///
/// Used by various widgets to make sure that they are only used in an
/// appropriate context.
///
/// To invoke this function, use the following pattern, typically in the
/// relevant Widget's build method:
///
/// ```dart
/// assert(debugCheckHasTraitData(context));
/// ```
///
/// Does nothing if asserts are disabled. Always returns true.
bool debugCheckHasTraitData(BuildContext context) {
  debugCheckHasMediaQuery(context);
  assert(() {
    if (context.widget is! CupertinoTraitEnvironment && context.ancestorWidgetOfExactType(CupertinoTraitEnvironment) == null) {
      final Element element = context;
      throw FlutterError(
        'No CupertinoTraitEnvironment widget found.\n'
        '${context.widget.runtimeType} widgets require a CupertinoTraitEnvironment widget ancestor.\n'
        'The specific widget that could not find a CupertinoTraitEnvironment ancestor was:\n'
        '  ${context.widget}\n'
        'The ownership chain for the affected widget is:\n'
        '  ${element.debugGetCreatorChain(10)}\n'
        'Typically, the CupertinoTraitEnvironment widget is introduced by the CupertinoApp or '
        'WidgetsApp widget at the top of your application widget tree.'
      );
    }
    return true;
  }());
  return true;
}
