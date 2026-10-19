#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
llvm=${LLVM:-$(brew --prefix llvm)}
work=$(runs_fresh charon-air2es)
trap 'rm -rf "$work"' EXIT

"$llvm/bin/clang++" $("$llvm/bin/llvm-config" --cxxflags | sed 's/-fno-exceptions//') "$root/tools/air2es/air2es.cpp" -o "$work/air2es" \
    $("$llvm/bin/llvm-config" --ldflags --libs core bitreader) -Wl,-rpath,"$llvm/lib"

python3 - "$llvm" "$here/fixtures" "$work" <<'PY'
import subprocess, sys

llvm, fixtures, work = sys.argv[1:4]


def module(name):
    return subprocess.run([llvm + '/bin/llvm-as', '%s/%s.ll' % (fixtures, name), '-o', '-'], check=True, capture_output=True).stdout


for library, names in (('quad', ('quad-vertex', 'quad-fragment', 'quad-stagein', 'quad-flow', 'quad-constants', 'quad-fetch', 'depth-vertex', 'depth-fragment', 'quad-pair', 'depth-read', 'depth-compare', 'mask-shape', 'mask-merge')), ('pair', ('fetch-pair',))):
    open('%s/%s.metallib' % (work, library), 'wb').write(b'MTLB' + bytes(16) + b''.join(module(name) for name in names))
PY

xmake l "$root/tools/air2es/metallib2es.lua" "$work/air2es" "$work/quad.metallib" "$work/quad.es2" >"$work/quad.out"
cat "$work/quad.out"

for file in library.json module0.vert module0.json module1.frag module1.json module2.vert module2.json module3.frag module3.json module4.frag module4.json module5.frag module5.json module6.vert module6.json module7.frag module7.json module8.frag module8.json module9.frag module9.json module10.frag module10.json module11.frag module11.json module12.frag module12.json; do
    if [ -n "${CHARON_WRITE_EXPECTED:-}" ]; then
        mkdir -p "$here/expected/quad"
        cp "$work/quad.es2/$file" "$here/expected/quad/$file"
    else
        diff -u "$here/expected/quad/$file" "$work/quad.es2/$file"
    fi
done

glslangValidator -S vert "$work/quad.es2/module0.vert"
glslangValidator -S frag "$work/quad.es2/module1.frag"
glslangValidator -S vert "$work/quad.es2/module2.vert"
glslangValidator -S frag "$work/quad.es2/module3.frag"
sed '1a\
#define charon_fc0 1\
#define charon_fc1 0.5\
#define charon_fc1_defined 1' "$work/quad.es2/module4.frag" >"$work/specialised.frag"
glslangValidator -S frag "$work/specialised.frag"
sed '/GL_EXT_shader_framebuffer_fetch/d; s/gl_LastFragData\[0\]/vec4(0.0)/' "$work/quad.es2/module5.frag" >"$work/fetching.frag"
glslangValidator -S frag "$work/fetching.frag"
glslangValidator -S vert "$work/quad.es2/module6.vert"
glslangValidator -S frag "$work/quad.es2/module7.frag"
glslangValidator -S frag "$work/quad.es2/module8.frag"
glslangValidator -S frag "$work/quad.es2/module9.frag"
sed '/GL_EXT_shadow_samplers/d; s/sampler2DShadow/sampler2D/; s/shadow2DEXT(\([a-z0-9]*\), vec3(\([^;]*\)));/texture2D(\1, vec2(0.0)).r;/' "$work/quad.es2/module10.frag" >"$work/shadow.frag"
glslangValidator -S frag "$work/shadow.frag"
grep -q "shadow2DEXT" "$work/quad.es2/module10.frag"
sed '/GL_EXT_shader_framebuffer_fetch/d; s/gl_LastFragData\[0\]/vec4(0.0)/' "$work/quad.es2/module11.frag" >"$work/mask-shape.frag"
glslangValidator -S frag "$work/mask-shape.frag"
glslangValidator -S frag "$work/quad.es2/module12.frag"
grep -q 'gl_LastFragData' "$work/quad.es2/module11.frag"
grep -q 'charon_attachment1' "$work/quad.es2/module12.frag"
grep -q "GL_EXT_shader_framebuffer_fetch" "$work/quad.es2/module5.frag"

if xmake l "$root/tools/air2es/metallib2es.lua" "$work/air2es" "$work/pair.metallib" "$work/pair.es2" >"$work/pair.out"; then
    :
fi
grep -q 'FAIL fragment fetchPairFragment: reading a colour attachment that the function writes together with others' "$work/pair.out"
grep -q '"functions": \[\]' "$work/pair.es2/library.json"

echo "air2es: ok"
