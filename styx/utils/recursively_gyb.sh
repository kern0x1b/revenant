#!/usr/bin/env bash

# Writes the GENERATED-*.swift files of the Combine sources. Each one is a Lua generator in utils/gyb/ that writes its own
# output (see utils/gyb/support.lua), so this runs every generator from the repository root, with xmake.

cd "$(dirname "$0")/.." || exit 1

for generator in utils/gyb/*.lua; do
    case "$(basename "$generator")" in
        support.lua | python_random.lua) continue ;;
    esac
    xmake l "$generator" > /dev/null || exit 1
done
