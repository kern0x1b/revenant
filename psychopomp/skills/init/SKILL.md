---
name: init
description: Interview the user about the app they want before anything is created — what it does, its screens and data, the iOS releases and devices, architectures, Objective-C or Swift, SwiftUI and Combine, frameworks and backports, identity, and where it is published — then write the decisions to PROJECT.md. Use first, in an empty directory, whenever someone asks for an app for old iOS (iOS 5, 6, 7, 9, armv7, iPhone 3GS/4/4S, iPad 2, iPod touch, jailbreak, Cydia), or when PROJECT.md is missing or incomplete. Reads answers.md first if one is present.
---

# The interview

Nothing is created before this is finished: no `xmake.lua`, no source file, no install. The output is
one file, `PROJECT.md`, that every later step reads. The approach is a design-tree interview (credit
at the end): the decisions form a tree, you ask in rounds, you recommend an answer to every question,
you look facts up yourself, and you stop only when every branch is settled and the user has confirmed.

## 1. Look before asking

- The directory: if `PROJECT.md` exists, this is a resumed interview. Read it, and ask only what it
  leaves open. If other files exist that you did not expect, ask what they are before touching them.
- `answers.md` in the directory: read it in full now. Match each answer to a node of the tree below.
  An answer settles its node; an answer that breaks a constraint in §3 does not, and becomes a question.
- Facts are yours to find, never the user's to supply: the host (`uname -sm`, `sw_vers`), whether
  `xcode-select -p`, `brew`, `xmake` exist, free disk (`df -h ~`), what the stack supports today (the
  tables in §3 and the skills `emulate`, `backports`, `swift`, `combine` and `swiftui`). Ask the user
  only for decisions.

## 2. Rounds

The **frontier** is every open node whose prerequisites are settled. Ask the whole frontier in one
round, then wait. A question that depends on another question still open this round waits for a later
round. After the answers, recompute the frontier and ask again.

One question, in this shape:

```
Q3 — Language: Objective-C or Swift?
<what depends on it, the options, the constraint that applies>
Recommended: <your answer and the one-line reason>
```

Number questions across the whole interview (Q1, Q2, … never restarting). Give options where the
answer is a choice. Keep a question to what the user can decide; never ask them to look something up.
If the environment offers a structured way to ask the user, use it; otherwise ask in plain text.

## 3. The tree

Prerequisites are in brackets. Recommendations must respect the constraints; if the user insists on
something the stack cannot do, say what fails and where, and ask again.

1. **Purpose** — what the app does in one sentence; its screens, each in one line; what the user does
   on each; the data it keeps; whether it talks to the network; gestures; notifications. Recommend the
   smallest first version that is still the app they asked for.
2. **Lowest iOS release** [1] — becomes `apple_minimum`. Constraints: no Swift was built or checked
   below 6.0 (skill `swift` §1); arm64 needs 7.0; armv7s needs 6.0; armv6 exists only up to 4.2.1; `weak` references need 5.0 (ARC
   below that needs the link flag the skill `project` gives). Each device has a highest release it
   can run: check the pair against the devices in node 4.
3. **Releases to check** [2] — which releases the app is verified on. The emulator boots only some:
   firmware from iOS 3.0 through 6.1.3 (Shade's README), and not every device and release pair in
   that range has been booted; iOS 7 is declared but has never been booted;
   iOS 8 and 9 cannot be emulated. A release outside that range is verified on a real device or not
   at all — say so in the question.
4. **Devices** [2] — by model identifier. Emulator profiles exist for `iPhone1,1`, `iPhone1,2`,
   `iPhone2,1` (3GS), `iPhone3,1` (4), `iPhone4,1` (4S), `iPod1,1`, `iPod2,1`, `iPod4,1`, `iPad1,1`,
   `iPad2,1`. Ask whether the user has a real jailbroken device and which. Screen: iPhone and iPod
   320×480 points (Retina on iPhone 4, 4S, iPod 4), iPad 768×1024 points.
5. **Architectures** [2, 4] — derive, do not ask unless it is a real choice: armv7 covers every device
   from the 3GS on; the original iPhone, the 3G and the first two iPod touch generations need armv6
   and a release no later than 4.2.1; add arm64 only for 64-bit devices on 7.0 and later.
6. **Language** [2] — Objective-C or Swift. Recommend Objective-C below 6.0 (no Swift was built or
   checked there), and for anything that must also build for arm64 (the whole Swift runtime was
   built for armv7 only). Before the user picks Swift, give them the choices of skill `swift` §1: at
   this pin `xmake deb` refuses the runtime a Swift app carries.
7. **Interface** [6] — UIKit in code, or SwiftUI (Swift only). There are no nibs or storyboards: the
   interface is built in code. Before recommending SwiftUI, check whether the pinned Charon provides
   Eidolon as a package (`charon@eidolon`, skill `swiftui` §1); if it does not, say so and recommend
   UIKit.
8. **Combine** [6] — only with Swift and its whole runtime; recommend it only when the app's data flow
   needs it, and say first what Styx lacks (skill `combine` §3).
9. **Frameworks and APIs** [1, 2] — list what the purpose needs (for example networking, storage,
   location, camera, maps). For each API introduced after the lowest release, look up whether the
   backports carry it (skill `backports`); the question is then "backport, or the older API?".
10. **Data, network, permissions** [1, 2, 9] — where data is kept (defaults, archive, plist, SQLite,
    Core Data), the servers it calls and whether they answer on that release's TLS, what the app
    asks the system for.
11. **Look** [2, 7] — the look of the lowest release (recommended: an iOS 6 app looks like iOS 6), or
    a custom one.
12. **Identity** — display name, bundle identifier (reverse DNS, the user's own domain or
    `com.<name>.<app>`), version, the Debian package name (usually the bundle identifier), the
    maintainer line `Name <email>` for the package, the icon (the user's PNG, or one you draw).
13. **Publishing** [4] — the `.deb` alone; installed on the user's device over SSH; or the user's own
    Cydia repository, and where it will be hosted.

## 4. Confirm

When the frontier is empty, show the decisions as one list and ask the user to confirm or correct.
Corrections reopen the nodes that depend on them. An `answers.md` that says the decisions are
confirmed counts as confirmation, but only if every node is settled.

If there is nobody to ask — you run without a user and `answers.md` leaves a node open or breaks a
constraint — stop. Write the open questions, with your recommendations, to the end of `PROJECT.md`
under `## Open questions`, report them, and create nothing else. Never settle a decision by guessing.

## 5. Write PROJECT.md

At the project root, in the user's words where they gave words:

- `## App` — purpose, screens (one line each), data, network, gestures.
- `## Target` — `apple_minimum`, releases to check, devices (identifiers and names), architectures.
- `## Code` — language, interface, Combine, frameworks, backports (each with the API that needs it).
- `## Identity` — name, bundle identifier, version, package name, maintainer, icon.
- `## Publishing` — the chosen target and, for a Cydia repository, where it is hosted.
- `## Progress` — one line per step, filled in by the later skills with the evidence (a log path,
  the verdict line, the `.deb` path): install, firmware, project, build, emulator, package, device,
  repository.
- `## Limits` — empty at first; later steps write here what the stack could not do natively, with
  what was measured.

Then follow the skill `install`.

## Traps

- Asking the user for a fact (their macOS version, whether xmake is there) → look it up; the user
  answers decisions only.
- Accepting "Swift on iOS 5" or "arm64 on iOS 6" because the user asked → name the constraint and ask
  again; the build would fail at the first link or the app at launch.
- Creating the project "to save time" before confirmation → the interview reshapes the tree; files
  written early encode answers that were never given.
- Promising an emulator check on iOS 8 or 9 → there is no kernel for them; plan a device check or none.

---

Approach adapted from the `grilling` and `grill-me` skills of
[mattpocock/skills](https://github.com/mattpocock/skills) (commit `c55ee46`), MIT License,
Copyright (c) 2026 Matt Pocock. See `THIRD-PARTY.md` in this plugin.
