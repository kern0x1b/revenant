# The toolchain

Legacy Apple platforms for [xmake](https://xmake.io): armv6 from iPhone OS 2.0
to 4.2.1, armv7 from iPhone OS 3.0, armv7s from iOS 6 and arm64 from iOS 7, built
by clang 23 from the `llvm` package with no Xcode. An `apple_minimum` outside the
releases its architecture runs is refused, naming the architectures that do run
it: a port that asks for 2.0 on armv7 is told to build armv6, never handed a 3.0
binary that says it is one.
A port is an ordinary `xmake.lua` in each module; the toolchain adds what xmake does not
know about these platforms, and nothing else:

- an **addon** - the `apple-ios` toolchain, the `tweak` rule, the checks every
  binary is held to where it is linked (Thumb interworking, `__PAGEZERO`,
  `LC_ENCRYPTION_INFO`, system calls a minimum release lacks, and every import
  against the device's own dyld shared cache), strip and `ldid` signing,
  reproducible Debian packages (`xmake deb`) and the phone (`xmake device`);
- a **package repository** - the SDK, ld64 from cctools-port, ldid and
  libplist, and the libraries ports share, each under `revenant@name`.

## A port

    set_project("kindlesyncfix")
    set_version("1.0.2")
    set_policy("package.requires_lock", true)

    add_repositories("revenant https://github.com/kern0x1b/revenant.git main")
    add_addons("revenant v0.8.4")
    set_config("apple_minimum", "6.0")
    includes("@addon/revenant/apple-ios")

    set_defaultplat("iphoneos")
    set_defaultarchs("iphoneos|armv7")

    target("kindlesyncfix")
        add_rules("@addon/revenant/tweak")
        add_files("kindlesyncfix.m")
        add_frameworks("Foundation")
        set_values("tweak.filter", "packaging/kindlesyncfix.plist")
        set_values("revenant.control", "packaging/control")

The rules, and the values each reads:

    @addon/revenant/tweak    a MobileSubstrate dylib; tweak.filter, revenant.install,
                           revenant.libraries (packages whose shared libraries it
                           loads, carried in /usr/lib/revenant/<Package>)
    @addon/revenant/daemon   an executable in /usr/libexec (revenant.install), with
                           its LaunchDaemons plist through add_installfiles, and
                           revenant.libraries as a tweak
    @addon/revenant/app      Name.app with app.plist-file, app.plist ("KEY=VALUE",
                           over the file), app.resources (folders copied flat into
                           the bundle), app.frameworks (packages whose shared
                           libraries go to Frameworks under their install names,
                           and shared-library targets the app add_deps(), all
                           loaded through @executable_path), app.url-scheme
    @addon/revenant/library  a shared library an application bundles: checked
                           where it links, stripped, signed and import-checked
                           with the bundle
    @addon/revenant/swift    added next to one of the above, compiles the target's
                           .swift files as one module, of the whole language when
                           the project requires revenant@swift-runtime (and
                           revenant@libcxx), which the port carries, or of Embedded
                           Swift when it requires revenant@swift-embedded, and
                           refuses both or neither; swift.module (the module
                           name, default the target's), swift.flags

and, on any of them, revenant.entitlements (signed with ldid and read back),
revenant.strip (default -x), revenant.control, revenant.maintainer-scripts,
revenant.licenses (into /usr/share/doc/<Package>/) and
revenant.waive.<check> "reason". Every object a target links and every member of
its packages' static archives has to record the port's minimum release; a
package that cannot is waived with revenant.waive.input-minimum.<package>. Info.plist keys the file and app.plist leave
out are derived: the bundle and executable name, the project version, and
MinimumOSVersion. The files a tweak, daemon or app target names with
add_installfiles go into its package at the path given, under the package root.
The rules strip after their checks, with revenant.strip, because the Thumb
interworking check reads the names of the functions a binary's code pointers
point at: where a release mode (mode.release, mode.releasedbg, mode.minsizerel)
would strip a target that sets no strip of its own at the link, the target is
linked with -dead_strip, as that strip would, and keeps its symbols until the
checks have run. A target that sets set_strip("all") itself arrives stripped at
the check and is refused.
A checkout nested inside another project (a worktree under
the main checkout) builds with `xmake -P .`; the rules refuse otherwise.

Then:

    xmake                      build; every binary is checked as it links
    xmake deb                  stage, strip, sign and write build/<Package>_<Version>_<Architecture>.deb
    xmake device install       the same, then dpkg -i on the phone device.env names,
                               refusing an app over one with another bundle identifier
    xmake device log [-s 30] [TEXT]
    xmake device run COMMAND, xmake device where
    xmake device list          the attached devices, their tunnels and who holds them
    xmake device --holder=NAME [--minutes=30] claim|release
                               hold a device so every other holder's command on it
                               is refused until the release or the expiry;
                               REVENANT_DEVICE_HOLDER names the holder for a shell
    xmake emulate install      the same packages into the image of an emulated device
    xmake emulate [-s 60] [--scale 10] run COMMAND
                               start COMMAND in it and report pass, fail, crash,
                               timeout or boot-blocked; -d DEVICE, -r RELEASE
    xmake emulate launch BUNDLE-ID [tap X Y | drag X1 Y1 X2 Y2 | home ...]
                               install, register the application with SpringBoard,
                               have SpringBoard launch it, keep its output and a
                               snapshot once its screen settles and after each step
    xmake emulate debug COMMAND
                               start COMMAND as the guest's first process under
                               the emulator's debugger and print where it stopped
    xmake emulate log [TEXT], xmake emulate shot [FILE]
    xmake queue -- COMMAND     run a build in one of this machine's build slots
    xmake emulate [--all] clean remove this port's images (--all: every image and golden image)
    xmake borrow PACKAGE ...   take installs this store lacks from another store
    xmake where PACKAGE        the folder a required package is installed in
    xmake check [--staged|--changed] [NAMES]
                               the project's checks; xmake check --install-hook
                               makes the git pre-commit hook run the staged ones

An application declared with `add_values("apple.architectures", "armv7", "arm64")`
is packaged universal: `xmake deb` takes the slice of the configured
architecture from the ordinary build and configures and builds each other one in
its own folder under the build directory - each slice for the release its architecture first runs where `apple_minimum` is older and another slice keeps it (arm64 at 7.0 beside armv7 at 6.0; the port is told once, and an architecture built alone at a release it never ran is still refused; the configured architecture is the one to build for the oldest release) - merges the bundles with lipo - every
other file has to be the same in every slice, so pin MinimumOSVersion in the
plist - and signs and checks the merged binaries. A slice with no shared cache
under ~/.revenant/dyld is said to be unchecked. The reader understands every
shared cache format from iOS 3.1 to today - 32-bit and arm64/arm64e, single
files and the split caches of iOS 15 on, whose subcache files it opens by the
suffixes the main header lists - deciding which header fields exist from the
header's own size, and the library folders of earlier releases. The same reader
takes the Objective-C inventory of those library folders, so `xmake firmware
classes` answers for iPhone OS 2 and iPhone OS 3.0 as it does for a cache. An import is looked up where dyld looks for it: in
the library its binding names and in what that library re-exports, so a
symbol the device exports only from another library is refused. A weak import
the checked release does not export is reported as a warning naming the binary
and the first twelve symbols, because it is NULL on the device and only a check
for it makes the call safe - and refused when the image is released, that is
under `xmake deb`, in Revenant's own guest programs, or with REVENANT_RELEASE set,
unless the target waives it with `revenant.waive.weak-imports` and says why every
call is guarded; for the symbols the compiler emits by itself -
the ARC entry points, the block runtime, emulated TLS and the wide atomics,
listed beside `ARRIVED` in `modules/apple/compat.lua` - it is refused instead,
naming what should have carried it into the image, since no version check can
stand in front of a call the compiler wrote. That is what catches an ARC port
whose link left out `-fobjc-arc`, so clang never force-loaded arclite. After the
imports, every selector the build's binaries reference (`__objc_selrefs`) that
neither they nor any class or protocol of the checked release implements is
reported as a warning naming the binary, the first twelve and all of them
under `xmake -v`: such a message must only be sent behind
`respondsToSelector:` or a version check, which no static reading can see.
Methods of the build's own classes, of its categories, including those on
classes it imports, and of the protocols it records count as implemented; a
protocol no class adopts is not recorded, and its optional methods are
reported. The release's selectors are cached as `selectors_<arch>.txt` beside its
cache; methods a runtime component adds at run time (arclite's subscripting)
are declared by that component in a `__DATA,__port_addsel` section and
count as implemented.

A check is a target:

    target("lint-strings")
        add_rules("@addon/revenant/check")
        set_values("check.script", "scripts/lint-strings.sh")
        add_values("check.files", "src/**.m", "src/**.h")
        set_values("check.pass-files", true)

check.script runs a script with the interpreter its extension names (.sh, .rb,
.pl, .js); check.command runs any program. A check runs when a file it
names is staged or changed, and on every run without --staged or --changed,
when it is given every tracked file it names; check.needs-files keeps it quiet
while there are none. A script that calls xmake again passes the task first:
`xmake where -P DIR tdlib`, not `xmake -P DIR where`, which xmake reads as a
target name.

`xmake compile-commands [-o FILE] [TARGETS]` writes compile_commands.json for
the named targets only, e.g. the iOS ones without the host tests.
A target sets `revenant.version` when its package is versioned apart from the
project.

Below iOS 7 an executable starts through Apple's `crt1.3.1.o` (or `crt1.o` below
3.1), which current SDKs no longer ship; ld64 would silently raise the binary's
minimum to 7.0 instead. The `iphoneos-sdk` package puts back into `usr/lib`
what the SDKs of iPhone OS 2 to iOS 6 carried there: `crt1.o`, `crt1.3.1.o`,
`dylib1.o` and `bundle1.o` built from Apple's open Csu, and
`libgcc_s.1.tbd`, the stub of the `/usr/lib/libgcc_s.1.dylib` that clang links
below iOS 5 and that holds those releases' arithmetic helpers and SjLj
unwinder, listing what the library exports on every release from 3.1.3 to
6.1.3. The SDK's libSystem stubs hide those symbols from 3.0 to 4.3 so they bind
to libgcc_s; the package extends that to iPhone OS 2, whose libSystem did not
export them either. An SDK whose stubs carry no `$ld$` marker at all, such as
26.2's, is not fit as it comes: the package takes the markers from the 16.5 SDK's
stubs (one archive, downloaded beside it), library by library by install name,
and for the symbols of libSystem that 16.5 does not have it writes one hide marker
for each release the 16.5 markers name below the first release the held dyld
caches export the symbol from (`markers/iPhoneOS26.2.tsv`, written by
`tools/sdk-markers.lua`). So the linker of 26.2 knows what the one of 16.5 knew, and
`__Unwind_GetIPInfo` still binds to libgcc_s below iOS 5. A libSystem without any hide
marker is refused whatever its version. Only libSystem gets markers derived, as in 16.5, where the frameworks' newer API is told apart by availability and weak links, not by markers (the rule agrees with 16.5's own libSystem hides for 181 of 184 symbols, measured; for the other three, libdispatch's `dispatch_assert_queue`, `dispatch_assert_queue_not` and `dispatch_queue_create_with_target`, the answer of 16.5 stands: hidden only at 10.0, where the caches say 7.0). The SDK's stubs also say only for armv7 and armv7s where
symbols lived on iOS 7 to 10 (`$ld$hide$os7.0$` in CFNetwork, `$ld$add$os7.0$`
in Foundation for NSURLCache, NSURLRequest and their neighbours), although
arm64 ran those releases too; the package repeats each such marker for arm64,
so an arm64 slice for iOS 7 binds them where the device has them. A helper iPhone OS 2 lacks altogether, such as
`__floatundidf`, fails to link there instead of failing to load. The package is
laid out as an Xcode developer folder
(`Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/`),
so clang's driver finds the toolchain's `libarclite_iphoneos.a` beside it,
which it force-loads into anything linked with `-fobjc-arc` below iOS 9 and
Xcode stopped shipping in 14.3. Revenant's own arclite defines the ARC entry
points hidden in each image: each tail-calls the system's implementation when
the running iOS has one (5.0 on), so the autoreleased-return handshake keeps
working, and otherwise sends retain, release and autorelease; below iOS 5 it
also gives `__weak` its zeroing references (the toolchain tells clang the
runtime has them): the side table lives in arclite, NSObject's `-release`
clears an object's weak references under a short lock just before its last
release and `-dealloc` again, so a load never resurrects an object on its way
out and no lock is held while user code deallocates; a class that manages its
own retain count is refused with the reason and the process aborts. Below iOS
5 that includes every toll-free bridged object - NSString, NSArray,
NSDictionary and the rest are CoreFoundation objects, released by
CoreFoundation, which gained `_tryRetain` and `_isDeallocating` only in 5.0 -
so a weak reference to one works from iOS 5 on and aborts below it. Below iOS
6 it adds the subscripting methods the collection classes lack. Below iPhone
OS 3.2, where clang weak-imports the blocks runtime, the toolchain links the SDK's
`libBlocksRuntime.a` (with libobjc, which its block classes are built on):
`_NSConcreteStackBlock` and the other block isa symbols are aliases of real
Objective-C classes defined in the image, so a block is an object from its
first instruction, and `_Block_copy`, `_Block_release`, `_Block_object_assign`
and `_Block_object_dispose` tail-call the system's runtime when the running
release has one and implement the clang block ABI themselves on 3.0 and 3.1. The rules
refuse a binary whose recorded minimum is not the port's.

`includes("@addon/revenant/apple-ios")` requires the SDK, ld64 and ldid at the
versions it pins, and hands every other package the `apple-ios` toolchain named
with those versions and `apple_minimum`, so a change of any of them rebuilds
what was built with it. The SDK is 16.4; a project whose source needs a newer
one sets `apple_sdk` before the include (`set_config("apple_sdk", "26.2")`), and
the package carries the versions it lists. A library comes from here as `revenant@name`. The rules
bind the same toolchain to their targets. Commit `xmake-requires.lock` and
`xmake-addons.lock`. The addon is pinned by its tag: a new release is a new
tag in `add_addons` (and a fresh `xmake-requires.lock`, since the addon and the
package repository move together), projects on different tags keep their own installs, and a
branch or a range is avoided - xmake resolves those against its own clone of
this repository, which it does not pull again once it has one. The import check reads
the system libraries of the earliest release of each slice's architecture that
is not older than the port's minimum - iOS 6.0 for an armv7 6.0 port, 7.0 for
its arm64 slice - from `~/.revenant/dyld/<release>/` (under `$REVENANT_HOME` if
set): `dyld_shared_cache_<arch>` and its subcaches, or `libraries_<arch>/`
for a release before 3.1, which has no cache. When they are not held, the
check offers to fetch them (`-y` accepts) and `xmake firmware [--arch=ARCH]
fetch RELEASE` does it by hand; `xmake firmware list` shows what is held. `xmake firmware
--device=IDENTIFIER rootfs RELEASE` unpacks the whole root filesystem of that
device's earliest firmware not older than the release (with the SystemOS
cryptex under `System/Cryptexes/OS` from iOS 16) into
`~/.revenant/firmware/rootfs/<device>/<version>_<build>/`, the input an emulator
boots. `xmake firmware [--arch=ARCH] classes RELEASE` writes the release's
Objective-C inventory - every class with its superclass, image, instance and
class methods and protocols, categories merged in - as JSON beside its cache,
read from the objc2 metadata in the cache: 32-bit and arm64 caches, pointers
decoded by the mapping's slide info (v1 to v5), relative method lists with
selector offsets, and the lists of lists iOS 17 on prebuilds. `xmake firmware
[--arch=ARCH] --library=NAME [--output=PATH] extract RELEASE` takes one library
out of a cache as a Mach-O of its own, to be read rather than run: the segments
with their file offsets and sections rebuilt, the link edit the image points
at, the local symbol names the cache keeps aside where the image says
`<redacted>`, and rebase opcodes made from the slide info of the 32 bit caches,
which cached images do not carry themselves. A cache copied
from a running device, whose pages hold pointers the device slid, is refused
with the command that fetches the release's cache from the firmware. The
release and its firmware come from a catalog of api.ipsw.me and
theapplewiki's firmware tables, kept in `~/.revenant/firmware/catalog.json` and
refreshed when a minimum is newer than anything it lists. Only the system image
is downloaded, by byte ranges of the IPSW on Apple's servers; the FileVault
images of iOS 2 to 9 are decrypted with the key theapplewiki publishes, the
Apple Encrypted Archives of iOS 18 on with the key Apple's wkms server hands
out, and the image is mounted to copy the cache (from the SystemOS cryptex on
iOS 16 on) or the libraries. A check that would have to be skipped is waived by name
with the reason, e.g. `set_values("revenant.waive.pagezero", "why")`.

`xmake emulate` runs the port on an emulated device instead of a phone, on a
macOS arm64 host. `includes("@addon/revenant/emulate")` after the `apple-ios`
include requires `revenant@emulator` - the emulator, Revenant's own emulator (MPL-2.0;
provenance and required attribution in its NOTICE), which boots a firmware's
own userland over an emulated XNU on macOS arm64 hosts; it is pinned by
commit, with the fixes it has not taken yet as patches under
`packages/e/emulator/patches/` - with
`revenant@swiftshader`, the CPU Vulkan driver its OpenGL ES is drawn through, and
`revenant@emulator-guest`, `revenant-runner` and `revenant-sblaunch` built by the
`daemon` rule for the port's architecture and minimum. The device is `-d`, or the first device of
the catalog of the configured architecture that emulator has a profile for and
that runs `-r` (default `apple_minimum`); its earliest release not older than
that is the one emulated. A device without a profile, or a release whose
Darwin the emulator does not emulate, is refused with the reason, never replaced by
another. The first run of a device and build unpacks its root filesystem as
`xmake firmware rootfs` does, marks Setup Assistant done - in the mobile user's
`com.apple.purplebuddy` preferences, which iOS 6.0 reads, and in lockdownd's
`com.apple.purplebuddy` domain, which 6.1 reads instead - and boots it once
past the first-boot data migration into a golden image under `~/.revenant/emulator/golden.noindex/`, keyed
by device, build and the emulator package; `install` clones it (an APFS clone
per port and device) and unpacks the data member of each package `xmake deb`
writes into the clone, through the image's own symbolic links, and runs each
package's maintainer scripts against the clone the way dpkg runs them against a
root, with `DPKG_ROOT` naming it: that is how a package whose libraries depend
on the release - `revenant@apple-backports` - links the ones built for the image's
own iOS, and a script that refuses the image stops the install and says why. `run` clones
that image again, puts a LaunchDaemon into `/System/Library/LaunchDaemons` of the image (the only folder
iOS 6's launchd reads) that starts `revenant-runner`, which starts COMMAND, once launchd has
registered the Mach services the firmware's LaunchDaemons declare (the verdict's `daemons` says
how many and how long that took), with a deadline of `-s` seconds and writes its exit status, signal and output into
`/private/var/revenant`; the boot is quit once that verdict is there, and killed
when `-t` seconds pass. The verdict, the guest's results, the emulator log and
the last frame stay in the image's `run` folder, and the clone the run booted
is removed unless `-k` keeps it. A golden image of an older emulator package is
removed when the golden image of the new one is made. A crash names the signal, the program counter the
emulator saw and the last frame, and a boot that never ran the command names
where it stopped: the emulator, a process that keeps crashing, SpringBoard or
the data migration.

`run` starts a program as a child of `revenant-runner`, outside SpringBoard, so a
UIKit application started that way never reaches
`application:didFinishLaunchingWithOptions:`. `launch BUNDLE-ID` starts one through
SpringBoard, so it does reach it, but not the way a tap on its icon does: the
launch is `SBSLaunchApplicationForDebugging`, which gives the application an
environment of its own (`CFLOG_FORCE_STDERR=1`, `NSUnbufferedIO=YES`) and its
standard output and error in files. What a run shows (an application that
printed, a tap that redrew it) stays true; what a tap's environment would add
or change is not checked. For each application bundle a package puts under
`/Applications`, `install` removes MobileInstallation's cache from the image
(`com.apple.mobile.installation.plist`, which `uicache` rewrites on a device),
and MobileInstallation builds it again from `/Applications` at boot, as on a
firmware's first boot, so SpringBoard lists the application. `launch` installs,
and has the runner start `revenant-sblaunch`, which waits up to `-s` guest seconds
for SpringBoard to take the launch through `SBSLaunchApplicationForDebugging`
and make the application frontmost, with the application's standard output and
error in `/private/var/revenant/app.stdout` and `app.stderr` (unbuffered, and
`NSLog` to standard error too). While SpringBoard refuses because the screen is
locked, `launch` unlocks it over the emulator's control channel. Then it has the emulator
`settle` and, once the screen has not changed for 60 display periods of guest
time, writes a snapshot, `app-0.png`, into the run folder; then it takes each
step given after the bundle identifier - `tap X Y`, `drag X1 Y1 X2 Y2` in points,
`home` - settles and takes a snapshot after each, and quits. One step is the
driver's own and is not sent to the emulator: `until-exit` holds the guest until the
application has ended, so a port whose application produces its result over time
is given the time to produce it, then settles and takes one more frame; the
verdict says in `held` whether the application's own end (`exited`) or the run's
budget (`deadline`) came first. The budget is `-s` again: the guest seconds the
application may run from the moment it is frontmost, counted by the host's clock at
the time scale. The runner's verdict file does not end the hold; it is written when
`revenant-sblaunch` returns, at launch. It prints the application's output, the snapshots and the run folder, which
is where a program that wrote into `/var/revenant` left them, and fails naming
SpringBoard's refusal, the signal or status the application ended with, or that
its process never started; `log` prints the output again and `shot` the last
frame. The guest has no network unless `-n` or a target's
`emulate.network` value says `loopback` or `host`. Several ports and sessions
emulate at once: golden images are built in a folder of their own and renamed
into place under a file lock, so a second session waits for the first instead
of building the same image, and a boot takes one of `min(cores/3, RAM/5 GB)`
slots of the machine, with the emulator's caches kept per slot.

Several sessions building at once are what makes a machine slow, and a run
started on top of that measures the queue rather than the guest. A run
therefore waits for the machine to quiet down - the load average below the
number of cores - but only for a while, and then starts anyway, because a busy
machine must still make progress. Builds can take a slot of their own:

    xmake queue -- xmake build          one of this machine's build slots
    xmake queue -c 3 -- xmake f -y      a different number of them

The slot is taken by the outermost `xmake` only: the command it runs carries
`REVENANT_BUILD_SLOT`, and a build that starts another build inside it runs in
the slot already held, so a nested build never waits for its own parent. This
is a queue for the builds that ask for it, not a limit on the machine: a
`xmake build` started beside it does not see the slots and does not wait.

A session that builds in a store of its own - `XMAKE_GLOBALDIR` pointing
somewhere other than the home - starts with nothing in it, and the host
packages it needs first are the ones that take longest to build: the compiler
alone is an hour. What another store has already built it can take instead:

    xmake borrow llvm swift             from the store beside $HOME
    xmake borrow --from=/path llvm      from another one, named with = as
                                        the packages follow the options

An install is taken under the same path it had, because the digest in that path
is what xmake looks an install up by, so what is taken answers for the configs
it was built with or is not used at all. On APFS the copy is a clone and costs
no space; where the filesystem cannot clone, it is an ordinary copy. An install
the store already holds is left alone, and a name the source store holds
nothing of is refused rather than passed over - a package the machine provides
of itself is never in a store to begin with.

The guest's clock runs slower than the host's, because the emulator is one to
two orders of magnitude slower than the device and the guest measures its own
watchdogs and RPC deadlines in wall-clock seconds. `--scale` is how many host
seconds one guest second takes, 10 by default: backboardd gives an app about
20 guest seconds to finish launching, an app needs up to two host minutes of
this emulator, and 10 covers that with room to spare without making the
guest's own waits the length of a run. Measured on iPhone4,1 6.1.3 over 11
minutes of booting: at 1 backboardd killed six processes (Setup and MobileMail
among them) and SpringBoard restarted five times, at 5 and 10 those kills are
gone. The scale is a property of the run, not a hidden
correction: it is in the emulator's log, in the verdict and in the line a run
prints, and a verdict carries `guest_seconds` (the guest's own clock, what the
runner measured) beside `host_seconds` (the wall-clock length of the boot), so
a test that measures time can convert. A target that measures time itself says
`set_values("emulate.timing", "strict")` and the run refuses any scale but 1
rather than hand it a converted number. Everything the guest reads
from its clock is scaled together - `mach_absolute_time`, `gettimeofday`,
dispatch timers and kevent deadlines all come from the one virtual clock the
emulator paces.

What the guest kills, the guest explains: the reports it writes into
`/private/var/logs/CrashReporter` are copied beside the verdict, and the reason
the first of them names (`mediaserverd: RPCTimeout message received to
terminate [0] with reason 'InitializeSystemSoundPorts'`) is part of a blocked
boot's verdict line. A boot that ends while a thread is still receiving the
reply to a request it sent waited for an answer that never came - a hole in the
emulation, not a slow guest - so the verdict names that request, the process
and how long it waited. A daemon parked on its service port is not that and is
not reported.

A device test of a library - a program that prints its own result and exits with
the number of failures, needing no UIKit and no SpringBoard - runs on an
emulated device like this, against a working copy of this repository:

    -- xmake.lua of the test port
    add_repositories("revenant /path/to/revenant")   -- the copy with your changes
    add_addons("revenant latest")
    set_config("apple_minimum", "6.0")
    add_requires("revenant@apple-backports", {alias = "apple-backports"})
    includes("@addon/revenant/apple-ios")
    includes("@addon/revenant/emulate")

    target("backports-test")
        set_kind("binary")
        add_rules("@addon/revenant/daemon")
        add_files("test.m")
        add_packages("apple-backports")
        add_frameworks("Foundation")
        set_values("revenant.version", "1.0")
        set_values("revenant.control", "packaging/control")

    xmake f -p iphoneos -a armv7 -y
    xmake emulate -d iPhone3,1 -r 6.0 install
    xmake emulate -d iPhone3,1 -r 6.0 run /usr/libexec/backports-test
    xmake emulate -d iPhone4,1 -r 6.1.3 install && xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/backports-test

A program that crashes on the guest says only where it stopped, and the
emulator prints that as a number. `xmake emulate debug /usr/libexec/port`
starts it as the guest's first process - nothing else boots, so what the report
holds is the program and what it loads - stops where it crashes and says what
it was doing:

    /usr/libexec/crasher stopped with signal 11 on iPhone3,1 6.0 (10A403)
      #0  pc     0x0000bf86  crasher`_wrong + 0x6
      #1  lr     0x0000bf7d  crasher`_main + 0x34
      #2  return 0x36e20b20  libdyld.dylib + 0x1b20

The toolchain speaks the debugger's protocol itself, because no debugger on an arm64
host talks to an armv7 guest. The frames are the chain the frame pointer holds,
and they are named by what the guest itself says it has loaded - dyld's own
list of images, which carries the shared cache's libraries as well as the
port's - with the nearest symbol of the images the image holds as files. The
whole reading, registers and images included, is left beside the log as
`debug.json`.

A port that carries the backports into a tweak or an application names them in
`revenant.libraries` the way the target knows them - `apple-backports`, the alias
the require carries - and not the repository they came from. The install of the
package is what a port links against, and the resolution a project has already
made is cached, so a change to the backports' sources or to their build module
is a different package that `xmake f -c` installs, where `xmake f` alone leaves
the port linking against the install it had.

`install` puts both packages into the image - the port's and the
`revenant@apple-backports` one `xmake deb` writes beside it - and runs their
maintainer scripts, so the libraries of the image's own release are linked.
`run` starts the program with the deadline of `-s`, and its exit status is the
verdict: `pass`, `fail(exit N)`, `timeout`, `crash(signal N)` or
`boot-blocked(...)`. `xmake emulate log` prints what it wrote.

A package of a port that builds with CMake calls the addon's bridge from its
install script, which writes a toolchain file from the `apple-ios` toolchain
(clang from the `llvm` package, `-target`, `-isysroot`, ld64, the SDK and
the package's installed dependencies as find roots) and configures, builds and
installs with Ninja:

    on_install("iphoneos", function (package)
        import("@addon.revenant.apple.cmake").install(package, {"-DBUILD_TESTING=OFF"})
    end)

xmake's own `package.tools.cmake` does not pass a custom compiler for iphoneos.
The third argument takes `cflags`, `cxxflags`, `ldflags`, `shflags`, `system`
(`Darwin` for projects such as LLVM's runtimes that recognise Apple only by that
name; no deployment target is set then, the flags carry it); `targets` builds
only those, and
`install = false` skips `cmake --install` - `install` returns the build folder
for a package that copies what it needs; `deps` (true, or dependency names)
turns what those packages declare - include folders, defines, flags, links -
into the toolchain file, so a C++ package names `{deps = {"libcxx"}}` instead of
spelling the runtime out; `prune` removes installed paths such as `lib/cmake` or
`lib/*.la`, and `licenses` copies the named files into the package's licenses.

A library without a build system of its own, a list of sources, is compiled by
`import("@addon.revenant.apple.sources").static(package, {files = {...},
includedirs, defines, cflags, cxxflags, mflags, mxxflags, deps, headers,
headers_prefix, licenses, prune, name})` into lib<name>.a with the toolchain's
flags, the language taken from each file's extension. A script that runs make
or autoconf itself ends with `import("@addon.revenant.apple.install").finish(package,
{prune = ..., licenses = ...})`.
Every package the port requires gets `-O3` with the toolchain, as a release
build of a Makefile or autotools project expects. An install script runs in the
extracted source, so its current directory is the source root.
The bridge runs CMake with IPHONEOS_DEPLOYMENT_TARGET, which reaches tools that
take no flags, such as an assembler a configure script calls. A script that
runs make or autoconf itself passes
`import("@addon.revenant.apple.envs").build(package, import("package.tools.autoconf").buildenvs(package))`
as its envs; a host step of a two-stage build (a generator built for macOS)
runs with the process environment, which does not carry it.
`revenant@libcxx` is libc++ 23 as the shared pair an application bundles, linked
with `revenant@apple-compat`, the hidden shims for what the minimum release lacks.
It is checked against the devices' own libraries from iPhone OS 2.2.1 to iOS
6.1.3. Below iOS 4.2, whose dyld cannot re-export single symbols, libc++ does
not re-export libc++abi and a client links both, as the package's links say;
below 3.0 apple-compat also carries `posix_memalign` and the integer-to-float and
byte-swap helpers iPhone OS 2's libgcc_s lacks.

Every compilation names the linker it is for with `-mlinker-version`, the
version of the ld64 package: clang 23 otherwise assumes the newest Apple
linker and emits `objc_msgSendClass$` class message stubs on arm64, which only
that linker synthesizes.

`thread_local`, `_Thread_local` and `__thread` compile for every release. dyld
reads `__thread_vars` on 32-bit iOS from 9.0 and on arm64 from 8.0; below that
the toolchain adds `-femulated-tls`, and a thread-local variable lives behind a
pthread key through `__emutls_get_address`, with C++ destructors registered by
`__cxa_thread_atexit`. The `llvm` package is clang 23.1.3 with the change that
lets it accept thread-local variables for a Darwin release under emulated TLS
and call `__cxa_thread_atexit` instead of dyld's `_tlv_atexit`, which iOS 6
does not have and iOS 7 and 8 leave empty on armv7. Both entry points are
exported by the libc++abi of `revenant@libcxx`, one copy for the whole process: a
copy in each image numbers variables on its own, and two images then read each
other's storage. The compiler's `libclang_rt.ios.a`, built by the same package,
leaves emutls out, so an image that does not link the runtime fails to link
rather than getting a copy of its own.
An atomic the processor cannot update in one instruction, such as a
`std::atomic` of a structure wider than a word, compiles to `__atomic_load`,
`__atomic_store`, `__atomic_exchange` and `__atomic_compare_exchange` calls,
which libSystem has from iOS 7.0 and which clang otherwise refuses to emit for an
older release. The `llvm` package's clang emits them for every iOS release, and
below 7.0 the libc++abi of `revenant@libcxx` exports compiler-rt's implementation,
re-exported by libc++, one copy for the whole process: it picks the lock for a
memory location from a table, and two images with tables of their own would
guard the same memory with different locks. The builtins leave it out as well,
so an image that makes these calls without the runtime fails to link.
Swift compiles as Embedded Swift, the subset without a runtime library of its
own: classes, structures, protocols and generics, closures, `any` existentials,
`throws`, arrays, dictionaries and strings, with no Objective-C interoperability,
reflection (`Mirror`), `Codable` or `async`. A port requires
`add_requires("revenant@swift-embedded", {alias = "swift-embedded"})` and adds the
`@addon/revenant/swift` rule to its target; C calls Swift through `@_cdecl`
functions, and a `main.swift` is the program's entry point. The result loads
nothing but libSystem, with `posix_memalign`, `arc4random_buf` and `putchar` the
calls of note; swift_test holds armv7 and armv7s at 6.0 and arm64 at 7.0 to the
devices' libraries, and older releases are not checked yet. `revenant@swift` is the compiler of the
release, built from the sources of its own tag - swift, swiftlang's LLVM, cmark,
swift-syntax, the string-processing library and the driver with its four
packages, each pinned to the commit its tag named - with two changes an iOS
older than Swift's own minimum needs. The frontend takes `-bundled-swift-runtime`:
the runtime ships with the program, so the features of this Swift release are
available at any deployment target, while the SDK's own availability is checked
as before, and the flag is written into a module interface so that whoever
compiles it reads the same. The driver stops refusing a deployment target below
iOS 7, which it had as its own minimum. `revenant@swift-bootstrap` is the swift.org
release toolchain, pinned by its digest and cut to the driver, the frontend,
their host libraries, the package manager and clang's headers; it compiles the
Swift sources of the compiler, because building a Swift compiler takes a Swift
compiler to begin with. Only `revenant@swift` is what a port uses: a compiled Swift
module loads only in the compiler that wrote it, and the Command Line Tools'
swiftc moves with macOS. The sources of the release are installed beside the
compiler, for the packages that build a module or a runtime from them. `revenant@swift-embedded` builds the `Swift`
module for the port's architecture and oldest release from those sources, the
way the Swift build does for its own Embedded targets, and the Unicode tables it
calls as a static library, and names its compiler in `SWIFT_EXEC`. The rule has
swiftc write LLVM bitcode and the `llvm` package's clang make the object: the
LLVM inside Swift 6.4 loads the stack guard of armv7 code through an absolute
address, and an executable with such text relocations loses PIE.

`revenant@swift-runtime` is the Swift runtime itself, built for the port's
architecture and oldest release from those sources: the standard library, its
Objective-C interoperation and reflection, concurrency, the C library's Swift
overlay, Synchronization, Observation and the regular expression libraries. What
the runtime calls and the release lacks comes from apple-compat, renamed where a
header can do it (`clock_gettime`, `clock_getres`, `dispatch_get_global_queue`,
whose class of service iOS 6 answers with NULL) and under its own name where the
compiler emits the call. Three changes are made to the runtime's sources: a
class the runtime instantiates is realized by a method lookup where
`objc_readClassPair` (iOS 8) is not there; a deadline is handed to libdispatch
as a duration where `dispatch_time_t` does not yet carry which clock it counts
(before iOS 12), which also avoids the fixed 125/3 timebase the runtime assumes
on ARM; and Synchronization and Observation name `os_unfair_lock_lock` and its
pair by symbol instead of importing `os/lock.h`, whose declaration carries iOS
10. The standard library's availability macros are rewritten to `*` for the same
reason the frontend takes the flag.

No Python runs in that build. The `.gyb` templates the runtime, its overlays,
Embedded Swift's module and Combine are generated from are expanded by
`modules/gyb`, a port of Swift's `utils/gyb.py` to Lua: the template language
itself, and an interpreter for the Python its code blocks and the helper modules
beside `gyb.py` (`SwiftIntTypes.py`, `SwiftFloatingPointTypes.py`,
`GYBUnicodeDataUtils.py`, `gyb_stdlib_support.py`) are written in, down to the
float formatting, arbitrary-precision integers and the Mersenne Twister of
`random.Random`. A recipe calls `gyb.template`'s `expand_to`; CMake calls
`xmake l modules/gyb/main.lua`, which takes `gyb.py`'s `-D`, `-o` and
`--line-directive` and a `--path` that says where `%import` looks, and which the
runtime's `gyb.cmake` is patched to run (`GYB_COMMAND`). A construct it does
not implement (a statement, an expression, a builtin, a module) raises an error
instead of being guessed at. The interpreter's
sources are part of the runtime's recipe digest (`modules/digest.lua`).

The runtime with Objective-C interoperation has iOS 6.0 as its floor. Built with
`SWIFT_CLASS_IS_SWIFT_MASK=1`, a Swift class marks itself with the low bit of
its `data` word. iOS 6.0's Objective-C runtime (objc4-532) masks that bit off
when it reads the word; iOS 5.1.1's does not, reads the class's read-only data
one byte off and follows a wild pointer at the first class it realizes. Below
6.0 the runtime would have to register no standard-library class with
Objective-C, giving up the Foundation bridges, or be adapted to that older
runtime. Embedded Swift registers nothing with Objective-C and is not bound by
this floor.

The runtime is built without library evolution unless its `library_evolution`
config asks for it (below), and that is a decision with consequences worth
knowing. A resilient layout makes a client's class need the
metadata update of iOS 12's Objective-C runtime (`_objc_realizeClassFromSwift`),
and the runtime stops with "class ... does not have a fragile layout" where that
is missing; a runtime that ships with the program needs no ABI stability anyway.
So: Swift modules built by different builds of the runtime do not mix in one
image, and everything is compiled together, which the package's hash already
enforces; two packages do not hand Swift types across their boundary, the same
line libc++ draws; and the `.swiftinterface` of these modules is not a stable ABI
contract. libswiftCore carries a mark naming the build it is, which a port links
against by name, so a program built against one build cannot be linked against
another; the package's own test links a program both ways and expects the second
to fail.

`library_evolution=true` is the other build: the standard library, the runtime and
concurrency the way Apple builds them, with resilient layouts and the symbols that
keep their ABI. It exists for a program that an SDK's Swift compiled and that binds
to those symbols by name (an Xcode-built demo needs `$sSQ2eeoiySbx_xtFZTq`, the
resilient `Equatable` operator), such as what the recompiler lifts; a port of this
repository's own does not want it, for the reason above. Three things about it.
It is part of the build hash, so it is a different package from the default one, with
its own shared-runtime name, and the mark still names the build: a program is linked
against exactly the runtime it was compiled with in both configs. It writes no
`.swiftinterface`: the compiler compiles an interface it emits again to check it, and
one built for this release cannot pass (the availability macros are all "always
available", as the runtime ships with the program, and the compiler holds
`InlineArray`'s value generic to iOS 26 and Observation's concurrency to iOS 13), while
the only readers of an interface are clients built by another compiler than the one
that built the runtime, which no port here is; a client reads the binary module. And an
arm64 install stops after Darwin: the overlays past it the SDK has for arm64, and
building this runtime's own beside the SDK's stops on QuartzCore (the SDK's Foundation
interface puts `CGFloat` in CoreFoundation, the overlay built here in CoreGraphics), so
an arm64 consumer expecting `libswiftFoundation` from this package finds none and takes
the SDK's; armv7 installs every overlay. Measured through the recipe: arm64 and armv7
install with it, armv7 without it.

A Swift library is a package the same way: it requires `revenant@swift-runtime`,
compiles its modules with the runtime's compiler and flags, installs them as
static libraries with their `.swiftmodule`s, and names the folders a port's
Swift finds them in with `package:setenv("REVENANT_SWIFT_MODULES", ...)`; the
swift rule adds those folders to the compile. `revenant@combine` is the first:
OpenCombine at a pinned commit with the patches in `packages/c/combine/patches`, a
single module named `Combine` — the core, the Dispatch scheduler and the
Foundation integration compiled together — with its C++ helper and that helper's
module map, so a port writes `import Combine`. The scheduler takes `DispatchTime`
distances from its own arithmetic, since the runtime's Dispatch overlay (from
Swift 5.4.3) has no `DispatchTime.distance(to:)`; the `URLSession` data task
publisher is declared from iOS 7, and a run loop timer's tolerance is read and
set only behind `#available`, so the module builds and runs on iOS 6 with
availability checking on. With `sources = true` the recipe installs the patched
tree laid out as that module and compiles nothing, for a project that builds it
itself. A port takes it with `add_requires("revenant@combine", {alias =
"combine"})` and `add_packages("combine")` beside the runtime and libcxx.

`revenant@swiftui-uikit` is the second: SwiftUI, the SwiftUI API written anew on the
UIKit of iOS 6, as one module named `SwiftUI` - every symbol an application
takes from SwiftUI is mangled with that name - compiled against the runtime and
against `revenant@combine` built against the same runtime, which it takes with the
same `shared`, `backports` and `backports_uikit` configs. Availability checking
stays on, so what a later release adds stays behind `#available`. A port writes
`import SwiftUI` and an `@main` `App`, with `add_requires("revenant@swiftui-uikit",
{alias = "swiftui"})` and `add_packages("swiftui")` beside the runtime and
libcxx; the package names Combine's module folders too, since SwiftUI re-exports
Combine. A SwiftUI port takes the `backports` variant of all three: Combine's own
weak import, `_CFRunLoopTimerSetTolerance`, is answered by
`revenant@apple-backports`, which the port then carries (`coredata = true`, and
`add_packages` plus `set_values("revenant.libraries", ...)` for it), as
`SwiftUI/rtpkg/xmake.lua` does. The runtime's own weak imports are checked against
`modules/apple/runtime_guards.lua`. That a SwiftUI port passes `xmake deb`
with no `revenant.waive.weak-imports` has not been run end to end yet: it needs the
rebuilt runtime.

The runtime carries the Swift overlays of the system's own frameworks, which
Apple ships inside a newer OS: ObjectiveC, Dispatch, CoreFoundation,
CoreGraphics and Foundation from swift-5.4.3, QuartzCore, UIKit and CoreData
from swift-5.2.5 - each from the last release that has it - built by today's
compiler with patches where today's SDK or an older release differs. API an
overlay reaches from a later release keeps the availability the SDK gives it,
so a port for 6.0 asks with `#available`. With the `backports` config, what
`revenant@apple-backports` implements of later releases is available from the
port's release instead: the port's headers (`tools/gen/cmd_headers.lua`, with the
rule of `tools/gen/target_availability.lua`) copy the SDK headers with the release
of every implemented API lowered - found from clang's AST, never lower than an
entry's own minimum, never for what the registry calls absent, inert or ignored,
checked both ways - and a VFS overlay lays the copies over the SDK for the overlays
that link the backports and for the port's own Swift (`REVENANT_SWIFT_PORT_HEADERS`,
which the swift rule hands the compiler). Beside the classes and members the
registry names, the port's headers lower a type only the headers declare - an
enumeration, a set of options - when every API of the SDK that uses it and is above
the port's release is implemented, and redeclare the members the SDK declares only
as requirements of a protocol (`traitCollection` of `UITraitEnvironment`) as a
category on each class the registry names, rather than
lower the protocol for every type that adopts it. The overlays of Foundation and
CoreData link libFoundationBackports and libCoreDataBackports by path; the
`backports_uikit` config, for an application, links UIKit's overlay to
libUIKitBackports too. A port that takes that runtime requires
`revenant@apple-backports` itself with the configs the runtime links (`coredata`,
and `uikit` with `backports_uikit`), and the rule says which is missing: a lowered
call finds its implementation only where that library is loaded, and a message to
a library that is not there is an unrecognized selector at run time, not a link
error.

A port that needs an API newer than its release takes the port's headers, not the
compiler's `-Xfrontend -disable-availability-checking`: that flag also turns every
`#available(iOS N, *)` into true, so a check written correctly is taken on a release
that lacks the API, and the call fails there. With the port's headers the mark of an
implemented API is lowered and every other stays, so `#available` remains a real test.

apple-compat links its shims into whoever requires it and force-includes
nothing on its own, because a shim's header brings its system header with it
(`unlinkat.h` brings `<unistd.h>`, and with it `sync`). A target names the
calls it renames with `add_values("apple.compat", "clock_gettime")`; a package
script takes the flags from
`import("@addon.revenant.apple.compat").force_includes(package:dep("apple-compat"), {"clock_gettime"})`.

What the Swift runtime calls and an old release lacks is there as well:
`memset_s` and `objc_allocWithZone` (iOS 7), `voucher_copy`, `voucher_adopt`, `os_release` and
`qos_class_self` and `dispatch_block_*` (8), `clock_getres`, `dispatch_activate` and
`dispatch_assert_queue$V2` (10), and `os_unfair_lock_*` (10) and
`os_unfair_recursive_lock_*` (12). A release that has one of them is asked for
it by name in the library that defines it - libsystem_platform, libdispatch or
libsystem_pthread - so a port built for iOS 6 and run on a newer device uses the
system's, and a lock it shares with an image built for that newer release is the
same lock. `dispatch_get_global_queue` is in this list for another reason: every
release exports it, but it took a class of service in place of a priority only
in iOS 8, and answers NULL for a class before that; a caller that hands it a
class renames it, `add_values("apple.compat", "dispatch_get_global_queue")`, and
the shim maps the class to the priority it stands for.

`dispatch_block_create` and its family make the block libdispatch of iOS 8 makes, the one `DispatchWorkItem` is built on:
it carries a dispatch group that `dispatch_block_wait` and `dispatch_block_notify` wait on, a cancelled block does not run,
and a block that is run and waited for twice is refused as it is there. A release has no classes of service and no
vouchers, so the flags and the class that name them (`DISPATCH_BLOCK_ENFORCE_QOS_CLASS` among them) are accepted and change
nothing; and `DISPATCH_BLOCK_BARRIER` is not honoured, because the release's `dispatch_async` cannot read a block's flags: a
barrier block runs as an ordinary one. A library that is already built calls these through weak imports of the system's
libdispatch, so it gets them only when it is linked with apple-compat again.
`os_unfair_lock_assert_owner` and `_not_owner` read the word the shims' lock keeps, so they
are hidden copies in each image, unlike the lock itself.

The shims for calls whose state a whole process shares are not linked into each
image. The waiters of an `os_unfair_lock` and the unlock that wakes them meet in
one table, so a lock two images take - a `Mutex` from the Synchronization
library is inlined into every image that locks it - has to reach one copy of
these calls. libc++abi carries that copy, as it carries emulated TLS and the
atomic library calls, and libc++ re-exports it; `revenant@libcxx` refuses a
runtime that does not export them below the release they arrived in, or that
exports them at or above it, where the system's own must be used. The word an
`os_unfair_lock` holds is this copy's own format: the owner's Mach thread port
name with the low bit set, which a waiter clears. libplatform writes the name as
it is, because XNU's names are odd; the bit is set here so that the lock also
works where a name is even, which is what the emulator gives a thread it starts. A
release below iOS 10 has no os_unfair_lock of its own, so nothing else reads
that word; from iOS 10 on the system's implementation is called instead. Two
packages that each carry their own runtime do not share these locks, the same
boundary their libc++ copies have.

A tweak or a daemon has no bundle, so what it loads from a package - libc++ and
libc++abi, which also carry emulated TLS - goes to
`/usr/lib/revenant/<Package>/`, named by the Package field of its
`revenant.control`, and the images are pointed there when they are checked and
installed; only the libraries an image actually loads are carried, so a C tweak
takes libc++abi alone. Each package carries its own copy rather than all
packages sharing one, because a runtime is built for a minimum release:
libc++ below iOS 4.2 does not re-export libc++abi, and an image linked against
a later build binds those symbols to libc++. Copies of different packages in one
process, two tweaks in SpringBoard, keep separate thread-local storage and
exception state. `operator new` and `operator delete` stay with the package too:
libc++abi defines them as ordinary symbols, forced by
`packages/l/libcxx/operators-not-weak.exp`, so the package's images and its
libc++ bind them two-level to its own runtime, and the runtime takes no part in
dyld's coalescing of weak definitions. A failed allocation in a tweak therefore
throws the `std::bad_alloc` its own `catch` names, and SpringBoard's code keeps
the system libstdc++'s `operator new`. Before this, dyld bound the first inserted
image's uses to libstdc++, whose allocation failure is thrown by iOS 5 and 6's
libc++abi as a `GNUCC++` exception with GNU typeinfo, which Revenant's libc++abi
can only catch as `catch (...)`. An image that replaces `operator new` reaches
its own allocations and the template code inlined into it, but not allocations
made inside libc++'s dylib; ld no longer marks such a replacement as overriding,
so it does not take over the host process's allocations either.

`revenant@apple-backports` brings Objective-C API later releases added -
NSURLSession, NSURLComponents, UIAlertController, UIStackView, the layout
anchors, the traits of a view, base64 data, the quality of service of an
operation, the measurements and units of iOS 10, its date intervals, its image
renderer and its timing curves - to a minimum release that lacks it, as
`libFoundationBackports.dylib`, with the `uikit` config
`libUIKitBackports.dylib`, with the `corelocation` config
`libCoreLocationBackports.dylib`, which asks for location authorization the way
iOS 6 gets it, by starting the updates the request stands for, and with the
`coredata` config `libCoreDataBackports.dylib`, the persistent container of iOS
10 over the release's own Core Data, and with the `avfoundation` config
`libAVFoundationBackports.dylib`, the discovery of cameras and microphones of iOS
10 over the release's own capture devices; all named
`/usr/lib/revenant/org.revenant.apple-backports/`. Unlike a runtime a package
carries, these are one per process: two copies of a class would be two classes.
`xmake deb` of a port that uses the package writes
`org.revenant.apple-backports_<release>+<digest>_iphoneos-arm.deb` beside the
port's own package, named by the latest the toolchain release the addon recipe lists
and the first eight hex digits of the digest of the backports' sources, their
build module and that recipe, and the port's control file gains a Depends on
that version; `xmake device install` installs it first. The package holds the
libraries once for each band under `bands/<release>/` and a `bands/ranges`
file; its postinst reads ProductVersion from the device's SystemVersion.plist
and links the libraries of the band whose range holds it, and refuses, naming
the ranges it has, a release outside all of them rather than taking the nearest.
A band starts at the port's minimum and at every release the SDK's
availability gives for the symbols a backport source exports, and runs to the
last release of the firmware catalog before the next one, the last band to the
catalog's last release a device running armv7 code gets. Each band is built
for its first release and import-checked against the shared caches of its first
and last releases, from an armv7 device where the catalog has one and an armv7s
device otherwise; a cache that is not held is fetched as the import check
fetches one, and a declined fetch stops the build with the command to run.
A class is implemented under its own name against the SDK's headers. xmake puts
every `-l` of a target and its packages before every `-framework`, whatever
order `add_packages` names them in, so the weak `_OBJC_CLASS_$_` references
clang emits for API newer than the minimum bind to the backports library, and
subclasses and categories of a port work as on the release that introduced the
class. The libraries are built for one release, the one the port's imports are
checked against: a source file whose exported symbols that release already
exports is left out and its symbols are re-exported from the system library
that has them, so a newer release never holds two classes of one name, and a
file mixing symbols of two releases is refused. A port whose minimum is older
than iOS 4.2 gets the file left out and nothing re-exported in its place, which
is what dyld there can do: ld64 refuses `-reexported_symbols_list` for such a
target, and the release's own symbol is what the port binds anyway. Methods a later release added
to an existing class are categories, which the link moves from `__objc_catlist`
to `__DATA,__port_catlist`, where the runtime does not attach them: the
library's initializer adds each method, property and protocol only to a class
that does not respond to it. It reads method lists rather than calling
`class_getInstanceMethod`, which on iOS 6 runs `+initialize` while UIKit is
still loading, and realizes the class with `objc_lookUpClass` first, since iOS
6's `class_addMethod` expects a realized class. The selector check counts those
categories as implemented. The import check refuses a weak import bound to a
system library that lacks it while a library of the build exports it, the sign
of a link that put a framework first, and a re-export from a library that does
not export the symbol. `tests/backports` holds differential tests against the
host's Foundation and UIKit and the device tests, run on an emulated iOS 6.

A backport carries the behaviour of the newest implementation, not of the
release that introduced the API: where Apple later corrected a number, the
corrected one is used, and the facts name both. `NSUnitMass`'s stone is the
plain case - iOS 10 converts it by 0.157473, the reciprocal of the 6.35029 it
should be, and a program that asks for stones is asking for stones. Each class
has a facts file under `packages/a/apple-backports/facts/<Framework>/`, saying
what was read, from which library and release, and what was deliberately left
out. `packages/a/apple-backports/registry/<Framework>/` lists every API
considered, a file per author so that work on different releases never edits the
same file, with one entry per class, method, property, function or constant and
one of four answers. `implemented` has facts and tests behind it. `inert` is
declared, does nothing and says so in the log once, and is allowed only where
doing nothing is a safe reading, such as an effect the release cannot draw.
`absent` is not there at all, so that `respondsToSelector:` answers honestly; it
is the default and the rule wherever quiet inaction would corrupt data or
mislead - security, saving, permissions, the network - because an application
that asks first keeps running while one that is lied to does not. `ignored` is
the quietest: the call reaches the release's own implementation, which does
something else with it, and nothing of ours is in the way, as with an
enumeration option the compiler writes into a system call; it names what comes
out instead. `NSMeasurementFormatter` is absent for now: formatting a
measurement needs private ICU entry points iOS 6's libicucore does not export.
What the package carries range by range, what it carries with a named
difference and what it refuses with the reason, is
`packages/a/apple-backports/README.md`.

The build reads the registry against what the libraries really define - the
classes they carry, from their exports and their class lists, and the selectors
their categories add, whose target class is read from the bind the link left -
and stops on a class or selector no entry describes, on one API named by two
files, on an entry that says implemented while neither the build nor the release
itself carries that name, and on a status that comes without the reason, effect
or facts it owes. A band built for a later release drops what that release
already has, so only the libraries of the port's own release are held to the
registry both ways. An entry that claims behaviour names the file of facts it
was read into; one that only records where an API begins or ends does not, and
the entries that still owe facts are counted, not refused.

xmake's package hash covers a package's version, configs and toolchain, but
neither its script nor the builds of its dependencies; the script is not in reach
of anything that runs before the hash is taken, so it cannot be digested for it. The toolchain that Revenant gives
packages carries a digest of the files that decide their compiler and linker
flags, so a release that changes those flags rebuilds every package once, for
every architecture. Revenant's libraries set
`package.strict_compatibility`, so what depends on them is rebuilt when they
change; a port should set `package.librarydeps.strict_compatibility` in its
project for its own packages, and give a package defined in its `xmake.lua` a
revision it raises with the script:
`add_configs("revision", {default = "2", readonly = true})`. A build cut short
can leave `.git/index.lock` in the package's source cache under
`~/.xmake/cache/packages/`; remove that lock file before building again.
`checkout.pinned` clones the repositories a package is built from, each verified
against the commit its tag named, and keeps them across installs: the sources of
a compiler are gigabytes, and an install that fails halfway, or a second
architecture, should not pay for them again. What the last install changed in
them is undone before the next one starts.

Writing a recipe has a few traps, each of which costs a whole build to find.
A package reaches a dependency by the dependency's own name, not by the alias it
was required under: `package:dep("swift-bootstrap")`, whatever `alias` says, and
the miss is a nil that only fails where the value is first used. A package with
no `add_urls` never has `on_download` called at all, however complete that
function is. A download that leaves a single directory is entered by the build,
so `os.curdir()` is that directory and a copy written against the level above
matches nothing - and a copy that matches nothing is silent, so a recipe that
lays out an install should assert what it laid down. Sources cloned by
`checkout.pinned` are kept between installs and restored to their tag, so a
recipe patches them in place and keeps its build tree beside the repositories,
never inside one. The package manager of Swift 6.4 builds through SwiftBuild and
reads its resource bundles from `usr/share/pm`, which a toolchain cut to the
compiler does not have. And two `xmake` processes on one project hold each
other's package locks: a build that appears to make no progress for a long time
is usually a second one left over from an earlier run.

xmake asks before it installs or reinstalls a package or an addon, and a
command run in the background waits for that answer forever; pass `-y` there.
The include makes autotools' m4 and pkgconf built packages (Homebrew's
pkgconf has no pkg.m4 for autogen.sh): macOS's /usr/bin/m4 is GNU M4
1.4.6, which autoconf 2.72 refuses.

A new machine needs `brew install xmake llvm` and `xcode-select --install`. The
addon's tests build their fixtures with the same ld64 and ldid:

    cd tests/addon && xmake f -y && xmake test

## The Conan driver

Ports that have not moved to xmake yet still build through the Conan driver
below; it goes away once they have.

## What is here

    config/settings_user.yml   iOS 6.0 and 6.1, which Conan does not ship
    config/extensions/hooks/   refuses a build missing what its platform requires, and maps machine paths away
    config/extensions/revenant/  the toolchain: the entry point, what it generates, and the phone transport
    config/extensions/revenant/platforms/  apple-ios: what a port that builds for iOS is built with
    recipes/ld64/              the linker, built from cctools-port
    recipes/ldid/              the signing tool the device accepts
    recipes/libplist/          the property-list library ldid reads entitlements with
    recipes/iphoneos-sdk/      the SDK, fetched and verified on the machine that uses it
    recipes/libcxx/            the C++ runtime an old iOS does not ship
    recipes/dyld-imports-check/  the check that every import exists in a device's dyld cache
    recipes/revenant-base/       what every port's recipe extends, whatever its platform
    recipes/revenant-apple/      the Apple half: Mach-O invariants, bundles, signing, the .deb writer

## A new machine

    brew install conan cmake ninja ccache llvm
    xcode-select --install

    git clone https://github.com/kern0x1b/revenant.git
    conan config install toolchain/config

    export LLVM_PREFIX="$(brew --prefix llvm)"

The toolchain is the entry point, the way Gradle is. Inside a port, run it once by its
full path:

    "$(conan config home)/extensions/revenant/revenant" setup <path to this repo>

That installs this configuration, registers this repository's recipes and the
port's own ahead of the general remotes, and links `revenant` into the first
writable folder on PATH, so every later call is just `revenant`. A new port starts from a template, which builds, packages and passes
`check:imports` as written:

    revenant new tweak|daemon|app NAME [--identifier com.example.name]

`REVENANT_MAINTAINER` fills the control file's maintainer. The verbs are the same
in every port:

    revenant build [--variant NAME]   everything the declaration names
    revenant lock                     pin every variant's graph to what the indexes serve now
    revenant task NAME [NAME...]      declared tasks, run the way the pipeline runs them
    revenant test [--tier NAME]       the declared test tiers
    revenant package                  the .deb, copied to build/<variant>/
    revenant install                  package and dpkg -i the .deb on the phone, refusing to
                                    install an app over one with another bundle identifier
    revenant deploy, revenant run       install on the phone, launch the application
    revenant device log [SECONDS] [TEXT]  the phone's log over USB, filtered
    revenant generate                 write the recipe, profile and CMake without building
    revenant integrate, clean, provenance, device run|copy|fetch

The phone is named in the port's `device.env` (`DEVICE_HOST`, `DEVICE_PORT`,
`DEVICE_UDID`, `DEVICE_PASSWORD`). A port with more than one keeps
`device.NAME.env` beside it and picks one with `--device NAME`, or with
`REVENANT_DEVICE=NAME` for a whole shell.

`conan config install` copies rather than links, so after changing the toolchain here
run `revenant setup` again; `revenant provenance` says which copy is answering.

A port with one pipeline needs no `[variants]`: each name under `[pipeline]` is
a variant with no options of its own. A port carries no conanfile.py, no profile,
no CMake and no Makefile. It carries
`revenant.toml`, and the toolchain writes the rest into `build/<variant>/revenant/`:

    [port]
    name = "revenant-webkit"
    version = "0.1.0"
    index = "revenant"

    [platform]
    use = "apple-ios"
    arch = "armv7"
    os-version = "6.0"
    distribution = "jailbreak"

    [target]
    cppstd = 23
    cpu = "cortex-a9"

    [requires]
    openssl = "3.0.15@revenant/stable"

    [[device-library]]
    name = "RevSafari"
    sources = ["platform/safari/rev-safari-tweak.c"]
    install = "/Library/MobileSubstrate/DynamicLibraries"
    installs-into = "stage"
    frameworks = ["CoreFoundation"]

    [tasks.carry-check]
    script = "scripts/carry-check.py"

    [tasks.where]
    shell = "echo built into"
    args = "{build}"

    [tasks.census]
    python = """
    import sys
    print(sys.argv[1:])
    """
    args = "{pkg:openssl}"

    [pipeline]
    system = ["task:carry-check", "build:device-library", "stage:frameworks", "task:where"]

`[[executable]]` is a program for the device - a daemon, a tool - generated as
`add_executable` and installed at `install`. A staged device library or
executable with `entitlements` is signed with that file and its signature read
back, as the application's is.

A task is a table with exactly one of `script`, `shell` or `python`, and its
`args` may name anything the build knows: `{port}`, `{build}`, `{stage}`,
`{pkg:NAME}`, `{include:NAME}`, `{lib:NAME:LIBRARY}`, `{bin:TOOL}`,
`{target:NAME}`. Every task runs from `{port}`, the folder holding
`revenant.toml`; the generated recipe finds it from the `build/<variant>/revenant`
folder it lives in, so it carries no checkout path, and `user.revenant:port`
names another. A task runs in `[pipeline]` as `task:NAME`, before the build under `revenant integrate`
when `[integrate] before-build` names it, or on its own with `revenant task NAME`.

A target's `sources` may be patterns - `src/**/*.m` - with `exclude`, expanded
when the toolchain writes the project; a pattern that matches nothing is refused. An
application is linked by `build:application` and signed by `sign:application`,
and the steps between them get `{application}` and `{executable}`, so a Mach-O
fix-up runs on the linked, unsigned binary. `strip = "-S -x"` strips the
executable right after it is linked; `plist-file` starts Info.plist from a file,
with `[application.plist]` over it and the derived keys filling only what both
leave out; `bundle = [{ from = "{pkg:NAME}/lib/libfoo.dylib", into = "Frameworks" }]`
copies a package's file into the bundle and gives a binary its
`@executable_path` identity. Neither the executable nor anything bundled may load a library the bundle carries from anywhere else, whatever version suffix the path spells. `include-exclude` removes a folder whether a pattern or a literal entry
brought it in, so excluding a tree excludes every folder inside it. A port that
copies C++ runtime libraries into the device layout names them under
`[stage.runtime]` and the package they come from as `[stage] runtime-from`; a
port that ships no runtime declares neither and needs no such package. A library the application opens by a path string
is not rewritten by any of this - that path is the application's own. A
pipeline that builds an application and never signs it is refused, unless
another variant merges it.

Anything the toolchain writes can be replaced. `cmake = "<dir>"` on a target uses that
project instead of a generated one; `[engine] user-toolchain` and
`project-include` name hand-written cmake files; `[use] profile` and
`[use] recipe` name a profile or a recipe of the port's own; `script =` keeps a
large task in a file. The declaration alone is the default and none of these is
required.

`[conf]` holds what dependency builds read from the profile. A sentence names a
value the port needs but does not set, and `revenant setup` warns while it is
empty; a table sets it, with the reason beside it:
`"user.x:headers" = { value = "{port}/include", why = "..." }`. A set value is
written into the generated profile, so a dependency Conan builds from source
under `revenant build` sees it too, and `{port}` is resolved by the profile from
where it lies rather than written as a checkout path. `[variants.NAME.conf]`
replaces the keys it names for that slice. A value may not name a package
placeholder, because a profile is read before the graph that could answer it;
a dependency that needs another package's files requires that package, for
example headers only with `requires(..., headers=True, libs=False)`.

Every binary a step produces is verified before anything strips or signs it,
whatever the pipeline says: targets installed into the stage, staged
frameworks, the application's executable and everything bundled with it, and
each merged binary. On armv7 every rebased pointer to a function must carry
bit 0 exactly when that function is Thumb code, read from the symbol table
while it is still there, and a binary none of whose code pointers names a function it can check is refused as having arrived stripped; ld64 gets this right, a linker that drops the bit or
a post-link edit that sets it on ARM code does not, and either one runs until
the first call through the pointer. An executable's `__PAGEZERO` must be at
least 4 GB on arm64 and end where `__TEXT` starts on armv7. After
`sign:application` the signature is read back and must carry every declared
entitlement with its declared value. After a project builds, every object and
archive member its links read - asked of Ninja with `ninja -t inputs`, so an
object left over from a deleted source is not read - must record the target's
minimum OS version exactly when it was built here or by a package in the
dependency graph; an input from outside the graph is refused only when newer
and otherwise reported by name: newer means the binary needs a later
iOS, and older or none means it was compiled without the target's flags - the
assembler is where that usually happens. Every host profile, shared or
generated, exports `IPHONEOS_DEPLOYMENT_TARGET` from its `os.version` into the
build environment, so a compiler or assembler a build system invokes without a
version flag stamps the target's minimum rather than its own default; an
explicit flag still wins. The variable reaches everything a host package's
build runs, so a recipe that compiles and runs a helper on the build machine
inside its own `build()` runs that step with an environment that unsets it;
a tool that belongs to the build machine is better a build-context package. A binary that weakly imports from libSystem a call apple-compat records as
arriving after the target release is refused, naming the component to link:
on the device that call jumps to NULL. A port can only take one out with a
reason, `[waive] pagezero = "why"`, and `input-minimum` may name packages,
`[waive] input-minimum = { tdlib = "why" }`; an unknown name, a package nothing
depends on, or an empty reason is refused.

Recipes reach a build only through a local recipe index, which trims each
`conandata.yml` to the version it exports. A top-level table with no key for
that version is dropped there, so a recipe reading it works from its folder and
fails for every consumer; `revenant build` and `revenant setup` refuse such an index
before anything runs. `revenant setup` also names each `conandata.yml` whose text
the trim rewrites: `conan create` in that folder gives a different revision from
the one consumers resolve, so a package built that way is not the one they use.

`[platform]` names what the port builds for, and nothing else says it. A
platform is a file of facts - `config/extensions/revenant/platforms/apple-ios.toml`
is the first - giving the operating system, its SDK name, the architectures it
builds with the oldest and newest release each supports, the tools every build
for an architecture requires (the SDK package; ld64 for armv7), the compiler's
runtime, the configuration and the deployment-target variable its tools read,
and the distributions it knows. The toolchain writes the whole host profile from it,
refuses an architecture, a release or a distribution the platform does not
have, and refuses `[target]` repeating `os`, `arch`, `os-version`, `sdk` or
`system-name`. `[variants.NAME.platform]` changes the architecture or the
release for one slice. A port's own `platforms/NAME.toml` is used before
Revenant's, so a platform can be written or corrected without changing the toolchain.
`[target]` keeps what tunes the build: `cppstd`, `cpu`, `fpu`, `defines`.

A platform also says where a framework lived before it became public:
`[frameworks.IOSurface] public-since = "11.0"` makes a build for an older release
link IOSurface through the SDK's own stub laid out at
`/System/Library/PrivateFrameworks`, so the image records the location that
release loads it from. `dyld-imports-check` refuses a binary that loads a library
neither the device's cache nor the build itself provides, besides every symbol
the device does not export.

`ldid` signs with the package the platform names under `port-tool-requires`,
never with one that happens to be on PATH.

`tool-requires` reach every package the profile builds; `port-tool-requires`
reach only the port's own recipe, beside its `[tools]`, and a port naming the
same tool picks its version. apple-ios names `dyld-imports-check` there, which
the `check:imports` step runs over the stage and the application bundle against
the device's shared cache: `user.apple-ios:dyld_shared_cache`, or else
`<user.revenant:home, ~/.revenant>/dyld/dyld_shared_cache_<arch>`. Without a cache
the step refuses rather than passing having looked at nothing. It is the check
that proves a build loads: a table of calls that arrived late only knows what
someone wrote into it.

`revenant where pkg:NAME` prints the folder of a package a variant's build links,
and `revenant where tool:NAME` one it runs, answered from the same lock and profile
the build uses and never building anything; a script asks it instead of reading
generated environment files.

The rest the toolchain derives rather than being told: the host profile comes from
`[target]`, the engine build is the one direct child of `build/` that CMake
configured and that has frameworks laid out, the frameworks to install are
whatever the build staged, and a test tier gets the phone, the build tree or its
packages only when it declares `needs` or `packages`.

`LLVM_PREFIX` is read once, by `config/global.conf`, into
`user.ld64:llvm_prefix`. Only the `ld64` recipe asks for it: cctools' configure
runs `llvm-config` to find `libLTO`, and a linker built without it silently
drops LTO support, which this target builds with. Recipes never read the
environment themselves, so a missing path stops `conan create` with that
sentence rather than producing a linker that cannot link.

To set it for one invocation instead, the flag is `-c:a`, not `-c`: `ld64` is a
`tool_requires`, so it is configured in the **build** context, which a plain
`-c` never reaches. A guard firing while the value is plainly set on the command
line is almost always this.

`libcxx` offers the newest LLVM release, 23.1.1. Its runtime calls what old
releases lack - `aligned_alloc`, `clock_gettime`, the `*at` calls, `__ulock_wait`
- and links `apple-compat` hidden, which provides each for the releases before it
arrived; the recipe refuses a runtime that still imports one of them. It also
builds apple-compat's process-wide shims, the unfair locks, into libc++abi with
default visibility and re-exports them from libc++, so that every image of a
process binds to one copy.

Xcode is not required and does not need to be installed. The `llvm` package
builds the compiler and its runtime, the SDK comes from the
`iphoneos-sdk` package, and the linker and the signing tool are built from
source by the `ld64` and `ldid` recipes. Theos itself is not needed.

## A port

A port is `revenant.toml`, its own `recipes/` for the libraries it builds, and its
own `conan.lock`. `revenant setup` registers the port's recipes as the remote
`[port] index` names and this repository's as `revenant`, and keeps both ahead of
ConanCenter. A port and this repository both carry recipes under names
ConanCenter also publishes - icu, brotli, libxslt - and Conan asks the remotes
in the order they are registered; `conan remote add` appends, so without that
ConanCenter answers first and a build that has never seen these packages
silently gets recipes that cannot cross-compile for this target.

`revenant profiles`, which `revenant setup` also runs, writes a shared profile for
every architecture of every platform - `apple-ios-armv7` at iOS 6.0 and
`apple-ios-armv8` at 7.0 - from the same platform files a port's profile is
written from, for building a recipe with plain `conan create`. A port's own
choices - the C++ standard, CPU tuning - are `[target]` keys.

`@revenant/stable` is for what this repository serves - the linker, the C++ runtime,
the base class - and nothing else. A port's own libraries carry the port's name,
`openssl/3.0.15@revenant/stable`, `openssl/3.0.15@itglegacy/stable`: two ports
build the same library with different choices, and two recipes behind one
reference overwrite each other's packages in the Conan cache every port on the
machine shares.

## Packaging a library

Three things every recipe meets sooner or later.

A library built with a SOVERSION leaves `libfoo.dylib -> libfoo.1.2.3.dylib` in
its build tree. A `copy(self, "*.dylib", ...)` in `package()` that matches the
unversioned name stores the link, not the file it points at, and the package
ends up holding a dangling symlink. Copy the real file, and recreate the short
name with `os.symlink` inside `package_folder` if consumers link against it.

Some sources already live in the consuming repository - a submodule pinned in a
monorepo, too large to copy around. There is no need for an environment
variable naming the checkout. Point `layout()` at the sources, build them where
they are with `conan build`, then turn that build into a normal package with
`conan export-pkg`: it runs `package()` against the local build folder and
stores the result in the cache, resolvable by `requires()` and written into
`revenant-deps.env` like any other. The cache holds the recipe and the artifacts, not
the sources, so it cannot rebuild the package with `--build`; the repository is
where that happens. If the package must be rebuildable from the cache,
`exports_sources` copies the sources in on export instead.

Each Conan command is its own process, and `conan build` and `conan export-pkg`
are two of them. Anything `build()` stores on `self` is gone when `package()`
runs, so `package()` has to find what it copies the same way `build()` made it -
from the layout and the settings - rather than from state the build left behind.

Editing a recipe changes its revision, and every package exported under the old
revision stops matching - for each architecture, including the ones the edit was
not about. A lockfile still names the old revision, and on the machine that made
the edit nothing fails: the old revision is still in the local cache, so the
build quietly uses it. Only a fresh clone fails. Update the lock in the same
change as the recipe:
`conan lock create . --lockfile="" --update --lockfile-out=conan.lock` with the
same profiles as the build. `--lockfile=""` starts over from what the recipes
say now - Conan otherwise reads a `conan.lock` it finds beside the conanfile as
its input and keeps the revisions in it - and `--update` exports the recipes
from the indexes again instead of taking the revision already in the cache.

Every recipe carries a `test_package`, and `conan create` runs it. `revenant-base`
provides the whole of it; a recipe adds three files:

    test_package/conanfile.py      python_requires_extend = "revenant-base.RevenantTestPackage"
    test_package/CMakeLists.txt    find_package(<name> CONFIG) and one executable
    test_package/test_package.c    a program that calls the library for real

The program is compiled against the package and linked for the target through
ld64, so a package that builds but cannot be linked against - a missing
component, a define its headers need, a runtime it forgot to declare - fails in
its own `conan create`, not in a port an hour into a build. It runs only where
the target can run; for iOS the link is the test. A tool such as ld64 checks
what it says about itself instead.

## Handing packages on

`revenant publish INDEX OUT` archives the packages built from an index's recipes
with `conan cache save`, without sources, and writes beside the archive a table
of each package's license, source and binaries. A recipe with `upload_policy =
"skip"` is left out - the iOS SDK is Apple's to hand on, not ours - and a package
with no `licenses/` folder refuses the archive. `conan cache restore` puts the
archive into another machine's cache, where builds for the same settings take
the binaries instead of building them. The archives of this index are attached
to the repository's releases named `packages-<date>`.

## Where the packages are

`CMakeDeps` serves CMake. Everything else a port runs - a test harness, a shell
script - needs the same answer, so `revenant-base` writes it once:
`build/conan/<arch>/revenant-deps.env`, one line per package, taken from the dependency
graph rather than typed out.

    REVENANT_HOST_OPENSSL=/.../openssl/3.0.15/Release/armv7
    REVENANT_BUILD_LD64=/.../ld64/956.6/Release/armv8

`REVENANT_HOST_*` are the libraries built for the device, `REVENANT_BUILD_*` the tools
that run on this machine. The same file reads from a shell and from make:

    . build/conan/armv7/revenant-deps.env
    include build/conan/armv8/revenant-deps.env

The folder is per architecture, so a port that ships both slices installs twice
and each slice keeps its own paths - a `lipo -create` step reads one file for
each. A port built from `revenant.toml` writes it into its build tree instead,
`build/<variant>/conan/revenant-deps.env`, and a test tier that declares `packages`
gets its own under `build/tier-packages/<tier>/`.

A port that extends `revenant-base.RevenantPort` gets it without doing anything. A
conanfile that does not - a test harness built for the Mac - calls it directly:

    def generate(self):
        self.python_requires["revenant-base"].module.DependencyEnv(self).generate()

Nothing downstream names a version, an architecture or a deploy layout, so a
version bump in `conanfile.py` reaches every consumer. A path that cannot be
written as a plain assignment - one with a space in it - stops the install
rather than producing a file that half the tools misread.

## What it takes from Apple

Nothing of Apple's is in this repository. What a build uses comes from three
places, and each is kept to what is needed:

- **The Command Line Tools** - the compilers and their runtime, `mig`, and the
  archive and binary tools. They are installed once by `xcode-select --install`
  and nothing here replaces them.
- **The iOS SDK, from the `iphoneos-sdk` package.** The profiles require it; it
  downloads the SDK archive [theos/sdks](https://github.com/theos/sdks) publishes
  as a release asset, checks its sha256 and its `SDKSettings.plist`, lays it out
  as Xcode does - `Platforms/iPhoneOS.platform/Developer/SDKs/` - and answers
  `tools.apple:sdk_path` for every build that requires it. It is never uploaded
  anywhere (`upload_policy = "skip"`): the SDK is Apple's, and this project only
  says where it comes from. A `tools.apple:sdk_path` set in a profile or on the
  command line still wins. This repository's CI fetches it only to check the
  package names the SDK it says it does.
- **ld64**, built from cctools-port. Only its linker is built - `ld64/src/3rd`,
  `mach_o` and `ld` - and only libtapi's own targets, with LLVM configured for
  the host alone. The package holds the linker, `libtapi.dylib` and their
  license files. cctools-port can build a whole toolchain beside it, its
  assembler under the GPL among it; none of that is built or shipped.

The linker is built with the optimisation cctools chooses by default. It used to
be built unoptimised by accident: the recipe passed `CFLAGS` to `configure` for
one warning in `otool`, and an explicit `CFLAGS` replaces the default `-O3`
rather than adding to it. Building only the linker made that warning flag
unnecessary. Built both ways with the same flags, the partial build and the full
one produce the same 31362 functions at the same sizes, differing only in the
order they are laid out; `libtapi.dylib` comes out byte for byte the same. The
engine links with the optimised linker and passes the same 55 on-device checks.

libtapi is built in two steps on purpose. `vt_gen` generates `GenVT.inc`, which
libtapi's sources include, and asking Ninja for both at once lets it compile
those sources first - a build that passes or fails depending on scheduling.

## Reproducible packages

Two things made the same recipe produce different bytes on a different machine,
and the hook removes both for every iOS 6 package: the absolute path of Conan's
build folder, which `__FILE__` writes into objects, is mapped to `/source` and
`/build` with `-ffile-prefix-map`. Recipes that stamp a time use the time of the
commit they build rather than the time they ran.

## Packaging

Every port ships a .deb. A port declares `[package] control` and, if it has
them, `maintainer-scripts`; `revenant package` hands the staged tree - laid out
as the device's filesystem, every binary signed with the `ldid` tool_requires -
to `revenant-apple.DebianPackage`. For the variant that builds `[application]`,
the final bundle joins that tree where the port's distribution installs
applications (`applications` under the platform's `[distributions.<name>]`,
`/Applications` for a jailbroken iOS device). A port with several variants
names the one its package is written from with `[package] variant`; the others
package their bundle or tree without a .deb. A recipe written by hand calls the same class:

    def package(self):
        self.python_requires["revenant-apple"].module.DebianPackage(
            self, "packaging/control", self._stage, "packaging/DEBIAN"
        ).write(os.path.join(self.package_folder, "deb"))

It writes the archive dpkg-deb and theos's dm.pl write - `debian-binary`,
`control.tar.gz`, `data.tar.lzma`, owned by root - with the version from the
recipe, so the port's control file carries neither `Version` nor
`Installed-Size`. Neither theos nor dpkg is needed to produce it.

Everything armv7 links through the `ld64` package, which the profile hands to
every CMake build as `-B`. Apple's own linker from Xcode 27 writes an
`LC_ENCRYPTION_INFO` load command into every armv7 dylib, and iOS 6 will not
start an app whose MobileSubstrate tweak carries one - no crash log, the tweak's
constructor never runs. The same source linked by ld64 has no such command and
loads.

What stays with the port is its identity - the package id, the icon, and what
it stages into the package.

Recipes name a git URL and a commit. Nothing is vendored, nothing is committed
as a binary, and a clean clone builds what the lock says.

## Why the linker is here

Apple's linker from Xcode 27 cannot link a 25MB armv7 dylib: a Thumb branch
reaches 16MB, the call stubs sit after all the text, and it does not insert the
branch islands that bridge the gap. ld64 does. It also has to be built from
source, with libtapi for the SDK's `.tbd` stubs, which makes it a package like
any other - pinned to the commits it is known to build from.
