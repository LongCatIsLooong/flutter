// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/src/painting/annotated_string.dart';
import 'package:flutter/src/painting/text_style_attributes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromInlineSpan', () {
    const text = 'heh';
    final AnnotatedString string = AnnotatedString.fromInlineSpan(TextSpan(
      text: text,
    ));

    expect(string.string, text);
  });
}
