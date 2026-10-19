# os_signpost, over this port's own os_log

`os_signpost` arrived in iOS 12 and it is a software subsystem, not hardware and not a service: an
application says "this interval began" and "it ended", with a name, and the system shows the
intervals in Instruments. The armv7 6.1.3 cache exports **none** of it — `_os_signpost_emit_with_name_impl`,
`os_signpost_enabled`, `os_signpost_id_generate`, `os_signpost_id_make_with_pointer` are all absent —
while this package has carried the log it sits on since 6.0 (`facts/Foundation/OSLog.md`,
`registry/Foundation/oslog.json`, `Foundation/OSLog9.m` and `OSLog10.m`).

## Four functions carry the family

Everything else in `signpost.h` is a macro over these four, so carrying them carries the whole family:
`os_signpost_interval_begin`, `os_signpost_interval_end`, `os_signpost_event_emit`,
`os_signpost_emit_with_type` and the `_os_signpost_emit_with_type` shape all end at
`_os_signpost_emit_with_name_impl`, and the two id sources and the enabled check stand beside it.

- **`os_signpost_enabled` answers true, and that is load-bearing.** The header's own macro is
  `if (os_signpost_enabled(_log_tmp)) { … } __extension__({})` — an answer of `false` compiles the whole
  emit away, so a family that answered false would record nothing and the metrics over it would be
  empty by construction. The port's log records what it is handed at fault and above and keeps every
  signpost interval, so a mark is always worth making.
- **The two id sources stay apart**, and the way they are kept apart is *this port's own convention,
  not the header's requirement** — which the review of this series measured and corrected. `os/signpost.h`
  says a `uint64_t` "can be cast directly" if it uniquely identifies the begin/end pair, names only
  `OS_SIGNPOST_ID_NULL` and `OS_SIGNPOST_ID_INVALID` as reserved, and says a generated value "is
  guaranteed to be unique within the matching scope". There is no high bit anywhere in it. An earlier
  version of this file claimed the header drew the distinction with the high bit, and the port set it;
  the host does not: `os_signpost_id_generate` on the host answers `0x0000000000000001`, the bit clear,
  and `os_signpost_id_make_with_pointer` does not mask a high bit either (measured twice, once with a top
  bit already clear and once with it set, `0x8db22e1cc60a6dac`). **The port now follows the host on the
  bit** — a generated id counts up from 1 with it clear, and nothing is masked off a pointer's address.

  What the test then found is the *other* half of the same function, which the header settles on its own
  words: "Mangles the pointer to create a valid os_signpost_id, **including removing address
  randomization**." So a pointer's id is **not** the pointer, the host's round trip fails too, and the
  review's "0x8db22e1cc60a6dac unmasked" is consistent with that rather than with an identity. The
  header's own `@result` names only two failures — `OS_SIGNPOST_ID_NULL` when signposts are turned off and
  `OS_SIGNPOST_ID_INVALID` for a system-scoped log — and **a NULL pointer is not one of them**, so the
  port's earlier "a NULL pointer is `OS_SIGNPOST_ID_NULL`" was an invention the header does not license.
  The port now mangles the address the only way it can, clearing the low three bits (where an arm64 malloc
  writes nothing) and ORing in its own bit so a pointer's id cannot be mistaken for a generated one, and
  what the test compares is what the header promises: a valid, stable id that is not one of the two
  reserved values.
- **The emit records.** An interval begin remembers a monotonic reading under its id, an interval end
  takes the difference and keeps it with the name and the subsystem and category of the handle it was
  marked through, and an event is kept at zero length. That store is what MetricKit's signpost metrics
  are read out of (`facts/MetricKit/MetricKit.md`), so a mark an application makes is measurable
  afterwards — which is the difference between carrying the family and stubbing it.

## How another of this package's libraries reaches the store

Not by a link. Measured on a built `libFoundationBackports.dylib`: it exports **six** `os_log*`
symbols and **zero** `charon_`-prefixed C symbols and zero `Charon*` classes, and the registry lists
**no** name beginning with `charon` — a library of this package exports only the names the registry
lists, and the registry lists only names an SDK header declares. So there is no name of ours that
another of our libraries can link, in either direction, and a first attempt at two C functions across
the boundary failed at link with exactly that:

```
Undefined symbols for architecture armv7:
  "_charon_signpost_intervals", referenced from: _CharonSignpostMetrics in MXMetricManager.o
```

MetricKit therefore looks the store up by its own name with `NSClassFromString` and messages it,
once, behind a `respondsToSelector:`. That is the port's own idiom for a class in another image —
`NSClassFromString` in `AVFoundation/AVCaptureDevice+Authorization.m`,
`CoreSpotlight/CSSearchableIndex.m` and `CallKit/CharonCallAudio.m` — and it costs one string lookup
per process.

## The snapshot pointer

MetricKit's private header (`MXSignpost_Private.h`, whose own comment says the header must be public
to let clients compile properly) appends a public `signpost:metrics` field to every signpost it emits
and passes `_MXSignpostMetricsSnapshot()` as that field's one argument. So the pointer is not an
address and nothing: it is the snapshot the metrics came from, carried on the mark itself. The port's
emit path records that pointer on the interval it takes, so the signpost the application marked and the
snapshot the metrics are read from are the same fact.

## The host differential, and the one part of it that does not run

`tests/backports/host/signpost` compares the three answers a caller reads: whether signposts are
enabled — the header's own emit macro compiles the whole call away when this is false, so it is not a
small answer — the ids from both sources, and the reserved-value rule. Its three mutations are the
enabled answer, the id counter, and the recorded duration.

**The end-to-end interval is not covered, and the reason is measured.** The case wants to mark an
interval the way an application does, with `os_signpost_emit_with_type`, and that path packs the format
through `__builtin_os_log_format` (trace_base.h:94) — and that builtin faults under this host build
(`lldb`: `_platform_strlen`, `EXC_BAD_ACCESS` at `0x7fffffff7ffffff0`) before any code of the port's
runs. So the store's check is limited to the store being present and empty, and the two mutations of its
arithmetic are what holds it. An interval marked end to end is the next thing to fix in this family.
