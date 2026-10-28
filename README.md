# gg_interact

Interactive terminal prompts for the gg suite: select, input and confirm,
with headless detection.

```dart
import 'package:gg_interact/gg_interact.dart';

throwWhenNotATerminal('the name prompt', 'pass --name');

final prompts = GgPrompts.current;
final index = await prompts.select(prompt: 'Language', options: ['Dart', 'TS']);
final name = await prompts.inputUntilValid(
  prompt: 'Name',
  validate: (v) => v.isEmpty ? 'Please enter a name.' : null,
  onInvalid: print,
);
final ok = await prompts.confirm(prompt: 'Create $name?');
```

- **`GgPrompts.current`** is what every gg prompt goes through. An embedder
  without a terminal — gg in Node, say — answers by assigning it; tests
  assign a scripted subclass and reset it with `GgPrompts.current = null`.
- **`select` and `input`** are the two prompts an embedder implements.
  `confirm` and `inputUntilValid` are built on them.
- **`editText`** opens a whole text in the user's editor — `GG_EDITOR`,
  else VS Code (`code --wait`; on Linux only with a display), else `VISUAL`
  or `EDITOR` — and returns what was saved. VS Code, its forks and Sublime
  Text get their wait flag when a variable lacks it. It answers null without
  a terminal, without an editor, when the editor cannot be started, and by
  default for an embedder, so the caller falls back to `input`. An editor
  ending with an error code cancels, like in git.
- **`throwWhenNotATerminal`** fails fast in CI, pipes and scripts instead of
  waiting forever for an answer.
- A Wasm build has no `dart:ffi`; its prompts throw
  `GgPromptsUnsupportedError` until an embedder supplies some.

The prompts used to live in `gg_one_core`, which re-exports them unchanged.
