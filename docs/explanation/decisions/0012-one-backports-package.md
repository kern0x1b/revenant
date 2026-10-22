# 0012: One package for every Backports library

Status: accepted

## Context

A program built by this toolchain links the Backports libraries of `frameworks/Backports`, and an application
built elsewhere binds to them when it runs on a device. Their install folder is `/usr/lib/revenant/org.revenant.backports/`,
which the libraries name in their install names. When the apple-backports package was deleted, nothing wrote the
package that installs them, so a target that linked one was refused at packaging, and an application outside this
repository had no package to require.

## Decision

The Backports libraries of a build are one Debian package, `org.revenant.backports`, written by `./xmakew deb -P .`:

- it holds every Backports library built for the configured architecture, each at
  `/usr/lib/revenant/org.revenant.backports/<library>`, and nothing else;
- its version is the addon's release and a hash of the libraries and of what they depend on, so a changed library
  is a new version, and an application that depends on it names that version exactly;
- its `Depends` names the shared package of each library it names outside its own folder (the Swift runtime, libc++),
  at that package's exact version, and no other package;
- the libraries are signed with the `ldid` of the application that is packaged with them;
- a target that links a Backports library gets the package as a `Depends` of its own package, and the package is
  copied into the outputs once.

The package is refused rather than written short when a library is not built, when a library names a path no
package holds, and when a library keeps a relative install name the package cannot resolve.

## Consequences

- `./xmakew deb -P .` builds every Backports library, not only the ones an application links: the package is one
  unit, and a library added to `frameworks/Backports/xmake.lua` joins it without another change.
- The shared packages keep their own folders and their own packages; the Backports package depends on them and does
  not carry them.
- The package is written by the toolchain's packaging module (`modules/apple/backports_package.lua`), not by a
  recipe, so it has no prebuilt key and is built from the current sources each time.

## Enforced by

`toolchain_packages/backports_package_test` (`toolchain/tests/addon/backports_package_test.lua`) builds a package
from two libraries and a shared package, and checks its file list, its control file (name, version, `Depends`,
installed size), that its libraries are signed and name their shared library by its folder, and that a library
naming an unheld package or an unresolved `@rpath` is refused.

## Not enforced

That an application packaged with the package installs and runs on a device, and that the whole iOS graph
configures so that `./xmakew deb -P .` can write it on a host: both need the prebuilt runtime packages, and are
checked when someone runs them.
