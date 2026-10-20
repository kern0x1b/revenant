# revenant: agent contract

The workspace contract (`$HOME/Git/projects/ios/AGENTS.md`) applies. Inside revenant:

- This file is the only agent file in the repository: no component keeps an `AGENTS.md`, `CLAUDE.md`, `.claude` or
  `.agents` of its own. What an agent needs to know about one component is in `docs/guides/<component>/`.
- One layout for the whole repository, so that nothing has to be remembered per component:

  ```
  AGENTS.md README.md CONTRIBUTING.md SECURITY.md   the only such files
  LICENSES/ REUSE.toml       every licence text once (SPDX names), and which paths each covers
  xmake.lua xmakew tools/    the one build graph, its xmake, the repository's Lua tools
  docs/                      all documentation, by kind (Diataxis), then by component:
    tutorials/<component>/     learning by doing, from nothing to a working result
    guides/<component>/        how to do one task (build, test, debug, release, work on it as an agent)
    reference/<component>/     facts to look up: APIs, options, formats, measured behaviour
    explanation/<component>/   why it is built the way it is: design, decisions, research
  third_party/<name>/        code we use but do not develop: upstream by url and commit, our patches/
  packages/ addons/          the package repository, read from the top of the checkout: packages/<group>/<name>/
                             and addons/<group>/<name>/
  <component>/               toolchain, emulator, recompiler, agent-skills, frameworks/<Framework>
  ```

  A document about the whole repository is not in a component's folder: it sits directly under its quadrant (`explanation/platform.md`, `explanation/backports-loading.md`, `guides/ci.md`, `guides/machine.md`, `guides/prebuilt.md`). A component's documents sit under `<quadrant>/<component>/`, and `docs/README.md` indexes every document.

  Every component has the same shape, lowercase, and nothing else at its top:

  ```
  xmake.lua    its targets and tests, included by the top xmake.lua (xmake test runs its tests)
  README.md    one screen: what it is, how to build, run and test it, links into docs/
  src/         all of its code
  include/     its public headers, when it has any
  patches/     when the component is an upstream at a commit plus our changes (its xmake.lua applies them)
  tests/       all of its tests; fixtures, reference outputs, snapshots and corpora in tests/data/
  examples/    demo applications
  tools/       its developer tools, Lua only
  ```

  `agent-skills` is the one plugin with a different shape: `README.md`, `tests/`, `.claude-plugin/`, `skills/`, `LICENSE`
  and `THIRD-PARTY.md`. The plugin format fixes its manifest at `.claude-plugin/plugin.json` beside the skills, and an
  installed plugin is that folder alone, so the skills and the licence and notice they carry stay there. Its
  `plugin.json` could point the skills at `src/`, but Claude Code's loading of a custom skills path is not verified
  here, so the skills are not moved until it is.
  `toolchain/` is the xmake addon `revenant`, so its `addon.lua`, `includes/`, `modules/`, `plugins/`, `rules/` and `toolchains/` take the shape xmake reads: `plugins/<name>/` holds `xmake.lua` and `main.lua`, `rules/`, `toolchains/` and `includes/` hold `<name>/xmake.lua`, and `modules/` holds Lua files only. The package repository is the top of the checkout, so `packages/<group>/<name>/` and `addons/<group>/<name>/` hold `xmake.lua` alone.

  A component uses another through the build graph (`add_deps`, or its package by name), never by a path into the
  other's folder. The layout is checked by `./xmakew l tools/check.lua layout`.
- A change that spans components is one series in revenant, one commit per component it touches.
- Nothing but the project lives in the revenant folder: no scratch, logs, notes, run output or worktrees. Scratch goes
  to `$HOME/.revenant/cache/<task>/` and is deleted when the task ends.
- No comments in code, scripts or recipes; a licence header a licence requires is the only exception. What a change
  does and why goes in its commit message; knowledge a reader of the code needs goes in `docs/`.
  `./xmakew l tools/comments.lua check [path ...]` finds comments, `strip` removes them, and `verify [rev]` proves that
  the files changed since `rev` differ from it in comments only (clang's raw tokens, Swift's parse tree, Lua's
  bytecode). Files that carry upstream text (`comments=upstream`) or whose comments are the test data (`comments=fixture`) are marked in `.gitattributes`.
- Third-party code is a package of `third_party/<name>/`: the upstream by url and commit or
  checksum, our changes as `git format-patch` files in its `patches/`, applied in order by `add_patches`. Never
  commit a copy of upstream code. The top `xmake.lua` includes each one, so a member requires it by its bare name
  (`add_requires("dynarmic 6.7.0")`).
- Every dependency is at its latest release, or at the head of its main branch where it has no releases or we need
  what is not released yet. A newer version that dropped something we need (armv7, iOS 6, an API, a build mode) gets
  it back as a patch on that version; an old pin is never the answer. Moving a pin means rebasing our patches onto
  the new version and dropping the ones upstream made unnecessary.
- Skills live in `.agents/skills/` at the top of revenant (`.claude/skills` links there); a member keeps none of its
  own. xmake's own skills come from the `xmake-skills` plugin pinned in `.claude/settings.json`, and are not copied into `.agents/`. The `xmake-*` skills of `agent-skills/` are derived from those upstream skills and rewritten for the toolchain: `agent-skills/THIRD-PARTY.md` maps each one to its upstream skills and to the commit they were taken from.
  `agent-skills/` is the plugin `agent-skills` of the revenant marketplace (`.claude-plugin/marketplace.json`).
- xmake at the top is always `./xmakew`, the pinned and patched xmake of `third_party/xmake` (built into
  `$HOME/.revenant/cache/xmake/` on first use): `./xmakew f -p iphoneos -a armv7`, `./xmakew build <target>`. It takes
  the revenant addon from `toolchain/` of the checkout; stock xmake would fetch and install the toolchain globally instead.
  Its package store is `$HOME/.revenant/cache/xmake-global` (`XMAKE_GLOBALDIR`). Everything a build can make again is under
  `$HOME/.revenant/cache`, and `./xmakew l tools/clean.lua [--packages | --all]` gives it back; it is in `docs/guides/machine.md`.
- Before handing a change over: `./xmakew l tools/check.lua layout`, `./xmakew l tools/check.lua <component>` for
  each component it touches, then that component's gate (the backports gate is gone until `xmake test` replaces it;
  for the emulator, the skill `emulator-session`).
