# surftool

The public surface of an SDK's `.swiftinterface`, read with **swift-syntax's `SwiftParser`**
(Apache-2.0, `https://github.com/swiftlang/swift-syntax`, taken at the path below) and printed as

    owner <TAB> member <TAB> argument labels <TAB> kind

The earlier regex gate, since removed, read the same files with hand-written patterns, which miss what
a parser sees: an `associatedtype` witness printed as a `var`, a nested `typealias` printed as a
property, an enum `case`, an `init`, a `subscript`, a static in a constrained extension. Those are
exactly the rows it then called invented.

The walker also follows each interface's `@_exported import` lines and walks the modules they name,
so the oracle is the closure SwiftUI reaches rather than a list of modules written down here. Measured
on this tree: 241 rows before the parser, 205 after it, **201** once the re-export closure is followed
and the four CoreGraphics typealiases that no `.swiftinterface` declares are on the allow-list with that
reason.

It is a host project of its own, `frameworks/SwiftUI/tests/surface/xmake.lua`, because the gate itself must stay Lua-only and
fast: `./xmakew l -P . frameworks/SwiftUI/tools/api_surface.lua apple` builds it and writes the surface file,
`apple-26-surface.tsv` in the run folder (`$HOME/.revenant/cache/<task>/swiftui/api/`), which `api_invented.lua`
reads.

* `swift-syntax` — the toolchain's package `revenant@swift-syntax` (604.0.0, the tag that matches the 6.4
  toolchain), Apache-2.0. Nothing from it is vendored: it is a build dependency of this one tool, and it is not
  linked into SwiftUI. The rows above were measured with the `swift-DEVELOPMENT-SNAPSHOT-2026-09-21-a` checkout
  the earlier SwiftPM package cloned; that 604.0.0 reads the 26.2 interfaces to the same rows has not been run.

## What each artifact is, and which pair goes with which

Both lists are run output and are kept in the run folder, not in the tree.

Four shapes are written by three tools, and pairing the wrong two used to print a green partition of
nothing. **`surface_diff.lua diff` reads three tab-separated columns per row, `owner` / `kind` / `name`, and
nothing else**; a file of any other shape is a hard error naming the file, the expected three and the
count found, because the sets it partitions would otherwise hold vacuously at `0 == 0`.

| artifact | columns | what it is | read by |
| --- | --- | --- | --- |
| `apple-26-surface.tsv` | 4 — owner, member, argument labels, kind | `api_surface.lua apple`'s output, the surftool's rows of Apple's 26.2 surface | `api_invented.lua` |
| `surface-26.2*.tsv` | **3** — owner, kind, name | `surface_rows.lua sdk`'s output: the surface of the SDK's interfaces | `surface_diff.lua diff` |
| `gaps*.tsv` | 1 — `Owner#name` | **gap rows**: what this tree declares no name for. 341 of them in `gaps14.tsv`, and *not* the 344 of the `|O\N|` above | read by eye; `surface_diff.lua gaps` writes them |
| `ours*.tsv` | 4 — owner, kind, name, path | `surface_rows.lua tree`'s output: this tree's own declarations | `surface_diff.lua gaps` |

**`surface_rows.lua tree` writes four columns and `surface_diff.lua diff` reads three**, so the three-column *ours* file is made
by `surface_rows.lua collapse`, which drops the path and collapses a row whose owner, kind and name repeat:

    ./xmakew l -P . frameworks/SwiftUI/tools/surface_rows.lua collapse ours13.tsv > ours13-3col.tsv

The refusal covers a 2-column file, a 4-column file, a 1-column *old* side, and an empty *new* side with and without `--allow-empty-new`.

    $ ./xmakew l -P . frameworks/SwiftUI/tools/surface_diff.lua diff old.tsv new.tsv      # new.tsv has two columns
    …/new.tsv: line 1 has 2 tab-separated column(s), the 3 this diff reads are owner/kind/name; 1 line(s)
    in all (first at line 1). Refusing to read the file as the empty set: the partition below would hold
    vacuously. Use the artifact that has three columns (docs/reference/swiftui/surface.md says …).
    $ echo $?
    1

One thing to know about what that refusal is *for*: `surface_diff.lua diff` was written to compare two
**extractions of the same interfaces**, the old hand-written one and the parser's. Run against Apple's
surface and this tree's declarations the sets partition exactly as the tool promises, and the classes are
then mostly a statement about two different corpora rather than about a lost extraction:

    |O| = 837   surface rows in OLD
    |N| = 8430   surface rows in NEW
    |O\N| = 344   |O\N| rows: moved 229  attribute 0  other 115
    |N\O| = 7937   |N\O| rows: gained
    identity over surface rows (not gap rows): |O|-|N| = -7593, |O\N| - |N\O| = -7593, classes: 229 + 0 + 115 = 344

**344 and 341 are two different sets that happen to be near each other, and nothing joins them:** 344 is
`|O\N|`, the OLD surface's rows the NEW one does not have, and 341 is the row count of the gaps list —
the *gap rows* of `surface_diff.lua gaps`, which are the surface this tree declares no name for. Every report line
the tool prints now names the set it counts, so the two are not read as one.

Read `moved` there as "this leaf name is declared at another owner", not as "the rewrite moved it", and
read `other` as the interesting part: `Animatable#_makeAnimatable` (underscored machinery the interfaces
declare and this tree does not) and two bare `subscript` rows the old file names and the new one does not.

## Two things to know before you measure with this

**The copy of Apple's framework is generated run output, and the authority is the SDK `surface_rows.lua sdk` reads.**
`tools/api_surface.lua prepare` copies the 16.4 SDK's `SwiftUI.framework` into the run folder
(`$HOME/.revenant/cache/<task>/swiftui/fw/`), outside the tree; nothing measured from it is a fact about this
repository. `surface_rows.lua sdk` and `surface_diff.lua` read the iOS 26.2 SDK that `toolchain/modules/workspace.lua` names
(`sdk()`: revenant's `iphoneos-sdk 26.2` package, or the folder `REVENANT_GEN_SDK` names), `surface_diff.lua` for its
`arm64e-apple-ios.swiftinterface` index. **A surface number is only comparable with another taken from the same
SDK root**, so `REVENANT_GEN_SDK` is the variable to set rather than a path to edit; and where the two disagree,
the 26.2 interfaces are right and the 16.4 copy is a convenience for the tools that want a framework tree rather
than interfaces.

**Patches 0006–0008 of the earlier series carry `wip:` subjects, and that history is exported rather than
rewritten.** Reading an exported patch as a claim about what ran would be wrong, and the series is not
amended to hide it: amending an exported series breaks every reference to it, and the honest form is the
commit's own message beside a note that says what it means. So: **read a series as a whole.** A `wip:`
commit says in its own subject line that its work did not run, and the commit that follows it is the one
that measured it. This series has no `wip:` subject, and `docs/guides/swiftui/contributing.md` asks for none — plain
imperative subject, no type prefix, no scope tag.
