#!/bin/sh
# The Compression buffer API against the HOST's own libcompression, in one process: differential.c.
# The codecs are the pinned upstreams of packages/libraries/lzfse, packages/libraries/zlib and packages/libraries/lz4, fetched into a fresh
# directory under the run area at the same commits the recipes pin (never built inside a shared clone). The port's
# layer is packages/frameworks/apple-backports/Compression/CompressionBuffer.c, built with its entry points renamed to
# revenant_host_* so the host's and the port's are callable in the same process. Usage: run.sh [seed]
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
seed=${1:-1}
build=${COMPRESSION_BUILD:-$(runs_folder compression-host)}
rm -rf "$build"
mkdir -p "$build/src"
fetch() {
    git clone -q "$2" "$build/src/$1"
    git -C "$build/src/$1" checkout -q "$3"
}
fetch lzfse https://github.com/lzfse/lzfse.git 88e2d2788b4021d0b2eb9fe2d97352ae9190f128
fetch zlib https://github.com/madler/zlib.git da607da739fa6047df13e66a2af6b8bec7c2a498
fetch lz4 https://github.com/lz4/lz4.git fdf2ef5809ca875c454510610764d9125ef2ebbd
fetch xz https://github.com/tukaani-project/xz.git d3e650e63c110e830fd5391e7f8b45df0b91d3da
src="$build/src"
for f in lzfse_decode lzfse_decode_base lzfse_encode lzfse_encode_base lzfse_fse lzvn_decode_base lzvn_encode_base; do
    xcrun clang -O2 -w -c -I"$src/lzfse/src" "$src/lzfse/src/$f.c" -o "$build/$f.o"
done
for f in adler32 crc32 deflate infback inffast inflate inftrees trees zutil; do
    xcrun clang -O2 -w -c -I"$src/zlib" "$src/zlib/$f.c" -o "$build/z_$f.o"
done
xcrun clang -O2 -w -c -I"$src/lz4/lib" "$src/lz4/lib/lz4.c" -o "$build/lz4.o"
# xz: the liblzma subset of packages/libraries/xz (the same sources and config.h as the recipe; the subset is listed in both)
xz="$src/xz/src/liblzma"
xzflags="-Os -fvisibility=hidden -DLZMA_API_STATIC -DHAVE_CONFIG_H -I$root/packages/libraries/xz -I$xz/api -I$xz/common -I$xz/check -I$xz/lzma -I$xz/lz -I$xz/rangecoder -I$xz/simple -I$xz/delta -I$src/xz/src/common"
xzsources="$(ls "$xz"/common/*.c | grep -v '_mt.c\|outqueue.c\|file_info.c\|lzip_decoder.c\|microlzma_\|alone_\|auto_decoder.c') $xz/check/check.c $xz/check/crc32_fast.c $xz/check/crc64_fast.c $xz/check/sha256.c $xz/lzma/lzma2_decoder.c $xz/lzma/lzma2_encoder.c $xz/lzma/lzma_decoder.c $xz/lzma/lzma_encoder.c $xz/lzma/lzma_encoder_optimum_fast.c $xz/lzma/lzma_encoder_optimum_normal.c $xz/lzma/lzma_encoder_presets.c $xz/lzma/fastpos_table.c $xz/lz/lz_decoder.c $xz/lz/lz_encoder.c $xz/lz/lz_encoder_mf.c $xz/rangecoder/price_table.c $src/xz/src/common/tuklib_cpucores.c $src/xz/src/common/tuklib_physmem.c"
for f in $xzsources; do
    xcrun clang $xzflags -c "$f" -o "$build/xz_$(echo "$f" | sed "s#^$src/xz/##" | tr / _).o"
done
# the layer includes its codecs by package name (<lz4/lz4.h>, <lzfse/lzfse.h>, <zlib/zlib.h>, <lzma/lzma.h>), so the
# headers are laid out as each package installs them
mkdir -p "$build/include/lz4" "$build/include/lzfse" "$build/include/zlib" "$build/include/lzma"
cp "$src/lz4/lib/lz4.h" "$build/include/lz4/"
cp "$src/lzfse/src/lzfse.h" "$src/lzfse/src/lzfse_internal.h" "$src/lzfse/src/lzfse_fse.h" "$src/lzfse/src/lzfse_tunables.h" "$src/lzfse/src/lzvn_decode_base.h" "$build/include/lzfse/"
cp "$src/zlib/zlib.h" "$src/zlib/zconf.h" "$build/include/zlib/"
cp "$xz/api/lzma.h" "$build/include/lzma/"
cp -R "$xz/api/lzma" "$build/include/lzma/"
renames="-Dcompression_encode_buffer=revenant_host_compression_encode_buffer -Dcompression_decode_buffer=revenant_host_compression_decode_buffer -Dcompression_encode_scratch_buffer_size=revenant_host_compression_encode_scratch_buffer_size -Dcompression_decode_scratch_buffer_size=revenant_host_compression_decode_scratch_buffer_size -Dcompression_stream_init=revenant_host_compression_stream_init -Dcompression_stream_process=revenant_host_compression_stream_process -Dcompression_stream_destroy=revenant_host_compression_stream_destroy"
xcrun clang -O2 -w $renames -I"$build/include" -c "$root/packages/frameworks/apple-backports/Compression/CompressionBuffer.c" -o "$build/port.o"
xcrun clang -O2 -w "$here/differential.c" "$build"/*.o -lcompression -o "$build/differential"
status=0
"$build/differential" "$seed" > "$build/log" 2>&1 || status=1
grep -v '^ok ' "$build/log" || true
echo "logs=$build"
exit $status
