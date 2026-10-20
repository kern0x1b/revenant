# HMHomeDelegate and HMHomeManagerDelegate

The two delegate protocols of the home graph, of **8.0**, in `HMHomeDelegateProtocols8_0.m` — a file
**generated** by `tests/backports/host/homekit/protocols.py`, which also generates their registry rows from
the same reading, so what the port declares and what the registry claims cannot drift apart.

| protocol | members | optional | required |
|---|---|---|---|
| `HMHomeDelegate` (`HMHome.h:481`) | 32 | 32 | 0 |
| `HMHomeManagerDelegate` (`HMHomeManager.h:110`) | 6 | 6 | 0 |

Every member is `@optional`, which is the header's word: a conformer implements the ones it needs, and a
port that turned one into a required method would make a conformer that legitimately omits it fail to
compile. Four members carry a later release and keep their own `API_AVAILABLE`:
`homeDidUpdateAccessControlForCurrentUser:` and `home:didUpdateHomeHubState:` are 11.0,
`homeDidUpdateSupportedFeatures:` is 13.2, and `homeManager:didUpdateAuthorizationStatus:` is 13.0.

## Where each part of a member comes from, and why not one reader

- **The selector** comes from `ObjCMethodDecl`'s `name` in clang's AST, cross-checked by an **independent
  regex count** of the header's declaration lines: AST 32 and 6, regex 32 and 6. The regex reader is
  count-only and never names a selector.
- **The declaration text** is **copied** from the header's own lines. Copying a declaration is safe;
  parsing one was not — four separate bugs in a regex over declarations produced a generator that reported
  2 members where the header has 32.
- **The required/optional split does not come from the AST at all.** This clang's JSON dump carries **no
  key containing `optional` or `required` anywhere in the subtree**, checked over the whole dump. It comes
  from the header's own `@optional` and `@required` marker lines, joined to each method by the line number
  that the AST's `loc.line` also gives.

Two readers, two things, one join.

## What the contract check does, and what it caught

`ast_check.py` reads **both** sides: the header's from the AST, the port's from its own markers and
selectors, and compares the two `(selector, optional)` sets, printing any difference by name. Two controls,
one per protocol, each required to be caught or the run fails:

- an `@optional` flipped to `@required` in a scratch copy under `.agent-work/runs/homekit/scratch` — caught
  by name as a required/optional difference;
- one declaration deleted from the port — caught by name as missing, with the count falling 32 → 31 and
  6 → 5.

It also carries a self-check that **fails the run if either side of the comparison is empty**, because
while the port side was empty every member differed and both controls "passed" for the wrong reason. A
comparison in which one side is empty is satisfied by everything differing.

Two defects it caught in this work, both of which would otherwise have shipped:

- the reader dropped each selector's **trailing colon** while the AST keeps it, so every multi-part
  selector differed on both sides. The runtime's spelling keeps the colon on the last part too, and a
  reader that drops it names an API that does not exist. The generator had the same `.rstrip(":")` and
  would have written wrong registry row names.
- the reader's availability-macro strip was a **regular expression with a literal `\\b`** in a raw string,
  which matched nothing. It is now a **scan for the macro's name and then its balanced parentheses**, which
  is the one reading that is right both for `API_AVAILABLE(ios(11.0), watchos(4.0), tvos(11.0))` — three
  levels deep — and for a bare macro with no argument, and cannot be over-escaped.

## What is not checked here

The **runtime half** — whether a conformer built against this library links and is called — is not checked
by any of this, for the reason recorded in `coordination/crutches.md`: no `HomeKit.framework` exists in any
macOS SDK on this machine, the SDK's own HomeKit types are marked `API_UNAVAILABLE(macos)`, and no
simulator runtime is installed. The native fix is the armv7 emulator, a heavy job left for a free slot.

The cache counts in `oracle.py` are **global, not per class**: a cache holds one copy of a selector name
shared by every class that uses it, so a count dates a name's first appearance and says nothing about
behaviour.
