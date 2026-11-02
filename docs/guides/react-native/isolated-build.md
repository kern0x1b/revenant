# Building the React Native host in your own folder

The host build lives in the spike project (`paseo-app/rn-spike`) until it becomes a component of this repository. Two scripts
there make a build that shares no path with anyone else's, so several workers can build at once: `isolate.sh` copies the project
and `build-isolated.sh` builds from the copy.

## 1. Make the copy

```sh
sh paseo-app/rn-spike/tools/isolate.sh <folder> <your revenant worktree> <your private cache>
```

The folder is new, and its path must not contain `test` or `Example` (the pod source filter used to read the whole path). The
script copies the hand-made inputs of `build/` with their absolute paths rewritten to the folder, links `build/ref` (the
application's `node_modules`, read only) and installs the `react-native` package with all its patches into the private cache.
`build/rn-src` links to those patched sources and `build/rn-headers` is relinked to them, so nothing is read from another
worker's tree.

The private cache is made with `./xmakew l -P . tools/private_cache.lua <folder>`. A cache made before the manifests were
rewritten is repaired with `./xmakew l -P . tools/private_cache.lua --repair <folder>`; without it the Swift compile does not
find the package modules such as Combine.

## 2. Build

```sh
sh <folder>/rn-spike/tools/build-isolated.sh <your revenant worktree> <your private cache> [RNHost|expo-jsi-probe]
```

The build is made against the stubs of the Expo modules. A module you are porting is built as real by naming it:
`REAL=expo-battery` for Expo packages (comma separated), `PODS="react-native-pager-view:RNCViewPager"` for community libraries
(`package:codegenModule`). The log is `<folder>/build/isolated.log`; the script prints the errors it holds. The sources of a
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

`isolate.lua copy` therefore gives the copy its own bundle id: `--bundle-id`, or `org.revenant.rnhost.<the folder's name>` with
anything but lower case letters, digits and dashes made a dash. It is printed when the copy is made, and it is the id the build
puts into `CFBundleIdentifier`.

* Install and launch your app by that id and by a folder of your own, `/var/stash/<claim holder>/<last part of the id>.app`; never
  remove an app whose id is not yours.
* Name your id in the claim note and in every window request, so others see whose app is on the phone.
* The host reads its configuration and bundle from its own `.app`, never from `/var/tmp`: `/var/tmp` takes files from any
  process, and a configuration there names the code that runs. `./xmakew l -P . frameworks/ReactNative/tools/host_install.lua deploy
  --bundle FILE --conf KEY=VALUE,...` puts `bundle.js` and `rnhost.conf` inside `<app folder>/`, root-owned and not writable by
  others. The host refuses a file that is a symlink, is not owned by root, can be written by others, or resolves outside the
  `.app`, and logs the refusal. It reads only the keys `module`, `bundle`, `engine` and `JSC_*`.
* Control flags and the command file are in the same `.app`, written as root (`./xmakew device run`): `rnhost.log.on` (log to
  `/var/tmp/<last part of the id>/rnhost.log`), `rnhost.fi` (frame interval), `rnhost.prof`, `rnhost.prof.stacks`, `rnhost.jsprof`.
  `rnhost.cmd` takes one command per line; the host runs each complete line once and only the lines appended after it, so append
  with `>>` and end the line with a newline. A rewrite in place with the same lines runs nothing; a replaced file (another inode) or
  one that no longer starts with the lines already run runs from its first line.
* The host writes its output to `/var/tmp/<last part of the id>/` (the log, `rnhost.cmd.out`, `rnhost.stack`, `rnhost.prof.out`,
  `rnhost.jsprof.out`). That folder belongs to the app's user, mode 700, and nothing the host writes there is read back.
* The spike host still reads `/var/tmp/rnhost.*` and `/var/tmp/real.js`. It must move to this host before a window is shared with it:
  two workers who share those paths must not run in the same window.
