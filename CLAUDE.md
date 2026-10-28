# gg_interact

The prompts every gg command asks its questions with.

## Concept

1. **One way to ask.** Every prompt of the gg suite goes through
   `GgPrompts.current`. An embedder without a terminal (gg in Node) answers
   by assigning it; tests assign a scripted subclass.
2. **Two primitives, the rest built on them.** An embedder implements only
   `select` and `input`; `confirm` and `inputUntilValid` are built on them, so
   new prompt kinds never break an embedder.
3. **Never hang.** Before gg asks, `throwWhenNotATerminal` checks that a user
   can see and answer: stdin *and* stdout (`stdioHasTerminal`) — on Windows
   stdin alone reports a terminal behind a pipe.
4. **One theme.** The colors belong to the theme (`promptTheme`); colors in a
   question or option are removed first.
5. **No `dart:ffi` in Wasm.** `package:interact` is reached through a
   conditional import only; a Wasm build gets `UnsupportedPrompts`.

`gg_one_core` re-exports this package unchanged.

<!-- helix:claude_md:start -->

@.claude/CLAUDE_dna_gg.md

<!-- helix:claude_md:end -->
