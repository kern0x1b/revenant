# iOS 6.1.3: mediaserverd deadlock and the runner that never started

Two independent faults kept 6.1.3 from being a usable image. Both are fixed; neither fix patches a
guest binary.

## 1. mediaserverd deadlocked on the emulated iPhone 4S

Symptom (iPhone4,1 10B329 only): SpringBoard up, no fatal, but crash reports
`mediaserverd: RPCTimeout ... 'FigPlayerRemoteCreate'`, `'InitializeSystemSoundPorts'`,
`'AudioSessionSetProperty'`, and mediaserverd killed and restarted every few minutes.
iPhone4,1 6.0 and iPhone3,1 6.1.3 were healthy. The recipe's package and the lab build behaved
the same, so it was not the JIT.

How it was found (all in mediaserverd, lab build `shade/build-diag`):

- `threads mediaserverd` through the control pipe, with the thread ids and r0-r3 the dump now
  prints: the main thread waited in `psynch_mutexwait` on a CoreMedia mutex owned by thread 4;
  thread 4 waited on VirtualAudio's state lock owned by the main thread. The mutex words (read with
  the gdb stub) showed both locks genuinely held, so it was an ABBA deadlock, not a lost wakeup.
- `--watch-address` on the lock's owner field, with the writer's frame chain: the main thread took
  the lock in `FigMediaServerStart` -> `pthread_once(FigPlayerCMSessionOneTimeInitialization)` ->
  CoreAudio -> VirtualAudio+0x5b446 and never released it.
- gdb breakpoints on every Lock/Unlock site of that lock in VirtualAudio: none of the unlock sites
  ran; `ProcessRouteConfigurationChange` threw `'nort'` at +0x1185c. The function holding the lock
  has no unwind cleanup for it, so the exception leaked it.
- A breakpoint on the plug-in's own logger (+0x89d20) reading its arguments from guest memory gave
  the error trail the plug-in never got to syslog: `copyAudioVocoderInfo` failed (the offline modem;
  harmless, 6.0 has it too), then `PV_GetInputStreamID: "The HAL returned input stream size of 0"`,
  then `ClearRouting: "could not get voice device"`.

Cause: VirtualAudio in 6.1.3 (AudioDriverPlugIns 404.20; 6.0 has 403.1 without this check) requires
the Voice IOAudio2 device to have an input stream. The emulator's catalog described Voice as a
stream-less routing endpoint.

Fix: Voice is now what a real iPhone 4S on 6.1.3 publishes (registry read on the device with
IORegistryEntryCreateCFProperties): input stream 100, output stream 200, 8 kHz stereo 16-bit
current, 16/20/24-bit at nine rates, I/O buffer 3072, latencies 12/13, safety offsets 48, selectors
300 (data source), 301 (destination, with its property selectors) and 302 (clock). The catalog model
gained per-device latencies/safety offsets and a control's property selectors; other devices keep
what they published. Lab: shade `lab/shared-image` e32dd8a. Charon: branch `shade-613`,
`voice-device.patch`.

Result, iPhone4,1 6.1.3, 600 s: mediaserverd starts once, no crash reports (package without the fix:
three starts, five RPC timeouts). iPhone4,1 6.0 unchanged.

The real device has six IOAudio2 devices (AppleBasebandAudio, Voice, Baseband Voice,
HighlandParkAudioDevice, AppleEmbeddedAudioDevice, AppleUSBMike). Since shade `lab/shared-image`
a97ce3a and 48e4e2e the iPhone 4S profile publishes all six as the dump shows them (the codec
as CS42L63 with streams 100/200 and its 25 controls 300-373; Baseband with 766-frame latencies
and its seven formats; no transport type on built-in devices; clock domain 'I2Sm'). Other models
keep the generic "Built-in Audio" and "Baseband". A comparator of the catalog against the dump
reports no differences. What the model still publishes differently: `buffer mapping options` on
every stream and `controls` = [] on Baseband and USB (the drivers publish neither key),
`exclusive access owner` (runtime pid on the device), and the registry order (the codec comes first,
the device lists it fifth). How the HAL sets the codec's input multi-selector (control 350) is not
known; it is not set during boot.

A pre-existing report on iPhone4,1 6.0 and 6.1.3, with or without these changes (f26e74e):
assistantd, `mediaserverd: RPCTimeout ... 'AudioSessionSetProperty'`, about 50 s into boot;
mediaserverd itself starts once.

## 2. The test runner never started on any 6.1.3

Symptom: a runner job in `/System/Library/LaunchDaemons` starts on 6.0 and never on 6.1.3, on any
device; the run ends without a verdict. This is what made `/usr/bin/true` "hang for 900 s" (which,
besides, does not exist on stock iOS 6: spawn fails with ENOENT).

Cause: iOS 6.1 launchd takes the system jobs from a prebuilt cache,
`/System/Library/Caches/com.apple.xpcd/xpcd_cache.dylib` inside the dyld shared cache. At boot it
only `stat`s the plists that cache lists (332 stats = 166 plists x 2, no open); a plist added to the
folder is never enumerated. Stock launchd does not read `/Library/LaunchDaemons`, and
`launchctl load` of a plist outside the cache is dropped after its `stat`. A device behaves the same.

Fix: `/etc/launchd.conf` is still read by launchctl at boot on 6.1.3, and its `bsexec` subcommand
starts a program without a job plist:

    bsexec .. /usr/local/libexec/charon-runner SECONDS PROGRAM [ARGS...]

The runner starts at about 4 s and writes its verdict. Charon's `modules/emulator.lua` installs its
runner as `System/Library/LaunchDaemons/org.charon.emulator.runner.plist` and so has the same
problem on 6.1.x; the change there waits for launchd.conf to be checked on 5.x/4.x/3.x.

## Tools this added

- `threads` dump: `tid=` (what thread_selfid returns, i.e. a mutex owner) and r0-r3.
- `--watch-address`: the writer's frame chain.
- `scripts/enable-syslog.sh` now starts syslogd with `-bsd_out 1` and creates the file (it did
  neither before). Guest messages still did not reach the file in these runs; not yet understood.
- `boot.sh` takes `HOST_CACHE=` for a clean host cache.
