# revenant

The platform for running current iOS software on old iOS releases (iOS 26.2 surface on iOS 6.1.3, iPhone 4S,
armv7), in one repository. Every component has the same layout (`src/`, `tests/`, `examples/`, `tools/`, `patches/`,
a one-screen `README.md`), all documentation is in `docs/`, and `AGENTS.md` at the top is the only agent file; the
layout is spelled out there:

| Folder | What it is |
| --- | --- |
| `toolchain/` | legacy Apple platforms for xmake: toolchains, SDKs and packages, the backports, the gate |
| `emulator/` | Revenant's emulator: boots a firmware's own userland on macOS arm64 |
| `frameworks/SwiftUI/` | SwiftUI for iOS 6, implemented on UIKit for armv7 (module `SwiftUI`) |
| `frameworks/Combine/` | Combine down to iOS 6, armv7 (module `Combine`) |
| `recompiler/` | static recompiler of arm64 iOS applications into armv7 binaries for iOS 6 |
| `agent-skills/` | skills for coding agents that build modern apps for old iOS |
| `frameworks/WebKit/` | a current WebKit built for armv7 (the engine is `third_party/webkit`: upstream at a commit plus the port's patches) |

Names: the repository and the platform are revenant; a folder is named for what it holds (`toolchain/`, `emulator/`,
`recompiler/`, `agent-skills/`); a group of products is named by its role (`frameworks/`); a member that implements
an Apple framework is named after that framework (`frameworks/SwiftUI`, `frameworks/Combine`, `frameworks/WebKit`).

Applications built on the platform (telegram-build, cydia, soundcloud-fix, kindle-sync-fix) are not members: they
consume the toolchain as an xmake repository.

## One xmake project

`xmake.lua` at the top is the project: it includes every member's own `xmake.lua`, so all targets are one graph and
a member uses another's target with `add_deps`. `./xmakew f -y && ./xmakew` at the top builds everything, `./xmakew
build <target>` one target, `./xmakew test` the tests.

`xmakew` is the xmake of revenant: the first run builds the xmake pinned in `third_party/xmake` (its url,
commit and patches, read from that recipe) into `~/.revenant/cache/xmake/<key>`, the key being made of the commit and
the patches' checksums, and every run executes that build with its arguments. It needs only `sh`, `git`, `make` and
a C compiler, and builds again when the recipe changes.

| Path | What it is |
| --- | --- |
| `xmakew` | the pinned and patched xmake, built on first use (above) |
| `third_party/<name>/` | an xmake package of third-party code: the upstream by url and commit or checksum, our changes in `patches/` applied in order by `add_patches` |
| `tools/check.lua` | `./xmakew l tools/check.lua [<member> ...]`: the members' checks that need no device or firmware |
| `tools/publish.lua` | `./xmakew l tools/publish.lua <member>`: a member's history as a repository of its own (below) |

Third-party code is never a copy here: `dynarmic` is MC-XiaoXiao's dynarmic at a commit plus our arm64 backend as
patches, `boost` the 1.81.0 release archive by its checksum, `xmake` the head of its dev branch after v3.1.2 plus our
patches to its addon handling, among them `add_addons(<name>, {sourcedir = <folder>})`, and the module `Combine`
OpenCombine at a commit plus the patches of `revenant@combine`.

### The members for iOS

`Combine` and `CombineHelpers`, `SwiftUI`, the SwiftUI demo, snapshot bundle, engine tests, probe and
typechecks are targets of the graph for iphoneos; Revenant's packages are third-party code to them (the Swift runtime,
libc++, the backports, the SDK and the tools). They are built with `./xmakew f -p iphoneos -a armv7`. The option
`--emulate=y` also requires the emulator, so that `./xmakew emulate -P .` installs their packages into an emulated
device and runs them there.

The toolchain is the addon `revenant` (toolchain and rules) of those builds, from the `toolchain/` folder of this checkout,
and the package repository of those builds is the checkout's root, with `packages/` and `addons/`. The top `xmake.lua`
declares the addon with `add_addons("revenant", {sourcedir = "toolchain"})` and the repository with
`add_repositories("revenant .")`:
xmake takes the addon from that folder for this project, as it is in the checkout, and installs nothing in its global
directory, so the machine's active revenant addon (the one other projects use) stays as it is. `@addon/revenant/...` rules, toolchains and
includes, `@addon.revenant.<module>` imports, the global modules of `toolchain/addon.lua` and Revenant's plugins all resolve
to `toolchain/`, also in the xmake processes a build starts. `./xmakew f -p iphoneos -a armv7 -v` prints the folder it
uses (`addon(revenant): <checkout>/toolchain`).

```
./xmakew f -p iphoneos -a armv7 -o $HOME/.revenant/cache/<task>/build && ./xmakew
```

Stock xmake does not know `sourcedir` in `add_addons` and would fetch and install the toolchain from the repository instead,
so revenant is always built with `./xmakew`.

`REVENANT_REPO` names another checkout of revenant for the packages (a released tree whose packages are installed already).
Revenant's recipes of the members (`revenant@combine`, `revenant@swiftui-uikit`, `revenant@swiftui`, `revenant@emulator`) are for
applications outside revenant and keep their pinned commits. The one revenant requires itself is `revenant@combine` with
`sources = true`: it installs the patched OpenCombine tree, and Combine's targets compile it.

## Publishing a member

Applications outside revenant take the toolchain with `add_repositories("revenant <url> <tag>")`, and xmake reads a package
repository from the top of what it clones. `./xmakew l tools/publish.lua toolchain` writes a mirror of the `toolchain/`
folder as the branch `publish/toolchain` (`git subtree split`); that mirror has the addon, but not the `packages/` and
`addons/` of the root, and `tools/publish.lua` cannot split the root yet.
`git subtree split` follows the folder's path, and the folder had another name before the rename, so the mirror's
history starts at the rename; the pins and tags of the earlier public repository stay valid there. Pushing it is a
separate step.

## History

Each member's history was brought in with `git subtree add` and is kept whole, as the second parent of the commit
that brought it in ("Bring <member> into revenant with its history"). Those commits name their files without the
member's folder, so the history before the move is read from that parent: `git log <bring-commit>^2 -- <path in the
member>`. Building and testing follow each member's own README.

## Licences and policies

Each member is under the licence in its own folder: the emulator under MPL-2.0 (with its `NOTICE`), every other member under
MIT. A member that builds on third-party code lists it in its third-party notice, `docs/reference/<member>/third-party.md`; the code itself comes in as a package
of `third_party/` or of the toolchain. [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md) hold for all members.
