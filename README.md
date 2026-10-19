# hades

The platform for running current iOS software on old iOS releases (iOS 26.2 surface on iOS 6.1.3, iPhone 4S,
armv7), in one repository. Each member keeps its own folder, history, `README.md` and `AGENTS.md`:

| Folder | What it is |
| --- | --- |
| `charon/` | legacy Apple platforms for xmake: toolchains, SDKs and packages, the backports, the gate |
| `shade/` | Charon's emulator: boots a firmware's own userland on macOS arm64 |
| `frameworks/eidolon/` | SwiftUI for iOS 6, implemented on UIKit for armv7 (module `SwiftUI`) |
| `frameworks/styx/` | Combine down to iOS 6, armv7 (module `Combine`) |
| `katabasis/` | static recompiler of arm64 iOS applications into armv7 binaries for iOS 6 |
| `psychopomp/` | skills for coding agents that build modern apps for old iOS |
| `revenant-webkit/` | a current WebKit built for armv7 (the WebKit tree itself is the `webkit-254` submodule) |

Names: a product with its own README, users and releases has a name of its own (charon, shade, styx, eidolon,
katabasis, psychopomp, revenant); a group of products is named by its role (`frameworks/`); a module that implements
an Apple framework is named after that framework (`SwiftUI`, `Combine`).

Applications built on the platform (telegram-build, cydia, soundcloud-fix, kindle-sync-fix) are not members: they
consume charon as an xmake repository.

## One xmake project

`xmake.lua` at the top is the project: it includes every member's own `xmake.lua`, so all targets are one graph and
a member uses another's target with `add_deps`. `./xmakew f -y && ./xmakew` at the top builds everything, `./xmakew
build <target>` one target, `./xmakew test` the tests.

`xmakew` is the xmake of hades: the first run builds the xmake pinned in `third_party/packages/x/xmake` (its url,
commit and patches, read from that recipe) into `~/.cache/hades/xmake/<key>`, the key being made of the commit and
the patches' checksums, and every run executes that build with its arguments. It needs only `sh`, `git`, `make` and
a C compiler, and builds again when the recipe changes.

| Path | What it is |
| --- | --- |
| `xmakew` | the pinned and patched xmake, built on first use (above) |
| `third_party/packages/<l>/<name>/` | an xmake package of third-party code: the upstream by url and commit or checksum, our changes in `patches/` applied in order by `add_patches` |
| `tools/check.lua` | `./xmakew l tools/check.lua [<member> ...]`: the members' checks that need no device or firmware |
| `tools/publish.lua` | `./xmakew l tools/publish.lua <member>`: a member's history as a repository of its own (below) |

Third-party code is never a copy here: `dynarmic` is MC-XiaoXiao's dynarmic at a commit plus our arm64 backend as
patches, `boost` the 1.81.0 release archive by its checksum, `xmake` the head of its dev branch after v3.1.2 plus our
patches to its addon handling, among them `add_addons(<name>, {sourcedir = <folder>})`, and styx's `Combine`
OpenCombine at a commit plus the patches of `charon@styx`.

### The members for iOS

styx's `Combine` and `CombineHelpers`, eidolon's `SwiftUI`, the eidolon demo, snapshots and engine tests, and
`eidolonrt` are targets of the graph for iphoneos; charon's packages are third-party code to them (the Swift runtime,
libc++, the backports, the SDK and the tools). They are built with `./xmakew f -p iphoneos -a armv7`.

charon is both the package repository and the addon (toolchain and rules) of those builds, from the `charon/` folder
of this checkout. The top `xmake.lua` declares it with `add_addons("charon", {sourcedir = "charon"})`: xmake takes the
addon from that folder for this project, as it is in the checkout, and installs nothing in its global directory, so
the machine's active charon (the one other projects use) stays as it is. `@addon/charon/...` rules, toolchains and
includes, `@addon.charon.<module>` imports, the global modules of `charon/addon.lua` and charon's plugins all resolve
to `charon/`, also in the xmake processes a build starts. `./xmakew f -p iphoneos -a armv7 -v` prints the folder it
uses (`addon(charon): <checkout>/charon`).

```
./xmakew f -p iphoneos -a armv7 -o $HOME/.cache/hades/<task>/build && ./xmakew
```

Stock xmake does not know `sourcedir` in `add_addons` and would fetch and install charon from the repository instead,
so hades is always built with `./xmakew`.

`CHARON_REPO` names another charon folder for the packages (a released tree whose packages are installed already).
charon's recipes of the members (`charon@styx`, `charon@eidolon`, `charon@swiftui`, `charon@shade`) are for
applications outside hades and keep their pinned commits. The one hades requires itself is `charon@styx` with
`sources = true`: it installs the patched OpenCombine tree, and styx's targets compile it.

## Publishing a member

Applications outside hades take charon with `add_repositories("charon <url> <tag>")`, and xmake reads a package
repository from the top of what it clones. charon's public repository is therefore a mirror of the `charon/` folder:
`./xmakew l tools/publish.lua charon` writes it as the branch `publish/charon` (`git subtree split`), whose commits
before the move are the very same commits charon had, so existing pins and tags stay valid. Pushing it is a separate
step.

## History

Each member's history was brought in with `git subtree add` and is kept whole, as the second parent of the commit
that brought it in ("Bring <member> into hades with its history"). Those commits name their files without the
member's folder, so the history before the move is read from that parent: `git log <bring-commit>^2 -- <path in the
member>`. Building and testing follow each member's own README.

## Licences and policies

Each member is under the licence in its own folder: shade under MPL-2.0 (with its `NOTICE`), every other member under
MIT. A member that builds on third-party code lists it in its `THIRD-PARTY.md`; the code itself comes in as a package
of `third_party/` or of charon. [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md) hold for all members.
