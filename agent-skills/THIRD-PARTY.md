# Third-party material

Psychopomp is MIT-licensed (`LICENSE`). The parts below are derived from other projects and stay
under their licenses as well; the full texts are in `LICENSES/`.

## xmake-io/xmake-skills

- Source: <https://github.com/xmake-io/xmake-skills>, commit `ef67caa`.
- License: Apache License 2.0 (`LICENSES/Apache-2.0.txt`).
- Used in: the `xmake-*` skills under `skills/`. Each is rewritten for the Charon toolchain and
  modified: content that does not apply to apps for old iOS is removed, advice that conflicts with
  Charon is replaced, and new material is added. Each file says at its top which upstream skills it
  derives from.

| Skill here | Upstream skills |
| --- | --- |
| `xmake-basics` | `xmake-basics`, `xmake-targets`, `xmake-commands`, `xmake-env-vars` |
| `xmake-packages` | `xmake-packages`, `xmake-addons` |
| `xmake-objc` | `xmake-objc` |
| `xmake-swift` | `xmake-swift` |
| `xmake-rules` | `xmake-rules` |
| `xmake-toolchains` | `xmake-toolchains`, `xmake-cross-compilation` |
| `xmake-scripting` | `xmake-scripting`, `xmake-script-modules` |
| `xmake-tests` | `xmake-tests` |
| `xmake-troubleshooting` | `xmake-troubleshooting` |

## mattpocock/skills

- Source: <https://github.com/mattpocock/skills>, commit `c55ee46`: the skills `grilling` and
  `grill-me` (and the earlier `grill-me` at `a6bdfd9`).
- License: MIT, Copyright (c) 2026 Matt Pocock (`LICENSES/MIT-mattpocock-skills.txt`).
- Used in: `skills/init`. Its interview follows their approach: a design tree, rounds that ask
  the whole frontier with a recommended answer each, facts looked up rather than asked, and done
  only when every branch is settled and the user confirms. The text is our own, written for this plugin.
