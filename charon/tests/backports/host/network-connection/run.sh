#!/bin/sh
# The host differential for the objects of Network: the port's own files compiled with every nw_*
# symbol they define renamed to charonhost_nw_*, linked into one program with differential.m, which
# asks the same questions of the port's implementation and of the host's own Network.framework and
# compares the answers.
#
# The rename set is read out of the sources rather than written down, so a call the port adds is
# renamed with it and one the port stops defining drops out of it: a name the program declares but no
# file defines would be an undefined symbol, and the build here would say so. The Charon classes are
# renamed the same way, so the port's objects are not the host's.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
BACKPORTS=${BACKPORTS:-$here/../../../../packages/a/apple-backports}
harness=${NETWORK_HARNESS:-$here/../../device}
build=${NETWORK_BUILD:-$(runs_folder charon-network-connection)}
sources=$(ls "$BACKPORTS"/Network/*.m | sort)
rm -rf "$build"
mkdir -p "$build"

# The names come out of the symbol tables, not out of the text of the sources: what is renamed is
# what a file defines, and the definitions are what the linker looks for.
mkdir -p "$build/plain"
for source in $sources; do
    xcrun clang -fobjc-arc -w -c "$source" -o "$build/plain/$(basename "$source" .m).o"
done
xcrun clang -fobjc-arc -w -c "$BACKPORTS/Network/CharonNWSupport.c" -o "$build/plain/CharonNWSupport.o"

renames=""
for name in $(nm -gU "$build/plain"/*.o | awk '$2=="T"||$2=="D"||$2=="S"{print $3}' | sed 's/^_//' | grep -E '^_?nw_' | sort -u); do
    renames="$renames -D$name=charonhost_$name"
done
for class in $(nm -gU "$build/plain"/*.o | awk '$2=="S"||$2=="D"{print $3}' | sed -n -e 's/^_OBJC_CLASS_\$_//p' -e 's/^_OBJC_METACLASS_\$_//p' | grep -E '^Charon' | sort -u); do
    renames="$renames -D$class=CharonHost$class"
done
rm -rf "$build/plain"
echo "renamed $(echo "$renames" | wc -w | tr -d ' ') names"

for source in $sources; do
    object="$build/$(basename "$source" .m).o"
    # shellcheck disable=SC2086
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -c "$source" -o "$object"
done
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$BACKPORTS/Network/CharonNWSupport.c" -o "$build/CharonNWSupport.o"

# The port's TLS calls SSLContextCreate, the name the 6.1.3 cache exports; the host's framework has the
# name from iOS 7 on, SSLCreateContext, and takes the connection type as a third argument. The two are
# links against the host's framework unaltered.

xcrun clang -fno-objc-arc -Wall -Wno-deprecated-declarations -Wno-incompatible-function-pointer-types -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build"/*.o \
    -framework Network -framework Security -framework SystemConfiguration -framework Foundation -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" | head -60 || true
echo "log=$build/log"
exit $result
