#!/bin/sh
# run.sh — measures a framework's exported string constants on the host and diffs them against the
# values this package carries, with tools/corpus/host-probe.c as the instrument.
#
# The two families this covers are HomeKit and AuthenticationServices. For each it asks the host's own
# copy of the framework for every constant the registry lists, and compares. The comparison is the
# point: a port that writes a constant from the name rather than from the release will show up here as
# a difference, and a port that invents one will show up as a name the host does not export.
#
# A framework's *class* names are not string constants and are not asked about: dlsym does not see a
# bare class name (the symbol is _OBJC_CLASS_$_Name), and a class that answered here would be a class
# reported as a constant. The registry's class rows are checked by check-model.sh against the tree
# instead, which is the right instrument for them.
#
# The library comparison needs the two built binaries, named by BUILT_HOMEKIT and
# BUILT_AUTHENTICATIONSERVICES (or BUILT for both) -- a gate run's libHomeKitBackports.dylib and
# libAuthenticationServicesBackports.dylib are what to point them at. Set HOMEKIT_SOURCES to a path
# relative to the repository root to have the code mutation built and shown failing as well.
#
# Run with no arguments it measures both families and writes a table per family into
# coordination/corpus/ledger/constant-values-<framework>.tsv, next to the HomeKit and
# AuthenticationServices ones it reproduces. Exit 0 only when every value agrees.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
revenant=${REVENANT:-$here/../../../..}
registry="$revenant/packages/frameworks/apple-backports/registry"
build=${BUILD:-$(runs_fresh revenant-constants)}
mkdir -p "$build"
ledger=${LEDGER:-$HOME/Git/projects/ios/coordination/corpus/ledger}

cc -O2 -Wno-unused-parameter -framework CoreFoundation -o "$build/host-probe" "$revenant/tools/corpus/host-probe.c"
cc -O2 -o "$build/object-constant" "$revenant/tools/corpus/object-constant.c"

failed=0
# The built library, when the caller names one. OBJECTS may be a dylib or a directory of objects; a
# relocatable object's pointer is unresolved, so a directory is only partly useful and the run says
# which it was given. The gate's libHomeKitBackports.dylib is the artefact that carries the values.
# One built binary per family, because a HomeKit constant is not in the AuthenticationServices
# library and a comparison against the wrong one would answer "not in the library" for all of it,
# which is indistinguishable from passing. Both default to BUILT, and each names its own library.
builtHomeKit=${BUILT_HOMEKIT:-${BUILT:-}}
builtAuthenticationServices=${BUILT_AUTHENTICATIONSERVICES:-${BUILT:-}}
selfTest="no"

measure() {
    framework="$1"
    source="$2"
    built="$3"
    names="$build/$framework-names.txt"
    measured="$build/$framework.tsv"
    table="$ledger/constant-values-$framework.tsv"

    # The names come from the registry, not from a list here: the registry is what the port claims,
    # so the set of questions is exactly the set of claims.
    runs_xmake l "$here/measure.lua" names "$registry/$framework" "$names"

    echo "== $framework: $(wc -l < "$names" | tr -d ' ') constants, asking $source"
    if ! "$build/host-probe" "$source" "$names" > "$measured"; then
        echo "   the probe reported names it could not measure; the comparison below says which"
    fi
    set +e
    # The library's own answer, from the binary: the value the port's code carries, as opposed to the
    # value its registry row claims. A row and the host can agree perfectly while the source defines
    # something else, and only this comparison sees that.
    objectValues="$build/$framework-objects.tsv"
    if [ -n "$built" ]; then
        set +e
        "$build/object-constant" "$built" "$names" > "$objectValues" 2>/dev/null
        set -e
    else
        : > "$objectValues"
    fi

    set +e
    runs_xmake l "$here/measure.lua" compare "$registry/$framework" "$measured" "$table" "$framework" "$objectValues"
    rc=$?
    set -e
    [ "$rc" -eq 0 ] || failed=1
}

measure HomeKit /System/Library/PrivateFrameworks/HomeKit.framework/Versions/A/HomeKit "$builtHomeKit"
measure AuthenticationServices /System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices "$builtAuthenticationServices"

# No verdict yet: the self-test below has a word in the run's outcome, and a verdict printed before it
# would be about half the run.

# The second comparison -- the built library against the row -- has to be shown to fail, or it is a
# check nobody can tell from no check. The mutation is the coordinator's: one constant's value changed
# in the *code* while its registry row stays correct, which is the shape a text comparison cannot see.
# It needs a linked binary, because a relocatable object's pointer is a relocation the linker fills in
# and holds no value at all -- which is why the comparison reads a dylib and not a .o.
if [ -n "${HOMEKIT_SOURCES:-}" ] && [ -d "${MUTANT_SDK:-/nonexistent}" ] && [ -x "${MUTANT_CLANG:-/nonexistent}" ]; then
    mutant="$build/mutant"
    mkdir -p "$mutant/clean" "$mutant/changed"
    # The mutated source is written before the loop that compiles it: the change is one constant's value
    # in the code, with its registry row left correct, which is the shape a text comparison cannot see.
    sed 's/@"array"/@"arrayX"/' "$revenant/$HOMEKIT_SOURCES" > "$mutant/changed.m" 2>/dev/null || true

    for side in clean changed; do
        source="$revenant/$HOMEKIT_SOURCES"
        [ "$side" = changed ] && source="$mutant/changed.m"
        # The port's deployment: the same target the objects in the tree are built for, which is why
        # the tool has to read a file rather than load it -- an armv7 binary is not this host's.
        "$MUTANT_CLANG" -target armv7-apple-ios6.1.3 -isysroot "$MUTANT_SDK" -fobjc-arc -Os -g0 -fPIC \
              -I"$revenant/packages/frameworks/apple-backports/HomeKit" \
              -c "$source" -o "$mutant/$side/c.o" 2>/dev/null || true
        [ -f "$mutant/$side/c.o" ] || continue
        "$MUTANT_CLANG" -target armv7-apple-ios6.1.3 -isysroot "$MUTANT_SDK" -dynamiclib -Wl,-undefined,dynamic_lookup \
              -install_name /usr/lib/libmutant.dylib -o "$mutant/$side/libmutant.dylib" "$mutant/$side/c.o" 2>/dev/null || true
    done
    if [ -f "$mutant/clean/libmutant.dylib" ] && [ -f "$mutant/changed/libmutant.dylib" ]; then
        printf 'HMCharacteristicMetadataFormatArray\n' > "$mutant/one.txt"
        a=$("$build/object-constant" "$mutant/clean/libmutant.dylib" "$mutant/one.txt" 2>/dev/null | tail -1 | cut -f4)
        b=$("$build/object-constant" "$mutant/changed/libmutant.dylib" "$mutant/one.txt" 2>/dev/null | tail -1 | cut -f4)
        if [ -z "$a" ] || [ -z "$b" ] || [ "$a" = "$b" ]; then
            echo "FAIL: the mutation did not change the value in the code ($a -> $b), so the self-test"
            echo "      would pass on a check that cannot see a wrong value"
            exit 1
        fi
        echo "ok:   the mutation changed one value in the code only ($a -> $b), with its row left correct"
        # Now the check has to go red on it. The mutant library is handed to the runner as the built
        # binary, which is the path the finding was about: the row agrees with the host, the library
        # does not, and the run has to exit non-zero because of the library alone.
        echo "ok:   handing the mutated library to this same check, which now has to fail:"
        set +e
        BUILT_HOMEKIT="$mutant/changed/libmutant.dylib" BUILT_AUTHENTICATIONSERVICES="$builtAuthenticationServices" \
            HOMEKIT_SOURCES= MUTANT_SDK= MUTANT_CLANG= \
            "$0" > "$mutant/rerun.txt" 2>&1
        rerun=$?
        set -e
        grep -E "THE LIBRARY SAYS|agree," "$mutant/rerun.txt" | sed 's/^/        /'
        if [ "$rerun" -eq 0 ]; then
            echo "FAIL: the run exited 0 with a library that disagrees with its own row"
            exit 1
        fi
        echo "ok:   that run exited $rerun, and the row agreed with the host throughout it"
        selfTest="yes"
    else
        selfTest="no"
        echo "note: the code mutation was not built here, so the library comparison is not shown failing"
    fi
fi

# The verdict, last, and about what was actually compared: the registry row, the host, and the built
# library where one was given. A run with no built library has compared two of the three and says so.
compared="the registry row and the host"
[ -n "$builtHomeKit" ] || [ -n "$builtAuthenticationServices" ] && compared="the registry row, the host, and the built library"
if [ "$failed" -ne 0 ] || [ "${selfTest:-no}" = "no" ] && [ -n "${HOMEKIT_SOURCES:-}" ]; then
    if [ "$failed" -ne 0 ]; then
        echo "FAIL: a value the port carries is not the same across $compared"
    else
        echo "FAIL: the self-test did not run"
    fi
    exit 1
fi
if [ "$failed" -ne 0 ]; then
    echo "FAIL: a value the port carries is not the same across $compared"
    exit 1
fi
echo "ok: every constant both families carry is the same across $compared"
