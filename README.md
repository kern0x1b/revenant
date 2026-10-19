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

## Members build each other from this tree

charon's packages of other members (`charon@shade`, `charon@styx`, `charon@eidolon`, `charon@swiftui`) build, inside
hades, the member folder of this checkout instead of a pinned commit of the member's old repository
(`charon/modules/hades.lua`). The package version is git's id of that folder's tree, plus a digest of changes not
committed, so the same sources reuse one install and any change is a new one. eidolon names charon by its folder here.
Outside hades, the same recipes keep their urls and versions.

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
