#!/bin/sh
# NSUUID of packages/frameworks/apple-backports/Foundation/NSUUID.m, compiled for the host with its two classes renamed, against the host's own
# NSUUID: parsing, equality, hash, description, archives (malformed ones too), nil arguments, and a subclass of the cluster.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/frameworks/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh revenant-uuid)}
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers"
rm -rf "$BUILD/port"
mkdir -p "$BUILD/port"
# The concrete class is not exported, so nm does not list it: it is renamed by name, beside the exported NSUUID.
xcrun clang -fobjc-arc -fvisibility=hidden $quiet -DNSUUID=RevenantHostNSUUID -D__NSConcreteUUID=RevenantHostConcreteUUID \
    -c "$FOUNDATION/NSUUID.m" -o "$BUILD/port/NSUUID.o"
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$BUILD/port/NSUUID.o" -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
