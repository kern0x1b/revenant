#!/bin/sh
# tests/backports/device/photos/run.sh -- the three Photos device programs, built from THIS tree's own
# Photos sources, run on a device, with their figures printed.
#
#     sh tests/backports/device/photos/run.sh [options] [PROGRAM...]
#
# Why this file exists: facts/Photos/Changes.md names photoschanges8.m, photosdata9.m and
# photosalbums8.m and quotes their check counts, and nothing in the tree ran them. The numbers were
# real when they were taken (an iPad 2 running 6.1.3, 2026-09-23 and 2026-09-24) and there was no path
# left to take them again, which is how a facts page ends up quoting a run nobody can repeat. This is
# that path: it builds each program from the sources beside it, so a run measures the tree it is run
# from and not a package that was installed weeks ago, and it prints what each program reported.
#
#   photosalbums8   a process of its own, denied the photo library by the release; it reads and writes
#                   nothing. Safe on any device, so it is the one this runs without being asked.
#   photosavailability13
#                   a process of its own, in the same state: what -[PHPhotoLibrary unavailabilityReason]
#                   answers and when an availability observer is told, for iOS 13. Reads and writes
#                   nothing, so it too runs on any device.
#   photoschanges8  an application (photoschanges8-Info.plist): it registers change observers and adds
#                   three 8-by-8 blue fixtures to the saved photos on every run.
#   photosdata9     an application (photosdata9-Info.plist): the iOS 9 creation request, the asset
#                   resources and the resource manager, over the same fixtures.
#   control         this directory's own negative control; it must FAIL, and the run says so.
#
# The two applications WRITE to the photo library of the device they run on, and the photo library of
# a device that is not the iPad 2 is the owner's. So a program that writes is refused unless the
# device is the iPad 2 (the one that holds the fleet's own fixtures, albums named CharonPhotosProbe)
# or PHOTOS_ALLOW_WRITE=1 says the device's library is a test library. Nothing is read to decide this:
# the device's name decides, so the check cannot itself touch the owner's data.
#
# Options:
#   --release R     the release to build and run for (default 6.1.3, the release the facts quote)
#   --device NAME   -d for `xmake device`: NAME picks device.NAME.env (default: device.env, the 4S)
#   --build-only    build and link everything, run nothing
#   --control       also run the negative control, and require it to fail
#   --allow-write   as PHOTOS_ALLOW_WRITE=1
#
# Environment (all optional; the defaults are what the shared xmake store holds):
#   PHOTOS_CC, PHOTOS_LD, PHOTOS_SDK    the toolchain; default the store's llvm, ld64 and iphoneos-sdk
#   PHOTOS_BUILD                       where the builds and the reports go
#                                      (default <worktree>/.agent-work/runs/photos-device)
#
# The claim is the operator's, not this script's: export CHARON_DEVICE_HOLDER and claim first
# (`xmake device -d NAME --minutes=30 claim`); this script refuses a device held by someone else and
# says so. Nothing here installs a package: the port's sources are compiled into each program, so the
# canon on the device (org.charon.apple-backports), which belongs to everybody, is left alone.
#
# Exits 0 only when every program that ran reported a figure with no failed check, and, with
# --control, when the control reported at least one.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
release=6.1.3
device_name=""
build_only=0
want_control=0
allow_write=${PHOTOS_ALLOW_WRITE:-0}
programs=""

while [ $# -gt 0 ]; do
    case $1 in
        --release) release=$2; shift 2 ;;
        --device) device_name=$2; shift 2 ;;
        --build-only) build_only=1; shift ;;
        --control) want_control=1; shift ;;
        --allow-write) allow_write=1; shift ;;
        --) shift; programs="$*"; break ;;
        -*) echo "run.sh: unknown option $1" >&2; exit 2 ;;
        *) programs="$programs $1"; shift ;;
    esac
done
[ -n "$programs" ] || programs="photosalbums8 photosavailability13 photoschanges8 photosdata9"
# No device is named here on purpose: an empty -d is the transport's own default (device.env, the
# device that is attached), and a run must not silently pick a different one. The write guard below
# refuses a program that writes unless the device IS the iPad 2 or the operator says otherwise.

store=$HOME/.xmake/packages
pick() { ls -d "$store/$1/$2"/*/ 2>/dev/null | head -1; }
: "${PHOTOS_CC:=$(ls "$(pick l/llvm 23.1.1)"bin/clang 2>/dev/null | head -1)}"
: "${PHOTOS_LD:=$(ls "$(pick l/ld64 956.6)"bin/ld 2>/dev/null | head -1)}"
if [ -z "${PHOTOS_SDK:-}" ]; then
    for folder in "$store"/i/iphoneos-sdk/16.4/*/; do
        sdk="$folder"'Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk'
        [ -d "$sdk" ] && PHOTOS_SDK=$sdk && break
    done
    : "${PHOTOS_SDK:=$(pick i/iphoneos-sdk 16.4)}"
fi
for tool in "$PHOTOS_CC" "$PHOTOS_LD" "$PHOTOS_SDK"; do
    [ -e "$tool" ] || { echo "run.sh: $tool is not there; set PHOTOS_CC, PHOTOS_LD and PHOTOS_SDK" >&2; exit 1; }
done
command -v ldid >/dev/null 2>&1 || { echo "run.sh: ldid is not on PATH (brew install ldid)" >&2; exit 1; }

out=${PHOTOS_BUILD:-$root/.agent-work/runs/photos-device}
mkdir -p "$out"
photos=$root/packages/a/apple-backports/Photos
triple=armv7-apple-ios$release
# The flags the library is built with (modules/apple/backports.lua:1118, :473), not a private set: the
# sources below must be compiled exactly as the dylib compiles them, or a run measures another build.
cflags="-target $triple -isysroot $PHOTOS_SDK -isystem $PHOTOS_SDK/usr/include -fobjc-arc -Os -g0 -Wall
        -Wno-unguarded-availability-new -Wno-incompatible-sysroot -I$photos -I$here/.."
# The frameworks the library itself is built against, copied from the declaration in
# modules/apple/backports.lua:66 (PhotosBackports) rather than gathered from the imports, so the two
# cannot drift. Photos and PhotosUI are NOT among them: no release below 13 carries them, which is
# why the port carries these classes at all. FoundationBackports is not linked either: at 6.1.3 the
# release's own Foundation is the one, and linking the port's would put two Foundations in the process.
frameworks="-framework AssetsLibrary -framework AVFoundation -framework CoreLocation -framework CoreGraphics
            -framework ImageIO -framework MobileCoreServices -framework UIKit -framework Foundation"

# The band's own sources, asked of the build's own rule and not of a list written out here:
# band.py reads the registry minimum of every class each file defines and prints the files this
# release's band carries. A hardcoded list is what it replaces, and it went stale twice in one
# afternoon -- once for PHChangeRequest13.m, a 13.0 object the 6.0 band carries because
# registry/Photos/ios13.json gives it minimum 6.0, and once for a file added beside it, whose absence
# only the device could see, as an unrecognized selector.
band=$(python3 "$here/band.py" "$release" "$photos" "$root/packages/a/apple-backports/registry")

compile_one() { # $1 source, $2 object
    # shellcheck disable=SC2086
    $PHOTOS_CC $cflags -c "$1" -o "$2"
}

link_one() { # $1 output, rest: objects
    output=$1
    shift
    # shellcheck disable=SC2086
    $PHOTOS_CC -target "$triple" -isysroot "$PHOTOS_SDK" -fuse-ld="$PHOTOS_LD" -fobjc-arc \
        -Wl,-rename_section,__DATA,__objc_catlist,__DATA,__charon_catlist \
        -o "$output" "$@" $frameworks $extra
    # Fatal, like the [ -e "$tool" ] and `command -v ldid` guards above: a binary that could not be
    # signed is a binary that is pushed and launched and then fails somewhere else -- an opaque launch
    # error for an application, and a confusing one for a bare process that a stock release does not
    # sign at all. `cmd || echo` is the shape self-review §2 names, a swallowed failure on a step whose
    # failure nobody would notice, and `set -eu` cannot stop on it.
    if ! ldid -S "$output" >/dev/null 2>&1; then
        echo "run.sh: ldid could not sign $output" >&2
        exit 1
    fi
}

# $1 program name, $2 process|app, $3 the plist's executable name. Every program is built over the
# whole band: the pickers of iOS 14 are in it too (registry/PhotosUI gives them minimum 6.0), they
# link without PhotosUI, and a program that leaves a file out is a program that will answer for a
# class the rest of the band is what the release runs with.
build() {
    name=$1
    kind=$2
    executable=$3
    # photosdata9.m writes its own test videos with AVAssetWriter and hands AVFoundation the pixel
    # buffer pool, so it links CoreMedia and CoreVideo as well; the other two programs need nothing
    # the library does not already name.
    extra=""
    [ "$name" = photosdata9 ] && extra="-framework CoreMedia -framework CoreVideo"
    objects="$out/$name.objects"
    rm -rf "$objects"
    mkdir -p "$objects"
    index=0
    for source in $band; do
        index=$((index + 1))
        compile_one "$photos/$source" "$objects/$index.o"
    done
    compile_one "$root/packages/a/apple-backports/attach.c" "$objects/attach.o"
    compile_one "$here/../check.m" "$objects/check.o"
    # A program of the device's own directory, or this directory's control, which is the only one
    # written here.
    if [ -f "$here/$name.m" ]; then main=$here/$name.m; else main=$here/../$name.m; fi
    compile_one "$main" "$objects/main.o"
    case $kind in
        process)
            link_one "$out/$name" "$objects"/*.o
            ;;
        app)
            bundle=$out/$executable.app
            rm -rf "$bundle"
            mkdir -p "$bundle"
            link_one "$bundle/$executable" "$objects"/*.o
            cp "$here/../$name-Info.plist" "$bundle/Info.plist"
            ;;
    esac
    echo "built $name for iOS $release ($(ls "$objects" | wc -l | tr -d ' ') objects)"
}

built=""
for name in $programs; do
    case $name in
        photosalbums8) build "$name" process photosalbums8 ;;
        photoschanges8) build "$name" app photoschanges ;;
        photosdata9) build "$name" app photosdata ;;
        photosavailability13) build "$name" process photosavailability13 ;;
        control) build "$name" process control ;;
        *) echo "run.sh: $name is not one of photosalbums8, photoschanges8, photosdata9, photosavailability13, control" >&2; exit 2 ;;
    esac
    built="$built $name"
done
[ "$build_only" = 1 ] && { echo "build-only: nothing was run"; exit 0; }
[ "$want_control" = 1 ] && built="$built control"

# The transport. Every command below goes through the driver's own device module, which checks the
# claim, the tunnel and the UDID; a raw ssh would check none of them and "permission denied" would
# then mean the wrong device.
[ -n "${CHARON_DEVICE_HOLDER:-}" ] || { echo "run.sh: export CHARON_DEVICE_HOLDER=<band> and claim the device first (xmake device ${device_name:+-d $device_name} --minutes=30 claim)" >&2; exit 1; }
device_flag=""
[ -n "$device_name" ] && device_flag="-d $device_name"
# The transport follows -d, and so must every push and fetch: copy.lua picks its env file from
# CHARON_DEVICE (modules/device.lua:46, `name or os.getenv(CHOSEN)`), which without this line was unset
# and every file went to device.env -- so `--device ipad2` copied the programs to the 4S and then ran
# them on the iPad. Found by running on the iPad for the first time; the 4S is the default device, which
# is why the same run worked there.
[ -n "$device_name" ] && export CHARON_DEVICE=$device_name
xmake device $device_flag list 2>&1 | sed 's/^/  /'

remote_dir=/private/var/backports
run_device() { xmake device $device_flag -s 300 run "$1"; }

# The launcher, if the device has not got one. The iPad 2 has no sblaunch -- tests/backports/README.md
# says so in as many words -- and charon-sblaunch is the tree's own way to start an application on
# either device, held at /usr/libexec and copied to a device from packages/e/emulator-guest, which is
# the package that builds it.
#
# It is FOUND, not built here, and the reason is measured: the same source compiled with this script's
# own clang line produces a binary that dies with SIGILL the moment SpringBoard is asked to run it --
# `Illegal instruction: 4`, exit 132, on the iPad 2 on 2026-10-01 -- while the copy out of the shared
# store exits 0. packages/e/emulator-guest builds it through @addon/charon/daemon, and installing that
# addon is not this script's business; PHOTOS_SBLAUNCH names a copy when the store has none.
sblaunch=/usr/libexec/charon-sblaunch
ensure_sblaunch() {
    if run_device "test -x $sblaunch"; then
        return 0
    fi
    launcher=${PHOTOS_SBLAUNCH:-$(ls -t "$HOME"/.xmake/packages/e/emulator-guest/latest/*/usr/libexec/charon-sblaunch 2>/dev/null | head -1)}
    if [ ! -f "$launcher" ]; then
        echo "run.sh: charon-sblaunch is not in the shared store and PHOTOS_SBLAUNCH does not name one;" >&2
        echo "  it is built by packages/e/emulator-guest, whose install holds it at usr/libexec/charon-sblaunch" >&2
        exit 1
    fi
    run_device "mkdir -p /usr/libexec"
    copy "$launcher" "$sblaunch"
    run_device "chmod 755 $sblaunch"
    echo "charon-sblaunch: copied to $sblaunch from $(basename "$(dirname "$(dirname "$(dirname "$(dirname "$launcher")")")")")"
}

# A push or a fetch that fails stops the run. It did not: a copy went to the wrong device, the run
# carried on, and the program's own chmod failure was what finally printed -- which is the shape of a
# swallowed failure the tree keeps paying for. CHARON_DEVICE is what copy.lua reads, and the export
# above it is what makes the push follow -d.
copy() { CHARON_ROOT=$root xmake l "$here/copy.lua" "$1" "$2" >/dev/null; }
fetch() { CHARON_ROOT=$root xmake l "$here/copy.lua" "$1" "$2" --fetch >/dev/null; }

failed=0
refused=0
ran=0
report() { # $1 program, $2 report path on this host
    name=$1
    report=$2
    if [ ! -s "$report" ]; then
        echo "$name: NO REPORT -- the program wrote nothing to $remote_dir, so nothing about it is known"
        failed=1
        return
    fi
    sed 's/^/  | /' "$report"
    if ! grep -Eq '^[0-9]+ checks, [0-9]+ failed' "$report"; then
        echo "$name: no figure line in the report"
        failed=1
        return
    fi
    figure=$(grep -E '^[0-9]+ checks, [0-9]+ failed' "$report" | tail -1)
    count=$(echo "$figure" | awk '{print $1}')
    bad=$(echo "$figure" | awk '{print $3}')
    grep -a '^FAIL' "$report" | sed 's/^/  FAILED /' || true
    echo "$name: $figure"
    # The control is the one program whose failure is the verdict: it is run with expect_failure set,
    # and then only a report that says 0 failed is a failure of the run.
    if [ "$name" = control ]; then
        [ "$bad" -ne 0 ] || failed=1
        return
    fi
    [ "$bad" -eq 0 ] || failed=1
    [ "$count" -gt 0 ] || failed=1
}

for name in $built; do
    case $name in
        photosalbums8|photosavailability13|control)
            ran=$((ran + 1))
            copy "$out/$name" "$remote_dir/$name"
            run_device "chmod +x $remote_dir/$name; $remote_dir/$name $remote_dir/$name.log; echo \"exit=\$?\""
            fetch "$remote_dir/$name.log" "$out/$name-$device_name.report"
            report "$name" "$out/$name-$device_name.report"
            ;;
        photoschanges8|photosdata9)
            if [ "$allow_write" != 1 ] && [ "$device_name" != ipad2 ]; then
                which=${device_name:-the default device}
                echo "$name: REFUSED -- it writes to the photo library, and $which's library is the owner's."
                echo "  Run it on the iPad 2 (the one holding the fleet's CharonPhotosProbe fixtures), or set PHOTOS_ALLOW_WRITE=1"
                echo "  if that device's library is a test library. Nothing was pushed and nothing ran."
                # Counted as refused, not as a failed check: a check did not fail, a program did not
                # run. The exit status stays non-zero either way, so a partial run is never a pass.
                refused=$((refused + 1))
                continue
            fi
            ran=$((ran + 1))
            executable=$(echo "$name" | sed 's/photoschanges8/photoschanges/; s/photosdata9/photosdata/')
            # The report name is the program's own, and it is NOT this script's name for it:
            # photoschanges8.m writes photoschanges.log and photoschanges.done, photosdata9.m writes
            # photosdata.log and photosdata.done, while the runner was waiting for photoschanges8.done.
            # So a program that ran and passed was reported as NO REPORT. Measured on the iPad 2 on
            # 2026-10-01: 22 checks and 0 failures in /private/var/backports/photoschanges.log, and
            # "NO REPORT" here. The stem is the bundle executable's, which is what those two names are.
            stem=${executable}
            # The last run's report and its .done marker go first, or this run reports the last one's
            # figures: the marker is there before the program has been launched, the wait below would
            # return at once, and the log fetched would be September's -- which is what the iPad held,
            # from the iPad runs of 2026-09-23 and 2026-09-24.
            run_device "rm -f $remote_dir/$stem.log $remote_dir/$stem.done"
            # The bundle is a directory and the transport copies files, one at a time: `scp: local
            # "photoschanges.app" is not a regular file` is what the first iPad run said. The bundle is
            # made on the device out of the two files, which is also what a hand-built test bundle is.
            run_device "rm -rf /Applications/$executable.app; mkdir -p /Applications/$executable.app"
            copy "$out/$executable.app/$executable" "/Applications/$executable.app/$executable"
            copy "$out/$executable.app/Info.plist" "/Applications/$executable.app/Info.plist"
            # uicache is a per-user cache and answers "incorrect user" from root: it is run as mobile,
            # which is what tests/backports/README.md says to do. And the iPad 2 has no sblaunch --
            # the launcher's own line -- so this is packages/e/emulator-guest/src/charon-sblaunch, built
            # and signed here with its entitlements and copied to /usr/libexec. Both facts came from
            # the first iPad run: "cannot open cache file. incorrect user?" and "sblaunch: command not
            # found".
            ensure_sblaunch
            run_device "su mobile -c 'uicache -p /Applications/$executable.app'"
            # One argument, no --wait: the copy in the shared store predates that option and answers
            # "usage: charon-sblaunch <bundle identifier>" with exit 2 (measured on the iPad 2 on
            # 2026-10-01), and the wait below -- for the .done marker the program itself writes -- is
            # what waits for the application anyway.
            run_device "/usr/libexec/charon-sblaunch local.charon.backports.${executable}"
            echo "$name: launched; the report is $remote_dir/$stem.log when it writes $remote_dir/$stem.done"
            # The applications write their report to a file, not to the launch's stdout, because a
            # process SpringBoard started has no terminal to print to. Wait for the .done marker the
            # program writes itself, bounded, and fetch the log it left.
            waited=0
            while [ "$waited" -lt 60 ]; do
                if run_device "test -f $remote_dir/$stem.done"; then
                    break
                fi
                waited=$((waited + 1))
                sleep 2
            done
            if [ "$waited" -ge 60 ]; then
                echo "$name: the program did not write $remote_dir/$stem.done within 120s; the log it did write follows"
            fi
            fetch "$remote_dir/$stem.log" "$out/$name-$device_name.report"
            report "$name" "$out/$name-$device_name.report"
            ;;
    esac
done

# The control is the last thing said, because it is what makes the figures above mean anything.
for name in $built; do
    [ "$name" = control ] || continue
    if grep -Eq '^[0-9]+ checks, [1-9][0-9]* failed' "$out/$name-$device_name.report" 2>/dev/null; then
        echo "control: it failed, so a failing check in a program above would have been seen"
    else
        echo "control: IT DID NOT FAIL. Either this device does not deny the process the release denies, which"
        echo "  makes photosalbums8's own check vacuous, or the report is not the control's. The figures"
        echo "  above are not evidence until this is."
        failed=1
    fi
done

echo "reports and builds: $out"
# Three counts, because one number would have to mean two things: a program that ran and passed, a
# program that ran and failed, and a program this script declined to run at all. A default run on any
# device but the iPad 2 refuses the two that write, and that is not a check failure -- saying which
# is the difference between a reader trusting the last line and a reader hunting a broken check that
# does not exist.
if [ "$failed" -eq 0 ] && [ "$refused" -eq 0 ]; then
    echo "photos device: $ran ran, 0 refused, every check that ran passed"
else
    echo "photos device: $ran ran, $refused refused (not run), $failed failed"
fi
[ "$failed" -eq 0 ] && [ "$refused" -eq 0 ]
