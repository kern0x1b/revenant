# iOS 6.1.3 under the emulator

Three faults kept 6.1.3 from being a usable image. All are fixed, and none of the fixes patches a guest binary.

## The backboardd crash loop was stale JIT code

On every profile, 6.1.3 stopped with backboardd dying at a register value that could not come from its own code.
backboardd loads its HID plug-ins in sequence. MultitouchHID is unmapped and AutoBrightness is mapped at the same
base, and the JIT kept executing the blocks it had translated for MultitouchHID. The invalidation of the unmapped
range found one block out of 589 that it covered: Dynarmic's `equal_range` over the block map returns the first of
several overlapping blocks only. The patch in `packages/d/dynarmic` walks the map from the start of the range
instead. After it, backboardd stays up and SpringBoard launches (about 92 s on an iPhone 4S).

The same lookup is wherever Dynarmic invalidates a range that holds more than one block: dlclose and dlopen at one
address, or self-modifying code that rewrites a page.

## mediaserverd deadlocked on the emulated iPhone 4S

On iPhone4,1 with 10B329, mediaserverd timed out in its RPCs (`FigPlayerRemoteCreate`,
`InitializeSystemSoundPorts`, `AudioSessionSetProperty`) and was killed and restarted every few minutes. The cause
is the VirtualAudio plug-in of 6.1.3, which requires the Voice IOAudio2 device to have an input stream. The catalog
had described Voice as a stream-less routing endpoint. The plug-in threw in `ProcessRouteConfigurationChange`, and
the function holds no unwind cleanup for its state lock, so the exception leaked the lock and the threads deadlocked.

The fix is to publish Voice as a real iPhone 4S on 6.1.3 does (read from the device's registry): input stream 100,
output stream 200, 8 kHz stereo 16-bit as the current format with the other formats listed, an I/O buffer of 3072
frames, latencies 12 and 13, safety offsets 48, and the selectors 300 (data source), 301 (destination) and 302
(clock). The catalog takes latencies and safety offsets per device; the other devices keep what they publish.

The iPhone 4S profile now publishes all six of the device's IOAudio2 devices as the dump shows them. Still different
from the device: the buffer mapping options on every stream, the empty controls of Baseband and USB, the exclusive
access owner (a runtime pid on the device), and the registry order. How the HAL sets the codec's input
multi-selector (control 350) is not known, and it is not set during boot.

On iPhone4,1 6.1.3, a 600 s run starts mediaserverd once with no crash report. Without the fix, the same run starts
it three times and records five RPC timeouts.

## The test runner never started on 6.1.3

On 6.1.3 a LaunchDaemon added to `/System/Library/LaunchDaemons` never starts. iOS 6.1 launchd takes the system jobs
from a prebuilt cache, `xpcd_cache.dylib` inside the dyld shared cache. At boot it only stats the plists that cache
lists, so a plist added to the folder is never enumerated, and `launchctl load` of a plist outside the cache is
dropped. A device behaves the same.

`/etc/launchd.conf` is still read at boot on 6.1.3, and its `bsexec` subcommand starts a program without a job
plist:

    bsexec .. /usr/local/libexec/revenant-runner SECONDS PROGRAM [ARGS...]

The runner starts at about 4 s and writes its verdict. The toolchain's emulator module installs its runner as a
LaunchDaemon, which has this problem on 6.1.x; that change waits for the same `launchd.conf` check on 5.x, 4.x and
3.x.

## Tools this added

- The `threads` dump prints each thread's `tid=` (what `thread_selfid` returns, the owner of a mutex) and r0 to r3.
- `--watch-address` prints the frame chain of the writer of a guest address.
