# hades: agent contract

The workspace contract (`$HOME/Git/projects/ios/AGENTS.md`) applies. Inside hades:

- Work inside one member folder at a time and read that member's `AGENTS.md` first: `charon/AGENTS.md`,
  `shade/AGENTS.md`, `frameworks/eidolon/AGENTS.md`, `frameworks/styx/AGENTS.md`, `katabasis/AGENTS.md`, `psychopomp/AGENTS.md`,
  `revenant-webkit/AGENTS.md`.
- A change that spans members is one series in hades, one commit per member it touches.
- Nothing but the project lives in the hades folder: no scratch, logs, notes, run output or worktrees. Scratch goes
  to `$HOME/.cache/hades/<task>/` and is deleted when the task ends.
- No comments in code, scripts or recipes. What a change does and why goes in its commit message and in the
  member's README.
- Third-party code is a package of `third_party/packages/<letter>/<name>/`: the upstream by url and commit or
  checksum, our changes as `git format-patch` files in its `patches/`, applied in order by `add_patches`. Never
  commit a copy of upstream code.
- Before handing a change over: `xmake l tools/check.lua <member>` for each member it touches that has a check
  there, then that member's own gate (charon's `backports-gate` skill, shade's boot skill).
