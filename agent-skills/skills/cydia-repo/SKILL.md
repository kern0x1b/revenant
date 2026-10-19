---
name: cydia-repo
description: Publish the app in the user's own Cydia repository (a source) — the directory layout, the Cydia fields of the control file, dpkg-scanpackages -m, Packages with .gz and .bz2, Release with its checksums, the depiction page and icons, the dependency packages (org.revenant.apple-backports, the shared Swift runtime) published beside the app because no public repository carries them, a local check, static hosting and adding the source on a device. Use after the skill package when PROJECT.md says the app is published through a Cydia repository, when releasing a new version into it, or when the user asks how others can install the app from Cydia.
---

# The user's own Cydia repository

A Cydia repository is a directory served over HTTP: the `.deb` files, an index of them
(`Packages`, compressed twice), a `Release` file that names the source and carries the index's
checksums, and optional pages and icons. Nothing runs on the server. You build the directory on the
user's machine; publishing it — pushing or uploading — leaves the machine, so it happens only when
the user says so.

Read `PROJECT.md` first: the package name, the version, the publishing decision and where the
repository is hosted. If the address it will be served from (the **base URL**, e.g.
`https://<user>.github.io/<repository>/`) is not decided, ask; the control file's links depend on it.

## 1. The Cydia fields in the control file

The app's control file (skill `package`) carries what Cydia shows. Besides `Package:`,
`Architecture: iphoneos-arm`, `Maintainer:`, `Description:` and the `Depends:` it already has:

```
Name: <display name>
Author: <Name <email>>
Section: <e.g. Utilities, Games, Productivity>
Depiction: <base URL>depictions/<package>.html
Icon: <base URL>icons/<package>.png
```

Never `Version:` or `Installed-Size:` — the toolchain writes both and refuses a control file that has them.
Then write the package again, the app's alone:

```
xmake deb -y -v <app target> > .logs/deb.log 2>&1
```

How to know it worked: the log's `deb build/...` lines name the app's `.deb` and every dependency
`.deb` written beside it, and `dpkg-deb -f build/<app>.deb Name Depiction Icon Depends` shows the
fields.

## 2. The repository directory

Keep the repository in a directory of its own, outside the app's project: it is published whole, and
the project holds sources and a build directory that must not be. Ask the user where (often its own
git repository, when the host serves one). Record the path in `PROJECT.md`.

```
<repo>/
  Release  Packages  Packages.gz  Packages.bz2
  CydiaIcon.png            the source's icon in Cydia's Sources list
  debs/                    every .deb, every version
  depictions/<package>.html
  icons/<package>.png
```

## 3. The packages, dependencies included

Copy into `debs/` **every** `.deb` that step 1's log names for this version: the app's, and each
dependency package — `org.revenant.apple-backports_<version>_iphoneos-arm.deb` when the app uses the
backports, the `org.revenant.swift-runtime-…` and `org.revenant.libcxx-…` packages when a Swift app
shares the runtime. The app's `Depends:` names them (`>=` for the backports, `=` for a shared
runtime), and no public repository publishes Revenant's packages: if this one does not carry them,
Cydia cannot install the app.

```
cp build/<app package>_<app version>_iphoneos-arm.deb build/org.revenant.apple-backports_<backports version>_iphoneos-arm.deb <repo>/debs/
```

Copy by the names the log printed, never `build/*.deb`: the build directory also holds older
versions, and the packages of probes and test stands (skill `checks`) that are never published.
Never delete a `.deb` already published: devices that installed it may still ask for it.

## 4. The index

From the repository's root — the paths in the index are relative to where it runs:

```
dpkg-scanpackages -m debs /dev/null > Packages
gzip -9nkf Packages
bzip2 -9kf Packages
```

`-m` keeps every version of a package in the index; without it only the newest is listed and the
older `.deb` files are unreachable. The warning `Packages in archive but missing from override file`
is expected (there is no override file). `dpkg-scanpackages` comes with `brew install dpkg`.

How to know it worked:

```
grep -c '^Package:' Packages                  # one entry per .deb in debs/
grep '^Filename:' Packages                    # each starts with debs/
grep -h '^Depends:' Packages | cut -d' ' -f2- | tr ',' '\n' | sed 's/^ *//; s/ .*//' | sort -u | comm -23 - <(grep '^Package:' Packages | cut -d' ' -f2 | sort -u)
```

The last command lists the dependencies that no package in the index provides. Only names the
device itself provides may remain — `firmware` (Cydia's package for the iOS release). Any
`org.revenant.…` name there is a missing `.deb`: go back to step 3. For a `=` dependency, check that the
exact version is in the index (`grep -A1 '^Package: <name>$' Packages`).

## 5. Release

Write the header once, in `<repo>/Release.head`:

```
Origin: <the source's name>
Label: <the source's name>
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm
Components: main
Description: <one line>
```

Then, every time the index changes, append the index files' checksums and sizes to it. Debian's own
tool for this, `apt-ftparchive release`, has no macOS build (Homebrew's `apt` requires `systemd`), so
the checksums are written with `openssl`:

```
{ cat Release.head
  for sum in MD5Sum:md5 SHA1:sha1 SHA256:sha256; do
    echo "${sum%%:*}:"
    for f in Packages Packages.gz Packages.bz2; do
      echo " $(openssl dgst -"${sum##*:}" -r "$f" | cut -d' ' -f1) $(wc -c < "$f" | tr -d ' ') $f"
    done
  done; } > Release
```

How to know it worked: `shasum -a 256 Packages.bz2` gives the hash on the `Packages.bz2` line of the
`SHA256:` block, and `gzip -dc Packages.gz | cmp - Packages` and `bzip2 -dc Packages.bz2 | cmp - Packages`
print nothing. Regenerate `Release` after every change to the index: its checksums are what the
device's package manager holds the downloaded index to.

## 6. Depiction and icons

- `depictions/<package>.html`, at exactly the URL the `Depiction:` field names: plain HTML with the
  styles inside the page — iOS 6's web view renders it, so nothing newer is needed. Say what the app
  does, the releases and devices it was checked on (from the evidence in `PROJECT.md`, not from
  hope), what it depends on, and what changed in each version.
- `icons/<package>.png`, at exactly the URL the `Icon:` field names: the app's own icon (the one the
  interview settled).
- `CydiaIcon.png` at the root: the source's icon. The user's own artwork, or one you draw — never
  Apple's.

## 7. Check it locally

Serve the directory and fetch everything a device will ask for:

```
npx --yes http-server -a 127.0.0.1 -p 8000        # in <repo>, in the background
for f in Release Packages.bz2 Packages.gz Packages CydiaIcon.png $(grep '^Filename:' Packages | cut -d' ' -f2) \
         depictions/<package>.html icons/<package>.png; do
  curl -s -o /dev/null -w "%{http_code} $f\n" "http://127.0.0.1:8000/$f"
done
```

Every line must say `200`; a `404` is a file missing or named differently from its link. Stop the
server afterwards.

## 8. Host it

Any static web host serves the directory as it is. On GitHub Pages, publish the repository directory
as the site's root and add an empty `.nojekyll` file so every file is served untouched. Ask the user
before the first push or upload, and before each one after.

The device fetches the source with its own network stack and trusts the certificates its release
trusts. Today a `github.io` address presents a chain that ends at `ISRG Root X1` (Let's Encrypt,
`openssl s_client -connect <host>:443 -servername <host>` shows it); whether an iOS 6 device accepts
it is not something this skill can check from the host. Confirm on a device (step 9) before telling
anyone the source works; if `https` is refused there, tell the user which host and address failed.

## 9. Add the source on a device

The user, in Cydia: Sources → Edit → Add, the base URL, then Add Source. Cydia lists the source with
its icon; the app is under its section and installs with its dependencies. When the user has a
device (skill `device`), this is the repository's real check — ask them what Cydia says.

## 10. A new version

`set_version` in `xmake.lua` → step 1 (`xmake deb` of the app) → step 3 (the new `.deb`, and each
dependency `.deb` whose version changed) → steps 4 and 5 → step 7 → publish after the user agrees.

## 11. Record

`PROJECT.md` `## Progress`, line `repository`: the base URL, the number of packages in the index, the
`SHA256` of `Packages.bz2` from `Release`, the local check's result, and whether a device has added
the source.

## Traps

- `dpkg-scanpackages` without `-m` → older versions vanish from the index while their files stay.
- Only the app's `.deb` published → Cydia cannot satisfy `org.revenant.apple-backports` (or the shared
  runtime); publish every dependency `.deb` the build wrote.
- `cp build/*.deb` → publishes old versions and the probes; copy by name.
- `dpkg-scanpackages` run inside `debs/` → `Filename:` paths lack `debs/` and every download fails; run
  it from the root with `debs` as the argument.
- `Packages` or `Release` edited by hand → the checksums no longer match; regenerate both, always in
  the order index, then `Release`.
- `Version:` in the control file → the toolchain refuses it; the version comes from `set_version`.
- A depiction or icon named after something other than the control file's URL → a missing page or a
  blank icon in Cydia.
- A `.deb` repacked with the host's `dpkg-deb -b` → it compresses its members with xz by default
  (the toolchain writes gzip, which every dpkg reads); never repack a package the toolchain wrote.
- Apple's artwork as an icon → never; the user's own or one you draw.
