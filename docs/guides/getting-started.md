# From a clean clone to a green test run

This guide takes a Mac from a `git clone` to two results: `./xmakew test -P .` ends green, and the Backports
library builds. Every command in it was run from a clean clone, on an empty revenant home, with `-j 2` where a
build takes a job count. The first configure installs the packages the project needs: in the verification run that
was thirteen, most of them built from source (boost and dynarmic among them), and it took about five minutes. The
Swift component, which CI's `swift` job builds, is not part of these steps.

## What you need

- An Apple silicon Mac with the Command Line Tools: `xcode-select --install`. CI selects Xcode 26.6
  (`.github/workflows/check.yml`); the run this guide was checked on used the Command Line Tools.
- Network access to github.com, for the clone, the package sources and the prebuilt releases.
- Disk space: the verification run's package store and build folders took between 4 and 6 GB across two runs of the steps below.

## 1. Clone

    git clone https://github.com/kern0x1b/revenant.git
    cd revenant

## 2. Read the map

[The README](../../README.md) says what the repository holds. [The architecture](../explanation/architecture.md)
says what the three layers are, and [the decisions](../explanation/decisions/README.md) say which rules are
enforced by a check and which are not. Neither is needed to run the commands below.

## 3. Configure

    REVENANT_PREBUILT=kern0x1b/revenant REVENANT_PREBUILT_ONLY=llvm,swift,ld64 ./xmakew f -P . -y --emulator_vulkan=n

The first run of `./xmakew` builds the pinned xmake under `~/.revenant/cache/xmake/`, which takes a few
minutes. The two variables take LLVM, Swift and ld64 from kern0x1b/revenant's releases; without them those
three are built from source, which takes hours: LLVM alone is about 3,200 build steps. `--emulator_vulkan=n` leaves the emulator's Vulkan backend
off, as CI does.

## 4. Run the tests

    ./xmakew test -P . -j 2

The last line reads `100% tests passed, 0 test(s) failed`. A count of expected failures is reported on the same
line, and it does not make the run red.

To see the cheap checks first, which take seconds:

    ./xmakew test -P . 'repository/*'

[The toolchain's tests](../reference/toolchain/tests.md) say what each suite covers and what needs a device.

## 5. Build the Backports library

    REVENANT_PREBUILT=kern0x1b/revenant REVENANT_PREBUILT_ONLY=llvm,swift,ld64 ./xmakew f -P . -p iphoneos -a armv7 --component=Backports -y -v
    ./xmakew l -P . frameworks/Backports/tools/generate.lua
    ./xmakew build -P . -j 2

The first command selects the Backports component, which `frameworks/Backports/xmake.lua` defines. The second
reads the facts of every framework and writes the generated sources under `build/generated/backports`. The third
builds the libraries. They land in `build/iphoneos/armv7/release/`, one `lib<Name>Backports.dylib` per framework, for
example `libFoundationBackports.dylib`. The build took about ten minutes on the re-run of the merged branch, which
also checked the exports report.

This reconfigures the checkout, so step 3 has to be run again before the tests. [The Backports overview](../../frameworks/Backports/README.md)
lists what each library provides.

## When something stops

- `package(<name>) is being accessed by other processes, please wait!` means another install holds that
  package's lock. It goes on when that install finishes. It can also appear within one run, when two installs
  of the same package meet. If it does not clear, look for a stuck xmake with `pgrep -fl xmake`.
- If the step 5 configure prints `Building CXX object` lines for LLVM, it was started without the two prebuilt
  variables. Stop it and run step 5 again with them, as written above.
- To keep a trial apart from your own cache, export `REVENANT_HOME` and `XMAKE_GLOBALDIR` to empty folders
  before step 3. The pinned xmake binary under `~/.revenant/cache/xmake/` is still shared.
- To give the cache back, see [the machine guide](machine.md).
