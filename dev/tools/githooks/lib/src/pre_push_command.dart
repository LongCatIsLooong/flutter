// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:clang_tidy/clang_tidy.dart';
import 'package:path/path.dart' as path;

import 'prepush_changed_files.dart';

/// Extension type wrapping a raw line read from stdin in a pre-push hook:
/// `<local_ref> <local_oid> <remote_ref> <remote_oid>`
extension type PushRef._(String line) {
  List<String> get _parts => line.trim().split(RegExp(r'\s+'));

  String get localRef => _parts[0];
  String get localOid => _parts[1];
  String get remoteRef => _parts[2];
  String get remoteOid => _parts[3];

  static PushRef? parse(String line) {
    final ref = PushRef._(line);
    return ref._parts.length >= 4 ? ref : null;
  }

  static Iterable<PushRef> fromLines(String lines) =>
      lines.split('\n').map(PushRef.parse).whereType<PushRef>();
}

/// The command that implements the pre-push githook
class PrePushCommand extends Command<bool> {
  // This getter must not be accessed outside of the `run` method.
  // This guarantees the content in stdin is not consumed more than once.
  late final Future<Iterable<PushRef>> pushRefs = io.stdin
      .transform(utf8.decoder)
      .join()
      .then(PushRef.fromLines);

  @override
  final String name = 'pre-push';

  @override
  final String description = 'Checks to run before a "git push"';

  @override
  Future<bool> run() async {
    final sw = Stopwatch()..start();
    final verbose = globalResults!['verbose']! as bool;
    final enableClangTidy = globalResults!['enable-clang-tidy']! as bool;
    final flutterRoot = globalResults!['flutter']! as String;

    if (!enableClangTidy) {
      print(
        'The clang-tidy check is disabled. To enable set the environment '
        'variable PRE_PUSH_CLANG_TIDY to any value.',
      );
    }

    final checkResults = <bool>[
      await _runFormatter(flutterRoot, await pushRefs, verbose),
      if (enableClangTidy) await _runClangTidy(flutterRoot, verbose),
    ];
    sw.stop();
    io.stdout.writeln('pre-push checks finished in ${sw.elapsed}');
    return !checkResults.contains(false);
  }

  Future<bool> _runClangTidy(String flutterRoot, bool verbose) async {
    io.stdout.writeln('Starting clang-tidy checks.');
    final sw = Stopwatch()..start();
    final String engineSrcDir = path.join(flutterRoot, 'engine', 'src');
    // First ensure that out/host_debug/compile_commands.json exists by running
    // //flutter/tools/gn.
    var compileCommands = io.File(
      path.join(engineSrcDir, 'out', 'host_debug', 'compile_commands.json'),
    );
    if (!compileCommands.existsSync()) {
      compileCommands = io.File(
        path.join(engineSrcDir, 'out', 'host_debug_unopt', 'compile_commands.json'),
      );
      if (!compileCommands.existsSync()) {
        io.stderr.writeln(
          'clang-tidy requires a fully built host_debug or '
          'host_debug_unopt build directory',
        );
        return false;
      }
    }
    final outBuffer = StringBuffer();
    final errBuffer = StringBuffer();
    final clangTidy = ClangTidy(
      buildCommandsPath: compileCommands,
      outSink: outBuffer,
      errSink: errBuffer,
    );
    final int clangTidyResult = await clangTidy.run();
    sw.stop();
    io.stdout.writeln('clang-tidy checks finished in ${sw.elapsed}');
    if (clangTidyResult != 0) {
      io.stderr.write(errBuffer);
      return false;
    }
    return true;
  }

  Future<bool> _runFormatter(String flutterRoot, Iterable<PushRef> refs, bool verbose) async {
    var hasEngineChanges = false;

    const zeroOid = '0000000000000000000000000000000000000000';
    for (final ref in refs) {
      final String base = switch (ref.remoteOid) {
        zeroOid || '' => await guessMergeBase(flutterRoot, ref.remoteOid, io.Process.run),
        final String baseOid => baseOid,
      };

      final Iterable<String> changedFiles = await getPrePushChangedFiles(
        flutterRoot,
        baseRef: base,
        targetRef: ref.localOid,
      );
      if (changedFiles.any(_isEngineFile)) {
        hasEngineChanges = true;
        break;
      }
    }
    if (!hasEngineChanges) {
      io.stdout.writeln('No engine changes detected. Skipping formatting checks.');
      return true;
    }
    io.stdout.writeln('Starting formatting checks.');
    final sw = Stopwatch()..start();
    final String engineDir = path.join(flutterRoot, 'engine', 'src', 'flutter');
    final ext = io.Platform.isWindows ? '.bat' : '.sh';
    final bool result = await _runCheck(
      engineDir,
      path.join(engineDir, 'ci', 'format$ext'),
      <String>[],
      'Formatting check',
      verbose: verbose,
    );
    sw.stop();
    io.stdout.writeln('formatting checks finished in ${sw.elapsed}');
    return result;
  }

  Future<bool> _runCheck(
    String flutterRoot,
    String scriptPath,
    List<String> scriptArgs,
    String checkName, {
    bool verbose = false,
  }) async {
    if (verbose) {
      io.stdout.writeln('Starting "$checkName": $scriptPath');
    }
    final io.ProcessResult result = await io.Process.run(
      scriptPath,
      scriptArgs,
      workingDirectory: flutterRoot,
    );
    if (result.exitCode != 0) {
      final message = StringBuffer();
      message.writeln('Check "$checkName" failed.');
      message.writeln('command: $scriptPath ${scriptArgs.join(" ")}');
      message.writeln('working directory: $flutterRoot');
      message.writeln('exit code: ${result.exitCode}');
      message.writeln('stdout:');
      message.writeln(result.stdout);
      message.writeln('stderr:');
      message.writeln(result.stderr);
      io.stderr.write(message.toString());
      return false;
    }
    if (verbose) {
      io.stdout.writeln('Check "$checkName" finished successfully.');
    }
    return true;
  }
}

/// This mirrows `getFileList` in engine/src/flutter/ci/bin/format.dart.
bool _isEngineFile(String filePath) {
  assert(filePath.isNotEmpty);
  final String normalized = path.normalize(filePath);
  const engineSubPath = 'engine/src/flutter';
  return normalized.contains(engineSubPath) && !normalized.contains('third_party');
}
