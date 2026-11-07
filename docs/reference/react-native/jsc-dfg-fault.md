# SIGBUS from JIT code on the Paseo bundle

The React Native host on JavaScriptCore can die with `fatal signal 10` (SIGBUS) while the Paseo bundle runs with the DFG
JIT enabled. This page records how to reproduce it, the fault record, the control runs, and what is still open. The
cause is not found yet; no patch is proposed here.

## Reproduction

The host is built with `engine=jsc` as in [Installing the host](../../guides/react-native/install-the-host.md), with the
Paseo bundle and these lines in its `rnhost.conf`:

```
module=main
bundle=bundle.js
engine=jsc
JSC_thresholdForJITAfterWarmUp=10
JSC_thresholdForJITSoon=10
JSC_thresholdForOptimizeAfterWarmUp=20
JSC_thresholdForOptimizeSoon=20
```

The `JSC_*` keys are set in the environment before the engine starts. The lowered thresholds move hot code into the DFG
much sooner than the defaults do.

1. Launch the host by bundle id and wait for `Running "main"` in its log.
2. Tap the welcome screen at (160, 352) to open the Direct connection sheet.
3. Tap the "Use SSL" checkbox at (35, 427) once a second, for about 20 taps.

The host dies during the checkbox taps, within the first few dozen seconds of them. The injector's commands are written to the application folder's
`rnhost.cmd` and answered in `rnhost.cmd.out` in the run folder. Send one tap at a time: a file that holds twenty taps starts
twenty touches at once, and `RCTIdentifierPool<17>::dequeue` loops forever when all seventeen identifiers are in use, which
hangs the main thread without a crash. That is an input artefact, not the fault below.

## Fault record

The handler prints the signal, the faulting address and the registers, then exits with 128 + signal.

| Field | Run 6 | Run 9 |
| --- | --- | --- |
| Signal | 10 (SIGBUS), si_code 1 | 10 (SIGBUS), si_code 1 |
| Fault address and pc | `0xe30a000` | `0xe31f000` |
| Region of the fault address | one page, `prot 0`, max 7 | one page, `prot 0`, max 7 |
| Region of the code before the fault | the engine's `__TEXT` at `0x3de2000`, size `0x2200000`, `prot 5` | JIT pool `0xc31f000`, size `0x2000000`, `prot 7` |
| Link register | `0x422a4d9`, in `JSObject::putDirectIndex`, after its call to `setIndexQuickly` | `0xdc05521`, in the pool (DFG code) |

The fault address is the pc, so the jump went to a page with no access. In run 9 that page is the first one after the
executable pool, which runs from `0xc31f000` to `0xe31f000`: the jump landed one byte past the pool's end. In run 6 the
link register sits in JSC's `putDirectIndex`, which calls `setIndexQuickly`, and the pool's frame comes further up the
chain. The pool base of run 6 is not measured; the value `0xc30a001` the register dump shows at the time suggests the same
layout.

In run 9 frames 2 and 3 of the backtrace are inside the pool, and the frames above them are JavaScriptCore helpers and the
host's JSC call path. The names of the frames outside the pool come from the stripped binary's nearest exported symbol and
are not reliable.

## Control runs

| Run | DFG | Thresholds | Taps after the sheet opened | Result |
| --- | --- | --- | --- | --- |
| 5 | on | default | 220 checkbox taps | no fault |
| 6 | on | lowered | checkbox taps from the first one | SIGBUS, pc `0xe30a000` |
| 8 | on | lowered | none, 25 s | no fault |
| 9 | on | lowered | 20 checkbox taps | SIGBUS, pc `0xe31f000` |
| 7 | off | lowered | none, 25 s | no fault |
| 10 | off | lowered | 20 checkbox taps | no fault |

Lowered thresholds with the DFG on faulted in 2 of 2 runs that tapped the checkbox. The same thresholds with the DFG off
ran 1 run with taps, without a fault, and the default thresholds with the DFG on ran 220 taps without a fault. The sample
is small: these are single runs per row, not a rate.

## Open

- The faulting jump is not identified. Its target is the pool's end; which code computes that target is not known yet.
- The patch stack has three places to look: patch 0006 relinks ARMv7 branches (`relinkJumpOrCall`, `linkJumpT4`); patch
  0005 adds `Ios6BlockReservationPool`, which hands out the JIT blocks; and patch 0007 restores the 32-bit DFG code that
  emits the calls.
- A next step that would settle it: assert in the ARMv7 link and relink paths that the target lies inside the JIT block
  that owns the branch, and print the offset of the failing call inside its code block, for the DFG code whose range
  contains the link register.
- Until then, `JSC_useDFGJIT=false` avoids the fault in these runs. Its cost on the steady state is not measured here.

The same injector is documented in [Driving a host by touch](../../guides/react-native/touch.md), which describes the
revenant copy that reads `/var/tmp/rnhost.cmd`. The host of the isolated build (`src/host`) reads the application folder's
`rnhost.cmd` instead, so the two copies differ, and the guide does not describe the one used here.
