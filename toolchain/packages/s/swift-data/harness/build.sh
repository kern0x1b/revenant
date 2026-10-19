#!/bin/bash
# The module built for armv7, with the counts every published number comes from.
#
# `swift-data` is in no LIBRARIES and no gate config, so the backports gate never builds it: a
# green gate says nothing about this package. This is the build that does, and it is here rather
# than in a band's .agent-work because a package's build belongs to the package.
#
# The flags are the ones modules/apple/swift.lua runtime_flags() builds, and the Foundation modules
# are the ones FetchDescriptor's predicate and sortBy are swift-foundation's own types from. Where
# the toolchain, the runtime and those two modules are is a fact about this machine's store, not
# about the package, so they are named in the environment and this script says so when they are
# not:
#
#   REVENANT_SWIFTC            the toolchain's swiftc
#   REVENANT_SWIFT_RESOURCE    the swift-runtime's resource directory, its lib/swift
#   REVENANT_SWIFT_MODULES     the swift-runtime's armv7 module directory
#   REVENANT_SWIFT_PORT      the backports' port headers, the vfs.yaml
#   REVENANT_SWIFT_SDK         the iPhoneOS SDK
#   REVENANT_SWIFT_PLUGIN_PATH the toolchain's macro plugins
#   REVENANT_SWIFT_AVAILABILITY a file of availability macros, one `Name Release: ...` per line
#   REVENANT_FOUNDATION_MODULES the Foundation band's build, for FoundationEssentials and
#                             FoundationInternationalization
#   REVENANT_FOUNDATION_CMODULES the C modules those two are built against, space separated
#   REVENANT_BACKPORTS         a built libCoreDataBackports.dylib to link against
#
#   ./harness/build.sh 6.1.3
set -eu
RELEASE="${1:-6.1.3}"
ARCH="${REVENANT_SWIFT_ARCH:-armv7}"
TRIPLE="$ARCH-apple-ios$RELEASE"
HERE="$(cd "$(dirname "$0")" && pwd)"
PACKAGE="$(cd "$HERE/.." && pwd)"
OUT="${REVENANT_SWIFTDATA_OUT:-${TMPDIR:-/tmp}/swiftdata-build/$RELEASE}"
mkdir -p "$OUT"

for name in REVENANT_SWIFTC REVENANT_SWIFT_RESOURCE REVENANT_SWIFT_MODULES REVENANT_SWIFT_PORT \
            REVENANT_SWIFT_SDK REVENANT_SWIFT_AVAILABILITY REVENANT_FOUNDATION_MODULES; do
    value="${!name:-}"
    if [ -z "$value" ] || [ ! -e "$value" ]; then
        echo "build.sh needs $name naming something that exists; it is not set here." >&2
        exit 2
    fi
done

AVAILABILITY=()
while IFS= read -r line; do
    name="${line%%:*}"
    [ -n "$name" ] || continue
    case "$name" in \#*) continue ;; esac
    AVAILABILITY+=(-Xfrontend -define-availability "-Xfrontend" "$name:*")
    case "$name" in
        SwiftStdlib*) AVAILABILITY+=(-Xfrontend -define-availability "-Xfrontend" \
                                      "${name/SwiftStdlib/StdlibDeploymentTarget}:*") ;;
    esac
done < "$REVENANT_SWIFT_AVAILABILITY"

# -wmo -c on its own writes a Mach-O. The bitcode wrapper comes from asking for the module
# interface in the same invocation, and a -emit-library link of that wrapper "succeeds" into an
# empty library - so the interface is a second compile and the count below is the check that the
# object is real.
FLAGS=(-target "$TRIPLE" -clang-target "$TRIPLE" -sdk "$REVENANT_SWIFT_SDK"
       -resource-dir "$REVENANT_SWIFT_RESOURCE" -Xfrontend -bundled-swift-runtime
       -runtime-compatibility-version none -wmo -parse-as-library
       -I "$REVENANT_SWIFT_MODULES" -vfsoverlay "$REVENANT_SWIFT_PORT" "${AVAILABILITY[@]}")
[ -n "${REVENANT_SWIFT_PLUGIN_PATH:-}" ] && FLAGS+=(-plugin-path "$REVENANT_SWIFT_PLUGIN_PATH")
FLAGS+=(-I "$REVENANT_FOUNDATION_MODULES")
for map in ${REVENANT_FOUNDATION_CMODULES:-}; do
    FLAGS+=(-Xcc "-fmodule-map-file=$map" -Xcc "-I$(dirname "$map")"
            -Xcc "-I$(dirname "$(dirname "$map")")")
done

SOURCES="$PACKAGE/files/SwiftData"
echo "COMPILE -target $TRIPLE -wmo -c packages/s/swift-data/files/SwiftData/*.swift"
"$REVENANT_SWIFTC" "${FLAGS[@]}" -module-name SwiftData -O \
         -c -o "$OUT/SwiftData.o" \
         "$SOURCES"/*.swift 2> "$OUT/compile.err"
"$REVENANT_SWIFTC" "${FLAGS[@]}" -module-name SwiftData -O \
         -emit-module-path "$OUT/SwiftData.swiftmodule" -emit-module \
         "$SOURCES"/*.swift 2>> "$OUT/compile.err"
echo "COMPILE ERRORS $(grep -cE 'error:' "$OUT/compile.err" || true)"
if grep -qE 'error:' "$OUT/compile.err"; then
    grep -E 'error:' "$OUT/compile.err" | head -10
    exit 1
fi
echo "OBJECT  $(basename "$OUT/SwiftData.o") $(stat -f %z "$OUT/SwiftData.o") bytes  $(file -b "$OUT/SwiftData.o")"

# The counts and what every undefined symbol is waiting for, from harness/symbols.lua: the number
# the delivery quotes, with the classification that says whether the module needs anything at all.
REVENANT_SWIFTDATA_OBJECT="$OUT/SwiftData.o" xmake l "$HERE/symbols.lua"

# And the link, with the pinned ld64 - which the flags name through REVENANT_SWIFTC's own -use-ld,
# and which the host's ld cannot substitute for.
if [ -n "${REVENANT_BACKPORTS:-}" ] && [ -f "$REVENANT_BACKPORTS/libCoreDataBackports.dylib" ]; then
    LD64="${REVENANT_LD64:-}"
    LINKFLAGS=()
    [ -n "$LD64" ] && [ -x "$LD64" ] && LINKFLAGS=(-use-ld="$LD64")
    echo "LINK -emit-library -lCoreDataBackports"
    if "$REVENANT_SWIFTC" "${FLAGS[@]}" "${LINKFLAGS[@]}" -module-name SwiftData \
                 -emit-library -o "$OUT/libSwiftData.dylib" \
                 -L "$REVENANT_BACKPORTS" -lCoreDataBackports \
                 "$OUT/SwiftData.o" 2> "$OUT/link.err"; then
        defined=$(nm -g "$OUT/libSwiftData.dylib" | grep -c ' T \| S \| B ')
        undefined=$(nm -u "$OUT/libSwiftData.dylib" | wc -l | tr -d ' ')
        echo "LINKED $OUT/libSwiftData.dylib $(stat -f %z "$OUT/libSwiftData.dylib") bytes"
        echo "SYMBOLS defined=$defined undefined=$undefined"
        if [ "$defined" -lt 50 ]; then
            echo "LINK SUSPECT: a library with $defined defined symbols did not take the module's code"
        fi
        otool -L "$OUT/libSwiftData.dylib" | sed 's/^/LC /'
    else
        echo "LINK FAILED - the undefined symbols are in the UNDEFINED lines above"
    fi
else
    echo "LINK not attempted: set REVENANT_BACKPORTS to a directory holding libCoreDataBackports.dylib"
fi
