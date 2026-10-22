# Reuse: what was compared against, and why it was or was not taken

The reviewer brief's rule (owner, 2026-09-28): a delivery names the open upstream it took from, or
"searched: none" with the queries. This is that line for `revenant@activitykit`.

**searched: none**, with the queries and their results in
[AppIntents' reuse line](../../AppIntents/AppIntents/Reuse.md): the fleet diff there covers all four
package directories, this one included, and the repository search found no open implementation of the
framework.

**What this module does reuse**, so the line is not read as "wrote everything from nothing":

* **`revenant@swift-runtime`** — the runtime a port carries; the recipe declares it, and
  `toolchain/modules/apple/swift.lua` supplies the compile flags rather than this package re-deriving them.
* **`revenant@appintents`** — for `LocalizedStringResource`, which the Swift target probes for and this
  release's Foundation does not have, and which therefore comes from the AppIntents module. Nothing
  here reimplements it.
* **Apple's own `.swiftinterface` and the toolchain's `swift-api-digester`** — as the reference for
  the declarations and the measurement. Nothing from either is vendored, and there is no host
  differential: ActivityKit exists on iOS only, so the check is the ledger against the digester's dump
  of the module built for `armv7-apple-ios6.1.3`, not a run on a host.
