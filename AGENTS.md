# revenant: agent contract

The workspace contract (`$HOME/Git/projects/ios/AGENTS.md`) applies. Inside revenant:

- Work inside one member folder at a time and read that member's `AGENTS.md` first: `toolchain/AGENTS.md`,
  `emulator/AGENTS.md`, `frameworks/SwiftUI/AGENTS.md`, `frameworks/Combine/AGENTS.md`, `recompiler/AGENTS.md`, `agent-skills/AGENTS.md`,
  `frameworks/WebKit/AGENTS.md`.
- A change that spans members is one series in revenant, one commit per member it touches.
- Nothing but the project lives in the revenant folder: no scratch, logs, notes, run output or worktrees. Scratch goes
  to `$HOME/.revenant/cache/<task>/` and is deleted when the task ends.
- No comments in code, scripts or recipes; a licence header a licence requires is the only exception. What a change
  does and why goes in its commit message; knowledge a reader of the code needs goes in the member's `docs/`.
  `./xmakew l tools/comments.lua check [path ...]` finds comments, `strip` removes them, and `verify [rev]` proves that
  the files changed since `rev` differ from it in comments only (clang's raw tokens, Swift's parse tree, Lua's
  bytecode). Files that carry upstream text (`comments=upstream`) or whose comments are the test data (`comments=fixture`) are marked in `.gitattributes`.
- Third-party code is a package of `third_party/packages/<letter>/<name>/`: the upstream by url and commit or
  checksum, our changes as `git format-patch` files in its `patches/`, applied in order by `add_patches`. Never
  commit a copy of upstream code.
- Every dependency is at its latest release, or at the head of its main branch where it has no releases or we need
  what is not released yet. A newer version that dropped something we need (armv7, iOS 6, an API, a build mode) gets
  it back as a patch on that version; an old pin is never the answer. Moving a pin means rebasing our patches onto
  the new version and dropping the ones upstream made unnecessary.
- Skills live in `.agents/skills/` at the top of revenant (`.claude/skills` links there); a member keeps none of its
  own. xmake's own skills come from the `xmake-skills` plugin pinned in `.claude/settings.json`, never a copy.
  `agent-skills/` is the plugin `agent-skills` of the revenant marketplace (`.claude-plugin/marketplace.json`).
- Workspace-wide procedures are skills in `$HOME/Git/projects/ios/.agents/skills/`: `device-session`,
  `canon-install`, `patch-merge`, `worktree-sweep`, `session-handoff`, `band-launch`, `band-supervise`. A session
  started inside revenant does not list them: read `<name>/SKILL.md` there.
- xmake at the top is always `./xmakew`, the pinned and patched xmake of `third_party/packages/x/xmake` (built into
  `$HOME/.revenant/cache/xmake/` on first use): `./xmakew f -p iphoneos -a armv7`, `./xmakew build <target>`. It takes
  the revenant addon from `toolchain/` of the checkout; stock xmake would fetch and install the toolchain globally instead.
- Before handing a change over: `./xmakew l tools/check.lua <member>` for each member it touches that has a check
  there, then that member's own gate (the toolchain's `backports-gate` skill, the emulator's `emulator-boot` skill).
