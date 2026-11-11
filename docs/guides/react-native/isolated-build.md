# Building the React Native host in your own folder

The host is built by `frameworks/ReactNative/tools/isolate.lua` from the application project (`paseo-app`, whose root `xmake.lua`
includes the host). `isolate.lua` makes a build that shares no path with anyone else's, so several workers can build at once:
`copy` makes the copy and `build` builds from it. The spike's scripts `isolate.sh` and `build-isolated.sh` were removed from
paseo-app (5321a86); their last state is at e6522b0.

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
its Swift runtime unshared, which changes the `swift-runtime` package key. `copy` rewrites the application's plain `swift-runtime` and `libcxx`
lines into those forms and adds the lines it lacks; an application that declares `swift-runtime` or `libcxx` with other configs is
refused, because the packages would not be the ones the whole configuration builds. The install probes of `copy` and of `--real`
packages carry the same libc++ and Swift runtime lines, so the packages they install are the ones the copy links. `build` refuses
a copy whose `xmake.lua` lacks these lines and names the one missing; such a copy is made again with `copy`. The `webkit-engine` line is
added under `if not os.getenv("RN_WEBKIT")`, so an application's own `RN_WEBKIT` declaration (with `carried`) applies when that is set
and the whole one applies when it is not.

The private cache is made with `./xmakew l -P . tools/private_cache.lua <your private cache>`. A cache made before the manifests were
rewritten is repaired with `./xmakew l -P . tools/private_cache.lua --repair <your private cache>`; without it the Swift compile does not
find the package modules such as Combine.

## 2. Build

```sh
./xmakew l -P . frameworks/ReactNative/tools/isolate.lua build <folder> --cache <your private cache> [--target RNHost] [--real a,b] [--pods pkg:module,...] [--jobs N] [--log file]
```

The build is made against the stubs of the Expo modules. A module you are porting is built as real by naming it:
`--real expo-battery` for Expo packages (comma separated), `--pods react-native-pager-view:RNCViewPager` for community libraries
(`package:codegenModule`). The community pods named in the application's manifest (`build/app-manifest/host.json`, made from
`rn-spike/host.json`) are built as real without `--pods`; `--pods` replaces that list. The command prints the exit code, the log
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
  `rnhost.jsprof.out`). That folder belongs to the app's user, mode 700, and nothing the host writes there is read back.
* Two copies with the same bundle id share one `.app` and one `/var/tmp/<last part of the id>/`. The default id comes from the
  folder's name, so give a second folder of that name its own `--bundle-id`.
