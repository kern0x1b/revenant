#!/usr/bin/env bash

cd "$(dirname "$0")/.." || exit 1
gyb="$(pwd)/../../charon/modules/gyb/main.lua"

find Sources -name '*.gyb' | sort | while read -r file; do
    output="$(dirname "${file%.gyb}")/GENERATED-$(basename "${file%.gyb}")"
    xmake l "$gyb" -Dtemplate_header="$(< utils/template_header.txt)" --line-directive '' -o "$output" "$file" || exit 1
done
