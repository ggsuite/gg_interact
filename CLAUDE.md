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

# gg workflow

This repo is developed ticket by ticket with the `gg` CLI. Follow the
development guide, it tells you when to ask the user and which command
comes next:

@doc/guides/for-ai/ai-dev-guide.md

The steps are also available as skills: `/gg-ticket`, `/gg-commit`,
`/gg-push`, `/gg-publish`, `/gg-cleanup`. `/gg` lists them and says which
one comes next.

<!-- helix:claude_md:end -->
