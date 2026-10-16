#!/usr/bin/env dart

// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_interact/gg_interact.dart';

Future<void> main() async {
  throwWhenNotATerminal('the example prompts', 'run the example in a terminal');

  final prompts = GgPrompts.current;

  final language = await prompts.select(
    prompt: 'Which language?',
    options: ['Dart', 'TypeScript'],
  );

  final name = await prompts.inputUntilValid(
    prompt: 'Name',
    validate: (answer) => answer.isEmpty ? 'Please enter a name.' : null,
    onInvalid: print,
  );

  final ok = await prompts.confirm(prompt: 'Create $name?');
  print('language: $language, name: $name, create: $ok');
}
