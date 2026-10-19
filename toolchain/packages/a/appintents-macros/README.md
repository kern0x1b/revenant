# charon@appintents-macros

The macro plugins `charon@appintents` and `charon@tipkit` name: `AppIntentsMacros` and `TipKitMacros`,
as host executables a device compile loads with `-load-plugin-executable`.

The framework expands these with its own compiler plugin, which is on the framework's own releases and
not on these, so a port that writes `@AppEntity(schema:)` has no expansion. This package is the port's
own expansion of them, and it is what the 19 macro rows in `charon@appintents` and the three in
`charon@tipkit` are waiting for.

**Built against `charon@swift-syntax`**, the Apache-2.0 upstream at the tag that matches the fleet's
6.4 toolchain, and not against the toolchain's own copy: that copy exports every macro protocol
(`AccessorMacro`, `PeerMacro`, `MemberAttributeMacro`, `MemberMacro`, `ExtensionMacro`,
`FreestandingMacro`, `Macro`) and **no** `CompilerPlugin` — it sits behind `@_spi(PluginMessage)` in
`SwiftCompilerPluginMessageHandling`, so a `-load-plugin-executable` cannot be written against it. The
measurement is in the commit that found it, and `packages/a/appintents/facts/AppIntents/Macros.md`
records what each macro's contract is, read off the framework's own `@attached` declarations.

**What is written and what is not**, per macro, in `Sources/`:

| macro | roles | state |
| --- | --- | --- |
| `ComputedProperty()` | peer + accessor | written, and both roles **typecheck** against the toolchain's own swift-syntax. The entry point and the expansion harness are **not** done: the rule that builds the plugin ships in the next addon release cut from main, and until it does `tests/Expansions.swift` **asserts nothing** -- it is a hand-written reference, and `tests/Mutation.md` says so and carries the mutant that must go red |
| `DeferredProperty()` | peer + accessor | not started |
| `AppEntity<T>(schema:)`, `AppIntent<T>(schema:)`, `AppEnum<T>(schema:)` | memberAttribute + extension | not started |
| `AssistantEntity/Enum/Intent<T>(schema:)` | memberAttribute + extension | not started |
| `UnionValue()` | expression | not started |

Apple's own plugin is **not** on this machine — the toolchain ships `libObservationMacros` and
`libSwiftMacros` and nothing else — so the reference is the framework's interface declarations plus a
hand-checked expansion, not a diff against Apple's output. `tests/Expansions.swift` says so in its own
header, and says which two of its own errors are its own.

## Building it, and the store rule that a run of it has to know

`charon@swift-syntax` is a **host** package, and the rule that builds a plugin from it is
`@addon/charon/macro`, not `rules/swift`: a plugin is compiled for the machine running the compiler
and loaded with `-load-plugin-executable`, so it is neither a port target nor a device binary.

**Use the shared `~/.xmake` store.** A run of mine set a private `XMAKE_GLOBALDIR` and the project
then re-resolved the whole chain *from the network* into an empty store — the log of that run:

```
=> download https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS16.5.sdk.tar.xz .. ok
=> install iphoneos-sdk 16.4 .. failed
clang: error: invalid linker name in argument '-fuse-ld=…/ld64/…/bin/ld'
```

A gigabyte-class download and then a toolchain install: network-bound, which is how it came to sit
for 26 minutes at 0% CPU with no child processes, holding a slow slot. The repository's own trap
says it: *a private store re-resolves the whole dependency chain from network, up to rebuilding LLVM
from source — never do that either.* Nothing collides in the shared store anyway, because
`charon@swift-syntax` installs under its own recipe digest (the recipe file's hash and the pinned
commit, since its sources are upstream's and not in this tree).

A gate that builds this should also **bound** its `xmake` calls and close stdin (`</dev/null`), so
neither a hang nor a prompt can hold a slot again, and it should be launched only when the machine is
below its load cap — a queued job that waits in heavy.sh is a job holding a slot, which is the thing
the cap exists to prevent.

## Where `charon@swift-syntax`'s products land — measured, not derived

`charon@swift-syntax` **installs**, and the run that first did so is what fixed the paths the recipe
copies and the rule includes. With a target-scoped `swift build`, SwiftPM writes each module's
`.swiftmodule` and its object **flat** in the scratch path's `release/`:

```
$STORE/s/swift-syntax/<version>/<digest>/lib/swift/host/SwiftSyntax.swiftmodule   <- the rule's -I
$STORE/s/swift-syntax/<version>/<digest>/lib/SwiftSyntax.o                       <- the rule links it
```

Three things are **not** there, and the recipe looked for all three before that run: no `Modules/`
subdirectory under `release/`, no `.a` archives (a target-scoped build links no library product), and
nothing under `release/PackageFrameworks`.

And each `X.swiftmodule` is a **directory**, not a file — `SwiftSyntax.swiftmodule/` holds
`arm64-apple-macos.swiftmodule` with its `.abi.json` and `.swiftdoc` beside it. `os.files("*.swiftmodule")`
returns none of them, so a copy step written with `os.files` copies nothing at all; the recipe uses
`os.filedirs` for the modules and `os.files` for the objects, and copies the modules whole. The `release/` directory held **19 `.swiftmodule` files**
and **21 objects** — the twelve the package's module list names, plus the versioned
`SwiftSyntaxNNN` modules SwiftPM emits alongside them, which are the same sources under their
release names and which a consumer may equally import. The recipe copies all of them and **raises**
if the directory holds neither a module nor an object, so a product that moves again is a refusal
with a message rather than an install that installed nothing.

The install also leaves `lib/pkgconfig/swift-syntax.pc`, `manifest.txt` and `references.txt`, and its
own `build/` scratch beside them; only `lib/` and `share/` are the package's interface.
