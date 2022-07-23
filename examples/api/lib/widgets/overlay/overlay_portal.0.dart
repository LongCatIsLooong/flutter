// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Flutter code sample for OverlayPortal

import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Code Sample',
      home: Scaffold(
        appBar: AppBar(title: const Text('OverlayPortal Example')),
        body: const Center(child: ClickableTooltipWidget()),
      )
    );
  }
}

class ClickableTooltipWidget extends StatefulWidget {
  const ClickableTooltipWidget({super.key});

  @override
  State<StatefulWidget> createState() => ClickableTooltipWidgetState();
}

class ClickableTooltipWidgetState extends State<ClickableTooltipWidget> {
  bool shouldShowTooltip = false;

  void _onPressed() {
    setState(() { shouldShowTooltip = !shouldShowTooltip; });
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _onPressed,
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 50),
        child: OverlayPortal(
          overlayChild: !shouldShowTooltip
            ? null
            : const Positioned(
                right: 50,
                bottom: 50,
                child: ColoredBox(
                  color: Colors.amberAccent,
                  child: Text('tooltip'),
                ),
              ),
          child: const Text('Press to show/hide tooltip'),
        ),
      ),
    );
  }
}
