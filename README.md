# hades

The platform for running current iOS software on old iOS releases (iOS 26.2 surface on iOS 6.1.3, iPhone 4S,
armv7), in one repository. Each member keeps its own folder, history, `README.md` and `AGENTS.md`:

| Folder | What it is |
| --- | --- |
| `charon/` | legacy Apple platforms for xmake: toolchains, SDKs and packages, the backports, the gate |
| `shade/` | Charon's emulator: boots a firmware's own userland on macOS arm64 |
| `eidolon/` | SwiftUI for iOS 6, implemented on UIKit for armv7 |
| `styx/` | Combine down to iOS 6, armv7 |
| `katabasis/` | static recompiler of arm64 iOS applications into armv7 binaries for iOS 6 |
| `psychopomp/` | skills for coding agents that build modern apps for old iOS |
| `revenant-webkit/` | a current WebKit built for armv7 (the WebKit tree itself is the `webkit-254` submodule) |

Applications built on the platform (telegram-build, cydia, soundcloud-fix, kindle-sync-fix) are not members: they
consume charon as an xmake repository.

## Layout beside the members

| Path | What it is |
| --- | --- |
| `third_party/<name>/UPSTREAM` | a third-party dependency we change or pin: its upstream (`url`, then `commit` for git or `sha256` for an archive) |
| `third_party/<name>/patches/` | our changes to it, as `git format-patch` files applied in order |
| `third_party/fetch.lua` | `xmake l third_party/fetch.lua <name> [<dir>]`: the pinned upstream plus the patches, in `.deps/<name>` by default |
| `tools/check.lua` | `xmake l tools/check.lua [<member> ...]`: the members' checks that need no device or firmware |
| `tools/publish.lua` | `xmake l tools/publish.lua <member>`: a member's history as a repository of its own (below) |
| `.deps/`, `.build/` | fetched dependencies and check builds; not committed |

A fork of third-party code is never a copy here: `dynarmic` is MC-XiaoXiao's dynarmic at a commit plus our arm64
backend as patches, `boost` the release archive by its checksum, `xmake` the release tag plus our patches. A fetch
is keyed by the pin and the patches' checksums, so it runs again only when one of them changes. Shade's CMake build
fetches its two by itself when they are missing.

## One xmake project

The top `xmake.lua` is the project; it includes every member's top `xmake.lua`, so the members' targets are one graph
and a member uses another's library with `add_deps`. styx's `Combine` and `CombineHelpers`, eidolon's `SwiftUI`, the
eidolon demo, snapshots and engine tests, and `eidolonrt` are targets of that graph; charon's packages are third-party
code to them (the Swift runtime, libc++, the backports, the SDK and the tools). The members for iOS are built with
`xmake f -p iphoneos -a armv7`.

charon is both the package repository and the addon (toolchain and rules) of those builds, from the `charon/` folder
of this checkout. xmake reads an addon only from the addons installed in its global directory, and installing a
folder there makes it the machine's active charon for every project that has not locked a version. hades therefore
has an xmake global directory of its own, `~/.cache/hades/xmake-global`, which shares the machine's package store,
and `tools/charon-addon.lua` installs the `charon/` folder of the checkout it is run in as that directory's addon
(run it again after a change to `charon/`, and in the checkout you build):

```
xmake l tools/charon-addon.lua
export XMAKE_GLOBALDIR=$HOME/.cache/hades/xmake-global
xmake f -p iphoneos -a armv7 -o $HOME/.cache/hades/<task>/build && xmake
```

`CHARON_REPO` names another charon folder for the packages (a released tree whose packages are installed already).
charon's recipes of the members (`charon@styx`, `charon@eidolon`, `charon@swiftui`, `charon@shade`) are for
applications outside hades and keep their pinned commits.

## Publishing a member

Applications outside hades take charon with `add_repositories("charon <url> <tag>")`, and xmake reads a package
repository from the top of what it clones. charon's public repository is therefore a mirror of the `charon/` folder:
`xmake l tools/publish.lua charon` writes it as the branch `publish/charon` (`git subtree split`), whose commits before
the move are the very same commits charon had, so existing pins and tags stay valid. Pushing it is a separate step.

## History

Each member's history was brought in with `git subtree add` and is kept whole, as the second parent of the commit
that brought it in ("Bring <member> into hades with its history"). Those commits name their files without the
member's folder, so the history before the move is read from that parent: `git log <bring-commit>^2 -- <path in the
member>`. Building and testing follow each member's own README.
