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
loads and no description names, and writes `OUT/host-packages.json` with the version each description gives. `deploy --packages`
asks the phone for each version with `dpkg-query` and stops, naming the package, when one is missing or another version; install
the packages of the build first. The Backports package has one name on every phone, so its version is the one a colleague may
depend on: build the host against that version rather than replacing the package.

## deploy

The phone must be claimed by your holder name. The app is installed by its bundle id, which `isolate.lua copy` gave your copy
(see [the isolated build](isolated-build.md)): `/var/stash/<holder>/<last part of the id>/<last part of the id>.app`, linked from
`/Applications`. Only the app of that id is removed, so a colleague's app stays. With `--bundle` the JavaScript bundle and the
configuration (`module=main`, that bundle and the `--conf` lines) are written inside the app as root-owned files, which is where the
host reads them. The host's output goes to `/var/tmp/<last part of the id>/`.

## launch

Wakes the phone and has SpringBoard start the app of the id. It does not kill another process: stop what is running before you start
your app if the phone is short of memory.

## stop

Ends the running process of the app of the id and of no other. The phone has no `ps` or `pkill`, so the tool reads the process id from
the `launchctl` entry `UIKitApplication:<id>[...]` and kills that one process. It prints `stopped <pid>` or `not running`. Never use
`killall RNHost`: it kills every host on the phone, those of other workers too.
