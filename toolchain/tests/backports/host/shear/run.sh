#!/bin/sh
# The port's thirty-six shears held against the host's own thirty-six, case by case: same shapes, same scales,
# same translates, same slopes, same edging modes, every byte of every destination row compared - and both
# answers compared against an expectation this harness computes in its own loops.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
# The four band files (vImageShear70/80/100/150.m) are in the build, with their thirty-six registry rows
# (commit 2f0211c2ef), and this harness compiles them from the package they ship in. They used to live in
# `.agent-work/pending-shears/`, a folder nothing tracks, which is why the sweep found them missing.
ACCELERATE=$here/../../../../packages/a/apple-backports/Accelerate
SHEARS=${SHEARS:-$ACCELERATE}
build=${SHEAR_BUILD:-$(runs_folder revenant-shear-host)}
rm -rf "$build"
mkdir -p "$build"

# **The port's objects are built with the package's own line** - `-Os -Wall -Wno-unguarded-availability-new
# -Wno-unguarded-availability` - and not with clang's default optimisation. That is not tidiness: every one of
# these functions declares its two buffers `VIMAGE_NON_NULL`, and an attributed parameter is assumed non-null
# inside the function, so at -Os a plain `if (!src)` is folded away and the refusal the release makes is simply
# not in the object. Built this way, the refusals below run against the same arithmetic the bands link, and the
# PLANT control removes the test that survives to show it.
package_cflags="-Os -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability"

# SAN=1 builds the port's objects and this harness with the address and undefined-behaviour sanitizers, at the
# package's own warning set but without its -Os, because an -Os build of a sanitizer's instrumentation is a
# sanitizer that reports less. The comparison is unchanged: the same three answers, byte for byte.
san=""
if [ -n "${SAN:-}" ]; then
    san="-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1"
    package_cflags="$package_cflags -Wno-deprecated-declarations -Wno-unguarded-availability -Wno-nullability-completeness"
fi

# PLANT=<substring> copies the four band files and the shared header to a scratch directory with that line
# removed, and the run is then REQUIRED to fail: a red control for the NULL tests. The copy is made by a script
# that counts its target first, because `str.replace` on a missing needle is a silent no-op and a "planted" run
# over an unplanted file reports a mutant as applied (BRIEF.md, 2026-10-03). Nothing here writes to the tracked
# sources.
plant=""
if [ -n "${PLANT:-}" ]; then
    mkdir -p "$build/planted"
    for source in vImageShear70.m vImageShear80.m vImageShear100.m vImageShear150.m; do
        cp "$SHEARS/$source" "$build/planted/$source"
    done
    for source in RevenantShear.h RevenantChannels.h RevenantResampling.h RevenantVImageFixed.h; do
        cp "$ACCELERATE/$source" "$build/planted/$source"
    done
    # PLANT_REPLACE chooses what the needle becomes; the default removes a whole statement, so what is left is
    # valid C (a bare `0;` where an `if` used to be would not compile, and a control that fails to build proves
    # nothing). A second control replaces an EXPRESSION - the vertical's far-edge anchor - and needs the
    # replacement spelled out.
    replace=${PLANT_REPLACE:-if (0) /* planted: the test can no longer hold */}
    python3 - "$build/planted" "$PLANT" "$replace" <<'PY'
import glob, sys
folder, needle, replacement = sys.argv[1], sys.argv[2], sys.argv[3]
hits = 0
for path in glob.glob(folder + "/*.h"):
    text = open(path).read()
    found = text.count(needle)
    if found:
        open(path, "w").write(text.replace(needle, replacement))
        hits += found
if hits == 0:
    sys.exit("PLANT: the needle is not in any of the copied headers, so nothing was planted")
print("planted: replaced %d occurrence(s) of the needle" % hits)
PY
    ACCELERATE="$build/planted"
fi

# Every API name the objects define is renamed in the port's own translation units, so this one can hold the
# port's answers and the host's side by side. The names come from the port's registry, not from a list kept
# here, so a name added to the library is renamed too.
# The names come from the band files' own definitions, not from a list kept here and not from the registry
# (which carries no rows for these functions yet), so a name added to a band file is renamed too.
names=$(grep -h "^vImage_Error vImage" "$SHEARS"/vImageShear*.m | cut -d'(' -f1 | awk '{print $2}' | sort -u)

renames=""
for name in $names; do
    renames="$renames -D$name=revenant_host_$name"
done

objects=""
for source in vImageShear70.m vImageShear80.m vImageShear100.m vImageShear150.m; do
    # $package_cflags is deliberately unquoted: it is a list of flags, and the count of diagnostics per
    # object is what this prints, because a warning here is a warning the package build would print too.
    diagnostics=$(xcrun clang -c -fobjc-arc $san $package_cflags $renames -I"$ACCELERATE" -I"$SHEARS" \
        "$SHEARS/$source" -o "$build/$(basename "$source").o" 2>&1 | grep -v "^$" || true)
    errors=$(printf '%s\n' "$diagnostics" | grep -c " error: " || true)
    warnings=$(printf '%s\n' "$diagnostics" | grep -c " warning: " || true)
    printf '%-22s errors=%s warnings=%s, with the package line\n' "$source" "$errors" "$warnings"
    printf '%s\n' "$diagnostics" | grep " warning: " || true
    objects="$objects $build/$(basename "$source").o"
done

# The differential includes the port's own filter header to make a filter the port will read, so the include
# path is the port's directory whether or not the objects above were planted.
xcrun clang -fobjc-arc $san -Wall -Wno-deprecated-declarations -I"$ACCELERATE" -I"$SHEARS" \
    "$here/differential.m" $objects \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v "^ok " "$build/log" | tail -40 || true
echo "log=$build/log"
if [ -n "${PLANT:-}" ]; then
    # The control, and the shape of the red it takes matters. With the NULL test gone the port dereferences the
    # pointer the refusal used to catch, so the run ends on a signal rather than printing a FAIL line - which is
    # exactly the behaviour the test exists to prevent, and a weaker red than a mismatch would be. What must NOT
    # happen is a clean run, so the check is on the run's own verdict line.
    if [ "$result" = 0 ] || grep -q "checks, 0 failures" "$build/log"; then
        echo "PLANT: the run is green with the NULL test removed, so the control does not hold" >&2
        exit 1
    fi
    if grep -q "^FAIL" "$build/log"; then
        echo "PLANT: the control holds - without the NULL test a case fails:"
        grep -m3 "^FAIL" "$build/log"
    else
        echo "PLANT: the control holds - without the NULL test the run ends on a signal (exit $result),"
        echo "       which is the release's own behaviour on three of these inputs and is what the test stops"
    fi
    exit 0
fi
exit $result