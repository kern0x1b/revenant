#!/bin/sh
# run.sh — the RealityFoundation/RealityKit overlays, compiled the way packages/s/swift-runtime
# builds them: two modules, RealityFoundation first, then RealityKit on top of it, then the harness
# linked against both.
#
# Two modules, not one. The one-unit build (every source of both modules in one invocation) is what
# this host test used to do, and it is not what the package does, and the difference is not
# cosmetic: in the one-unit build Accessibility.swift's component does not satisfy `Component`
# ("subscript 'subscript(_:)' requires that 'Entity.AccessibilityComponent' conform to 'Component'",
# 6 errors), while the same file in the two-module build the package performs compiles with none.
# Under Apple's swiftlang driver the one-unit build refuses outright as well - "module
# 'RealityFoundation' is an implementation detail of 'RealityKit'". The package's shape is the
# authoritative one, so this is that shape.
#
# The compiler is the Swift 6.4.0 the package builds with (charon@swift 6.4.0, swift-6.4-RELEASE),
# named rather than taken from PATH; RF_SWIFTC overrides it.
#
# What this is not: a system comparison - no release before iOS 13 carries either module and the
# 26.2 one is an interface with no implementation to run. main.swift says so at its top.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
files=${RF_OVERLAY_FILES:-$here/../../../../packages/s/swift-runtime/files}
# The build goes in the worktree's own run directory, not the system temp path: the brief's rule is
# that nothing of a band goes in /tmp, which is wiped, and this build is run output.
here_root=$(cd "$here/../../../.." && pwd)
build=${RF_BUILD:-$here_root/.agent-work/runs/host-realityfoundation}
sdk=${RF_SDK:-$(xcrun --show-sdk-path)}
target=${RF_TARGET:-$(uname -m)-apple-macos14}
swiftc=${RF_SWIFTC:-$HOME/.xmake/packages/s/swift/6.4.0/f1d0e4f9eebe477396350986a88081e5/bin/swiftc}
[ -x "$swiftc" ] || swiftc=swiftc
[ -d "$sdk" ] || sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
rm -rf "$build"
mkdir -p "$build"

sources() { # every source of both overlays, as words
    for source in "$files"/RealityFoundation/*.swift "$files"/RealityKit/*.swift; do printf '%s ' "$source"; done
}

common="-target $target -sdk $sdk -swift-version 5 -parse-as-library -O -wmo"

# RealityFoundation (xmake.lua:700)
# shellcheck disable=SC2086
"$swiftc" $common -module-name RealityFoundation -emit-module \
    -emit-module-path "$build/RealityFoundation.swiftmodule" -emit-object -o "$build/RealityFoundation.o" \
    $(for source in "$files"/RealityFoundation/*.swift; do printf '%s ' "$source"; done)

# RealityKit (xmake.lua:717)
# shellcheck disable=SC2086
"$swiftc" $common -module-name RealityKit -I "$build" -emit-module \
    -emit-module-path "$build/RealityKit.swiftmodule" -emit-object -o "$build/RealityKit.o" \
    $(for source in "$files"/RealityKit/*.swift; do printf '%s ' "$source"; done)

# the harness: top-level code in its own main.swift, so no -parse-as-library here
# shellcheck disable=SC2086
"$swiftc" -target "$target" -sdk "$sdk" -swift-version 5 -I "$build" \
    -o "$build/rf-check" "$build/RealityFoundation.o" "$build/RealityKit.o" "$here/main.swift"

# The registry's sources are bound to what the differential actually measures, and the binding is
# checked here rather than trusted: --check exits non-zero if a row's source is not what coverage.py
# decides, and the control beside it is the same edit the reviewer made, run every time.
python3 "$here/coverage.py" --check \
    "$here/../../../../packages/s/swift-runtime/registry/RealityFoundation.json" \
    "$here/../../../../packages/s/swift-runtime/registry/RealityKit.json" > "$build/coverage.txt" \
    && coverage=0 || coverage=1
[ "$coverage" -eq 0 ] || { echo "registry sources are not what coverage.py decides:"; \
    grep -E "MISMATCH|CLAIMS A MEASUREMENT" "$build/coverage.txt" | head -6; }
sh "$here/coverage-control.sh" > "$build/coverage-control.txt" 2>&1 && control=0 || control=1
[ "$control" -eq 0 ] || { echo "the coverage control failed:"; head -8 "$build/coverage-control.txt"; }
grep -E "^control: OK" "$build/coverage-control.txt" || true

"$build/rf-check" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
# The number, because a commit message quotes it and a run that prints only "ALL CHECKS PASSED"
# cannot be checked against one.
printf 'checks: %s\n' "$(grep -c '^ok ' "$build/log")"
echo "log=$build/log"

# A differential that cannot tell a mutation from itself guards nothing, so the two mutations this
# family's own commits name are run against it: the clamp's composition - which both the per-pass
# demand and the pose go through - and the pose a limit is held to. Each is a one-token change that
# still compiles, and a mutant counts as caught only when the *suite* goes red: a compiler error is a
# build failure and proves nothing, which is how the first attempt at this was measured.
if [ "${RF_MUTANTS:-1}" = "1" ]; then
    survived=0
    notbuilt=0
    mutant() {
        label=$1; from=$2; to=$3
        rm -rf "$build/mutant"; mkdir -p "$build/mutant"
        cp -R "$files" "$build/mutant/files"
        python3 "$here/mutate.py" "$build/mutant/files/RealityFoundation/IK.swift" "$from" "$to" || { echo "MUTANT REFUSED: $label"; survived=$((survived + 1)); return; }
        if RF_OVERLAY_FILES="$build/mutant/files" RF_BUILD="$build/mutant-build" RF_MUTANTS=0 \
           sh "$here/run.sh" > "$build/mutant-build.log" 2>&1; then
            echo "MUTANT SURVIVED: $label"
            survived=$((survived + 1))
        elif grep -qE "error:" "$build/mutant-build.log"; then
            echo "MUTANT DID NOT BUILD: $label - a build failure, not a caught mutation"
            notbuilt=$((notbuilt + 1))
        else
            echo "caught: $label"
        fi
        rm -rf "$build/mutant-build" "$build/mutant"
    }
    # 1. The clamp takes the *held* twist off and puts it back, so the limit undoes itself. One
    #    token, and it still builds - the review's own attempt failed to compile, which proved nothing.
    mutant "the clamp's composition" \
        "    return (rotation * original.inverse) * clamp" \
        "    return (rotation * clamp.inverse) * clamp"
    # 2. The pose is not held to the joint's limit: the read-back and write-back go, and the demand
    #    clamp above is the only limit left, which bounds a pass and not a joint.
    mutant "the pose a limit holds" \
        "                        if held != posed { chain[at].setWorldOrientation(held) }" \
        "                        if false, held != posed { chain[at].setWorldOrientation(held) }"
    if [ "$survived" -ne 0 ] || [ "$notbuilt" -ne 0 ]; then
        echo "$survived mutant(s) survived and $notbuilt did not build; the differential is not holding"
        exit 1
    fi
    echo "mutations: all caught"
fi
if [ "$result" -ne 0 ] || [ "$coverage" -ne 0 ] || [ "$control" -ne 0 ]; then
    # the differential, the registry's sources and the control that guards them are one verdict
    echo "realfoundation-host: FAILED - checks=$result coverage=$coverage control=$control"
    exit 1
fi
exit 0
