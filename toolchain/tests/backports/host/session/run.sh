#!/bin/sh
set -eu
echo "FAIL host/session/run.sh: it ends in with-server.sh, whose Python step server.py is gone and not yet ported to Lua" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
DEVICE=${DEVICE:-$here/../../device}
CHECK=${CHECK:-$DEVICE}
BUILD=${BUILD:-$(runs_fresh revenant-session)}
# THE WHOLE NSURLSession FAMILY, DISCOVERED, not a list kept beside it. Six of the fourteen were named here
# and two of the eight that were missing broke the run in turn, in the two ways a missing source does: the
# link said `Undefined symbols _revenant_network_cellular` (RevenantNetworkAccess.c defines it, and it is the
# port's own C helper, a file of its own for the reason its header gives), and then, with that linked, a task
# answered -delegate with doesNotRecognizeSelector: because -[NSURLSessionTask delegate] lives in
# NSURLSessionTask+Delegate15.m, a category nothing had pulled in. A category is reached through objc_msgSend,
# so no linker error names it: only the sources decide. The family is fourteen files and every one of them
# belongs to the framework this harness compares, so all fourteen are built and the next one is picked up.
sources=$(ls "$FOUNDATION"/NSURLSession*.m | sed -e "s|^$FOUNDATION/||" | sort)
[ -n "$sources" ] || { echo "FAIL: no NSURLSession*.m in $FOUNDATION, so the port's own session code is not built"; exit 1; }
# The one private class the family reaches. NSURLSessionStreamTask9.m calls NSURLSessionStreamTaskState, which
# the port defines for itself in RevenantStreamTaskState.m - a class no SDK header declares, so it carries a name
# of its own that has nothing to do with the session. It is named here because the LINK is what finds a missing
# one: a class is reached through objc_msgSend and only an undefined _OBJC_CLASS_$_ symbol names it.
sources="$sources RevenantStreamTaskState.m"
# ... and the port's plain C with them: a C function shared between backport files lives beside neither of them,
# so it is a file of its own and the family glob cannot reach it. RevenantNetworkAccess.c is that file here.
for source in "$FOUNDATION"/*.c; do
    [ -f "$source" ] || { echo "FAIL: no .c in $FOUNDATION, so a C helper the port's own sources call is not built"; exit 1; }
    sources="$sources $(basename "$source")"
done
# REVENANT_HOST_BUILD: this is a host differential - the port's classes are renamed into names of their
# own and the system's Foundation is in the same process, so there is no release class for a
# revenant_alias.h proxy to stand in for, nothing for the library's loader to re-parent and no name to
# export. The header's own comment gives the two measurements: the macOS linker refuses the metaclass
# alias ("ld: null objc class data for '_OBJC_METACLASS_$_Revenant<Name>'", from the smallest file that
# carries nothing but REVENANT_ALIAS), and a name built by ## cannot be renamed the way the line below
# renames classes. What the alias is FOR is a device band; here the class of the release's name is the
# class, and the seven members below are measured on it.
quiet="-DREVENANT_HOST_BUILD -Wno-deprecated-declarations -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$FOUNDATION/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_|^_[A-Za-z][A-Za-z0-9]*$' | sed -e 's/^_OBJC_CLASS_\$_//' -e 's/^_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet $renames -c "$FOUNDATION/$source" -o "$BUILD/renamed/$source.o"
done
xcrun clang -fobjc-arc $quiet -I"$DEVICE" -I"$CHECK" "$here/differential.m" "$DEVICE/session-scenarios.m" "$CHECK/check.m" "$BUILD"/renamed/*.o \
    -framework Foundation -framework SystemConfiguration -o "$BUILD/differential"
echo "renamed:$renames"
exec "$here/with-server.sh" "$BUILD/differential" "$@"
