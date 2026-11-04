# 0016: Swift overlays are self-contained

Status: accepted

## Context

A Swift overlay of a backported framework (`frameworks/Backports/src/Swift`, for example `swiftNetwork` for the
Network module) defines the public Swift API: classes, structs, enums and protocol conformances. On a release that
ships the same module, the system's Swift library defines the same types under the same mangled names.

A Swift value type has a layout and witness tables fixed by the module that defines it. The backport's `NWPath` or
`NWEndpoint` and the system's are different types with different layouts and witness tables, even when their names
and signatures match. A call that forwards one of their symbols to the other, or to a renamed copy of the backport's,
mixes the two representations, and that is unsound.

Each dynamic library has its own namespace under two-level namespaces, so the backport's `libswiftNetwork` and the
system's do not collide, and an app binds each symbol to the library it was linked against.

## Decision

A Swift overlay implements its API in Swift over the backport's own C and Objective-C layers, on every release,
including releases that ship the same module. It does not defer an individual Swift symbol to the system, and it does
not forward a symbol to a renamed copy of its own. The Network overlay's `NWPathMonitor`, for example, runs over
`SCNetworkReachability` on every release.

The `BACKPORT_IMPL` forwarders of the skeleton apply to C functions and to the data constants of the backports. They
do not apply to Swift symbols.

## Consequences

- A comparison of an overlay with the system's Swift exports on iOS 12 or later measures coverage, not a set of
  forwarding targets. The mangled names of two compilers differ in their details (old `$S` and new `$s` prefixes,
  witness-table names), so a raw set difference overstates the gap.
- A gap in an overlay is closed in the overlay, not by pointing the app at the system's symbol.

## Not enforced

No check reads the overlays for forwarding. A reviewer checks a new overlay symbol against this record.
