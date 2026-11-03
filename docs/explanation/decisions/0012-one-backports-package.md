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
  `/usr/lib/revenant/org.revenant.backports/<library>`, with the FFmpeg HEVC libraries those libraries link, in the same
  folder; and the Vision text models of the tessdata package, under `/var/lib/revenant/tessdata/{fast,best}`; and the
  licences of the tessdata models and of the decoder, under `/usr/share/doc/org.revenant.backports/licenses/`;
- its version is the addon's release and a hash of the libraries, the models and what they depend on, so a changed
  library or model is a new version, and an application that depends on it names that version exactly;
- its `Depends` names the shared package of each library it names outside its own folder (the Swift runtime, libc++),
  at that package's exact version, and no other package: the FFmpeg decoder and the models are carried, not depended on;
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
- The models are about 330 MB unpacked, and `/usr` is the system volume with about 25 MB free on the iPad, so the models
  are under `/var`, where the device has about 13 GB. The loader reads that folder.
- The package is written by the toolchain's packaging module (`modules/apple/backports_package.lua`), not by a
  recipe, so it has no prebuilt key and is built from the current sources each time.

## Enforced by

`toolchain_packages/backports_package_test` (`toolchain/tests/addon/backports_package_test.lua`) builds a package
from two libraries and a shared package, and checks its file list, its control file (name, version, `Depends`,
installed size), that its libraries are signed and name their shared library by its folder, and that a library
naming an unheld package or an unresolved `@rpath` is refused. It also builds a library that names a carried FFmpeg
decoder by another folder, with a model and a licence, and checks that the decoder is named in the package's folder,
that the model and the licence sit in their folders, and that no `Depends` is written for them.
`toolchain_packages/vision_text_test` checks the model paths of the tessdata package, an unknown model, and a missing licence.
The CI check of the built package, `toolchain/tools/deb_check.lua`, is enforced by `toolchain_light/deb_check_test`
(`toolchain/tests/addon/deb_check_test.lua`): a package with exactly the files of the list above passes, and a package
that adds a model the vision text list does not name, a model at another level, another FFmpeg library, another licence
or any other file is refused by name; so is one without the FFmpeg decoder.

## Not enforced

That an application packaged with the package installs and runs on a device, and that the whole iOS graph
configures so that `./xmakew deb -P .` can write it on a host: both need the prebuilt runtime packages, and are
checked when someone runs them.
