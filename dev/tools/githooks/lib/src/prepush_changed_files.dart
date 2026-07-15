// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

/// Function signature for running process commands to enable mocking in tests.
typedef ProcessRunner =
    Future<io.ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

/// Gets the list of modified file paths for a pre-push operation given target and base OIDs.
Future<Iterable<String>> getPrePushChangedFiles(
  String flutterRoot, {
  required String baseRef,
  required String targetRef,
  ProcessRunner runner = io.Process.run,
}) async {
  final io.ProcessResult result = await runner('git', <String>[
    'diff',
    '--name-only',
    '--diff-filter=d',
    '$baseRef...$targetRef',
  ], workingDirectory: flutterRoot);

  return result.trimmedStdout
          ?.split('\n')
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty) ??
      const <Never>[];
}

/// Guesses the base commit for `git diff` given the `targetRef`.
///
/// Returns the common ancestor commit between [targetRef] and the estimated main
/// tracking branch (typically upstream/master).
///
/// Assumptions:
/// - Assumes `upstream`, if configured (falls back to `origin` otherwise),
///   points to flutter/flutter.git and is thus a reasonable branch to find the
///   base commit.
///   .
/// - Assumes the target integration branch on the remote is named `master`.
Future<String> guessMergeBase(String flutterRoot, String targetRef, ProcessRunner runner) async {
  final String upstreamRemote = await _guessUpstreamRemote(flutterRoot, runner);
  final targetBranch = '$upstreamRemote/master';
  final io.ProcessResult result = await runner('git', <String>[
    'merge-base',
    targetRef,
    targetBranch,
  ], workingDirectory: flutterRoot);

  return switch (result.trimmedStdout) {
    null || '' => targetBranch,
    final String base => base,
  };
}

// Returns the name of the remote who will be used as the diff base.
// The logic is copied from `engine/src/flutter/ci/bin/format.dart`, which assumes
// the remote name is either `upstream` or `origin`.
Future<String> _guessUpstreamRemote(String flutterRoot, ProcessRunner runner) async {
  const upstream = 'upstream';
  final io.ProcessResult result = await runner('git', <String>[
    'remote',
    'get-url',
    'upstream',
  ], workingDirectory: flutterRoot);

  return switch (result.trimmedStdout) {
    null || '' => 'origin',
    _ => upstream,
  };
}

extension _ProcessResultExtension on io.ProcessResult {
  /// Gets the trimmed stout of the [ProcessResult], or null if the process
  /// exited with a non-zero return code.
  String? get trimmedStdout {
    return exitCode != 0 ? null : (stdout as String).trim();
  }
}
