// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../widgets/framework.dart';

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

/// Cupertino-specific information about the correct UI subtree.
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
class CupertinoInterfaceTraitData {
  /// Creates data for a [CupertinoTraitEnvironment] with explicit values.
  const CupertinoInterfaceTraitData({
    this.userInterfaceLevel,
    this.accessibilityContrast,
  });

  /// The elevation level of the interface.
  final CupertinoInterfaceLevel userInterfaceLevel;

  /// TBD:
  /// Whether the user requested a high contrast between foreground and background
  /// content, in either:
  /// * Settings -> Accessibility -> Increase Contrast (iOS)
  /// * Settings -> Accessibility -> High contrast text (Android)
  final CupertinoAccessibilityContrast accessibilityContrast;

  /// Creates a copy of this interface trait data but with the given fields replaced
  /// with the new values.
  CupertinoInterfaceTraitData copyWith({
    CupertinoInterfaceLevel userInterfaceLevel,
    CupertinoAccessibilityContrast accessibilityContrast,
  }) {
    return CupertinoInterfaceTraitData(
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
        && typedOther.accessibilityContrast == accessibilityContrast;
  }

  @override
  int get hashCode => hashValues(userInterfaceLevel, accessibilityContrast);

  @override
  String toString() {
    return '$runtimeType('
             'userInterfaceLevel: $userInterfaceLevel, '
             'accessibilityContrast: $accessibilityContrast, '
           ')';
  }
}

/// Establishes a subtree in which media queries resolve to the given data.
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
/// {@youtube 560 315 https://www.youtube.com/watch?v=A3WrA4zAaPw}
///
/// See also:
///
///  * [WidgetsApp] and [MaterialApp], which introduce a [MediaQuery] and keep
///    it up to date with the current screen metrics as they change.
///  * [MediaQueryData], the data structure that represents the metrics.
class CupertinoTraitEnvironment extends InheritedWidget {
  /// Creates a widget that provides [MediaQueryData] to its descendants.
  ///
  /// The [data] and [child] arguments must not be null.
  const CupertinoTraitEnvironment({
    Key key,
    @required this.data,
    @required Widget child,
  }) : assert(child != null),
       assert(data != null),
       super(key: key, child: child);

  /// Contains information about the current media.
  ///
  /// For example, the [MediaQueryData.size] property contains the width and
  /// height of the current window.
  final CupertinoInterfaceTraitData data;

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
    final CupertinoTraitEnvironment environment = context.inheritFromWidgetOfExactType(CupertinoTraitEnvironment);
    if (environment != null)
      return environment.data;
    if (nullOk)
      return null;
    throw FlutterError(
      'CupertinoTraitEnvironment.of() called with a context that does not contain a CupertinoTraitEnvironment.\n'
      'No CupertinoTraitEnvironment ancestor could be found starting from the context that was passed '
      'to CupertinoTraitEnvironment.of(). This can happen because you do not have a WidgetsApp or '
      'CupertinoApp widget (those widgets introduce a CupertinoTraitEnvironment), or it can happen '
      'if the context you use comes from a widget above those widgets.\n'
      'The context used was:\n'
      '  $context'
    );
  }

  @override
  bool updateShouldNotify(CupertinoTraitEnvironment oldWidget) => data != oldWidget.data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CupertinoInterfaceTraitData>('data', data, showName: false));
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
