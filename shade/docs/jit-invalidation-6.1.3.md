# iOS 6.1.3: backboardd crash loop was stale JIT code

## Symptom

On every profile, 6.1.3 stopped at `boot-blocked(backboardd)`: backboardd died with

```
[cpu] fatal pid=23 cpu=0 pc=0x100ad496 lr=0x8 fault=0x3e4ccced access=0x1 size=0x4
      sp=0x2ffffb50 cpsr=0x80000030 r0=0x3e4ccccd r1=0x0 r2=0x44 r3=0xfffffffc r4=0x1082b600 ...
```

and was respawned by launchd, over and over, so SpringBoard never came up. 6.0 was unaffected.
The registers looked impossible: `r0` held `0x3e4ccccd`, which is the float constant `0.2f` that
`AABPlugIn::UpdateTimeConstantTable` writes into its table, and `pc` pointed at an address that is
not an instruction boundary in AutoBrightness.plugin.

## What was actually running

backboardd loads its HID plugins in sequence. In the guest:

```
[mmap] pid=23 address=0x100ac000 size=57344 prot=5 file=.../MultitouchHID.plugin/MultitouchHID
...
[mmap] unmap-executable pid=23 address=0x100ac000 size=57344
[mmap] pid=23 address=0x100ac000 size=32768 prot=5 file=.../AutoBrightness.plugin/AutoBrightness
```

MultitouchHID is unmapped and AutoBrightness is mapped at the same base. The JIT kept executing the
blocks it had translated for MultitouchHID: the faulting store went to `0x100ba8ec`, which is inside
MultitouchHID's `__DATA` but inside AutoBrightness's read-only `__LINKEDIT`. The "impossible"
registers are simply the registers of one image's code running against another image's memory.

## Why the invalidation did not help

The unmap does request an invalidation (`[mmap] unmap-executable` -> `Cpu::invalidate_cache_range`
-> `NativeCodeSlab::request_cache_range` -> `A32AddressSpace::InvalidateCacheRanges`). With a
temporary counter in the slab, the range `[0x100ac000, 0x100b9fff]` reported:

```
[slab] invalidate ranges=1 locations=1 first=0x100ac000
```

One block out of the hundreds translated from that 57 KB of code. `BlockRangeInformation::
InvalidateRanges` looks the blocks up with

```cpp
auto pair = block_ranges.equal_range(invalidate_interval);
```

`boost::icl::interval_map` orders intervals with an exclusive-less comparison. That comparison is
not a strict weak ordering once intervals overlap: every block inside the invalidated range compares
equivalent to the range, but the blocks are ordered among themselves, so the binary search behind
`equal_range` stops after the first equivalent node. A minimal check with the vendored Boost 1.71:
five blocks at 0x1000, 0x3000, 0x5000, 0x7000, 0x9000, a query interval covering all five ->
`equal_range` yields one node, a manual `intersects` scan yields five.

## Fix

Walk the map instead of trusting `equal_range`: start at `lower_bound` of a point interval at the
start of the invalidated range (which also catches a block that begins before the range and reaches
into it) and iterate while the node's first address is within the range.
`jit-repro/ranges.cpp` is the regression check: 1 of 5 before, 5 of 5 after, and a second pass finds
nothing left.

## Result

`[slab] invalidate ... locations=589` for the same unmap, and 6.1.3 boots:

- iPod4,1 6.1.3: no `[cpu] fatal`, backboardd spawned once, SpringBoard launched.
- iPhone4,1 6.1.3 (the owner's device release): no `[cpu] fatal`, backboardd spawned once,
  SpringBoard launched at ~92 s and reaches its icon-cache work at ~235 s.

## Scope

The defect is in `src/umbra/backend/block_range_information.cpp`, shared by the x64 and arm64
backends, and the same `equal_range` lookup is in azahar-emu/umbra master, so it is not specific
to the Shade fork or to this port. It only shows up when a range invalidation has to cover more than
one translated block - dlclose/dlopen at the same address, or self-modifying code that rewrites a
whole page.

## What 6.1.3 hits next

With the JIT fix, backboardd stays up and SpringBoard launches, but the guest does not reach the home
screen yet: the boot logo stays and SpringBoard is restarted every 100-200 s. The guest writes its own
crash reports, and they name the reason:

```
Exception Code: 0xbe18d1ee
Reason: mediaserverd: RPCTimeout message received to terminate [0] with reason 'InitializeSystemSoundPorts'
```

`/private/var/logs/CrashReporter` of a 900 s run also holds watchdog kills of Setup.app, MobileMail,
voiced, assistantd and mediaserverd clients, and `[signal] sent pid=23 target=... signal=9` shows
backboardd killing apps that do not finish launching in about 20 s.

None of it is a CPU or kernel fault: every one of these is a wall-clock timeout. The emulator paces
guest monotonic time 1:1 against host time (`RealtimePacer::allowed_device_monotonic_time`), so every
watchdog and every RPC timeout in the guest is a host-wall-clock timeout, and the guest is one to two
orders of magnitude slower than the device. The general answer is to let guest time run slower than
host time (a `--time-scale`), which covers the launch watchdog, the SpringBoard startup watchdog and
the fig/mediaserverd RPC timeouts at once, instead of holding a watchdog assertion per process.

Two smaller findings from the same runs: Setup.app still launches on 6.1.3 with the 6.0 purplebuddy
keys (`scripts/prepare-home.sh` needs the 6.1.3 variant), and the guest's own crash reports are worth
collecting in the factory's verdict, because they name the reason a process died.
