# Coordination: restarting the whole effort from nothing

This file exists so that one fresh session, given nothing but this file, can rebuild the team,
pick up every thread and keep coordinating. Read it top to bottom before doing anything else.
It is the handoff document; `AGENTS.md` is the contributor guide and stays the map of the code.

Paths use `$HOME`. No credentials, addresses or personal paths belong in this file, ever.

## 1. What is being built, and the order of importance

Modern iOS APIs are backported onto **armv7 / iOS 6.1.3** (iPhone 4S, iPad 2) so that current
64-bit App Store applications run unmodified. The long goal is every current application; the
proving ground is the **official Telegram**, recompiled and running on a 4S.

Priority, highest first:

1. **The Telegram port.** Anything blocking it outranks everything else.
2. Backports that live applications actually reach (demand-driven, never speculative).
3. Everything else.

## 2. The rule that overrides every other judgement

**"It did not exist in iOS 6" is a description of the task, not a reason to refuse it.**

By that logic there would be no Swift runtime, no Metal over ES2, no Vision — all of which now
work. A backport is the act of building what is missing.

- **Default: implement.**
- `documented-absent` is permitted **only at a wall we physically cannot reach** — a remote Apple
  service, an authentication we are locked out of, hardware that is not in the device. Even then
  the **API surface still exists** and everything not depending on the wall is implemented; the
  honest refusal happens only at the seam.
- `absent` for a **strong-imported class symbol is forbidden** — that is not a missing feature,
  that is dyld killing the application at launch.
- Never a silent fake. A quietly-different answer is the most dangerous outcome there is, worse
  than an honest refusal, because nobody can see it.
- An API must never crash the caller. Missing or hardware-gated: present, and honestly says
  "unavailable" — the way a device without the hardware answers.

## 3. How work flows

Bands produce patches. **Only the coordinator merges and pushes.**

1. A band works in **its own worktree** (`git -C $HOME/Git/projects/ios/revenant worktree add <path> -b <branch> origin/main`).
   The shared checkout belongs to the coordinator; a band editing it corrupts the coordinator's gate.
2. The band runs the full package gate itself, then sends `git format-patch` output with: the base
   commit, what is inside, which checks ran, and honest caveats.
3. The coordinator applies with `git am -3`, runs light-guard, runs the **full gate**, and pushes
   only on green. Every claim in the patch is re-verified here; a band's own gate is not enough.
4. After each push the coordinator regenerates the registry export the demand engine reads.

Gate: the skill `backports-gate` (`.agents/skills/backports-gate/SKILL.md`) — light guard, full
gate, release split, how to read the verdict. Merge: the workspace skill `patch-merge`
(`$HOME/Git/projects/ios/.agents/skills/patch-merge/SKILL.md`). `build-gate.lua` takes the
checkout as argument three — **never hardcode the path**.

**The tree is frozen while a gate runs on it.** `build-gate.lua` reads the checkout live, so a patch
applied mid-run makes the result meaningless in both directions: it can fail on state the build never
saw, and it can pass work the checks never reached. Patches that arrive during a gate wait for the
next stack. Paid for twice on 2026-09-23.

**Two blind spots of this gate, both measured, both to be covered by other means:**

- It checked only classes and method-shaped spellings against what is built, so a **constant or plain
  C function** registered but not carried — or carried but not registered — passed green. Fixed
  2026-09-23; the detector now also tests `found.symbols`. It was blind twice before that, so a green
  gate from earlier in the tree proves less about constants than it looks.
- Its release-split check works on the **coarsened grid of band points**, not per symbol, so a
  registry entry wrong by a whole release boundary can pass. Cover it with
  `xmake l tools/release-split.lua <dir-with-compiled-objects>` — a **mandatory step after a
  successful `build()` and before `write_deb()`**. It walks every exported symbol through the cache
  ladder and names the first release that exports it. Known blind spot of its own: a **category** has
  no `nm`-visible symbols, so a clean result says nothing about category files — measure those by
  direct selector-string search against the caches, with a negative control.

## 4. The bands

Each is an independent session with its own worktree. Domains do not overlap.

| Band | Domain |
| --- | --- |
| Backports · iOS 7–10 | UIKit and Foundation, APIs introduced 7.0–10.x; the release-ladder tools (`release-split.lua`, `introduced_in()`) |
| Backports · iOS 11–12 | same, 11.x–12.x, and AVKit 11+; also owns canon builds, test-suite health and the demand engine's LAUNCH-BLOCK ranking |
| Backports · iOS 13–14 | same, 13.x–16.x; the gate's category check |
| Backports · frameworks | AVFoundation, AVKit before 11, CoreMedia, VideoToolbox, CoreSpotlight, MediaPlayer, Security, Metal, CoreImage, ImageIO, CoreVideo, QuartzCore, CoreTelephony, Accelerate, GameController, Intents, FileProvider |
| Backports · fixes by review of main | JavaScriptCore: JSContext, JSValue, JSVirtualMachine, JSManagedValue and JSExport over the release's own C API (`facts/JavaScriptCore/JSContext.md`) |
| Backports · SceneKit/PassKit/Speech/ReplayKit | those four frameworks, including a real `SCNView` renderer for Telegram |
| The toolchain: app launch in the emulator | `xmake emulate launch`, the guest tools it needs, and the `revenant@swiftui-uikit` package |
| Telegram from source | the official Telegram built from its own source with this toolchain; no stubs, no recompiler |

Photos, CallKit and Contacts are closed; their facts files describe what was carried. A closed
domain is reopened by a new band, not by a stray patch.

The demand engine **does not decide**. It produces evidence; the coordinator issues verdicts.

## 5. Traps that have already cost us time

Every one of these was paid for once. None of them is theoretical.

**Measurement**

- A list saying an API is missing is **not evidence**. Before writing code, grep the tree. Five of
  six "top demand" rows were already implemented; later 76 of 140 symbol rows were false.
- A **one-off script that bypasses the verified pipeline** is more dangerous than a bug in it: a bug
  shows up in the numbers, a bypass does not.
- "Found in the tree" and "not found in the tree" are claims of different strength. Not found is
  reliable. Found must be read: a declaration, a synthesised property and `@dynamic` all look like
  an implementation until you open the file. **`@dynamic` is evidence of absence.**
- An explicit registry decision (`absent`/`ignored` with a reason and a facts file) **outranks** a
  find in the tree. The tree decides only where the registry is silent.
- A protocol's status must not be pushed onto a member that implemented classes provide. "Protocol
  absent" means we do not carry the protocol, not that the member is missing.
- Proving absence requires a **control**: show the probe finds something you know is there,
  otherwise "found nothing" may mean the probe is broken.

**Tests**

- A test that fails to link dies silently under `set -eu` and is indistinguishable from one nobody
  ran. One such test hid 76 groups for a day while looking healthy. Run `sh tests/backports/host/run-all.sh`.
- After reviving a dead test, do **not** declare it healthy — run it fully and look for regressions
  that accumulated while it was blind.
- Compiling under Mac Catalyst is **not** proof it builds: the real package build is stricter.
  Catalyst is a **behaviour oracle**, not a build check. It works here: the Command Line Tools'
  `MacOSX.sdk/System/iOSSupport` carries `UIKit`, and the host tests under `tests/backports/host/`
  are built and run as Catalyst probes. Other oracles: `objc.inventory`/`dyld.load` against the
  release's real armv7 cache for statics, `xmake emulate` on an armv7 guest, and a real device.
  The emulator's audio is unverified; anything needing AudioSession may fail there with
  `kAudioSessionNotInitialized`, which reads like a code error and may not be one.
- Before disassembling a firmware cache, check whether the host answers. When the host diverges for
  a known reason, name the divergence and make the test fail if it ever stops diverging.
- The header can be wrong. Where the header and the running system disagree, follow the system and
  record the divergence.
- A backport whose behaviour can differ on the device (UIKit, graphics, media, anything a macOS host
  answers differently) is not done on a host run. Hold it to the most faithful target that can
  answer: a real device, `xmake emulate` where hardware is not needed, the host only as the floor.
  Until the device run is green the patch says **device-unverified** in its caveats. Rebuilding or
  downloading what that run needs is worth the disk.

**Registry**

- `ignored` ("the release does this itself") is valid only if the **protocol itself exists** in the
  release. No protocol, no `ignored`.
- One release per object file, or `check_registry` fails.
- `@dynamic` is required for readonly properties added onto a real SDK class, otherwise the
  compiler synthesises a getter and the strict check fails.
- JSON indentation is **not uniform** across registry files. A script that reprints a whole file
  produces thousands of lines of noise. Patch lines in place.

**Build and devices**

- Hard-linking a clone of the xmake store carries the `*.lock` files with it and the flocks stay
  shared: run `find "$XMAKE_GLOBALDIR" -name '*.lock' -delete` after cloning.
- Never point `add_repositories` at the shared checkout — xmake may `checkout`/`reset --hard` in it.
- `add_addons("revenant latest")` fetches the newest **tag** from GitHub; a hand-placed `latest`
  directory is never picked up. The real lever is `add_repositories` on the main tree.
- Before building the canon, diff `toolchains`, `includes` and `rules` against the addon tag; if
  they moved, the canon will be built with a foreign toolchain while the recipe looks correct.
- `xmake device claim` is mandatory and a failed claim means stop. Devices are shared; hold briefly.
- A tunnel's **port number means nothing** — check which UDID it serves (`ps | grep iproxy`).
- Launching an application does not guarantee it is frontmost; verify before sending touches.
- Only `revtouch tap X Y` (in points) delivers a touch; the other tool reports success and nothing
  arrives.
- Never remove the Swift runtime or libc++ packages — the Telegram port runs on them.
- Install the canon with a clean `dpkg -i` only. Never unpack by hand, never delete the top-level
  symlinks: the postinst recreates them.
- When a crash makes no sense, **take your own debugging scaffolding off first** and re-measure.
- Do not fix a hypothesis before the measurement. Silence and a crash are different symptoms and
  point at different causes.

## 6. Reporting

Honesty is a hard requirement, not a style.

- Say what was measured and what was reasoned. Never let a claim of a device run stand for a run
  that did not happen — that has happened here and had to be corrected afterwards.
- Report the user-visible fact first. "The crash is gone and the tab switches" is not the same as
  "the screen works", and presenting the former as the latter is misleading even when every
  sentence is true.
- Retract your own earlier conclusions out loud when they turn out wrong, and say what caused them.
- Caveats belong in the facts file, not in the author's head.

## 7. Restarting from nothing

1. Read this file and `AGENTS.md`.
2. `git -C $HOME/Git/projects/ios/revenant fetch origin && git log --oneline -5` — see where main is.
3. Create the coordinator's own merge worktree; never merge in the shared checkout.
4. The gate scripts are in `$HOME/Git/projects/ios/coordination/`; gate the merge worktree by passing it
   as argument three (skill `backports-gate`).
5. Bring up one session per band from the table in section 4 — workspace skill `band-launch`.
6. Bring up the demand engine and have it re-certify **through `tools/corpus/verify.py`** before anything
   is handed out. Nothing goes out any other way.
7. Ask the Telegram port for its current blocker and route it first.

## 8. Where state lives

- Code and registry: `$HOME/Git/projects/ios/revenant`, branch `main`.
- The canon package and its checksum: the shared canon directory under the system temp path,
  rebuilt from current main by the iOS 11–12 band; one file only, older ones removed.
- Demand engine artefacts (ranked demand, decisions, verifier): its own worktree scratchpad plus
  `tools/corpus/verify.py` in the repository.
- The runtime window: `deliveries/45-runtime-window/`, an atomic bundle, **held until the owner
  says otherwise**. Its patches must never be merged individually.
