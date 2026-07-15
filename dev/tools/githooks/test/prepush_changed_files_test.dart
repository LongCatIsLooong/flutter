// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

import 'package:githooks/src/pre_push_command.dart';
import 'package:githooks/src/prepush_changed_files.dart';
import 'package:test/test.dart';

void main() {
  group('PushRef.parse', () {
    test('parses stdin line correctly', () {
      final PushRef? ref = PushRef.parse(
        'refs/heads/feature_branch 1a2b3c4d5e6f refs/heads/feature_branch 7a8b9c0d1e2f',
      );
      expect(ref, isNotNull);
      expect(ref!.localRef, equals('refs/heads/feature_branch'));
      expect(ref.localOid, equals('1a2b3c4d5e6f'));
      expect(ref.remoteRef, equals('refs/heads/feature_branch'));
      expect(ref.remoteOid, equals('7a8b9c0d1e2f'));
    });

    test('returns null for malformed line', () {
      expect(PushRef.parse('invalid line'), isNull);
    });
  });

  group('getPrePushChangedFiles', () {
    test('diffs against remoteOid when remoteOid is valid SHA', () async {
      late final List<String> capturedArgs;

      Future<io.ProcessResult> mockRunner(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
      }) async {
        capturedArgs = arguments;
        return io.ProcessResult(0, 0, 'engine/src/flutter/shell/platform/darwin/foo.mm\n', '');
      }

      final Iterable<String> files = await getPrePushChangedFiles(
        '/fake/flutter',
        baseRef: 'remote_sha_456',
        targetRef: 'local_sha_123',
        runner: mockRunner,
      );

      expect(capturedArgs, contains('remote_sha_456...local_sha_123'));
      expect(files, equals(<String>['engine/src/flutter/shell/platform/darwin/foo.mm']));
    });

    test(
      'uses upstream/master when upstream remote exists and diffs against merge-base when zeroOid',
      () async {
        late final List<String> capturedArgs;

        Future<io.ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          if (arguments.contains('get-url')) {
            return io.ProcessResult(0, 0, 'git@github.com:flutter/flutter.git\n', '');
          }
          if (arguments.contains('merge-base')) {
            expect(arguments, contains('upstream/master'));
            return io.ProcessResult(0, 0, 'fork_point_sha_789\n', '');
          }
          capturedArgs = arguments;
          return io.ProcessResult(0, 0, 'dev/tools/githooks/lib/githooks.dart\n', '');
        }

        const zeroOid = '0000000000000000000000000000000000000000';
        final Iterable<String> files = await getPrePushChangedFiles(
          '/fake/flutter',
          baseRef: zeroOid,
          targetRef: 'local_sha_123',
          runner: mockRunner,
        );

        expect(capturedArgs, contains('fork_point_sha_789...local_sha_123'));
        expect(files, ['dev/tools/githooks/lib/githooks.dart']);
      },
    );

    test('falls back to origin/master when upstream remote does not exist', () async {
      late final List<String> capturedArgs;

      Future<io.ProcessResult> mockRunner(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
      }) async {
        if (arguments.contains('get-url')) {
          return io.ProcessResult(1, 0, '', 'fatal: No such remote');
        }
        if (arguments.contains('merge-base')) {
          expect(arguments, contains('origin/master'));
          return io.ProcessResult(0, 0, 'fork_point_sha_789\n', '');
        }
        capturedArgs = arguments;
        return io.ProcessResult(0, 0, 'dev/tools/githooks/lib/githooks.dart\n', '');
      }

      const zeroOid = '0000000000000000000000000000000000000000';
      final Iterable<String> files = await getPrePushChangedFiles(
        '/fake/flutter',
        baseRef: zeroOid,
        targetRef: 'local_sha_123',
        runner: mockRunner,
      );

      expect(capturedArgs, contains('fork_point_sha_789...local_sha_123'));
      expect(files, ['dev/tools/githooks/lib/githooks.dart']);
    });
  });
}
