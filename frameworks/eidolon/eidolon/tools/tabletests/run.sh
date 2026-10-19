#!/bin/bash
# run.sh: type-check the two table snippets against the module this tree builds - positive must compile,
# negative must be rejected. The positive one says a table can be written over a collection of rows and
# that the row value reaches through ForEach and Group as the element's own type; the negative one says a
# Text is not table content. Build the module first (eidolon/build.sh), which writes eidolon/out/mods.
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
O=$ROOT/eidolon/out
# pkg-env.sh finds the packages under $PWD, so it is read from the repository root, the way build.sh does
cd "$ROOT"
source ./pkg-env.sh
# Without a compiler there is nothing to type-check, and a snippet that was never checked would read as a
# snippet that passed. Say so and fail.
if [ -z "${SWIFTC:-}" ] || [ ! -x "${SWIFTC:-}" ]; then
  echo "tabletests: no swiftc: pkg-env.sh set SWIFTC='${SWIFTC:-}'" >&2
  echo "tabletests: install rtpkg's packages into the shared store, then run eidolon/build.sh, after eidolon/build.sh" >&2
  exit 2
fi
cd "$ROOT/eidolon"

# The positive snippet must compile, and the negative one must be rejected for the reason it exists:
# a Text is not table content, and a bare `if` is not a widget bundle member. Anything else -- a snippet that compiles, or one rejected for an
# unrelated reason -- is a failure, and this script's exit code is the gate.
status=0
check_one() {
  local name=$1 expect=$2 extra="${3:-}"
  local out
  # shellcheck disable=SC2086
  out=$("$SWIFTC" $PKGFLAGS $OCFLAGS -I "$O/mods" -module-cache-path "$O/mc" -enforce-exclusivity=unchecked \
        -suppress-warnings -typecheck -parse-as-library -module-name TableChecks $extra \
        "$ROOT/eidolon/tools/tabletests/$name.swift" 2>&1)
  if [ $? -ne 0 ] && [ -z "$out" ]; then
    printf '%-9s FAIL -- the compiler exited without saying why\n' "$name:"
    status=1
    return
  fi
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
check_one negative "conform to 'TableRowContent'"
# the second negative: a bare `if` in a widget bundle. Apple's own builder has no overload for one -
# its two `buildOptional` forms (SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:21949 and :21970)
# take the marker intersection and a `W: Widget`, neither of which an `if` without `#available`
# produces - so the `if` reaches the type checker as `any Widget` and is refused. The widget API is
# iOS 14 and this tree targets iOS 6, so the check is about the builder and not about availability.
# a bare `if` yields `any Widget`, which the available marker intersection does not take either, so
# it is refused at the type checker - Apple's overload set refuses it too, by refusing to bind `W`
check_one negative-widget-bundle "could not be inferred" "-disable-availability-checking"
# and the same with a named widget type in the `if`, which is what tells the generic unavailable
# overload from a concrete one (arm64e-apple-ios.swiftinterface:21970)
check_one negative-widget-concrete "could not be inferred" "-disable-availability-checking"
exit $status
