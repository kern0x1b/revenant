---
name: package
description: Turn the built app into a Debian package for a jailbroken device with Charon's `xmake deb` — the control file (Package, Name, Architecture iphoneos-arm, Maintainer, Depends), the version, what the build adds (Version, Installed-Size, the Depends on the backports or the shared Swift runtime), the dependency .debs written beside it, and how to inspect the result with dpkg-deb before it goes to a device or a Cydia repository. Use after a green build and the emulator check, when asked for a .deb, to change the package's identity or version, or when `xmake deb` refuses.
---

# Package the app

`xmake deb` builds the project, stages every target that names a control file, strips and signs
the binaries with `ldid`, checks every import against the release's own libraries **as a release
build** (a weak import the release lacks is refused here, where a plain build only warns), and
writes a `.deb`. For an app that uses `charon@apple-backports`, or shares the Swift runtime, it
also writes the `.deb` of each such dependency beside it and adds a `Depends` on it. At this pin a
Swift app that carries its runtime is refused here, and a shared runtime was never built (skill
`swift` §7). Read
`PROJECT.md` first: `## Identity` gives the package name, version and maintainer; `## Publishing`
says where the package goes next.

## 1. The control file

Write it by hand, for this app, at a path of the project (for example `packaging/control`), and
name it from the app's target:

```
set_values("charon.control", "packaging/control")
```

Fields, one per line, `Field: value`:

| Field | Value |
| --- | --- |
| `Package` | **required**; the package name from `PROJECT.md` (lower case, usually the bundle identifier). It names the `.deb` file |
| `Architecture` | **required**; `iphoneos-arm`, what Cydia and dpkg install on the rootful jailbreaks of the releases this stack builds for, 32- and 64-bit alike |
| `Name` | the display name a package manager shows |
| `Maintainer` | `Name <email>` from `PROJECT.md`; `Author` likewise if the author differs |
| `Section` | a Cydia section, for example `Utilities`, `Games` |
| `Description` | one line; further lines start with a space |
| `Depends` | what the app itself needs, for example `firmware (>= 6.0)` for `apple_minimum` 6.0. Never write the backports or the Swift runtime here: the build adds them with the exact version |

Never write `Version` or `Installed-Size`: the build writes both, and refuses a control file that
carries either. The version is the project's `set_version("1.0.0")` (or a target's
`set_values("charon.version", "…")` when the package is versioned apart from the project); without
one the build refuses to write the package. Raise the version for every package a user will
install over an older one.

Other values on the target, only when the app needs them: `charon.maintainer-scripts` (a folder
holding `preinst`, `postinst`, `prerm`, `postrm`, copied into the package), `charon.licenses` (files
copied to `/usr/share/doc/<Package>/`), `charon.entitlements` (a plist `ldid` signs into the
executable), `charon.install` (the folder the `.app` goes to instead of `/Applications`).

## 2. Write the package

```
xmake deb -y -v > .logs/deb.log 2>&1
```

`-o DIR` writes the packages to DIR instead of the build directory; a target name as the last
argument packages only the control file that target names.

Check, in `.logs/deb.log`: a line `deb build/<Package>_<Version>_iphoneos-arm.deb`, and for an app
with backports a line `deb build/org.charon.apple-backports_<release>+<digest>_iphoneos-arm.deb`
before it; no `error:`, no `add -v for getting more warnings` (without `-v` xmake shows only the
first warning). Selector warnings are the skills `build`'s and `backports`' concern: `xmake deb`
does not refuse them, so read every one, do not skip them.

When `xmake deb` stops with `these imports are not exported by the device's iOS:` and a symbol the
binary "weakly imports": the app calls an API the release lacks with no backport carrying it. Go
back to skill `backports` (a missing config, or an API that needs a version check); never waive it
to get a package.

## 3. Inspect it

```
dpkg-deb -I build/<Package>_<Version>_iphoneos-arm.deb
dpkg-deb -c build/<Package>_<Version>_iphoneos-arm.deb
```

`dpkg-deb` comes with Homebrew's `dpkg` (skill `install`). In `-I`, check:

- `Package:`, `Name:`, `Architecture: iphoneos-arm`, `Maintainer:` as `PROJECT.md` says;
- `Version:` equal to the project's version, and `Installed-Size:` present;
- `Depends:` your own entries, then, for an app with backports,
  `org.charon.apple-backports (>= <release>+<digest>)` — the exact version of the backports `.deb`
  written beside it — and, for a Swift app that shares its runtime, the runtime's packages.

In `-c`, check: `./Applications/<Name>.app/` with `<Name>` (the executable), `Info.plist` and the
app's resources; nothing under `/usr/lib/charon/org.charon.apple-backports/` (the backports are
**not** in the app's package; they come in their own); no source, no build artefact, nothing of
Apple's.

Inspect the backports package the same way when there is one: `Package: org.charon.apple-backports`,
`Architecture: iphoneos-arm`, its libraries under `./usr/lib/charon/org.charon.apple-backports/bands/`.
Its `postinst` links the band of the device's own release when it is installed, and refuses a
release outside the bands it carries.

## 4. What travels together

The app's `.deb` is not installable alone when it depends on the backports or a shared runtime:
dpkg refuses it until `org.charon.apple-backports` of at least that version is installed. Keep
every `.deb` this step wrote together:

- on the user's own device, skill `device`: `xmake device install` installs the dependency
  packages first, then the app;
- in a Cydia repository, skill `cydia-repo`: publish the dependency `.deb`s in the same repository
  — no public repository carries `org.charon.*` packages, so a user of the repository has no other
  way to get them.

Record in `PROJECT.md` `## Progress`: the `.deb` paths, and the `Package`, `Version`,
`Architecture` and `Depends` lines as `dpkg-deb -I` printed them. Then follow the skill `device` or
`cydia-repo`, as `## Publishing` says.

## Traps

- `Version:` in the control file → the build refuses it; the version comes from `set_version`.
- Writing `Depends: org.charon.apple-backports` by hand → it goes stale when the backports change;
  the build adds it with the exact version of the package it just wrote.
- Shipping only the app's `.deb` → it cannot be installed where the backports package is missing;
  ship every `.deb` the step wrote.
- `Architecture: armv7` or `iphoneos-armv7` → package managers of rootful jailbroken iOS install only
  `iphoneos-arm`; the CPU architecture is in the binary, not in the control file.
- Reusing a version for a changed app → a device that has it installed treats it as the same
  package; raise the version.
- A `charon.control` path that does not exist or lacks `Package`/`Architecture` → the build stops
  and names the file and the field.
- Packaging without looking at `xmake-addons.lock` → xmake 3.1.1 writes into it the Charon addon
  version *active on the machine*, not always the one `add_addons` pins, when another project on
  the machine installed a different Charon; check it names `version = "v0.8.10"` (the pin) before
  packaging. If it does not, stop and tell the user: the package would be built by another Charon.
- Changing the identity late (bundle identifier, package name) → `xmake device install` refuses an
  app over one with another bundle identifier; settle identity in the interview (skill `init`).
