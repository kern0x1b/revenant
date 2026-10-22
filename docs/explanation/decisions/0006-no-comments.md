# 0006: No comments in code, scripts or recipes

Status: accepted

## Context

Comments in this repository drift. A comment that says what the code did last year is worse than none, and
the explanations we need (why a number, why a workaround) belong in the docs, where they can be linked and
dated.

## Decision

No comment in code, scripts or recipes. The one exception is a licence header that a licence requires. Text
copied from upstream keeps its comments, and such files are marked in `.gitattributes` as `comments=upstream`;
a test fixture whose comments are its data is marked `comments=fixture`.

`tools/comments.lua` finds comments (`check`), removes them (`strip`), and proves that a change is comments only
(`verify`): clang's raw tokens, Swift's parse tree, and Lua's bytecode.

## Consequences

- Reasons go in `docs/`, next to the decision record or the guide they belong to.
- A change that only removes comments is checked, not reviewed by eye.

## Enforced by

`repository/comments_check` runs `comments.lua check` over the tracked files. `repository/comments_test` tests the
tool itself. Both are in the `repository/*` group of `./xmakew test -P .`.
