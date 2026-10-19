// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_console_colors/gg_console_colors.dart';

/// Signature of the check whether a user can answer on the terminal.
typedef HasTerminal = bool Function();

/// Whether stdin alone is a terminal. Kept for old callers; prompts take
/// [stdioHasTerminal], since stdin alone does not show who reads along.
// coverage:ignore-start
bool defaultHasTerminal() => stdin.hasTerminal;
// coverage:ignore-end

/// Whether a user can answer: stdin to read and stdout to draw on. On
/// Windows stdin reports a terminal even when nobody sees the output.
// coverage:ignore-start
bool stdioHasTerminal() => stdin.hasTerminal && stdout.hasTerminal;
// coverage:ignore-end

/// Throws when stdin or stdout is not a terminal, so headless runs (CI,
/// scripts, pipes) fail fast with an actionable message instead of hanging
/// forever on an interactive prompt.
///
/// [what] names the prompt (e.g. `the merge message prompt`); [alternative]
/// tells the user how to supply the value non-interactively. [hasTerminal]
/// replaces the check in tests — `dart test` hands the test isolate a
/// stdin whose `hasTerminal` differs per platform, so the check must be
/// injected instead of observed.
void throwWhenNotATerminal(
  String what,
  String alternative, {
  HasTerminal hasTerminal = stdioHasTerminal,
}) {
  if (!hasTerminal()) {
    throw Exception(
      cError(
        'Cannot show $what: stdin or stdout is not a terminal. '
        'For headless runs, $alternative.',
      ),
    );
  }
}
