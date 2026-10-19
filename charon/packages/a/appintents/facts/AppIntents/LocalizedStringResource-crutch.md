# The crutch, and what the native fix is

**The crutch.** `charon@appintents` **carries** `LocalizedStringResource` for the ports on these
releases: the type is the module's, `Sources/AppIntents/Module.swift` declares it when
`CHARON_APPINTENTS_CARRIES_LOCALIZED_STRING` is defined, and the recipe defines that flag when its
probe finds the type in the runtime (`xmake.lua:118-133`). It is open in `coordination/crutches.md`
and it is only closed by a **native** fix merged into main.

**Which piece is missing, and what the native fix is.** `LocalizedStringResource` is a **Foundation**
type — iOS 16 / macOS 13 — and it is not in the runtime's Foundation overlay. The overlay is
`charon@swift-runtime`'s, and the runtime lowers each overlay file's availability marks with two
mechanisms, both named in its own recipe (`packages/s/swift-runtime/xmake.lua`): a blanket strip for
every file not in `still_ios7` (`:34`, `:463`), and a per-file rewrite for the files in
`lowered_with_backports` (`:42`, `:467`) which lowers each `iOS 7…11` mark to the port's release and
leaves the rest. **The native fix is to add the file that declares `LocalizedStringResource` to that
overlay and to name it in the second list**, so its marks come down the way `URLComponents.swift`'s and
`DateInterval.swift`'s do. What it would carry is the type and the spellings the ports use
(`LocalizedStringResource("…")`, the `table:`/`bundle:`/`comment:` initialisers, the
`ExpressibleByStringLiteral` conformance, the `String` initialiser). What it needs to build is what
every other overlay file needs: swift-corelibs-foundation's `Localization.swift` compiled against the
runtime's **port** Foundation headers, for the port's architecture and oldest release, with the
backports linked — and, per that recipe's own comment, each mark the backports do not carry has to be
lowered *or the compiler refuses the file*, which is how the current lists were found: "Found by
building without the marks and reading what the compiler refused."

**It is not this band's work, and it cannot be done now without colliding.** The Foundation Swift
family — `Measurement`, `AttributedString`, `LocalizedStringResource`, `Calendar.RecurrenceRule` — was
assigned to **another band** on 2026-09-28, and the file and the recipe are `charon@swift-runtime`'s.
So the crutch stays open, and the one thing I can usefully hand over is the **input** to that work, not
the work: the exact recipe lines, the two mechanisms, and the finding that **no installed runtime
carries the type** (measured: every `…/lib/swift/iphoneos` in the store has zero hits for
`LocalizedStringResource`), so it is not a question of finding an older build that has it.
