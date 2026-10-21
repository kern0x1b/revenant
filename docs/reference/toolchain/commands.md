# Commands

The xmake verbs the toolchain adds, their options and defaults, the verdicts and files of an emulated run, and the environment variables the toolchain reads. The verbs are plugins under `toolchain/plugins/`. Run them from a port's folder, with `xmake`; the revenant checkout itself is built with `./xmakew`.

## Build and package

| Command | What it does |
| --- | --- |
| `xmake` | Builds. Every binary is checked as it links. |
| `xmake deb` | Stages the package, strips, signs, and writes `build/<Package>_<Version>_<Architecture>.deb`. A target with several `apple.architectures` is built for each slice and the bundles are merged with `lipo`. |
| `xmake where PACKAGE` | Prints the folder a required package is installed in. |
| `xmake compile-commands [-o FILE] [TARGETS]` | Writes `compile_commands.json` for the named targets. |
| `xmake check [--staged \| --changed] [NAMES]` | Runs the project's checks. `--staged` and `--changed` limit them to the staged or changed files. |
| `xmake check --install-hook` | Makes the git pre-commit hook run the staged checks. |

## device

`xmake device [-d NAME] [-s SECONDS] [--holder=NAME] [--minutes=N] [--keep] ACTION [ARGUMENTS]`

| Action | What it does |
| --- | --- |
| `install` | Builds and packages as `xmake deb` does, then installs the packages on the phone with `dpkg -i`. Refuses an application over one with another bundle identifier. |
| `uninstall [--keep]` | Removes the packages named. `--keep` leaves the shared runtime packages no program needs any more. |
| `log [TEXT]` | Reads the phone's log for `-s` seconds (default 15), filtered by `TEXT`. |
| `run COMMAND` | Runs a command on the phone for `-s` seconds. |
| `where` | Prints the phone the bound `device.env` names. |
| `list` | Lists the attached devices, with their UDID, product, iOS release, tunnel and lease. |
| `claim`, `release` | Holds the device for `--holder` for `--minutes` (default 30), so every other holder's command is refused until the release or the expiry. |

`-d NAME` picks `device.NAME.env`. The phone is named in that file by `DEVICE_HOST`, `DEVICE_PORT`, `DEVICE_UDID` and `DEVICE_PASSWORD`.

## emulate

`xmake emulate [-d DEVICE] [-r RELEASE] [-s SECONDS] [-t SECONDS] [-n NETWORK] [--scale N] [-k] [--prune-hours N] ACTION [ARGUMENTS]`

| Option | Default | Meaning |
| --- | --- | --- |
| `-d`, `--device` | the first device of the configured architecture the emulator has a profile for, and that runs the release | the device to emulate, for example `iPhone3,1` |
| `-r`, `--release` | `apple_minimum` | the release; the earliest firmware not older than it is emulated |
| `-s`, `--seconds` | 60 | how long a run may take to start; with `launch`, how long SpringBoard may take to accept the launch, and with `until-exit`, how long the application may run |
| `-t`, `--timeout` | 900 | the wall-clock limit of a whole boot; after it the emulator is told to quit, then killed |
| `-n`, `--network` | the target's `emulate.network`, else `isolated` | `isolated`, `loopback` or `host` |
| `--scale` | 10 | host seconds per guest second; see [the scale](../../explanation/toolchain/design.md#the-guest-clock) |
| `-k`, `--keep` | off | keeps the root filesystem a run booted, beside its log |
| `-a`, `--all` | off | with `clean`: every port's images and every golden image |
| `--prune-hours` | 24 | how long an unused image may sit before the next `xmake emulate` removes it |

| Action | What it does |
| --- | --- |
| `install` | Puts the packages of the port, and the Backports targets if it is used, into the image of the emulated device, and runs their maintainer scripts against it. |
| `run COMMAND` | Starts `COMMAND` in a fresh clone of the image and reports a verdict. |
| `launch BUNDLE-ID [STEP ...]` | Installs, registers the application with SpringBoard, has SpringBoard launch it, and keeps its output and a snapshot. Steps follow the identifier: `tap X Y`, `drag X1 Y1 X2 Y2` (in points), `home`, `until-exit`. |
| `debug COMMAND` | Starts `COMMAND` as the guest's first process under the emulator's debugger, and prints where it stopped. |
| `log [TEXT]` | Prints what the last run wrote, filtered by `TEXT`. |
| `shot [FILE]` | Copies the last frame. |
| `clean` | Removes this port's images, or every image and golden image with `-a`. |

`until-exit` holds the guest until the application has ended, so an application that produces a result over time is given the time to produce it. The verdict then says in `held` whether the application's own end (`exited`) or the run's budget (`deadline`) came first.

### Verdicts

`xmake emulate run` ends with one of:

- `pass`
- `fail(exit N)`
- `timeout`
- `crash(signal N)`: the program counter and the last frame are printed too.
- `boot-blocked(...)`: the boot stopped before the command ran, and the verdict names where: the emulator, a process that keeps crashing, SpringBoard, or the data migration.

The verdict also carries `guest_seconds` (the guest's own clock, measured by the runner), `host_seconds` (the wall-clock length of the boot), and `daemons` (how many of the firmware's LaunchDaemons registered their services, and how long that took).

### Files of a run

Each run keeps its files in the image's `run` folder:

| File | Holds |
| --- | --- |
| `verdict` | the verdict above |
| `results` | the guest's own results, written under `/private/var/revenant` |
| `emulator.log` | the emulator's log |
| `frame.png` | the last frame |
| `debug.json` | with `debug`: the registers and the images the guest had loaded |
| `app-0.png`, `app.stdout`, `app.stderr` | with `launch`: the snapshot after the screen settled, and the application's output |

A boot that never ran the command, whose reports show a daemon was killed, is explained from the CrashReporter reports the guest wrote, which are copied beside the verdict.

## firmware

`xmake firmware [-a ARCH] [-d DEVICE] [-o OUTPUT] [-l LIBRARY] ACTION [RELEASE]`

| Action | What it does |
| --- | --- |
| `fetch RELEASE` | Fetches the system libraries of the release for the import check: the shared cache, or the library folder before iOS 3.1. |
| `rootfs RELEASE` | With `-d`: unpacks the whole root filesystem of the device's earliest firmware not older than the release, into `~/.revenant/firmware/rootfs/<device>/<version>_<build>/`. From iOS 16 the SystemOS cryptex is included. |
| `classes RELEASE` | Writes the release's Objective-C inventory as JSON beside its cache, with `-o` to choose the path. |
| `extract RELEASE` | With `-l`: takes one library out of the shared cache as a Mach-O of its own, to be read, not run. |
| `list` | Lists what is held. |

`-a` is one of `armv6`, `armv7`, `armv7s`, `arm64` and `arm64e`; the default is the configured architecture. Firmware and caches are downloaded from Apple's servers and from the catalogue kept in `~/.revenant/firmware/catalog.json`. Only the system image is downloaded.

## Environment

| Variable | Read by | Meaning |
| --- | --- | --- |
| `REVENANT_HOME` | the caches, firmware and emulator folders | the root of the state folders, default `~/.revenant` |
| `REVENANT_RELEASE` | the import check | pins the release, so weak imports the release lacks are refused |
| `REVENANT_DEVICE` | `xmake device` | the `device.NAME.env` of the whole shell |
| `REVENANT_DEVICE_HOLDER` | `xmake device` | the holder the whole shell claims as |
| `REVENANT_SWIFT_MODULES` | the `swift` rule | folders of the Swift modules a package installs, set by the package with `package:setenv` |
| `REVENANT_SWIFT_PORT_HEADERS` | the `swift` rule | the port's headers, which the compiler sees in place of the SDK's |
| `REVENANT_ASSETS_EXTRACT_CACHE` | `tools/assets-extract` | where the tool builds itself |
| `LLVM_PREFIX` | the `ld64` package | the prefix of the `llvm` package, from which `llvm-config` finds `libLTO` |
| `XMAKE_GLOBALDIR` | `./xmakew` | the package store, default `~/.revenant/cache/xmake-global` |
