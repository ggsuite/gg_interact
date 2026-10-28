// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

/// Interactive terminal prompts for the gg suite.
library;

export 'src/external_editor.dart';
export 'src/prompts.dart';
export 'src/prompts_interact.dart'
    if (dart.library.js_interop) 'src/prompts_unsupported.dart'
    show colorOff;
export 'src/terminal_guard.dart';
