# Psychopomp

A set of skills for coding agents that build **modern apps for old iOS** (5, 6, 7 and later) and old
devices: the iPhone 3GS, 4 and 4S, the iPad 1 and 2, the iPod touch. You make an empty
directory, install the plugin into your agent and describe the app you want. The agent interviews
you, installs the toolchain, creates the project, writes the code in Objective-C or Swift, builds it,
checks it in an emulator on the release and device you chose, and packages a `.deb` for your
device or your Cydia repository.

It stands on four open projects:

- [Charon](https://github.com/kern0x1b/charon): the [xmake](https://xmake.io) addon, the toolchain
  (clang, ld64, ldid, no Xcode), the backports of newer iOS APIs, and a Swift runtime for iOS 6;
- [Styx](https://github.com/kern0x1b/styx): Combine;
- [Eidolon](https://github.com/kern0x1b/eidolon): SwiftUI on the UIKit of iOS 6 (not yet packaged
  by Charon at the pinned 0.8.10);
- [Shade](https://github.com/kern0x1b/shade): the emulator that boots a real iOS firmware's userland.

> **Status: early.** The route, the interview, the build path from installing the tools to the
> `.deb`, delivery to a device or a Cydia repository, self-review, Objective-C, Swift and Combine
> code, SwiftUI (what the pin lacks and what to do instead) and a reference for xmake are written.
> No test run has passed yet. Each runtime's install line is marked with whether it has been verified.

## What you need

- A Mac with Apple silicon and the Command Line Tools (`xcode-select --install`). Xcode is not
  needed.
- Disk and time for the first build: the toolchain's compiler and the Swift compiler are built
  from source once and then reused by every project.
- A network connection. Nothing of Apple's is in this repository: no firmware, no SDK headers, no
  frameworks. The system images the emulator boots and the libraries the build checks against are
  downloaded from Apple's own servers on your machine, by you, when a skill asks you to.
- For a real device: a jailbroken one with OpenSSH.

## Install

The skills are in `skills/<name>/SKILL.md`, in the [Agent Skills](https://agentskills.io) format.

| Agent | Install | Verified |
| --- | --- | --- |
| Claude Code | `claude plugin marketplace add kern0x1b/psychopomp`, then `claude plugin install psychopomp@psychopomp` | not yet |
| Codex | `codex plugin marketplace add kern0x1b/psychopomp`, then `codex plugin add psychopomp@psychopomp` | per its documentation, not tried |
| opencode | `npx skills add kern0x1b/psychopomp -a opencode` | not yet |
| Others | `npx skills add kern0x1b/psychopomp -a <agent>` | not yet |

## Use

In an empty directory, tell the agent what you want, for example "a shopping list for my iPhone 4
on iOS 6". It starts with the interview and creates nothing until you have confirmed the answers.

## License

MIT, see `LICENSE`. Parts derived from other projects are listed in `THIRD-PARTY.md`, once there
are any.
