#!/bin/sh
# The apple-compat shims OSAtomicIncrement32, OSAtomicIncrement32Barrier, OSAtomicDecrement32, OSAtomicDecrement32Barrier,
# ffsll and flsll against the HOST's own definitions, in one process: differential.c. The shims are compiled from
# packages/a/apple-compat/src with CHARON_COMPAT_SYSTEM=0, so the port's own code answers, not a lookup of the system's, and
# with each name renamed to charon_port_* so the two are callable together. A planted control then replaces the add with
# one that adds two, and the differential must fail on it: a differential that cannot fail proves nothing.
# Usage: run.sh   (the build area is .agent-work/runs/compat-libc-host under the checkout)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
src="$root/packages/a/apple-compat/src"
build=${COMPAT_LIBC_BUILD:-$root/.agent-work/runs/compat-libc-host}
rm -rf "$build"
mkdir -p "$build/planted"
names="OSAtomicIncrement32 OSAtomicIncrement32Barrier OSAtomicDecrement32 OSAtomicDecrement32Barrier OSAtomicIncrement64 OSAtomicIncrement64Barrier OSAtomicDecrement64 OSAtomicDecrement64Barrier ffsll flsll timingsafe_bcmp strchrnul rpmatch strtonum strsignal_r timespec_get"

compile() {
    # compile SOURCE NAME OUTPUT: one shim, its name renamed to charon_port_NAME, the system lookup compiled out
    xcrun clang -O2 -w -DCHARON_COMPAT_SYSTEM=0 -D"$2"=charon_port_"$2" -I"$src" -c "$1" -o "$3"
}

objects=""
for name in $names; do
    compile "$src/$name.c" "$name" "$build/$name.o"
    objects="$objects $build/$name.o"
done
xcrun clang -O2 -w "$here/differential.c" $objects -o "$build/differential"
status=0
"$build/differential" > "$build/log" 2>&1 || status=1
cat "$build/log"
[ "$status" -eq 0 ] || { echo "differential failed"; exit 1; }
xcrun clang -O2 -w "$here/differential-libc.c" $objects -o "$build/differential-libc"
"$build/differential-libc" > "$build/libc-log" 2>&1 || status=1
cat "$build/libc-log"
[ "$status" -eq 0 ] || { echo "differential-libc failed"; exit 1; }

# the control: the add adds two, and the differential must say so
sed 's/__sync_add_and_fetch(theValue, 1)/__sync_add_and_fetch(theValue, 2)/' "$src/OSAtomicIncrement32.c" > "$build/planted/OSAtomicIncrement32.c"
grep -q '__sync_add_and_fetch(theValue, 2)' "$build/planted/OSAtomicIncrement32.c"
compile "$build/planted/OSAtomicIncrement32.c" OSAtomicIncrement32 "$build/planted/OSAtomicIncrement32.o"
planted_objects=$(echo "$objects" | sed "s#$build/OSAtomicIncrement32.o#$build/planted/OSAtomicIncrement32.o#")
xcrun clang -O2 -w "$here/differential.c" $planted_objects -o "$build/planted/differential"
control=0
"$build/planted/differential" > "$build/planted/log" 2>&1 || control=$?
if [ "$control" -eq 0 ] || ! grep -q '^FAIL OSAtomicIncrement32 ' "$build/planted/log"; then
    echo "control: the planted add was not caught"
    exit 1
fi
echo "control: planted add caught ($(grep -c '^FAIL' "$build/planted/log") failing lines)"
echo "logs=$build"
