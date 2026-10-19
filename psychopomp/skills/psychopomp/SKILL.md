---
name: psychopomp
description: The route for building a modern app for old iOS (iOS 5, 6, 7 and later; iPhone 3GS, 4, 4S, iPad, iPod touch; armv7) from an empty directory to a .deb for a jailbroken device or a Cydia repository, in Objective-C or Swift, SwiftUI and Combine included, with the Charon toolchain and the Shade emulator. Use at the start of any such request, to find which skill handles the current step, or when resuming a project that has a PROJECT.md.
---

# From an empty directory to a .deb

The journey has fixed steps, each with its own skill. Do them in order; each ends with evidence
written into `PROJECT.md` under `## Progress`. When resuming, read `PROJECT.md` and continue from the
first step without evidence.

| Step | Skill | Ends with |
| --- | --- | --- |
| 1. Interview | `init` | `PROJECT.md` with every decision, confirmed by the user |
| 2. Host | `install` | the tools and the Charon addon answer their checks |
| 3. Apple's files | `firmware` | the release's libraries and, for the emulator, its root filesystem on the user's machine |
| 4. Project | `project` | `xmake.lua`, `Info.plist`, resources, configured for the chosen release and architectures |
| 5. Code | `objc` or `swift` (with `combine`, `swiftui`), and `backports` for API newer than the release | the app's sources, written for the chosen releases |
| 6. Build | `build` | a green build log, imports checked against the release |
| 7. Check | `emulate`, `checks` | the verdict and the evidence from the emulator on the chosen device and release |
| 8. Package | `package` | a `.deb` and its dependencies, inspected |
| 9. Deliver | `device` and/or `cydia-repo` | installed on the user's device, or published in their repository |

When a step needs to understand or change the build itself, the `xmake-*` skills are the reference:
`xmake-basics`, `xmake-packages`, `xmake-objc`, `xmake-swift`, `xmake-rules`, `xmake-toolchains`,
`xmake-scripting`, `xmake-tests`, `xmake-troubleshooting`.

## Rules for every step

- **Write the app, do not copy it.** These skills are instructions. Never paste their text, their
  fragments strung together, or any file of this plugin into the user's project. Every file in the
  project is written for this app.
- **Nothing of Apple's goes into the project.** No firmware, no dyld cache, no SDK header or
  framework copied in, no Apple artwork. The build reads them from where Charon keeps them on the
  user's machine.
- **Native, or say it cannot be done.** Every change is the way the system and the stack intend
  it: public API or a Charon backport, never a private trick, a stub, a disabled check or a copied
  file standing in for a build step. Before a step's evidence goes into `## Progress`, follow the
  skill `self-review`; what cannot be done natively goes to the user and under `## Limits`.
- **Evidence, not belief.** A step is done when its check has run and its output says so. Record
  the command and the line that proves it in `## Progress`. A build that "should" pass has not
  passed; an emulator run that did not happen is not described.
- **Say what the stack cannot do.** If Charon, the emulator, the backports or Eidolon (skill
  `swiftui`) lack something the app needs, stop at that point and tell the user what is missing and where. Do not fake an API,
  stub a check, or switch the target release or device without asking.
- **Long commands are normal.** The first build compiles the toolchain's compiler and, for Swift, the
  Swift compiler from source: it can take hours. Run it with a long timeout, log to a file in the
  project (`.logs/`), and wait for it. Never kill a build to make it faster, and never force a rebuild.
- **The package store is shared by every project on the machine.** Never `xmake require --force`,
  never delete anything under `~/.xmake/packages`, never point `XMAKE_GLOBALDIR` somewhere private:
  a changed package is already a new install path, and a private store rebuilds everything from
  source.
- **Non-interactive xmake.** Pass `-y` to every `xmake` command that may prompt.
- **Keep the user's data private.** On a real device, read nothing that is not the app's: no
  messages, contacts, photos, accounts.

## When the user asks for something else

- An app for a current iOS release, the simulator or the App Store: this route does not apply; say so.
- A tweak or a daemon instead of an app: the same route, with Charon's `tweak` or `daemon` rule in
  place of `app` (skill `xmake-rules`); the interview still comes first.
