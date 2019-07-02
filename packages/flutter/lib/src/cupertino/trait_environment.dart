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

  /// Creates a new [MediaQuery] that inherits from the ambient [MediaQuery] from
  /// the given context, but removes the specified paddings.
  ///
  /// This should be inserted into the widget tree when the [MediaQuery] padding
  /// is consumed by a widget in such a way that the padding is no longer
  /// exposed to the widget's descendants or siblings.
  ///
  /// The [context] argument is required, must not be null, and must have a
  /// [MediaQuery] in scope.
  ///
  /// The `removeLeft`, `removeTop`, `removeRight`, and `removeBottom` arguments
  /// must not be null. If all four are false (the default) then the returned
  /// [MediaQuery] reuses the ambient [MediaQueryData] unmodified, which is not
  /// particularly useful.
  ///
  /// The [child] argument is required and must not be null.
  ///
  /// See also:
  ///
  ///  * [SafeArea], which both removes the padding from the [MediaQuery] and
  ///    adds a [Padding] widget.
  ///  * [MediaQueryData.padding], the affected property of the [MediaQueryData].
  ///  * [new removeViewInsets], the same thing but for removing view insets.
  ///  * [new removeViewPadding], the same thing but for removing view insets.
  factory MediaQuery.removePadding({
    Key key,
    @required BuildContext context,
    bool removeLeft = false,
    bool removeTop = false,
    bool removeRight = false,
    bool removeBottom = false,
    @required Widget child,
  }) {
    return MediaQuery(
      key: key,
      data: MediaQuery.of(context).removePadding(
        removeLeft: removeLeft,
        removeTop: removeTop,
        removeRight: removeRight,
        removeBottom: removeBottom,
      ),
      child: child,
    );
  }

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
  /// MediaQueryData media = MediaQuery.of(context);
  /// ```
  ///
  /// If there is no [MediaQuery] in scope, then this will throw an exception.
  /// To return null if there is no [MediaQuery], then pass `nullOk: true`.
  ///
  /// If you use this from a widget (e.g. in its build function), consider
  /// calling [debugCheckHasMediaQuery].
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
      'MaterialApp widget (those widgets introduce a CupertinoTraitEnvironment), or it can happen '
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
