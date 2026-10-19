# kern0x1b repository standard

A single house standard so every `kern0x1b` repository — the toolchain, the
engine, the emulator, the JIT, the recompiler and Eidolon — looks and is
organised the same way. It is deliberately **minimal-necessary**: every item
below earns its place across the whole set, not one repo's taste.

Status: **proposal, for the owner to approve before rollout.** Nothing has been
changed in any repo. The per-repo checklist at the end is what conforming would
take.

Themes it honours:

- **Naming** — the mythological underworld/undead line: Charon, Revenant,
  Shade, Umbra, Eidolon, and the recompiler's forthcoming name.
- **AI is shown, not hidden.** Everything here is built with Claude, and that is
  stated openly — in a commit trailer, and in the README. We mark our work; we
  never disguise it.
- **No personal data, ever, in a public repo.** No device IPs, hostnames,
  serials, credentials, or absolute `/Users/<name>/…` paths. Use `$HOME`,
  `device.env` (gitignored), and placeholders.
- **Licence compliance is non-negotiable.** Forks keep every notice their
  licence mandates. We may strip an upstream's *product branding* where the
  licence allows and rework the tree freely, but required legal text stays.

---

## 1. Required files

Two tiers. **Core** files are in every repo. **Conditional** files appear only
when the trigger applies. Everything not listed is out of the standard — do not
add it just to fill a checklist.

### Core (every repo, at the root)

| File | Purpose | Notes |
| --- | --- | --- |
| `README.md` | The front door. | Template in §2. |
| `LICENSE` | The repo's own licence, full text. | Filename is exactly `LICENSE`, no extension, even for forks whose upstream used `LICENSE.txt` — unless the licence text itself dictates the name. |
| `AGENTS.md` | Agent- and contributor-facing working map. | House title **"Contributor guide"**. See §1 note below. |
| `CONTRIBUTING.md` | How to work on it, for a human who isn't us. | Short; points at `AGENTS.md` for the deep guide. Template below. |
| `SECURITY.md` | How to report a vulnerability privately. | Template below; pairs with GitHub Private Vulnerability Reporting. |
| `CHANGELOG.md` | Notable changes, newest first. | Keep a Changelog 1.1.0 + SemVer. §3. |
| `.gitignore` | Build artifacts, scratch, and all personal-data files. | Must ignore `device.env*` and absolute-path scratch. |
| `.gitattributes` | Line-ending and linguist normalisation. | Baseline below. |
| `.editorconfig` | Editor baseline (indent, EOL, final newline). | Baseline below. |

### Conditional

| File | Include when… | Notes |
| --- | --- | --- |
| `NOTICE` | a licence **mandates** carrying notices: MPL-2.0 (§3.4), Apache-2.0 (§4d), or you bundle BSD/MIT copies that require their notice to ship. | Legal text only. `shade` already has one; keep it. Not needed for a purely MIT/BSD-3/0BSD original. |
| `THIRD-PARTY.md` | the repo links or bundles any third-party code. | Human-readable dependency inventory: component / version / licence / where it comes from. `revenant-webkit`'s is the reference example. |
| `.clang-format` | the repo has C/C++/Obj-C source. | `shade` and `umbra` already have one; standardise its contents across C/C++ repos. |
| `CODE_OF_CONDUCT.md` | **only if a real outside contributor community forms.** | Deliberately **omitted** by default — see decision below. |

**`AGENTS.md` vs `CONTRIBUTING.md`.** They are different audiences and both are
committed and public. `AGENTS.md` ("Contributor guide") is the working map —
architecture, gotchas, where things live, playbooks — written for whoever (human
or AI) is actually building. `CONTRIBUTING.md` is the short outside-contributor
front door: licence of contributions, commit convention, the no-personal-data
rule, and a pointer into `AGENTS.md`. Because `AGENTS.md` is public it obeys the
no-personal-data rule like any other file.

**CODE_OF_CONDUCT decision — omit by default.** These are AI-built personal
projects with no contributor community to govern; an unenforced code of conduct
is worse than none (Open Source Guides). GitHub's community checklist will show
it as missing, and that is fine. Fold the one line that matters ("be
straightforward and civil in issues and PRs") into `CONTRIBUTING.md`. Add the
Contributor Covenant only if and when a community actually appears.

---

## 2. README template

One H1 that is the **product name**, a one-line em-dash tagline, then sections in
this fixed order. Omit a section if it is genuinely empty; never reorder.

```markdown
# <Product Name>

**<One-line tagline — what it is, for whom, in one breath.>**

<2–4 sentence overview: the problem, and the outcome. No marketing.>

<!-- Optional: one centred screenshot/hero for a visual project. -->

## Contents        <!-- only if the README exceeds ~8 sections or ~150 lines -->

## What it does / What works
## How it works
## Requirements
## Build            <!-- or Install / Quick start -->
## Usage            <!-- or Deploy and test, per project -->
## Repository layout
## Documentation    <!-- link table into docs/ -->
## Provenance       <!-- OMIT for rebranded forks: per the owner's directive we do NOT name the original product; lineage lives in git history + LICENSE. Only a non-fork's own note goes here, if any. -->
## Trademarks       <!-- only if screenshots show third-party sites/brands -->
## License
```

**Badges.** At most a single row directly under the tagline, and only badges
that are *true and useful*: licence, and CI status if there is CI. No download
counters, no "made with love", no vanity badges. Many repos here will carry
**zero** badges — that is the preferred default.

**AI-built statement.** Every README ends its `## License` section (or carries a
short `## Built with` note) with one honest line:

```markdown
Built with Claude (Anthropic). This project is developed with AI assistance,
openly — see the commit history.
```

**Licence section.** State the repo's own licence and file, then — for forks or
anything with vendored/linked third-party code — one sentence pointing at
`NOTICE` and/or `THIRD-PARTY.md`. Example patterns:

- *Original, MIT:* "MIT, see `LICENSE`. Third-party dependencies and their terms
  are listed in `THIRD-PARTY.md`; nothing third-party is vendored."
- *Rebranded fork, MPL-2.0:* "MPL-2.0, see `LICENSE`; required notices are in
  `NOTICE`." — do **not** name the original product (owner rebrand directive);
  MPL requires only the licence text/per-file headers, not the product name.
- *Rebranded fork, 0BSD:* "0BSD, see `LICENSE` — no notice required." — 0BSD
  mandates nothing; present it as our own, do not name the original.

**Rebrand overrides naming (owner directive).** Where a licence does not require
it, we strip every mention of the original product: no `## Provenance` naming an
upstream, no upstream-named topic, no "fork of X" in the README. We keep only
license-mandated notices (MPL `NOTICE`/headers, bundled MIT/BSD notices). Lineage
stays in git history and `LICENSE`. This governs `shade`, `umbra` and any future
fork.

**No personal data.** A README is public. Device address, port and password go
in `device.env` (gitignored) with a tracked `device.env.example`; commands use
`$HOME` and placeholders, never a real path or host.

---

## 3. GitHub metadata, releases and versioning

**Description** — one present-tense line, **≤ 120 chars, leading with the
product name**:

```
<Product> — <what it is and the one property that matters>.
```

Examples (fix the ones that drift):

- `Charon — xmake/Conan cross-compilation toolchain and package repo for legacy iOS (down to iOS 3).`
- `Revenant WebKit — a current WebKit (armv7) running today's sites on an iPhone 4S / iOS 6: TLS 1.3, Web Crypto, JIT.`
- `Shade — Charon's ARM/iOS userland emulator for macOS arm64; a fork of iLEmu. Notices in NOTICE.`
- `Umbra — the ARM JIT core under Shade; a fork of dynarmic (0BSD).`

> Note: `revenant-webkit`'s live description says WebKit **2.53** while the repo
> says **2.54** — reconcile to the built version on rollout.

**Topics** — a common spine plus per-repo specifics. Rebranded forks do **not**
carry a `fork` topic or the upstream's name (owner rebrand directive) — they are
presented as our own.

- Common spine (where true): `ios`, `armv7`, `legacy-hardware`, `jailbreak`.
- `charon`: `cross-compilation`, `toolchain`, `conan`, `xmake`, `ios-6`.
- `revenant-webkit`: `webkit`, `browser-engine`, `ios-6`, `iphone-4s`, `tls13`, `webassembly`.
- `shade`: `emulator`, `arm`, `macos`, `ios`.
- `umbra`: `jit`, `arm`, `arm64`, `armv7`.
- recompiler: `aot`, `binary-translation`, `arm64`, `armv7`.
- Eidolon: `swiftui`, `ios-6`, `ui-framework`.

**Default branch:** `main`, everywhere (already true).

**Versioning:** SemVer `MAJOR.MINOR.PATCH`. Tags are annotated, prefixed **`v`**:
`v1.4.2`. Every tag has a matching `CHANGELOG.md` entry, and cutting a release
moves that repo's `[Unreleased]` block to a dated version heading. Forks version
on **our own** scheme starting at `v0.1.0` — we do not track the upstream's
numbers. Where the shipped version lives elsewhere (e.g. `version` in
`charon.toml` for `revenant-webkit`), the tag must match it.

**CHANGELOG** — Keep a Changelog 1.1.0 header, newest first, `[Unreleased]` on
top, standard groups (Added / Changed / Fixed / Removed / Security). Present in
every repo, even if it currently holds only `[Unreleased]`.

**Social preview:** a simple, consistent card per repo — product name + one-line
tagline on a shared dark template, so the set reads as one family. Nice-to-have,
not blocking.

**Licence detection:** keep `LICENSE` as recognised SPDX text so GitHub shows the
licence instead of "Other" (this is why `revenant-webkit` reads "Other" — a mixed
tree; keep the top-level `LICENSE` clean and describe the submodule's terms in
prose + `THIRD-PARTY.md`).

---

## 4. Directory layout and shared conventions

Not one rigid tree — the repos are genuinely different shapes (an xmake
toolchain, a CMake emulator, a WebKit port). Instead, **common names mean the
same thing** wherever they appear:

| Path | Holds |
| --- | --- |
| `src/` | first-party source (CMake repos) |
| `docs/` | long-form docs; the README links into it, never duplicates it |
| `tests/` | the test suites |
| `tools/` | diagnostic/maintenance helpers |
| `scripts/` | build/deploy/device helper scripts |
| `.github/workflows/` | CI |
| `recipes/` | Conan/package recipes (toolchain-adjacent repos) |

Naming and style, common to all:

- **Directories and files:** lowercase, hyphen-separated (`core-update.md`).
  Markdown docs live in `docs/`; only the standard root files sit at the root.
- **Product name** is capitalised in prose and is the README H1. The em-dash
  tagline style ("*A current WebKit for hardware the web left for dead.*") is the
  house voice: plain, declarative, no hype.
- **Trademark/nominative note** whenever a README or docs show third-party sites
  or brands (as `revenant-webkit` does): shown nominatively, under fair use, no
  affiliation, ships none of their assets.
- **C/C++ repos** share one `.clang-format`; all repos share `.editorconfig` and
  `.gitattributes` (baselines in §6).
- **Build artifacts are never committed** and are gitignored; the repo tracks
  source only (both `recompile` and `revenant-webkit` already state this).

---

## 5. Commit messages and attribution

- **Subject:** plain imperative, describing the change; no type prefixes, no
  scope tags, no tool noise in the subject. (`Lock onto Charon's libplist 2.7.0`,
  not `chore(deps): bump libplist`.)
- **Body:** wrap ~72 cols, explain *why* when it isn't obvious.
- **AI attribution trailer, on every commit:**

  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

  This is the house convention and it is intentional — the work is openly
  AI-built and we keep the mark. A model-versioned form
  (`Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`) is an acceptable
  variant when a session emits it; the generic `Claude` trailer is the default.
  Do **not** strip it.
- **Never** commit personal data (see §1/§2). Scrub paths and hosts before
  staging.
- **Submodules** (e.g. `revenant-webkit`'s `webkit-254`): commit/push are
  forward-only; never `checkout`/`reset` destructively inside them.

---

## 6. Copy-paste templates

### `CONTRIBUTING.md`

```markdown
# Contributing

This is an openly AI-built project (developed with Claude). Contributions are
welcome; the working guide — architecture, gotchas, how to build and test —
lives in [AGENTS.md](AGENTS.md).

- **Commits:** plain imperative subject. Keep the `Co-Authored-By: Claude
  <noreply@anthropic.com>` trailer — we mark AI-built work, we do not hide it.
- **No personal data.** No device addresses, hostnames, credentials, or absolute
  `/Users/<name>/…` paths in tracked files. Use `$HOME`, placeholders, and the
  gitignored `device.env`.
- **Licence of contributions:** by contributing you agree your work is under this
  repository's licence (see `LICENSE`).
- Be straightforward and civil in issues and pull requests.
```

### `SECURITY.md`

```markdown
# Security policy

Please report vulnerabilities privately — do **not** open a public issue.

Use GitHub's private vulnerability reporting for this repository
(Security → Report a vulnerability). We aim to acknowledge within a few days.

There are no supported "old" releases: fixes land on `main` and in the next
tagged release.
```

### `.editorconfig`

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 4

[*.{md,markdown}]
trim_trailing_whitespace = false

[*.{yml,yaml,json,toml,lua}]
indent_size = 2

[Makefile]
indent_style = tab
```

### `.gitattributes`

```gitattributes
* text=auto eol=lf

*.png binary
*.jpg binary
*.gif binary
*.pdf binary
*.deb binary
*.a   binary
*.dylib binary

# Keep generated/vendored bulk out of language stats and diffs
docs/**            linguist-documentation
*.lock             linguist-generated
```

### `.gitignore` — personal-data floor (merge into each repo's own)

```gitignore
.DS_Store
__pycache__/

# Personal / device data — never tracked. Only the example is.
device.env*
device.*.env
!device.env.example

# Local screenshots may show device content
**/shots/
*-shots/
```

### `CHANGELOG.md` skeleton

```markdown
# Changelog

All notable changes to this project are recorded here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
### Changed
### Fixed
```

---

## 7. Per-repo application checklist

Ordered by effort. None of this has been done — it is the proposed work.

### `charon` (MIT, original, public)
- [ ] Add `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.editorconfig`,
      `.gitattributes`.
- [ ] Add `AGENTS.md` ("Contributor guide") if absent; it has `DESIGN.md` and a
      README but no agent map at root.
- [ ] Rewrite the description to lead with "Charon"; add topics
      (`cross-compilation`, `toolchain`, `conan`, `xmake`, `ios`, `armv7`).
- [ ] `THIRD-PARTY.md` if it bundles/pins third-party recipes users should see.
- [ ] Confirm no personal paths in `config/`, `toolchains/`, docs.

### `revenant-webkit` (MIT + WebKit submodule, public) — reference model
- [ ] Reconcile the GitHub description version (`2.53` → built version) and lead
      with the product name.
- [ ] Add the missing core files: `CONTRIBUTING.md`, `SECURITY.md`,
      `.editorconfig`, `.gitattributes`.
- [ ] Add topics (§3). Keep `README`, `CHANGELOG`, `THIRD-PARTY.md`, `AGENTS.md`,
      CI — they already match the standard and set the bar.
- [ ] Add the one-line "Built with Claude" statement to the README.
- [ ] Leave `LICENSE` clean MIT so GitHub stops showing "Other"; the submodule's
      terms stay described in prose + `THIRD-PARTY.md`.
- [ ] Verify no personal data: `device.env`/`device.ipad2.env` are gitignored
      (they are), and no host/path leaked into docs or `carry-*` files.

### `shade` (MPL-2.0, fork of iLEmu, public)
- [ ] **Add a `README.md`** — it currently has none. Use the §2 template. Do
      **NOT** name iLEmu (rebrand directive) — no `## Provenance` naming it;
      present Shade as our own.
- [ ] Keep `NOTICE` (MPL-required) and `LICENSE`; add `THIRD-PARTY.md` for
      bundled `external/` deps (their MIT/BSD/BSL notices).
- [ ] Add `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.editorconfig`.
      Keep `.clang-format`, `.gitattributes`.
- [ ] Add topics `emulator`, `arm`, `macos`, `ios` — no `fork`/`ilemu`.
- [ ] Confirm MPL file headers are intact on reworked source (MPL wants the
      per-file header) — but they are generic MPL boilerplate, no product name.

### `umbra` (0BSD, fork of dynarmic, public)
- [ ] Rename `LICENSE.txt` → `LICENSE` (0BSD needs no notice, so the rename is
      safe and matches the house name).
- [ ] Add `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.editorconfig`.
      Keep `.clang-format`; README and `docs/` already exist.
- [ ] Do **NOT** name dynarmic (rebrand directive; 0BSD requires nothing) — no
      `## Provenance` naming it. Topics `jit`, `arm`, `arm64`, `armv7` — no
      `fork`/`dynarmic`.
- [ ] `THIRD-PARTY.md` for `externals/` (their MIT/BSD-3/BSL notices must ship).

### `recompile` (local git, 0 remote, to be named/public later)
- [ ] Pick the underworld name; then create the public repo.
- [ ] Add all core files. The Russian `REPORT.md` is research, not a README —
      keep it under `docs/` (e.g. `docs/research.md`) and write a proper English
      `README.md`.
- [ ] Decide licence (original → MIT to match the family) and add `LICENSE`.
- [ ] `.gitignore` already tracks source-only; add the personal-data floor (§6).
- [ ] Scrub `REPORT.md`/scripts for absolute `~/Git/...`-expanded paths before
      it goes public.

### `swiftui-study` / **Eidolon** (local, **not yet a git repo**)
- [ ] `git init` — it currently has no `.git` at all.
- [ ] Add all core files; the `REPORT.md` (research) moves under `docs/`, a real
      `README.md` replaces it as the front door.
- [ ] Name the product **Eidolon** in the README H1 and description.
- [ ] Choose licence (original → MIT); add `LICENSE`.
- [ ] Add the personal-data-floor `.gitignore`; `runs.noindex/`, `shots/`,
      `scratch/` and build output must be ignored, and scrub device/host details
      from `device.lua`, `run-app.sh`, `pkg-env.sh` before publishing.

---

## Sources

- [GitHub — About community profiles / community-standards checklist](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/about-community-profiles-for-public-repositories)
- [GitHub — Best practices for repositories](https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories)
- [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning 2.0.0](https://semver.org/)
- [standard-readme spec](https://github.com/RichardLitt/standard-readme/blob/main/spec.md)
- [Open Source Guides — Your Code of Conduct](https://opensource.guide/code-of-conduct/)
- [Contributor Covenant](https://www.contributor-covenant.org/)
- [Open Source Guides — Security best practices](https://opensource.guide/security-best-practices-for-your-project/)
- [EditorConfig](https://editorconfig.org/)
- [MPL-2.0 text (notice obligations §3)](https://www.mozilla.org/en-US/MPL/2.0/)
