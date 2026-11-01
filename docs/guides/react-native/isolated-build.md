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
