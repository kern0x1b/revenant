# Contributor guide: agent-skills

Orientation for anyone, human or AI, changing the plugin. It is the map; the skills themselves are the product.

## What this is

agent-skills is a set of Agent Skills that guides a coding agent through building a modern app for old iOS (5, 6, 7, 9
and later) and old devices, from an empty directory to a `.deb`: the interview, installation, the project and its
`xmake.lua`, the code (Objective-C or Swift, SwiftUI and Combine included), the build, a check in the emulator on the
chosen release and device, packaging, and a Cydia repository. It stands on the stack of
[toolchain](https://github.com/kern0x1b/revenant/tree/main/toolchain), [Combine](https://github.com/kern0x1b/revenant/tree/main/frameworks/Combine),
[SwiftUI](https://github.com/kern0x1b/revenant/tree/main/frameworks/SwiftUI) and the
[emulator](https://github.com/kern0x1b/revenant/tree/main/emulator).

[The README](../../../agent-skills/README.md) is for the people who install the plugin; this guide is for the people who
change it.

## Layout

| Path | Holds |
| --- | --- |
| `.claude-plugin/` | `plugin.json`, the manifest of the plugin; the marketplace that lists it is `.claude-plugin/marketplace.json` at the top of revenant. Several runtimes read these. They list the plugin, they do not contain it. |
| `skills/<name>/SKILL.md` | the skills, one directory each, in the Agent Skills format |
| `tests/` | the clean-machine check: scenarios (a request and the interview answers, never code), `run.lua` that runs them and `check.lua` that decides whether a run counts. [Clean-machine tests](clean-machine-tests.md) describes them. |
| `LICENSE`, `THIRD-PARTY.md` | the MIT licence of the plugin and what is derived from whom, at which commit, under which licence; they stay in the plugin because the installed copy carries them |

## How to check

- Manifests: the validator of the runtime whose format they are, run in strict mode. The exact commands are in
  [clean-machine tests](clean-machine-tests.md).
- Skills: the name is `a-z0-9-`, at most 64 characters and equal to its directory. The description is at most 1024
  characters. `SKILL.md` stays under 500 lines.
- The only proof a skill works is an agent that followed it. `tests/` runs every scenario in an empty directory outside
  any repository, with only the plugin installed. A run counts only when the agent wrote the code itself, built it,
  checked it in the emulator and packaged a `.deb`, and nothing from the plugin ended up in the project. No run has
  passed yet.

## Conventions

- **Skills are instructions, not examples.** No sample app, no finished project, no template tree anywhere in the
  repository. A code fragment is allowed only when it serves a single step: one `xmake.lua` line, one call, one flag.
- **Nothing proprietary to Apple.** No firmware, dyld cache, SDK header, framework binary or artwork. A skill tells the
  user how to obtain what they need.
- **Written for any runtime.** A skill names no particular agent, product or model, and relies only on reading files,
  running commands and asking the user. Runtime-specific manifests stay in their own files.
- **Anchored to the stack as it is.** Every command, option and path in a skill is checked against the current
  toolchain, Combine, SwiftUI and the emulator before it is written; an intention is not described as a feature.
- **Derived text keeps its origin.** A skill built on third-party material says so in its own file and in
  `THIRD-PARTY.md`, with the source, commit and licence.
- **Commits:** plain imperative subject, no type prefixes; an agent's commit ends with its own `Co-Authored-By:` trailer.
- **No personal data:** no device identifiers, addresses, credentials or absolute `/Users/<name>/` paths; write `$HOME`.
