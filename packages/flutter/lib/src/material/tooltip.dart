// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'feedback.dart';
import 'theme.dart';
import 'tooltip_theme.dart';
import 'tooltip_visibility.dart';

/// A Material Design tooltip.
///
/// Tooltips provide text labels which help explain the function of a button or
/// other user interface action. Wrap the button in a [Tooltip] widget and provide
/// a message which will be shown when the widget is long pressed.
///
/// Many widgets, such as [IconButton], [FloatingActionButton], and
/// [PopupMenuButton] have a `tooltip` property that, when non-null, causes the
/// widget to include a [Tooltip] in its build.
///
/// Tooltips improve the accessibility of visual widgets by proving a textual
/// representation of the widget, which, for example, can be vocalized by a
/// screen reader.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=EeEfD5fI-5Q}
///
/// {@tool dartpad}
/// This example show a basic [Tooltip] which has a [Text] as child.
/// [message] contains your label to be shown by the tooltip when
/// the child that Tooltip wraps is hovered over on web or desktop. On mobile,
/// the tooltip is shown when the widget is long pressed.
///
/// ** See code in examples/api/lib/material/tooltip/tooltip.0.dart **
/// {@end-tool}
///
/// {@tool dartpad}
/// This example covers most of the attributes available in Tooltip.
/// `decoration` has been used to give a gradient and borderRadius to Tooltip.
/// `height` has been used to set a specific height of the Tooltip.
/// `preferBelow` is false, the tooltip will prefer showing above [Tooltip]'s child widget.
/// However, it may show the tooltip below if there's not enough space
/// above the widget.
/// `textStyle` has been used to set the font size of the 'message'.
/// `showDuration` accepts a Duration to continue showing the message after the long
/// press has been released or the mouse pointer exits the child widget.
/// `waitDuration` accepts a Duration for which a mouse pointer has to hover over the child
/// widget before the tooltip is shown.
///
/// ** See code in examples/api/lib/material/tooltip/tooltip.1.dart **
/// {@end-tool}
///
/// {@tool dartpad}
/// This example shows a rich [Tooltip] that specifies the [richMessage]
/// parameter instead of the [message] parameter (only one of these may be
/// non-null. Any [InlineSpan] can be specified for the [richMessage] attribute,
/// including [WidgetSpan].
///
/// ** See code in examples/api/lib/material/tooltip/tooltip.2.dart **
/// {@end-tool}
///
/// {@tool dartpad}
/// This example shows how [Tooltip] can be shown manually with [TooltipTriggerMode.manual]
/// by calling the [TooltipState.ensureTooltipVisible] function.
///
/// ** See code in examples/api/lib/material/tooltip/tooltip.3.dart **
/// {@end-tool}
///
/// See also:
///
///  * <https://material.io/design/components/tooltips.html>
///  * [TooltipTheme] or [ThemeData.tooltipTheme]
///  * [TooltipVisibility]
class Tooltip extends StatefulWidget {
  /// Creates a tooltip.
  ///
  /// By default, tooltips should adhere to the
  /// [Material specification](https://material.io/design/components/tooltips.html#spec).
  /// If the optional constructor parameters are not defined, the values
  /// provided by [TooltipTheme.of] will be used if a [TooltipTheme] is present
  /// or specified in [ThemeData].
  ///
  /// All parameters that are defined in the constructor will
  /// override the default values _and_ the values in [TooltipTheme.of].
  ///
  /// Only one of [message] and [richMessage] may be non-null.
  const Tooltip({
    super.key,
    this.message,
    this.richMessage,
    this.height,
    this.padding,
    this.margin,
    this.verticalOffset,
    this.preferBelow,
    this.excludeFromSemantics,
    this.decoration,
    this.textStyle,
    this.textAlign,
    this.waitDuration,
    this.showDuration,
    this.triggerMode,
    this.enableFeedback,
    this.child,
  }) :  assert((message == null) != (richMessage == null), 'Either `message` or `richMessage` must be specified'),
        assert(
          richMessage == null || textStyle == null,
          'If `richMessage` is specified, `textStyle` will have no effect. '
          'If you wish to provide a `textStyle` for a rich tooltip, add the '
          '`textStyle` directly to the `richMessage` InlineSpan.',
        );

  /// The text to display in the tooltip.
  ///
  /// Only one of [message] and [richMessage] may be non-null.
  final String? message;

  /// The rich text to display in the tooltip.
  ///
  /// Only one of [message] and [richMessage] may be non-null.
  final InlineSpan? richMessage;

  /// The height of the tooltip's [child].
  ///
  /// If the [child] is null, then this is the tooltip's intrinsic height.
  final double? height;

  /// The amount of space by which to inset the tooltip's [child].
  ///
  /// On mobile, defaults to 16.0 logical pixels horizontally and 4.0 vertically.
  /// On desktop, defaults to 8.0 logical pixels horizontally and 4.0 vertically.
  final EdgeInsetsGeometry? padding;

  /// The empty space that surrounds the tooltip.
  ///
  /// Defines the tooltip's outer [Container.margin]. By default, a
  /// long tooltip will span the width of its window. If long enough,
  /// a tooltip might also span the window's height. This property allows
  /// one to define how much space the tooltip must be inset from the edges
  /// of their display window.
  ///
  /// If this property is null, then [TooltipThemeData.margin] is used.
  /// If [TooltipThemeData.margin] is also null, the default margin is
  /// 0.0 logical pixels on all sides.
  final EdgeInsetsGeometry? margin;

  /// The vertical gap between the widget and the displayed tooltip.
  ///
  /// When [preferBelow] is set to true and tooltips have sufficient space to
  /// display themselves, this property defines how much vertical space
  /// tooltips will position themselves under their corresponding widgets.
  /// Otherwise, tooltips will position themselves above their corresponding
  /// widgets with the given offset.
  final double? verticalOffset;

  /// Whether the tooltip defaults to being displayed below the widget.
  ///
  /// Defaults to true. If there is insufficient space to display the tooltip in
  /// the preferred direction, the tooltip will be displayed in the opposite
  /// direction.
  final bool? preferBelow;

  /// Whether the tooltip's [message] or [richMessage] should be excluded from
  /// the semantics tree.
  ///
  /// Defaults to false. A tooltip will add a [Semantics] label that is set to
  /// [Tooltip.message] if non-null, or the plain text value of
  /// [Tooltip.richMessage] otherwise. Set this property to true if the app is
  /// going to provide its own custom semantics label.
  final bool? excludeFromSemantics;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  /// Specifies the tooltip's shape and background color.
  ///
  /// The tooltip shape defaults to a rounded rectangle with a border radius of
  /// 4.0. Tooltips will also default to an opacity of 90% and with the color
  /// [Colors.grey]\[700\] if [ThemeData.brightness] is [Brightness.dark], and
  /// [Colors.white] if it is [Brightness.light].
  final Decoration? decoration;

  /// The style to use for the message of the tooltip.
  ///
  /// If null, the message's [TextStyle] will be determined based on
  /// [ThemeData]. If [ThemeData.brightness] is set to [Brightness.dark],
  /// [TextTheme.bodyText2] of [ThemeData.textTheme] will be used with
  /// [Colors.white]. Otherwise, if [ThemeData.brightness] is set to
  /// [Brightness.light], [TextTheme.bodyText2] of [ThemeData.textTheme] will be
  /// used with [Colors.black].
  final TextStyle? textStyle;

  /// How the message of the tooltip is aligned horizontally.
  ///
  /// If this property is null, then [TooltipThemeData.textAlign] is used.
  /// If [TooltipThemeData.textAlign] is also null, the default value is
  /// [TextAlign.start].
  final TextAlign? textAlign;

  /// The length of time that a pointer must hover over a tooltip's widget
  /// before the tooltip will be shown.
  ///
  /// Defaults to 0 milliseconds (tooltips are shown immediately upon hover).
  final Duration? waitDuration;

  /// The length of time that the tooltip will be shown after a long press
  /// is released or mouse pointer exits the widget.
  ///
  /// Defaults to 1.5 seconds for long press released or 0.1 seconds for mouse
  /// pointer exits the widget.
  final Duration? showDuration;

  /// The [TooltipTriggerMode] that will show the tooltip.
  ///
  /// If this property is null, then [TooltipThemeData.triggerMode] is used.
  /// If [TooltipThemeData.triggerMode] is also null, the default mode is
  /// [TooltipTriggerMode.longPress].
  final TooltipTriggerMode? triggerMode;

  /// Whether the tooltip should provide acoustic and/or haptic feedback.
  ///
  /// For example, on Android a tap will produce a clicking sound and a
  /// long-press will produce a short vibration, when feedback is enabled.
  ///
  /// When null, the default value is true.
  ///
  /// See also:
  ///
  ///  * [Feedback], for providing platform-specific feedback to certain actions.
  final bool? enableFeedback;

  static final List<TooltipState> _openedTooltips = <TooltipState>[];

  /// Dismiss all of the tooltips that are currently shown on the screen.
  ///
  /// This method returns true if it successfully dismisses the tooltips. It
  /// returns false if there is no tooltip shown on the screen.
  static bool dismissAllToolTips() {
    if (_openedTooltips.isNotEmpty) {
      // Avoid concurrent modification.
      final List<TooltipState> openedTooltips = _openedTooltips.toList();
      for (final TooltipState state in openedTooltips) {
        state._scheduleDismissTooltip(withDelay: Duration.zero);
      }
      return true;
    }
    return false;
  }

  @override
  State<Tooltip> createState() => TooltipState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty(
      'message',
      message,
      showName: message == null,
      defaultValue: message == null ? null : kNoDefaultValue,
    ));
    properties.add(StringProperty(
      'richMessage',
      richMessage?.toPlainText(),
      showName: richMessage == null,
      defaultValue: richMessage == null ? null : kNoDefaultValue,
    ));
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('margin', margin, defaultValue: null));
    properties.add(DoubleProperty('vertical offset', verticalOffset, defaultValue: null));
    properties.add(FlagProperty('position', value: preferBelow, ifTrue: 'below', ifFalse: 'above', showName: true));
    properties.add(FlagProperty('semantics', value: excludeFromSemantics, ifTrue: 'excluded', showName: true));
    properties.add(DiagnosticsProperty<Duration>('wait duration', waitDuration, defaultValue: null));
    properties.add(DiagnosticsProperty<Duration>('show duration', showDuration, defaultValue: null));
    properties.add(DiagnosticsProperty<TooltipTriggerMode>('triggerMode', triggerMode, defaultValue: null));
    properties.add(FlagProperty('enableFeedback', value: enableFeedback, ifTrue: 'true', showName: true));
    properties.add(DiagnosticsProperty<TextAlign>('textAlign', textAlign, defaultValue: null));
  }
}

/// Contains the state for a [Tooltip].
///
/// This class can be used to programmatically show the Tooltip, see the
/// [ensureTooltipVisible] method.
class TooltipState extends State<Tooltip> with SingleTickerProviderStateMixin {
  static const double _defaultVerticalOffset = 24.0;
  static const bool _defaultPreferBelow = true;
  static const EdgeInsetsGeometry _defaultMargin = EdgeInsets.zero;
  static const Duration _fadeInDuration = Duration(milliseconds: 150);
  static const Duration _fadeOutDuration = Duration(milliseconds: 75);
  static const Duration _defaultShowDuration = Duration(milliseconds: 1500);
  static const Duration _defaultHoverShowDuration = Duration(milliseconds: 100);
  static const Duration _defaultWaitDuration = Duration.zero;
  static const bool _defaultExcludeFromSemantics = false;
  static const TooltipTriggerMode _defaultTriggerMode = TooltipTriggerMode.longPress;
  static const bool _defaultEnableFeedback = true;
  static const TextAlign _defaultTextAlign = TextAlign.start;

  Timer? _timer;
  late final AnimationController _controller = AnimationController(
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
      vsync: this,
    )..addStatusListener(_handleStatusChanged);

  LongPressGestureRecognizer? _longPressRecognizer;
  TapGestureRecognizer? _tapRecognizer;

  late bool _mouseIsConnected;

  // Whether the tooltip's fadeout animation should start, if it's not already
  // started.
  AnimationStatus _animationStatus = AnimationStatus.dismissed;

  // The ids of mouse devices that are keeping the tooltip from being dismissed.
  // The last id in the collection will not be removed until the tooltip is
  // completely dismissed, even if it's no longer hovering over this tooltip.
  final Set<int> _keepAlivePointerDevices = <int>{};
  final Set<int> _activePointers = <int>{};

  late bool _visible;
  late TooltipThemeData _tooltipTheme;
  late TooltipTriggerMode _triggerMode;

  /// The plain text message for this tooltip.
  ///
  /// This value will either come from [widget.message] or [widget.richMessage].
  String get _tooltipMessage => widget.message ?? widget.richMessage!.toPlainText();

  @override
  void initState() {
    super.initState();
    _mouseIsConnected = RendererBinding.instance.mouseTracker.mouseIsConnected;
    // Listen to see when a mouse is added.
    RendererBinding.instance.mouseTracker.addListener(_handleMouseTrackerChange);
    // Listen to global pointer events so that we can hide a tooltip immediately
    // if some other control is clicked on.
    // Pointer events are dispatched to global routes after other routes.
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointerEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TooltipVisibility.of(context);
    _tooltipTheme = TooltipTheme.of(context);
    _triggerMode = widget.triggerMode ?? _tooltipTheme.triggerMode ?? _defaultTriggerMode;
  }

  @override
  void didUpdateWidget(Tooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _triggerMode = widget.triggerMode ?? _tooltipTheme.triggerMode ?? _defaultTriggerMode;
  }

  // https://material.io/components/tooltips#specs
  double _getDefaultTooltipHeight() {
    final ThemeData theme = Theme.of(context);
    switch (theme.platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return 24.0;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return 32.0;
    }
  }

  EdgeInsets _getDefaultPadding() {
    final ThemeData theme = Theme.of(context);
    switch (theme.platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0);
    }
  }

  double _getDefaultFontSize() {
    final ThemeData theme = Theme.of(context);
    switch (theme.platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return 12.0;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return 14.0;
    }
  }

  // Forces a rebuild if a mouse has been added or removed.
  void _handleMouseTrackerChange() {
    if (!mounted) {
      return;
    }
    final bool mouseIsConnected = RendererBinding.instance.mouseTracker.mouseIsConnected;
    if (mouseIsConnected != _mouseIsConnected) {
      setState(() {
        _mouseIsConnected = mouseIsConnected;
      });
    }
  }

  void _handleStatusChanged(AnimationStatus status) {
    assert(mounted);
    final bool needsRebuild;
    switch (status) {
      case AnimationStatus.dismissed:
        needsRebuild = _animationStatus != AnimationStatus.dismissed;
        if (needsRebuild) {
          Tooltip._openedTooltips.remove(this);
        }
        break;
      case AnimationStatus.completed:
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        needsRebuild = _animationStatus == AnimationStatus.dismissed;
        if (needsRebuild) {
          SemanticsService.tooltip(_tooltipMessage);
          Tooltip._openedTooltips.add(this);
        }
        break;
    }

    if (needsRebuild) {
      setState(() { /* The build method reads from _status. */ });
    }
    _animationStatus = status;
  }

  void _scheduleShowTooltip({ required Duration withDelay, Duration? showDuration }) {
    void dismissTimerCallback() {
      if (!_visible)
        return;
      _controller.forward();
      _timer?.cancel();
      _timer = showDuration != null
        ? Timer(showDuration, _controller.reverse)
        : null;
    }

    assert(
      !(_timer?.isActive ?? false) || _controller.status != AnimationStatus.reverse,
      'timer must not be active when the tooltip is fading out',
    );
    print('>>>>> ${widget.message} scheduled for showing');
    switch (_controller.status) {
      case AnimationStatus.dismissed:
         if (withDelay.inMicroseconds <= 0) {
           dismissTimerCallback();
         } else {
          _timer ??= Timer(withDelay, dismissTimerCallback);
         }
        break;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
      case AnimationStatus.completed:
        // Fade in if needed and schedule to hide.
        dismissTimerCallback();
        break;
    }
  }

  void _scheduleDismissTooltip({ required Duration withDelay }) {
    assert(
      !(_timer?.isActive ?? false) || _controller.status != AnimationStatus.reverse,
      'timer must not be active when the tooltip is fading out',
    );

    print('<<<<< ${widget.message} scheduled for dismissal');
    switch (_controller.status) {
      case AnimationStatus.reverse:
      case AnimationStatus.dismissed:
      case AnimationStatus.forward:
        _controller.reverse();
        // Cancel timers if already fading out/dismissed.
        _timer?.cancel();
        _timer = null;
        break;
      case AnimationStatus.completed:
        // Already fully visible. Reset the fade out timer.
        _timer?.cancel();
        if (withDelay != null && withDelay != Duration.zero) {
          _timer = Timer(withDelay, _controller.reverse);
        } else {
          _timer = null;
          _controller.reverse();
        }
        break;
    }
  }

  /// Shows the tooltip if it is not already visible.
  ///
  /// Returns `false` when the tooltip shouldn't be shown or when the tooltip
  /// was already visible.
  bool ensureTooltipVisible() {
    if (!_visible)
      return false;

    final bool madeVisible;
    switch (_controller.status) {
      case AnimationStatus.dismissed:
        madeVisible = true;
        break;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
      case AnimationStatus.completed:
        return madeVisible = false;
    }

    _scheduleShowTooltip(withDelay: Duration.zero);
    return madeVisible;
  }

  void _handleMouseEnter(PointerEnterEvent event) {
    if (!mounted) {
      return;
    }
    _keepAlivePointerDevices.add(event.device);
    final List<TooltipState> openedTooltips = Tooltip._openedTooltips.toList();
    bool otherTooltipsDismissed = false;
    for (final TooltipState tooltip in openedTooltips) {
      final Set<int> mouseDevices = tooltip._keepAlivePointerDevices;
      final bool shouldDismiss = tooltip != this
                              && (mouseDevices.length == 1 && mouseDevices.single == event.device);
      if (shouldDismiss) {
        otherTooltipsDismissed = true;
        tooltip._scheduleDismissTooltip(withDelay: Duration.zero);
      }
    }

    _scheduleShowTooltip(
      withDelay: otherTooltipsDismissed ? Duration.zero : (widget.waitDuration ?? _tooltipTheme.waitDuration ?? _defaultWaitDuration)
    );
  }

  void _handleMouseExit(PointerExitEvent event) {
    if (!mounted) {
      return;
    }

    if (_keepAlivePointerDevices.length > 1) {
      _keepAlivePointerDevices.remove(event.device);
      return;
    }

    _scheduleDismissTooltip(
      withDelay: widget.showDuration ?? _tooltipTheme.showDuration ?? _defaultHoverShowDuration,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!mounted) {
      return;
    }

    switch (_triggerMode) {
      case TooltipTriggerMode.longPress:
        _tapRecognizer?.onTap = null;
        final LongPressGestureRecognizer recognizer = _longPressRecognizer ??= LongPressGestureRecognizer(debugOwner: this);
        recognizer
          ..onLongPressCancel = (() => _handlePressCancel(recognizer))
          ..onLongPress = _handlePress;
        recognizer.addPointer(event);
        break;
      case TooltipTriggerMode.tap:
        _longPressRecognizer?.onLongPress = null;
        final TapGestureRecognizer recognizer = _tapRecognizer ??= TapGestureRecognizer(debugOwner: this);
        recognizer
          ..onTapCancel = (() => _handlePressCancel(recognizer))
          ..onTap = _handlePress;
        recognizer.addPointer(event);
        break;
      case TooltipTriggerMode.manual:
        _tapRecognizer?.onTap = null;
        _longPressRecognizer?.onLongPress = null;
        break;
    }

    final bool trackingPointer = event.pointer == _tapRecognizer?.primaryPointer
                              || event.pointer == _longPressRecognizer?.primaryPointer;
    if (trackingPointer) {
      _activePointers.add(event.pointer);
    }
  }

  void _handlePress() {
    final bool tooltipCreated = _visible && _controller.status == AnimationStatus.dismissed;
    _scheduleShowTooltip(
      withDelay: Duration.zero,
      showDuration: widget.showDuration ?? _tooltipTheme.showDuration ?? _defaultShowDuration,
    );
    final bool enableFeedback = widget.enableFeedback ?? _tooltipTheme.enableFeedback ?? _defaultEnableFeedback;
    if (tooltipCreated && enableFeedback) {
      final TooltipTriggerMode triggerMode = widget.triggerMode ?? _tooltipTheme.triggerMode ?? _defaultTriggerMode;
      if (triggerMode == TooltipTriggerMode.longPress)
        Feedback.forLongPress(context);
      else
        Feedback.forTap(context);
    }
  }

  // If a PointerEvent a local gesture recognizer was tracking is cancelled,
  // remove it from _activePointers so it will be handled by the global pointer
  // event listener to dismiss the tooltip.
  void _handlePressCancel(PrimaryPointerGestureRecognizer recognizer) {
    final int? cancelledPointer  = recognizer.primaryPointer;
    if (cancelledPointer == null) {
      assert(false);
    }
    _activePointers.remove(cancelledPointer);
  }

  void _handleGlobalPointerEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_activePointers.remove(event.pointer)) {
        // Skip if the pointer event is also received by our Listener.
        return;
      }
      _scheduleDismissTooltip(withDelay: Duration.zero);
    } else if (event is PointerDownEvent && !_activePointers.contains(event.pointer)) {
      _scheduleDismissTooltip(withDelay: Duration.zero);
    }
  }

  @override
  void deactivate() {
    Tooltip._openedTooltips.remove(this);
    _timer?.cancel();
    _timer = null;
    _controller.stop(canceled: false);
    super.deactivate();
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalPointerEvent);
    RendererBinding.instance.mouseTracker.removeListener(_handleMouseTrackerChange);
    _timer?.cancel();
    _timer = null;
    _controller.dispose();
    _tapRecognizer?.dispose();
    _longPressRecognizer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If message is empty then no need to create a tooltip overlay to show
    // the empty black container so just return the wrapped child as is or
    // empty container if child is not specified.
    if (_tooltipMessage.isEmpty) {
      return widget.child ?? const SizedBox();
    }
    assert(Overlay.of(context, debugRequiredFor: widget) != null);
    final ThemeData theme = Theme.of(context);
    final TextStyle defaultTextStyle;
    final BoxDecoration defaultDecoration;
    if (theme.brightness == Brightness.dark) {
      defaultTextStyle = theme.textTheme.bodyText2!.copyWith(
        color: Colors.black,
        fontSize: _getDefaultFontSize(),
      );
      defaultDecoration = BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      );
    } else {
      defaultTextStyle = theme.textTheme.bodyText2!.copyWith(
        color: Colors.white,
        fontSize: _getDefaultFontSize(),
      );
      defaultDecoration = BoxDecoration(
        color: Colors.grey[700]!.withOpacity(0.9),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      );
    }

    Widget result = Semantics(
      tooltip: (widget.excludeFromSemantics ?? _tooltipTheme.excludeFromSemantics ?? _defaultExcludeFromSemantics)
          ? null
          : _tooltipMessage,
      child: widget.child,
    );

    // Only check for gestures if tooltip should be visible.
    if (_visible) {
      result = Listener(
        onPointerDown: _handlePointerDown,
        behavior: HitTestBehavior.opaque,
        child: result,
      );
      // Only check for hovering if there is a mouse connected.
      if (_mouseIsConnected) {
        result = _ExclusiveMouseRegion(
          onEnter: _handleMouseEnter,
          onExit: _handleMouseExit,
          child: result,
        );
      }
    }

    final OverlayInfo overlayInfo = OverlayInfo.of(context)!;
    final bool showOverlay = _controller.status != AnimationStatus.dismissed;

    // We create this widget outside of the overlay entry's builder to prevent
    // updated values from happening to leak into the overlay when the overlay
    // rebuilds.
    final Widget? overlay = !showOverlay ? null : Directionality(
      textDirection: Directionality.of(context),
      child: _TooltipOverlay(
        overlayInfo: overlayInfo,
        tooltipState: this,
        richMessage: widget.richMessage ?? TextSpan(text: widget.message),
        height: widget.height ?? _tooltipTheme.height ?? _getDefaultTooltipHeight(),
        padding: widget.padding ?? _tooltipTheme.padding ?? _getDefaultPadding(),
        margin: widget.margin ?? _tooltipTheme.margin ?? _defaultMargin,
        onEnter: _mouseIsConnected ? _handleMouseEnter : null,
        onExit: _mouseIsConnected ? _handleMouseExit : null,
        decoration: widget.decoration ?? _tooltipTheme.decoration ?? defaultDecoration,
        textStyle: widget.textStyle ?? _tooltipTheme.textStyle ?? defaultTextStyle,
        textAlign: widget.textAlign ?? _tooltipTheme.textAlign ?? _defaultTextAlign,
        animation: CurvedAnimation(
          parent: _controller,
          curve: Curves.fastOutSlowIn,
        ),
        verticalOffset: widget.verticalOffset ?? _tooltipTheme.verticalOffset ?? _defaultVerticalOffset,
        preferBelow: widget.preferBelow ?? _tooltipTheme.preferBelow ?? _defaultPreferBelow,
      ),
    );

    return EvilWidget(
      remoteChild: overlay,
      overlayInfo: overlayInfo,
      child: result,
    );
  }
}

/// A delegate for computing the layout of a tooltip to be displayed above or
/// bellow a target specified in the global coordinate system.
class _TooltipPositionDelegate extends SingleChildLayoutDelegate {
  /// Creates a delegate for computing the layout of a tooltip.
  ///
  /// The arguments must not be null.
  _TooltipPositionDelegate({
    required this.overlayInfo,
    required this.tooltipState,
    required this.verticalOffset,
    required this.preferBelow,
  }) : assert(overlayInfo != null),
       assert(tooltipState != null),
       assert(verticalOffset != null),
       assert(preferBelow != null);

  final OverlayInfo overlayInfo;

  final TooltipState tooltipState;

  /// The amount of vertical distance between the target and the displayed
  /// tooltip.
  final double verticalOffset;

  /// Whether the tooltip is displayed below its widget by default.
  ///
  /// If there is insufficient space to display the tooltip in the preferred
  /// direction, the tooltip will be displayed in the opposite direction.
  final bool preferBelow;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final RenderBox box = tooltipState.context.findRenderObject()! as RenderBox;
    final Offset target = box.localToGlobal(
      box.size.center(Offset.zero),
      ancestor: overlayInfo.overlayRenderObject,
    );

    return positionDependentBox(
      size: size,
      childSize: childSize,
      target: target,
      verticalOffset: verticalOffset,
      preferBelow: preferBelow,
    );
  }

  @override
  bool shouldRelayout(_TooltipPositionDelegate oldDelegate) {
    return overlayInfo != oldDelegate.overlayInfo
        || tooltipState != oldDelegate.tooltipState
        || verticalOffset != oldDelegate.verticalOffset
        || preferBelow != oldDelegate.preferBelow;
  }
}

class _TooltipOverlay extends StatelessWidget {
  const _TooltipOverlay({
    required this.overlayInfo,
    required this.tooltipState,
    required this.height,
    required this.richMessage,
    this.padding,
    this.margin,
    this.decoration,
    this.textStyle,
    this.textAlign,
    required this.animation,
    required this.verticalOffset,
    required this.preferBelow,
    this.onEnter,
    this.onExit,
  });

  final OverlayInfo overlayInfo;
  final TooltipState tooltipState;
  final InlineSpan richMessage;
  final double height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;
  final TextStyle? textStyle;
  final TextAlign? textAlign;
  final Animation<double> animation;
  final double verticalOffset;
  final bool preferBelow;
  final PointerEnterEventListener? onEnter;
  final PointerExitEventListener? onExit;

  @override
  Widget build(BuildContext context) {
    Widget result = IgnorePointer(
      child: FadeTransition(
        opacity: animation,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyText2!,
            child: Container(
              decoration: decoration,
              padding: padding,
              margin: margin,
              child: Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: Text.rich(
                  richMessage,
                  style: textStyle,
                  textAlign: textAlign,
                ),
              ),
            ),
          ),
        ),
      )
    );
    if (onEnter != null || onExit != null) {
      result = _ExclusiveMouseRegion(
        onEnter: onEnter,
        onExit: onExit,
        child: result,
      );
    }
    return Positioned.fill(
      bottom: MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0.0,
      child: CustomSingleChildLayout(
        delegate: _TooltipPositionDelegate(
          overlayInfo: overlayInfo,
          tooltipState: tooltipState,
          verticalOffset: verticalOffset,
          preferBelow: preferBelow,
        ),
        child: result,
      ),
    );
  }
}

class _ExclusiveMouseRegion extends MouseRegion {
  const _ExclusiveMouseRegion({
    super.onEnter,
    super.onExit,
    super.child,
  });

  @override
  _RenderExclusiveMouseRegion createRenderObject(BuildContext context) {
    return _RenderExclusiveMouseRegion(
      onEnter: onEnter,
      onHover: onHover,
      onExit: onExit,
    );
  }
}

class _RenderExclusiveMouseRegion extends RenderMouseRegion {
  _RenderExclusiveMouseRegion({
    super.onEnter,
    super.onHover,
    super.onExit,
  });

  static bool foundInnermostMouseRegion = false;
  static bool isOutermostMouseRegion = true;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    bool hitTarget = false;
    final bool outermost = isOutermostMouseRegion;
    isOutermostMouseRegion = false;
    if (size.contains(position)) {
      hitTarget = hitTestChildren(result, position: position) || hitTestSelf(position);
      if ((hitTarget || behavior == HitTestBehavior.translucent) && !foundInnermostMouseRegion) {
        foundInnermostMouseRegion = true;
        result.add(BoxHitTestEntry(this, position));
      }
    }

    if (outermost) {
      isOutermostMouseRegion = true;
      foundInnermostMouseRegion = false;
    }
    return hitTarget;
  }
}
