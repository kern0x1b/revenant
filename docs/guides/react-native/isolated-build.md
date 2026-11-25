# Building the React Native host in your own folder

The host is built by `frameworks/ReactNative/tools/isolate.lua` from an application project (any folder whose root `xmake.lua`
includes the host and which holds the application's manifest). `isolate.lua` makes a build that shares no path with anyone else's, so several workers can build at once:
`copy` makes the copy and `build` builds from it.

## 1. Make the copy

```sh
./xmakew l -P . frameworks/ReactNative/tools/isolate.lua copy <project> <folder> --cache <your private cache> [--bundle-id <id>]
```

`<project>` is the application project, whose `build/` holds the inputs that [`inputs.lua make`](build-inputs.md) made.

The folder is new, and its path must not contain `test` or `Example` (the pod source filter used to read the whole path). The
command copies the hand-made inputs of `build/` with their absolute paths rewritten to the folder, links `build/ref` (the
application's `node_modules`, read only) and installs the `react-native` package with all its patches into the private cache.
`build/rn-src` links to those patched sources and `build/rn-headers` is relinked to them, so nothing is read from another
worker's tree. The sources are the install the recipe reports for this build, not another recipe's install that happens to
carry the same patches.

The copy carries the requirements of the whole configuration, the one the root `xmake.lua` makes when no `--component` is given:
`revenant@swift-runtime` shared, `revenant@libcxx` packaged, every libc++ dependency packaged too (`add_requireconfs("**.libcxx")`),
and `webkit-engine` as `frameworks/WebKit` declares it. It also declares the `component` option (default empty, so `--component`
selects one component as in the root) and `add_requireconfs("combine")` with `shared = get_config("component") == "" or nil`, the
same rule `frameworks/Combine` applies to its own `shared`; without it the application's `RN_DEPS_REPO` line makes `combine` build
its Swift runtime unshared, which changes the `swift-runtime` package key. The application's `swiftui`, `cryptokit`, `uniformtypeidentifiers` and `swift-crypto` take the shared runtime through
`add_requireconfs` lines that `copy` writes for each of them and for their dependants (`shared = true` and the SDK); each of the
three libraries is then a shared package of its own, `org.revenant.<name>-<hash>`, which the application binds by absolute install
names and does not carry. `copy` rewrites the application's plain `swift-runtime` and `libcxx`
lines into those forms and adds the lines it lacks; an application that declares `swift-runtime` or `libcxx` with other configs is
refused, because the packages would not be the ones the whole configuration builds. The install probes of `copy` and of `--real`
packages carry the same libc++ and Swift runtime lines, so the packages they install are the ones the copy links. `build` refuses
a copy whose `xmake.lua` lacks these lines and names the one missing; such a copy is made again with `copy`. The `webkit-engine` line is
added under `if not os.getenv("RN_WEBKIT") and not os.getenv("RN_HERMES")`, so an application's own `RN_WEBKIT` declaration (with `carried`)
applies when that is set, and the whole one applies when neither is set. A Hermes host (`RN_HERMES=1`) links neither WebKit nor
JavaScriptCore, so it does not require the engine package, and a build does not wait for a prebuilt of it or compile WebKit.

The host declares `libcxx` in `app.frameworks`, so that a build without the shared package carries libc++. The copy adds an
`after_load` rule to its `RNHost` target that removes `libcxx` from `app.frameworks`, because the shared `libcxx` package installs
libc++ and libc++abi, and the host loads them from `/usr/lib/revenant/org.revenant.libcxx-<hash>`. It is `after_load`, not `on_load`:
a second `on_load` replaces the host's own, which also holds its weak links.

The private cache is made with `./xmakew l -P . tools/private_cache.lua <your private cache>`. A cache made before the manifests were
rewritten is repaired with `./xmakew l -P . tools/private_cache.lua --repair <your private cache>`; without it the Swift compile does not
find the package modules such as Combine.

### A host that carries its own Swift runtime

`copy ... --embed-swift 1` sets `revenant.embed` on `RNHost`: the packages are built as for the shared host, and the step that writes the
application copies the libraries of `swift-runtime`, `swift-crypto`, `cryptokit` and `uniformtypeidentifiers` that the host reaches into
its `Frameworks` folder, names them `@executable_path/Frameworks/<name>` and signs them. libc++ and Backports are still loaded from the
phone. Use it on a phone whose installed Swift packages are of another build than the host's and must not change: a package name does not
say which runtime its libraries link.

## 2. Build

```sh
./xmakew l -P . frameworks/ReactNative/tools/isolate.lua build <folder> --cache <your private cache> [--target RNHost] [--real a,b] [--pods pkg:module,...] [--jobs N] [--log file]
```

The build is made against the stubs of the Expo modules. A module you are porting is built as real by naming it:
`--real expo-battery` for Expo packages (comma separated), `--pods react-native-pager-view:RNCViewPager` for community libraries
(`package:codegenModule`). The community pods named in the application's manifest (`build/app-manifest/host.json`, made from
the project's `--manifest` file) are built as real without `--pods`; `--pods` replaces that list. The command prints the exit code, the log
path and the errors it holds. The log is `<folder>/build/isolated.log` unless `--log` names another file. The sources of a
module come from its package in `packages/`, never from another worker's folder.

A module whose own dependencies are not packages yet (`ZXingObjC` for expo-camera, `SDWebImageWebPCoder` for
expo-image-manipulator) fails at `no such module`: package the dependency first.

## 3. A stale module cache

A Swift error such as `cannot assign value of type 'UnsafeMutablePointer<facebook.jsi.IRuntime>'` or `'pointee' is a 'let'
constant` means the shared clang module cache holds a `jsi` module built without the API notes. Delete the `jsi-*` and
`ExpoModules*` entries under `$TMPDIR/../C/clang/ModuleCache` and rebuild.

## 4. Installing next to other workers' builds

The phone has one `/Applications` and one `/var/tmp`. A build installed under the same bundle id replaces the one a colleague is
measuring, and a measurement made on a replaced app measures the wrong thing.

`isolate.lua copy` therefore gives the copy its own bundle id, in this order: `--bundle-id`, then the `bundleId` of the
application's manifest, then `org.revenant.rnhost.<the folder's name>` with anything but lower case letters, digits and dashes made
a dash. The id is printed when the copy is made, written as `bundleId` into the copy's `build/app-manifest/host.json`, and it is the
id the build puts into `CFBundleIdentifier`.

* Install and launch your app by that id and by a folder of your own, `/var/stash/<claim holder>/<last part of the id>.app`; never
  remove an app whose id is not yours.
* Name your id in the claim note and in every window request, so others see whose app is on the phone.
* The host reads its configuration and bundle from its own `.app`, never from `/var/tmp`: `/var/tmp` takes files from any
  process, and a configuration there names the code that runs. `./xmakew l -P . frameworks/ReactNative/tools/host_install.lua deploy
  --bundle FILE --conf KEY=VALUE,...` puts `bundle.js` and `rnhost.conf` inside `<app folder>/`, root-owned and not writable by
  others. The host refuses a file that is a symlink, is not owned by root, can be written by others, or resolves outside the
  `.app`, and logs the refusal. It reads only the keys `module`, `bundle`, `engine` and `JSC_*`.
* Control flags and the command file are in the same `.app`, written as root (`./xmakew device -P . run`): `rnhost.log.on` (log to
  `/var/tmp/<last part of the id>/rnhost.log`), `rnhost.fi` (frame interval), `rnhost.prof`, `rnhost.prof.stacks`, `rnhost.jsprof`.
  `rnhost.cmd` takes one command per line; the host runs each complete line once and only the lines appended after it, so append
  with `>>` and end the line with a newline. A rewrite in place with the same lines runs nothing; a replaced file (another inode) or
  one that no longer starts with the lines already run runs from its first line.
* The host writes its output to `/var/tmp/<last part of the id>/` (the log, `rnhost.cmd.out`, `rnhost.stack`, `rnhost.prof.out`,
  `rnhost.jsprof.out`). That folder belongs to the app's user, mode 700, and nothing the host writes there is read back. It is
  the one place on the phone that is not the claim's scratch folder, because the host runs as `mobile`, which cannot write
  under `/var/root`. The host limits it itself: the log and every appended file (`rnhost.cmd.out`, `rnhost.stack`,
  `rnhost.prof.out`) are truncated when they pass 1 MiB, and the log is truncated at each start. `host_install.lua deploy` is the
  only tool that writes into the scratch folder (the archive, removed after unpacking); `release` erases the rest.
* Two copies with the same bundle id share one `.app` and one `/var/tmp/<last part of the id>/`. The default id comes from the
  folder's name, so give a second folder of that name its own `--bundle-id`.

## Where a host build's time goes, and what the next one costs

Measured on the Paseo host (`module_build.lua`, copy `iso-paseo`, 2026-11-19/20). Times are wall clock, one process, load 24–30.

| Run | Time | What it was |
| --- | --- | --- |
| Cold, merged toolchain | 4176 s | libcxx source build ≈ 240 s; Backports wrapper install 1075 s + its configure 307 s (both slowed by the load); the rest is the other shared packages and the final build |
| Pre-merge toolchain, warm | 1833 s | Backports wrappers (15 + 3 libraries) ≈ 270 s; cryptokit wrapper configure 183 s; uniformtypeidentifiers wrapper configure 327 s; final build 331 s |
| Nothing changed, `--deb` | 665 s | no compile; the time is `xmake f -c`, package resolution and the wrapper configures |
| One provider file changed | 701 s | one swift compile of `expo-app-modules` 77 s and the link; the other ≈ 620 s is the fixed overhead above |
| Three libraries added to the link list | 486 s | Backports 19-library wrapper install 179 s, one swift compile, link |

Repeated work on the same code: of the 4176 s only the first-time builds (libcxx, the package installs keyed by a new content key) are unavoidable on a cold store, ≈ 1500 s. The rest, ≈ 2600 s, was waiting under load (the same installs ran at load 26–30) and the fixed overhead that every run pays again with unchanged inputs: a full `xmake f -c` reconfigure, package resolution, and the wrapper configures of cryptokit, uniformtypeidentifiers and Backports (≈ 500–600 s together). A run with no change costs 665 s only because of that overhead.

What the next build after a one-file edit costs with the isolated copy: the compile is one file (≈ 80 s for Swift) plus link, and the overhead is ≈ 400–600 s, so 8–12 min, which is inside the 20-minute rule but not "minutes". The cuts, in order of size: do not run `xmake f -c` when the configuration is unchanged (≈ 200–300 s); do not configure the wrappers whose key is unchanged (cryptokit 183 s, uniformtypeidentifiers 327 s in the pre-merge run); one Backports install per key (179 s when the library list changes). These are not done yet; each is a change to the build tools of its own.

`isolate.lua clone_project`: the clone is one `cp -cR` (APFS clone, 9600 files, ≈ 7.5 s, of which the copy is nearly all). The old order copied first and then walked the copy twice with `grep -rIlF` (find the files that name an old root, then check nothing is left): ≈ 0.4–1 s per pass on this tree. The new order searches the source once, clones, opens only the files found, and verifies only those; the symlink search skips `build/ref`. On this copy no file names an old root any more, so the measured gain is the second whole-tree pass (≈ 0.5–1 s of 7.5 s) and, for a tree that names roots in a few files, the rewrite and the verification touch those files only. The clone itself stays the cost; it is not on the minute scale.
