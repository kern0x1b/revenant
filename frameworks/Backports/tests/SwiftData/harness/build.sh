#!/bin/bash
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

REVENANT_SWIFTDATA_OBJECT="$OUT/SwiftData.o" xmake l "$HERE/symbols.lua"

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
