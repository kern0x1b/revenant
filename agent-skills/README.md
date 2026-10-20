# agent-skills

A set of skills for coding agents that build **modern apps for old iOS** (5, 6, 7 and later) and old devices: the iPhone 3GS, 4 and 4S, the iPad 1 and 2, the iPod touch. You make an empty directory, install the plugin into your agent and describe the app you want. The agent interviews you, installs the toolchain, creates the project, writes the code in Objective-C or Swift, builds it, checks it in an emulator on the release and device you chose, and packages a `.deb` for your device or your Cydia repository.

## Install

In Claude Code, from any directory:

```sh
claude plugin marketplace add kern0x1b/revenant
claude plugin install agent-skills@revenant
```

The other agents, what you need and what the skills stand on are in [install and use](../docs/guides/agent-skills/install.md). The skills are in `skills/<name>/SKILL.md`, in the [Agent Skills](https://agentskills.io) format.

## License

MIT, see `LICENSE`. Parts derived from other projects are listed in [`THIRD-PARTY.md`](THIRD-PARTY.md).
