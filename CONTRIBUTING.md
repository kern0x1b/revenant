# Contributing

revenant is an openly AI-built project (developed with Claude). Contributions are welcome. [AGENTS.md](AGENTS.md) at the top is the working guide of the whole
repository: how the members fit together, the layout and the rules. Each member's guide (architecture, gotchas,
how to build and test) is `docs/guides/<component>/contributing.md`, and [the documentation index](docs/README.md)
lists every document.

- **Commits:** plain imperative subject, one commit per member a change touches. Keep the
  `Co-Authored-By: Claude <noreply@anthropic.com>` trailer: we mark AI-built work, we do not hide it.
- **No personal data.** No device addresses, host names, credentials or absolute `/Users/<name>/…` paths in tracked
  files. Use `$HOME`, placeholders and the git-ignored `device.env` and `local.env`.
- **No Apple code or assets.** A reimplemented framework is written from its public shape; nothing from Apple's
  binaries or SDKs is copied into the tree.
- **Licence of contributions:** by contributing you agree your work is under the licence of the member it lands in
  (that member's `LICENSE`).
- Be straightforward and civil in issues and pull requests.
