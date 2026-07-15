// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

import 'package:githooks/githooks.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// The path to the flutter checkout. Used to run test against a real checkout.
//
// DO NOT use `dart test` to run this test or this path points to a temp dir
// created by the test runner, causing tests to fail. Use `flutter test` instead.
//
// Since we set `resolution: workspace` in pubspec.yaml, `Platform.script` reports
// FLUTTER_RROT/main.dart.
final String _flutterRoot = io.File(io.Platform.script.path).parent.path;

void main() {
  assert(
    io.Platform.environment.containsKey('FLUTTER_TEST'),
    'Use "flutter test" to run this test.',
  );

  test('Fails gracefully without a command', () async {
    int? result;
    try {
      result = await run(<String>[]);
    } catch (e, st) {
      fail('Unexpected exception: $e\n$st');
    }
    expect(result, equals(1));
  });

  test('Fails gracefully with an unknown command', () async {
    int? result;
    try {
      result = await run(<String>['blah']);
    } catch (e, st) {
      fail('Unexpected exception: $e\n$st');
    }
    expect(result, equals(1));
  });

  test('Fails gracefully without --flutter', () async {
    int? result;
    try {
      result = await run(<String>['pre-push']);
    } catch (e, st) {
      fail('Unexpected exception: $e\n$st');
    }
    expect(result, equals(1));
  });

  test('Fails gracefully when --flutter is not an absolute path', () async {
    int? result;
    try {
      result = await run(<String>['pre-push', '--flutter', 'non/absolute']);
    } catch (e, st) {
      fail('Unexpected exception: $e\n$st');
    }
    expect(result, equals(1));
  });

  test('Fails gracefully when --flutter does not exist', () async {
    int? result;
    try {
      result = await run(<String>[
        'pre-push',
        '--flutter',
        if (io.Platform.isWindows) r'C:\does\not\exist' else '/does/not/exist',
      ]);
    } catch (e, st) {
      fail('Unexpected exception: $e\n$st');
    }
    expect(result, equals(1));
  });

  test('post-merge runs successfully', () async {
    int? result;
    try {
      result = await run(<String>['post-merge', '--flutter', _flutterRoot]);
    } catch (e, st) {
      fail('Unexpected exception: $e\n$st');
    }
    expect(result, equals(0));
  });

  test('pre-rebase runs successfully', () async {
    int? result;
    try {
      result = await run(<String>['pre-rebase', '--flutter', _flutterRoot]);
    } catch (e, st) {
      fail('Unexpected exception: $e\n$st');
    }
    expect(result, equals(0));
  });

  test('post-checkout runs successfully', () async {
    int? result;
    try {
      result = await run(<String>['post-checkout', '--flutter', _flutterRoot]);
    } catch (e, st) {
      fail('Unexpected exception: $e\n$st');
    }
    expect(result, equals(0));
  });

  test('Setting core.hooksPath to engine/src/flutter/tools/githooks still works', () async {
    final String oldHooksPath = io.Directory(
      path.join(_flutterRoot, 'engine', 'src', 'flutter', 'tools', 'githooks'),
    ).path;

    final io.ProcessResult postCheckoutResult = await io.Process.run(
      path.join(oldHooksPath, 'post-checkout'),
      <String>[],
      workingDirectory: oldHooksPath,
    );
    expect(postCheckoutResult.exitCode, 0);
  });
}
