#!/usr/bin/env bash
# The framework's Objective-C++ wrapper, compiled and linked by hand in the package's own source tree, so a change to
# the flags or the header layout costs a compile of the files that depend on it and not a whole package resolve.
#
# This is the recipe's Stage 2 with the same flags, as a loop: it is what finds the next error in minutes. What it
# produces is the same libMatterBackports.dylib, and once it links the recipe is made to do exactly this, and the
# package is built once for real.
#
#   sh tools/matter-framework.sh [n]     n is how many files to compile in parallel (8 by default)
set -u
S=$HOME/.xmake/cache/packages/2609/m/matter/v1.6.1.0/source/matter
OUT=$(ls -d "$S"/out-* 2>/dev/null | head -1)
CLANG=$HOME/.xmake/packages/l/llvm/23.1.1/6a8c97aaa69241df9ed69ac86f13a045/bin/clang
SDK=$HOME/.xmake/packages/i/iphoneos-sdk/16.4/cccc080d0cbe42c2a85b1369aba6e290/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk
LIBCXX=$HOME/.xmake/packages/l/libcxx/23.1.1/afd18d1468a741e7ad4e07d594813e7e/include/c++/v1
VFS=$(ls -t $HOME/.xmake/packages/s/swift-runtime/6.4.0/*/share/port/*/vfs.yaml 2>/dev/null | head -1)
LD64=$HOME/.xmake/packages/l/ld64/956.6/aac8ea2d04874dfdbdc0b81f5db2dd03/bin/ld
JOBS=${1:-8}
STAGED=$OUT/framework/Matter
OBJ=$S/framework
FW=$S/src/darwin/Framework/CHIP
CH=$(cd "$(dirname "$0")/.." && pwd)/packages/m/matter/Charon

[ -d "$S" ] || { echo "no $S: build charon@matter once first"; exit 1; }
[ -f "$VFS" ] || { echo "no port headers: build charon@swift-runtime with the backports once first"; exit 1; }

# The header layout. Each header keeps its own place under the framework - so "MTRFoo.h" resolves against the including
# file's own directory and "zap-generated/MTRFoo.h" resolves from the framework's root, which is what the upstream Xcode
# project's header map does - and is also reachable under its bare name, the one <Matter/MTRFoo.h> asks for, by a link
# to that same file. A link and not a copy: none of these headers has an include guard, so a copy is a second file and
# every class in it would be defined twice.
stage() {
    rm -rf "$STAGED" "$OBJ"
    mkdir -p "$STAGED" "$OBJ"
    # bash 3.2 has no associative array, so the names already placed are kept in a file and grepped.
    local seen
    seen=$(mktemp)
    # CHIP/app is the framework's own: it carries the one header the core files' #include "app/PluginApplicationCallbacks.h"
    # needs, and the framework's header search path is the CHIP directory, so "app/..." resolves there.
    # CHARON is this package's own addition to the library: the Apple-prefixed spellings of the Aliro feature, which
    # the open-source model declares under its own name and Apple's framework does not, generated as forwards.
    for dir in "$FW" "$FW/zap-generated" "$FW/ServerEndpoint" "$FW/XPC Protocol" "$FW/app" "$CH"; do
        [ -d "$dir" ] || continue
        for f in "$dir"/*.h "$dir"/*.mm; do
            [ -e "$f" ] || continue
            name=$(basename "$f")
            if grep -qxF "$name" "$seen" 2>/dev/null; then
                echo "DUPLICATE $name in $(grep -xF "$name" "$seen") and $f"
                rm -f "$seen"
                exit 1
            fi
            echo "$name" >> "$seen"
            rel=${f#"$FW"/}
            mkdir -p "$(dirname "$STAGED/$rel")"
            cp -f "$f" "$STAGED/$rel"
            # The bare-name link is for the <Matter/...> spelling, which only a header has. A source is compiled where
            # it sits, and a second name for it would compile it twice.
            case "$rel" in
                Charon/*) ;;   # the generated additions are reached by their own path, not by a bare name
                *.h) [ "$STAGED/$rel" = "$STAGED/$name" ] || ln -sf "$STAGED/$rel" "$STAGED/$name" ;;
            esac
        done
    done
    rm -f "$seen"
    # The framework's own Xcode project generates this header in a run-script phase before compiling (Matter.xcodeproj,
    # "GIT_COMMIT_SHA=$(git rev-parse --short HEAD)" writing DERIVED_FILES_DIR/git_commit_sha.h), and
    # MTRFrameworkDiagnostics.mm imports it for the version it reports. The same header, the same read.
    printf "#ifndef GIT_COMMIT_SHA_H\n#define GIT_COMMIT_SHA_H\n\n#define GIT_COMMIT_SHA \"%s\"\n\n#endif /* GIT_COMMIT_SHA_H */\n" \
        "$(git -C "$FW/../../.." rev-parse --short HEAD 2>/dev/null || echo unknown-sha)" > "$STAGED/git_commit_sha.h"
    echo "staged $(ls "$STAGED" | wc -l | tr -d ' ') headers and sources in $STAGED"
}

FLAGS=(-target armv7-apple-ios -miphoneos-version-min=6.1.3 -isysroot "$SDK" -mlinker-version=956.6
       -femulated-tls -Wno-incompatible-sysroot -ivfsoverlay "$VFS"
       -fobjc-arc -fno-c++-static-destructors -fmacro-prefix-map="$STAGED"/=   # the two-sided form: clang 23 rejects the one-sided one
       -nostdinc++ -isystem "$LIBCXX"
       -DMTR_NO_AVAILABILITY=1 -DMTR_ENABLE_PROVISIONAL=1 -DMTR_ENABLE_UNSTABLE_API=1
       -DCHIP_HAVE_CONFIG_H=1 -DCHIP_CONFIG_SKIP_APP_SPECIFIC_GENERATED_HEADER_INCLUDES=1 -DCHIP_CONFIG_GLOBALS_NO_DESTRUCT=1
       -I"$STAGED" -I"$OUT/framework" -I"$OUT/gen/include"
       -I"$S/src" -I"$S/src/include" -I"$S/zzz_generated" -I"$S/zzz_generated/app-common"
       -I"$S/third_party/nlassert/repo/include" -I"$S/third_party/nlio/repo/include")

# The framework's own target carries 123 sources, not 100: besides its MTR* Objective-C++ it compiles the app layer the
# server endpoint needs - the data model provider, the server clusters, the attribute storage - as C++ of the project's
# own. The list is read out of that target's Sources phase (Matter.xcodeproj, PBXNativeTarget "Matter"), not guessed:
# these are the twenty-three names it holds that are not MTR*, and each is the one file of that name in the tree.
CXXSOURCES=(
  src/app/server-cluster/AttributeListBuilder.cpp
  src/app/server-cluster/DefaultServerCluster.cpp
  src/app/server-cluster/ServerClusterInterface.cpp
  src/app/server-cluster/ServerClusterInterfaceRegistry.cpp
  src/app/server-cluster/SingleEndpointServerClusterRegistry.cpp
  src/app/persistence/AttributePersistenceProviderInstance.cpp
  src/app/persistence/DefaultAttributePersistenceProvider.cpp
  src/data-model-providers/codegen/ClusterIntegration.cpp
  src/data-model-providers/codegen/CodegenDataModelProvider.cpp
  src/data-model-providers/codegen/CodegenDataModelProvider_Read.cpp
  src/data-model-providers/codegen/CodegenDataModelProvider_Write.cpp
  src/data-model-providers/codegen/EmberAttributeDataBuffer.cpp
  src/data-model-providers/codegen/Instance.cpp
  src/app/clusters/descriptor/CodegenIntegration.cpp
  src/app/clusters/descriptor/DescriptorCluster.cpp
  src/app/clusters/ota-provider/OTAProviderCluster.cpp
  src/app/util/DataModelHandler.cpp
  src/app/util/attribute-storage.cpp
  src/app/util/ember-io-storage.cpp
  src/app/util/generic-callback-stubs.cpp
  src/app/util/util.cpp
  src/app/reporting/reporting.cpp
  zzz_generated/app-common/app-common/zap-generated/cluster-objects.cpp
)

[ "${SKIP_STAGE:-0}" = 1 ] || stage

mkdir -p "$OBJ"
# One file per invocation. xargs always appends its argument last, so the source is $1 and everything else comes from
# the environment: the flags, the staged tree, where the objects go and the compiler.
# bash 3.2 cannot export an array, so the flags are written as a shell file that defines one and the driver sources
# it. Reading them back a line at a time loses a flag whose value carries an "=".
{
    printf "FLAGS=("
    for f in "${FLAGS[@]}"; do printf "'%s' " "$f"; done
    printf ")\n"
} > "$OUT/framework.flags"
cat > "$OUT/compile-one.sh" <<'EOF'
#!/usr/bin/env bash
# $1 is the source to compile; the paths are in the environment and the flags in the file beside this script.
source "$FLAGS_FILE"
rel=${1#"$STAGED"/}
mkdir -p "$(dirname "$OBJ/$rel.o")"
out=$("$CLANG" "${FLAGS[@]}" -c "$1" -o "$OBJ/$rel.o" 2>&1)
if [ -n "$out" ]; then
    echo "=== $rel"
    echo "$out" | grep -E "error:|fatal error" | head -8
fi
EOF
chmod +x "$OUT/compile-one.sh"

export CLANG STAGED OBJ
export FLAGS_FILE="$OUT/framework.flags"
echo "compiling the framework's sources with $JOBS at a time"
find "$STAGED" -name "*.mm" -print0 | xargs -0 -P "$JOBS" -n1 "$OUT/compile-one.sh" || true
# The app layer is C++, so it is compiled as C++: the same target, sysroot and libc++, without ARC and without the
# framework's own Objective-C++ switches.
CXXFLAGS=(-target armv7-apple-ios -miphoneos-version-min=6.1.3 -isysroot "$SDK" -mlinker-version=956.6
          -femulated-tls -Wno-incompatible-sysroot -ivfsoverlay "$VFS" -Os
          -nostdinc++ -isystem "$LIBCXX"
          -DCHIP_HAVE_CONFIG_H=1 -DCHIP_CONFIG_SKIP_APP_SPECIFIC_GENERATED_HEADER_INCLUDES=1 -DCHIP_CONFIG_GLOBALS_NO_DESTRUCT=1
          -I"$OUT/gen/include" -I"$S/src" -I"$S/src/include" -I"$S/zzz_generated" -I"$S/zzz_generated/app-common"
          -I"$S/third_party/nlassert/repo/include" -I"$S/third_party/nlio/repo/include"
          -I"$OUT/framework" -I"$STAGED")
{
    printf "FLAGS=("
    for f in "${CXXFLAGS[@]}"; do printf "'%s' " "$f"; done
    printf ")\n"
} > "$OUT/cxx.flags"
cat > "$OUT/cxx-one.sh" <<'EOF'
#!/usr/bin/env bash
source "$FLAGS_FILE"
rel=${1#"$S"/}
mkdir -p "$(dirname "$OBJ/$rel.o")"
out=$("$CLANG" "${FLAGS[@]}" -c "$1" -o "$OBJ/$rel.o" 2>&1)
if [ -n "$out" ]; then
    echo "=== $rel"
    echo "$out" | grep -E "error:|fatal error" | head -8
fi
EOF
chmod +x "$OUT/cxx-one.sh"
export S
export FLAGS_FILE="$OUT/cxx.flags"
printf "%s\n" "${CXXSOURCES[@]}" | xargs -P "$JOBS" -I{} "$OUT/cxx-one.sh" "$S/{}" || true

echo "objects: $(find "$OBJ" -name "*.mm.o" -o -name "*.cpp.o" 2>/dev/null | wc -l | tr -d ' ') of $(( $(find "$STAGED" -name "*.mm" | wc -l) + ${#CXXSOURCES[@]} ))"

# The link, the recipe's own line, including -Wl,-no_implicit_dylibs: charon's ld64 956.6 asserts in OutputFile's
# dylibToOrdinal on a symbol bound through a re-export (libc++ re-exports libc++abi), and the flag is what says the
# upstream behaviour - a re-exported dylib maps to its parent's ordinal - from outside. coordination/crutches.md has it.
# The link, the recipe's own line: the Stage 1 static library, the objects, the Network and Foundation backports (iOS 6
# has no Network.framework, so the framework's device browser's nw_* calls come from the backport), the port's libc++,
# apple-compat's shims, and the frameworks Apple's xcconfig names.
BP=$(ls -dt $HOME/.xmake/packages/a/apple-backports/latest/*/ | while read -r d; do
        [ -f "$d/lib/libNetworkBackports.dylib" ] && [ -f "$d/lib/libCoreDataBackports.dylib" ] && echo "$d" && break
    done)
AC=$(ls -dt $HOME/.xmake/packages/a/apple-compat/*/*/ | while read -r d; do
        [ -f "$d/lib/libapple-compat.a" ] && echo "$d" && break
    done)
LCXX=$HOME/.xmake/packages/l/libcxx/23.1.1/afd18d1468a741e7ad4e07d594813e7e/lib
[ -f "$BP/lib/libNetworkBackports.dylib" ] || { echo "no libNetworkBackports: build apple-backports with network=true"; exit 1; }
[ -f "$AC/lib/libapple-compat.a" ] || { echo "no libapple-compat.a: build apple-compat for 6.1.3"; exit 1; }
LIB=$OUT/libMatterBackports.dylib
mkdir -p "$(dirname "$LIB")"
"$CLANG" -target armv7-apple-ios -miphoneos-version-min=6.1.3 -isysroot "$SDK" -mlinker-version=956.6 \
    -fuse-ld="$LD64" -dynamiclib \
    -install_name /usr/lib/charon/org.charon.apple-backports/libMatterBackports.dylib \
    -o "$LIB" "$OUT/lib/libCHIP.a" $(find "$OBJ" \( -name "*.mm.o" -o -name "*.cpp.o" \)) \
    -L"$BP/lib" -lNetworkBackports -lFoundationBackports \
    -L"$LCXX" -lc++abi -lc++ \
    "$AC/lib/libapple-compat.a" \
    -framework Foundation -framework Security -framework CoreData -framework CoreBluetooth \
    -Wl,-rpath,"$LCXX" -Wl,-rpath,@loader_path -Wl,-no_implicit_dylibs 2>&1 | head -40
if [ -f "$LIB" ]; then
    echo "LINKED $LIB"
    otool -hv "$LIB" | tail -1
    echo "exports: $(nm -gU "$LIB" | wc -l | tr -d ' ')"
else
    echo "LINK FAILED"
    exit 1
fi
