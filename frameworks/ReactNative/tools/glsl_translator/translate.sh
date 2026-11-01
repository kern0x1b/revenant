#!/bin/sh
set -u
out="$1"
cross="$2"
gl="$3"
glslangValidator() { "$gl" "$@"; }
cd "$out" || exit 1
for name in meshbasic meshstandard instanced-shadermaterial; do
  for stage in vert frag; do
    src="$name.$stage"
    spv="$name.$stage.spv"
    es100="$name.$stage.es100"
    sed 's/average(/revenant_average(/g' "$src" > "$name.$stage.renamed"
    sed 's/^#version 300 es$/#version 310 es/' "$name.$stage.renamed" > "$name.$stage.310"
    glslangValidator -S "$stage" "$name.$stage.renamed" > "$name.$stage.es300.log" 2>&1
    es300rc=$?
    echo "$src: es300 validate exit $es300rc ($(head -c 200 "$name.$stage.es300.log" | tr '\n' ' '))"
    glslangValidator -G --aml -S "$stage" "$name.$stage.310" -o "$spv" > "$name.$stage.glslang-spv.log" 2>&1
    rc1=$?
    if [ "$rc1" -ne 0 ]; then
      echo "$src: frontend exit $rc1 ($(head -c 200 "$name.$stage.glslang-spv.log" | tr '\n' ' '))"
      continue
    fi
    "$cross" --es --version 100 --output "$es100" "$spv" > "$name.$stage.cross.log" 2>&1
    rc2=$?
    if [ "$rc2" -ne 0 ]; then
      echo "$src: spirv-cross exit $rc2 ($(head -c 300 "$name.$stage.cross.log" | tr '\n' ' '))"
      continue
    fi
    glslangValidator -S "$stage" "$es100" > "$name.$stage.es100.log" 2>&1
    rc3=$?
    echo "$src: spirv exit 0; es100 bytes $(wc -c < "$es100"); es100 validate exit $rc3 ($(head -c 300 "$name.$stage.es100.log" | tr '\n' ' '))"
  done
done
