# hades: agent contract

The workspace contract (`$HOME/Git/projects/ios/AGENTS.md`) applies. Inside hades:

- Work inside one member folder at a time and read that member's `AGENTS.md` first: `charon/AGENTS.md`,
  `shade/AGENTS.md`, `eidolon/AGENTS.md`, `styx/AGENTS.md`, `katabasis/AGENTS.md`, `psychopomp/AGENTS.md`,
  `revenant-webkit/AGENTS.md`.
- A change that spans members is one series in hades, one commit per member it touches.
- The agent work area is `hades/.agent-work/` (worktrees, runs, handoffs), not a member's own `.agent-work/`.
- Third-party forks live as `third_party/<name>/UPSTREAM` plus `patches/`; never commit a copy of upstream code.
