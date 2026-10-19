#!/bin/sh
# ggml-host.sh <builddir> - the engine the port's own translation units link, built for the host, and the
# path of the archive on standard output. Both MLCompute harnesses need it and neither of them may have its
# own copy of this: the arithmetic has to be one engine, or the two answers come out of two.
#
# The package's libggml.a is armv7, built for the release the gate builds, and cannot go into an arm64
# Catalyst program or dylib, so this builds the engine for the host: the sources come from the package's own
# cached tarball - the file the recipe pins by its sha256 - the flags are the recipe's, and the list of
# translation units is the CPU backend's own, read out of src/ggml-cpu/CMakeLists.txt at that commit: the
# base GGML_CPU_SOURCES, and for an arm64 target the ARM branch's two arch units. The five C units the
# release build compiles are not enough here: on arm64 the dispatch and the vector-product and quantization
# kernels live in the C++ units beside them, and the link names every symbol they hold.
#
# The release build is unaffected - its kernels are in the C, which is why the gate's build of the engine is
# clean in both bands. This is the harnesses and nothing else.
set -eu
build=$1
: "${build:?usage: ggml-host.sh <builddir>}"
ggmltar=${MLCOMPUTE_GGML_TARBALL:-$(ls -t "$HOME"/.xmake/cache/packages/*/g/ggml/0.25.3/ggml-0.25.3.tar.gz 2>/dev/null | head -1)}
: "${ggmltar:?no cached ggml 0.25.3 tarball; set MLCOMPUTE_GGML_TARBALL}"
ggmlsrc=$build/ggml
mkdir -p "$build"
rm -rf "$ggmlsrc" "$build/tmp"
mkdir -p "$build/tmp"
tar xzf "$ggmltar" -C "$build/tmp"
mv "$build/tmp/ggml-0.25.3" "$ggmlsrc"
mkdir -p "$build/hostbuild"
printf '#pragma once\n\n#define GGML_VERSION "v0.25.3"\n#define GGML_COMMIT  "8dd76549e6e714c064348a1c89d90ed7c6306727"\n' > "$build/hostbuild/ggml-version.h"

common="-target arm64-apple-ios15.0-macabi -isysroot $(xcrun --show-sdk-path) -fobjc-arc -w"

# The library's own base units, from the add_library(ggml-base ...) block of src/CMakeLists.txt at that
# commit, and the CPU backend's GGML_CPU_SOURCES with the ARM branch's two arch units, which is the whole of
# what an arm64 target compiles. The base units are here because the five C units the release build compiles
# are a subset: on arm64 the backend registry, the threading helpers and the dispatch all live in the C++
# beside them, and the link names every symbol they hold.
ENGINE_C="ggml.c ggml-alloc.c ggml-quants.c"
ENGINE_CXX_BASE="ggml.cpp ggml-backend.cpp ggml-backend-meta.cpp ggml-threading.cpp"
ENGINE_CXX="ggml-cpu/ggml-cpu.c ggml-cpu/ggml-cpu.cpp ggml-cpu/repack.cpp ggml-cpu/iqp.cpp ggml-cpu/hbm.cpp ggml-cpu/quants.c ggml-cpu/traits.cpp ggml-cpu/binary-ops.cpp ggml-cpu/unary-ops.cpp ggml-cpu/vec.cpp ggml-cpu/ops.cpp ggml-cpu/arch/arm/quants.c ggml-cpu/arch/arm/repack.cpp"
ENGINE_FLAGS="-Os -fvisibility=hidden -fno-rtti -D_GNU_SOURCE -Dggml_EXPORTS"
ENGINE_INCLUDES="-I$ggmlsrc/include -I$ggmlsrc/include/ggml -I$ggmlsrc/src -I$ggmlsrc/src/ggml-cpu -I$build/hostbuild"

mkdir -p "$build/hostobj"
hostobjects=""
for source in $ENGINE_C $ENGINE_CXX_BASE $ENGINE_CXX; do
    object="$build/hostobj/$(echo "$source" | tr / _).o"
    if [ ! -f "$object" ]; then
        # The C units with the compiler, the C++ ones with clang++ and the standard CMake asks for.
        case "$source" in
            *.cpp) compiler="xcrun clang++"; standard="-std=c++17" ;;
            *) compiler="xcrun clang"; standard="" ;;
        esac
        $compiler $common $ENGINE_FLAGS $standard $ENGINE_INCLUDES -c "$ggmlsrc/src/$source" -o "$object"
    fi
    hostobjects="$hostobjects $object"
done
xcrun libtool -static -o "$build/libggml-host.a" $hostobjects 2>/dev/null
echo "$build/libggml-host.a"