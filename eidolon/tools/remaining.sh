#!/bin/bash
# remaining.sh ROOT TYPE...: a name-level work list for a slice, for when a dump is not to hand.
# Greps our sources for each name, so it is coarser than tools/slice-diff.lua and is a cross-check.
# remaining.sh: Apple's 26.2 declarations for a slice of types that our sources do not name at all.
# Name-level, not signature-level: the digester dump behind slice-diff.lua is a build-adjacent job, and
# this is a light check. A name it reports may still exist with another spelling, so it is a work list.
set -u
ROOT=$1; shift
for t in "$@"; do
  xmake l "$ROOT/eidolon/tools/decls.lua" "$t" 2>/dev/null \
  | sed 's/.*\(func\|var\|let\|init\|subscript\|typealias\|case\|associatedtype\) /\1 /' \
  | awk -v t="$t" '{print t"\t"$0}' \
  | while IFS=$'\t' read -r owner decl; do
      name=$(echo "$decl" | sed 's/^[a-z]* //; s/(.*//; s/:.*//' | tr -d ' ')
      [ -z "$name" ] && continue
      if ! grep -rq "\b$name\b" "$ROOT/eidolon/Sources/SwiftUI" 2>/dev/null; then
        echo "$owner	$decl"
      fi
    done
done
