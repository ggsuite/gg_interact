# gg_interact

The prompts every gg command asks its questions with.

## Concept

1. **One way to ask.** Every prompt of the gg suite goes through
   `GgPrompts.current`. An embedder without a terminal (gg in Node) answers
   by assigning it; tests assign a scripted subclass.
2. **Two primitives, the rest built on them.** An embedder implements only
   `select` and `input`; `confirm` and `inputUntilValid` are built on them, so
   new prompt kinds never break an embedder. `editText` (a whole text in the
   editor, `ExternalEditor`) answers null by default — the caller then asks
   with `input`.
3. **Never hang.** Before gg asks, `throwWhenNotATerminal` checks that a user
   can see and answer: stdin *and* stdout (`stdioHasTerminal`) — on Windows
   stdin alone reports a terminal behind a pipe. `editText` opens no editor
   without a terminal: nobody would close it.
4. **One theme.** The colors belong to the theme (`promptTheme`); colors in a
   question or option are removed first.
5. **No `dart:ffi` in Wasm.** `package:interact` is reached through a
   conditional import only; a Wasm build gets `UnsupportedPrompts`.
6. **Fall back, don't fail.** An editor that cannot be started (a typo in
   `GG_EDITOR`; VS Code is skipped on a Linux box without a display) makes
   `editText` answer null, so the caller asks with `input`. Only an editor
   that ends with an error code cancels, like in git. An editor that returns
   at once would hand back the defaults unseen, so
   `ExternalEditor.withWaitFlag` adds `--wait`/`-w` to VS Code, its forks and
   Sublime Text. On Windows only a batch file (`code.cmd`) runs in a shell
   (`ExternalEditor.launchOf`): the shell breaks quoted paths like
   `C:\Program Files (x86)\...`.

`gg_one_core` re-exports this package unchanged.

<!-- helix:claude_md:start -->

@.claude/CLAUDE_dna_gg.md

<!-- helix:claude_md:end -->
