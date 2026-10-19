#!/bin/bash
# run.sh: type-check the two tab-value snippets against the module this tree builds - positive must
# compile, negative must be rejected for the reason it exists: a tab's value must be Hashable.
# Build the module first (eidolon/build.sh). The exit code is the gate.
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
O=$ROOT/eidolon/out
cd "$ROOT"
source ./pkg-env.sh
if [ -z "${SWIFTC:-}" ] || [ ! -x "${SWIFTC:-}" ]; then
  echo "tabtests: no swiftc: pkg-env.sh set SWIFTC='${SWIFTC:-}'" >&2
  echo "tabtests: install rtpkg's packages into the shared store, then run eidolon/build.sh, after eidolon/build.sh" >&2
  exit 2
fi
cd "$ROOT/eidolon"
status=0
check_one() {
  local name=$1 expect=$2
  local out
  out=$("$SWIFTC" $PKGFLAGS $OCFLAGS -I "$O/mods" -module-cache-path "$O/mc" -enforce-exclusivity=unchecked \
        -suppress-warnings -typecheck -parse-as-library -module-name TabChecks \
        "$ROOT/eidolon/tools/tabtests/$name.swift" 2>&1)
  local first
  first=$(echo "$out" | grep -m1 'error:')
  if [ "$expect" = compiles ]; then
    if [ -z "$out" ]; then printf '%-9s compiles\n' "$name:"
    else printf '%-9s FAIL -- it should compile: %s\n' "$name:" "$first"; status=1; fi
  else
    case "$first" in
      *"$expect"*) printf '%-9s rejected -- %s\n' "$name:" "$first" ;;
      *) printf '%-9s FAIL -- expected a rejection naming %s, got: %s\n' "$name:" "$expect" "${first:-it compiled}"; status=1 ;;
    esac
  fi
}
check_one positive compiles
check_one negative "conform to specified type 'TabContent'"
exit $status
