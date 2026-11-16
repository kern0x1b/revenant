# Installing the React Native host on the phone

`frameworks/ReactNative/tools/host_install.lua` makes an installable archive of a built host and puts it on the claimed phone. It
replaces the staging and deploy scripts of the spike.

```
./xmakew l -P . frameworks/ReactNative/tools/app_config.lua --output DIR APP_DIR
./xmakew l -P . frameworks/ReactNative/tools/host_install.lua stage --app BUILT.app --backports DIR --manifest DIR --output OUT [--bundle-id ID]
./xmakew l -P . frameworks/ReactNative/tools/host_install.lua deploy --archive OUT/host.tgz --bundle-id ID [--bundle FILE] [--conf engine=hermes,...]
./xmakew l -P . frameworks/ReactNative/tools/host_install.lua launch --bundle-id ID
./xmakew l -P . frameworks/ReactNative/tools/host_install.lua stop --bundle-id ID
```

## stage

`--app` is the built `RNHost.app`, `--manifest` the folder `app_config.lua` wrote `EXConstants.bundle` into, `--backports` the folder
with the `lib*Backports.dylib` files. The tool adds the manifest folder and the libraries, retargets every reference from
`/usr/lib/revenant/org.revenant.backports` to `@executable_path/Frameworks`, signs each Mach-O file with the `ldid` of the cache and
packs `OUT/host.tgz`. The folder `OUT` is emptied first.

With `--bundle-id` the executable is renamed to `RNHost-<last part of the id>` and `CFBundleExecutable` follows, so that two
installed hosts do not share a process name. Give it whenever more than one host can be on the phone.

## stage for a host that binds shared packages

A host built against the shared packages (`swift-runtime`, `libcxx`, `backports`, `swift-crypto`, `cryptokit`,
`uniformtypeidentifiers`) loads its libraries from `/usr/lib/revenant/<package>` and carries no `Frameworks` folder. Stage it without
`--backports` and name the build's package descriptions:

```
./xmakew l -P . frameworks/ReactNative/tools/host_install.lua stage --app BUILT.app --packages DIR[,DIR...] --manifest DIR --output OUT --bundle-id ID
./xmakew l -P . frameworks/ReactNative/tools/host_install.lua deploy --archive OUT/host.tgz --packages OUT/host-packages.json --bundle-id ID ...
```

`--packages` takes the `share/shared-packages` folders of the packages the host was linked against. Stage refuses a host that loads a
library from its own `Frameworks` (two copies of a library in one process crash it at launch), refuses a package folder the host
loads and no description names, and writes `OUT/host-packages.json` with the version each description gives and every Backports
symbol that the host and the packages it loads import, by library. `deploy --packages` asks the phone for each version with
`dpkg-query` and stops, naming the package, when one is missing or another version; install the packages of the build first. The
Backports package is the exception: it has one name on every phone and a colleague depends on its version, so another version only
prints a warning with both versions. What `deploy` checks instead is the state the phone is in: it copies the Backports libraries the host
loads from the phone, reads their exported symbols and stops, naming the library and the symbol, when one of the imports is not
exported. A host built against another Backports build starts when the installed libraries export everything it imports.

`deploy --packages` also reads which Swift runtime the packages on the phone link. Every package the process loads has to link the
runtime the host links: two runtimes in one process load two `libswiftCore`, and a string of the second stops the host with
`-[__SharedStringStorage _fastCharacterContents]: unrecognized selector`. A package that links another runtime, or one that is not
installed, stops the deploy naming the file, the package and both keys; install the package from a deb built against the host's
runtime. `xmake device runtimes` runs the same check over everything installed.

When the phone's Backports package is an older build than the host's, a folder with the libraries of the host's build can stand in for
it for one start: copy the folder to the phone, pass `--provided org.revenant.backports` to `deploy` (that package is then not
checked, nor are its symbols) and start with `launch --dyld FOLDER`. dyld looks for each library by file name in `DYLD_LIBRARY_PATH` before the install
name, so the folder's libraries load instead of the installed ones; a start from the home screen sets no variable and loads the
installed package. Remove the folder when the run is over.

## deploy

The phone must be claimed by your holder name. The app is installed by its bundle id, which `isolate.lua copy` gave your copy
(see [the isolated build](isolated-build.md)): `/var/stash/<holder>/<last part of the id>/<last part of the id>.app`, linked from
`/Applications`. Only the app of that id is removed, so a colleague's app stays. With `--bundle` the JavaScript bundle and the
configuration (`module=main`, that bundle and the `--conf` lines) are written inside the app as root-owned files, which is where the
host reads them. The host's output goes to `/var/tmp/<last part of the id>/` (it runs as `mobile` and cannot write the claim's scratch folder; the host
caps each file there at 1 MiB). The archive travels through the claim's scratch folder `/var/root/revenant-scratch/<holder>/` and is removed after unpacking.

## launch

Wakes the phone and has SpringBoard start the app of the id. It does not kill another process: stop what is running before you start
your app if the phone is short of memory.

## stop

Ends the running process of the app of the id and of no other. The phone has no `ps` or `pkill`, so the tool reads the process id from
the `launchctl` entry `UIKitApplication:<id>[...]` and kills that one process. It prints `stopped <pid>` or `not running`. Never use
`killall RNHost`: it kills every host on the phone, those of other workers too.

## A short window: `window`

`host_install.lua window` is the whole phone window in one command, so that the claim lasts about 20 minutes: claim the phone first
(`./xmakew device -P . --minutes=20 claim`), then

```
./xmakew l -P . frameworks/ReactNative/tools/host_install.lua window --archive host.tgz --bundle-id space.kern0x1b.paseo-ios6.rnhost \
  --packages host-packages.json --debs DEBS/org.revenant.swift-runtime-KEY_..._iphoneos-arm.deb,... \
  --probe probe.hbc --expect FileSystem,ExpoCamera,ExpoImage,ExpoSecureStore --restore-bundle bundle.hbc --output build/window
```

It installs only the packages of `--debs` whose version the phone lacks, one at a time with a 3 s pause (the phone has dropped off USB after
heavy writes), copies the host archive only when its sha256 differs from the one recorded beside the app (`<stash>/<name>.archive.sha256`),
puts the probe bundle in the app, launches it, waits 25 s and reads `rnhost.log` for the lines `rn-probe <module> <json>`. The probe is
`frameworks/ReactNative/src/probe/modules.js`: for each Expo module it reports whether the module is registered and its exports, and calls the
ones whose behaviour is known (a keychain round trip, the network state, the device model, the brightness, the store-review flag). It is compiled
with the package's `hermesc`: `hermesc -O -emit-binary -out probe.hbc modules.js`. `OUT/window.json` holds the answers, the modules of `--expect` that
never answered and the steps; `OUT/diagnostics/` holds the crash reports, the log and a screenshot. With `--restore-bundle` the application's own
bundle goes back, and the app is stopped. The command does not claim, lock or release the phone: the session does, with `revenant-unlock lock`
and `./xmakew device -P . release` right after it.
