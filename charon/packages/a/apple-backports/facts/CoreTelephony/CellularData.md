# CTCellularData, iOS 9

The crash-exposure row that reopened CoreTelephony: the corpus's demand index had been silent on
the whole framework because this SDK carries no CoreTelephony umbrella header for it to read, and
fixing that surfaced `telegram` calling `CTCellularData` directly (rank 222) and two of its members
(`cellularDataRestrictionDidUpdateNotifier`, `restrictedState`). `CTCellularData` reports a
cellular-data *restriction* state, not a radio *technology* - unlike
`serviceCurrentRadioAccessTechnology`'s real single-radio wall
(`facts/CoreTelephony/CTRadioAccessTechnology.md`), there is no hardware boundary here: the
iPhone 4S has a real cellular radio, and the only real question is how 6.1.3 expresses a data
restriction.

## What the device has

iOS 6.1.3's own `CoreTelephony.framework` exports `_CTServerConnectionGetCellularDataIsDisallowed`,
`_CTServerConnectionSetCellularDataIsDisallowed` and `_CTServerConnectionCreate` - confirmed
present via `modules/apple/dyld.lua`'s `image_symbols` (not `strings` on an `extract()`ed copy,
which missed them; a second instance of the recurring `extract()`/`otool -oV` gap - the export
trie itself is fine, only the rebuilt file's own symtab confuses `otool`, so reading the trie
directly is what actually found these). Disassembling both with capstone against the raw cache
bytes gives their real signature, cross-checked against the real, public `CTError` struct
(`domain`/`error`, `CoreTelephonyDefines.h`) which the null-argument path in both functions writes
verbatim - `{kCTErrorDomainPOSIX(1), EINVAL(22)}` - confirming the reverse-engineered calling
convention rather than assuming it:

```c
typedef void *CTServerConnectionRef;
CTServerConnectionRef CTServerConnectionCreate(CFAllocatorRef allocator, CTServerConnectionCallback callback, CTServerConnectionContext *context);
CTError CTServerConnectionGetCellularDataIsDisallowed(CTServerConnectionRef connection, Boolean *disallowed);
```

`CTServerConnectionCreate` internally opens a Mach IPC connection to the CoreTelephony daemon
(disassembly shows a bootstrap-style port lookup before constructing the connection object); this
port calls it once, lazily, with a `NULL` callback and context, since it only needs synchronous
reads, not the daemon's own async delivery.

The release also exports a single Darwin notification, `"com.apple.coretelephony"` - confirmed
present as a literal string in the shared cache - which this release's own CoreTelephony code
posts on any state change it tracks (radio access, cellular data restriction, and others
undifferentiated at the notification level).

## What the port does

`-restrictedState` calls `CTServerConnectionGetCellularDataIsDisallowed` fresh every time (never
cached) and answers `kCTCellularDataRestricted`/`kCTCellularDataNotRestricted` only when the call
answers `kCTErrorDomainNoError`. Any failure - `dlsym` finding nothing, connection creation
failing, or the call itself returning an error - answers `kCTCellularDataRestrictedStateUnknown`,
never `kCTCellularDataNotRestricted`: an application that cannot have its real restriction state
measured is told exactly that, not told it is unrestricted.

`-setCellularDataRestrictionDidUpdateNotifier:` registers for the Darwin notification
`"com.apple.coretelephony"` on `CFNotificationCenterGetDarwinNotifyCenter()`. Every time it fires,
`restrictedState` is re-read and the stored notifier is only called if the answer changed from the
last known one - so a radio-access change or any other CoreTelephony event this single umbrella
notification also carries does not spuriously fire a cellular-data notifier for no reason. The
notifier is also called once immediately with the current state when set, matching real
`CTCellularData`'s own documented behaviour of an immediate first call.

## What is measured and what is not

The function signatures, the `CTError` convention and the Darwin notification name are measured
from the release's own binary, not guessed.

Measured 2026-09-23 on the iPhone 4S (6.1.3), `tests/backports/device/cellulardata.m`: the first
assumption this port carried - that `CTServerConnectionCreate` tolerates a `NULL` callback the way
the earlier host-only read of its disassembly suggested - was wrong. On real hardware the call
answers `NULL` for every combination that passes a `NULL` callback, whatever the context is, and
only succeeds once a real (even inert) callback function pointer is given. `CharonCTConnection` in
`CTCellularData9.m` now passes one; without this fix `restrictedState` answered
`kCTCellularDataRestrictedStateUnknown` on every read, not because the state was unknown but
because the connection was never created - the honest-`Unknown` guarantee was doing its job, but on
a wrong premise it never surfaced as a bug this port could see without a device. Fixed, the same
device now reads `kCTCellularDataNotRestricted` twice in a row with no error
(`CTServerConnectionGetCellularDataIsDisallowed` answers `domain=kCTErrorDomainNoError`,
`disallowed=false`), which is the value a 4S with no cellular-data restriction actually carries -
`restrictedState` no longer answers `Unknown` when the state is in fact known, closing the second
trap named for this task.

The notifier's own mechanism - Darwin notification registration on `set`, removal on unset, the
immediate first call, and the immediate call carrying the same state a direct read gives - is
confirmed on hardware. What is **not** confirmed, and could not be with the tools this pass had:
whether `"com.apple.coretelephony"` fires for a real cellular-data-restriction change, because iOS
6 carries no Settings UI for a feature introduced in iOS 9 to drive one through, and the one other
way to raise a real change - calling the daemon's own `CTServerConnectionSetCellularDataIsDisallowed`
directly - answers `kCTErrorDomainNoError` but silently no-ops: the same connection reads the flag
back unchanged immediately after setting it true, and no notification arrives. That is read as an
entitlement wall around the *write* path (CommCenter accepting the request from an unentitled
process without applying or erroring it, the way `CXProvider` answered `Unentitled` for CallKit but
this daemon answers success instead), not a defect in this port's notifier wiring - the read path
and the notifier's own mechanics are both confirmed working against the one real, known state this
device has to offer.
