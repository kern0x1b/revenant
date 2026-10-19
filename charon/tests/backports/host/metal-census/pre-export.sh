#!/bin/sh
# pre-export.sh - the two checks the 6.1.3 gate found that neither a compile nor a review could see.
#
#     sh tests/backports/host/metal-census/pre-export.sh
#
# Run from packages/a/apple-backports. It compiles every .m of Metal/ and MetalKit/ with the
# library's own flags, then on the resulting OBJECTS runs the two checks below. A compile cannot
# catch either of them, and both cost a merge.
#
# 1. NO UNRESOLVED _Charon* SYMBOL. A `static` that is DECLARED in one .m and DEFINED in another is
#    a link error, not a compile error: each file compiles alone, and the 6.1.3 link fails on
#    undefined _CharonAttributesFromFunction. So every undefined _Charon* symbol of every object is
#    resolved against the DEFINED symbols of the whole library directory, and one that no object
#    defines is a failure with its name.
#
# 2. ONE OBJECT, ONE RELEASE. release-split walks the real cache ladder and fails an object that
#    carries symbols first exported in two different releases, because such an object is placed in
#    neither band. A file that mixes 9.0 and 10.0.1 compiles, links, and passes every test, and the
#    gate stops on it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/pre-export}
# CHECK 2 TAKES ITS OWN OBJECTS DIRECTORY, so it runs on ANY library: the gate's mixed-release object
# was SecProtocolMetadataAccessors13_0.m in Security, and a check that can only look at Metal cannot
# see it. The compile loop above is Metal and MetalKit; this is whatever you point it at.
split_dir=${SPLIT_DIR:-$work/obj}
SDK=""
for candidate in "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk; do
    if [ -f "$candidate/SDKSettings.json" ]; then SDK="$candidate"; break; fi
done
[ -n "$SDK" ] || { echo "FAIL: no iOS 16.4 SDK; set it in the script" >&2; exit 1; }
# ONE guard for every script that removes a scratch path - see work-guard.sh. WORK comes from the
# caller and is handed straight to rm -rf, so a relative path, a path with a `..` in it, or an empty
# one is refused here rather than discovered afterwards.
. "$(dirname "$0")/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -rf "$work"
mkdir -p "$work/obj"

# CHECK 2 ALONE, for a library that is not Metal: SPLIT_DIR says whose objects, and ONLY_SPLIT=1
# skips the compile loop so the check can be run on any library's objects. The gate's mixed-release
# object was in Security, and a check that can only reach Metal cannot see it.
# CHECK 2 ITSELF, in one place, because it is the same check on both paths. IT MUST HAVE LOOKED AT
# SOMETHING AND SUCCEEDED: the tool's own exit status, AND a verdict naming a file count above zero.
#
# It used to run with `|| true` and then only grep for an `error:` line, so every one of these printed
# "pre-export: OK" and exited 0: an EMPTY objects dir, a dir that DOES NOT EXIST (so the cd failed and
# the tool never ran), an objects dir holding a .o that is NOT Mach-O (the tool's log said "error:
# there is nothing to split", which is not a `release-split:` line), and an xmake that FAILED. A
# check that examined nothing said it passed - the same class of defect as alloc-r7.
run_split() {   # fails, naming why, unless the tool succeeded over at least one real object
    split=${SPLIT_OUT:-$work/split.txt}
    status=0
    ( cd "$root" && xmake l tools/release-split.lua "$split_dir" "$split" "$SDK" ) \
        > "$work/split.log" 2>&1 || status=$?
    plain=$(sed 's/\x1b\[[0-9;]*m//g' "$work/split.log")
    mixed=$(printf '%s\n' "$plain" | grep -E "^error: release-split" || true)
    if [ -n "$mixed" ]; then
        echo "$mixed" >&2
        echo "pre-export: an object in $(cd "$split_dir" && pwd) carries two releases' API" >&2
        exit 1
    fi
    if [ "$status" -ne 0 ]; then
        echo "pre-export: release-split exited $status, so its verdict is not a verdict" >&2
        printf '%s\n' "$plain" | tail -3 | sed 's/^/    /' >&2
        exit 1
    fi
    # the verdict itself, and a file count ABOVE ZERO. "clean ... (0 files ...)" means the tool had
    # no object to place, which is not a pass - it is a check that examined nothing.
    clean=$(printf '%s\n' "$plain" | grep -E "^release-split: clean," || true)
    if [ -z "$clean" ]; then
        echo "pre-export: release-split said no clean verdict about $(cd "$split_dir" && pwd)" >&2
        printf '%s\n' "$plain" | tail -3 | sed 's/^/    /' >&2
        exit 1
    fi
    # "file" as a PREFIX, not "files?": a \? is not portable across seds and silently matched
    # nothing, which read as "no count" and failed the run this script must pass.
    count=$(printf '%s\n' "$clean" | sed -n 's/.*(\([0-9][0-9]*\) file.*/\1/p' | head -1)
    if [ -z "$count" ] || [ "$count" -eq 0 ]; then
        echo "pre-export: release-split placed ${count:-no} file(s), so it examined nothing" >&2
        echo "  $clean" >&2
        exit 1
    fi
    echo "release-split: $count file(s) in $(cd "$split_dir" && pwd), each in one release"
}

if [ -n "${ONLY_SPLIT:-}" ]; then
    run_split
    echo "pre-export: OK (split only)"
    rm -rf "$work"
    exit 0
fi

# THE COMPILE, on clang's own exit status, and a count line.
count=0
bad=0
for dir in Metal MetalKit; do
    for source in "$dir"/*.m; do
        count=$((count + 1))
        if ! xcrun clang -target armv7-apple-ios6.1.3 -isysroot "$SDK" -fobjc-arc -Os -g0 -Wall \
             -Wno-unguarded-availability-new -Wno-unguarded-availability \
             -Werror=objc-missing-property-synthesis -c "$source" -o "$work/obj/$(basename "${source%.m}").o" \
             > "$work/obj/$(basename "${source%.m}").build" 2>&1; then
            bad=$((bad + 1))
            echo "FAIL does not compile: $source" >&2
            sed 's/^/    /' "$work/obj/$(basename "${source%.m}").build" | head -6 >&2
        fi
    done
done
[ "$bad" -eq 0 ] || { echo "pre-export: $bad file(s) do not compile" >&2; exit 1; }
echo "$count files, 0 errors"

# 1. every undefined _Charon* resolved against every DEFINED symbol of this library
#
# NM MUST HAVE WORKED, AND MUST HAVE READ SOMETHING. It used to run with 2>/dev/null into a pipeline,
# so an nm that failed - or one that printed nothing - left $defined empty, no symbol ever looked
# undefined, and a library with a real link error printed "no unresolved _Charon* symbol in 58
# object(s)" and passed. An empty result is the absence of evidence and is now a failure.
nm_all=$work/nm-all.txt
nm_status=0
xcrun nm -g "$work"/obj/*.o > "$nm_all" 2>"$work/nm.err" || nm_status=$?
if [ "$nm_status" -ne 0 ]; then
    echo "FAIL: nm exited $nm_status over the objects, so check 1 could not read them" >&2
    sed 's/^/    /' "$work/nm.err" | head -3 >&2
    exit 1
fi
defined=$(awk '$2 != "U" {print $3}' "$nm_all" | sort -u)
defined_count=$(printf '%s\n' "$defined" | grep -c . || true)
objects=$(ls "$work"/obj/*.o | wc -l | tr -d ' ')
examined=0
unresolved=0
for object in "$work"/obj/*.o; do
    one=$work/nm-one.txt
    one_status=0
    xcrun nm -g "$object" > "$one" 2>"$work/nm-one.err" || one_status=$?
    if [ "$one_status" -ne 0 ]; then
        echo "FAIL: nm exited $one_status on $(basename "$object"), so check 1 could not read it" >&2
        sed 's/^/    /' "$work/nm-one.err" | head -3 >&2
        exit 1
    fi
    examined=$((examined + $(wc -l < "$one" | tr -d ' ')))
    for symbol in $(awk '$1 == "U" || $2 == "U" {print $NF}' "$one" | grep "^_Charon" | sort -u); do
        if ! printf '%s\n' "$defined" | grep -qx "$symbol"; then
            unresolved=$((unresolved + 1))
            echo "FAIL $(basename "$object") needs $symbol and no object of this library defines it" >&2
        fi
    done
done
[ "$unresolved" -eq 0 ] || { echo "pre-export: $unresolved unresolved _Charon* symbol(s)" >&2; exit 1; }
# A pass is only a pass if symbols were actually read. Zero defined symbols AND zero lines examined
# means nm produced nothing at all, whatever its exit status said.
if [ "$defined_count" -eq 0 ] && [ "$examined" -eq 0 ]; then
    echo "FAIL: check 1 examined no symbols at all, so it cannot have found an unresolved one" >&2
    exit 1
fi
echo "no unresolved _Charon* symbol in $objects object(s); nm read $examined symbol line(s), $defined_count defined"

# 2. release-split on SPLIT_DIR, whatever library that is: one release each
run_split
echo "pre-export: OK"
# THE SCRATCH IS REMOVED HERE, and its whole point is that a run leaves nothing behind to be read as
# a result by the next one.
rm -rf "$work"
