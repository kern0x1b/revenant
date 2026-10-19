#!/bin/sh
# compare.sh — the differential itself: Apple's answer and the port's, on one input, side by side.
#
# Two programs, one input. oracle.m compiles kernels.metal with Apple's own compiler on this host, runs
# each kernel on this host's GPU and prints what came out; air2cpu turns the AIR the same compiler
# wrote into C, driver.c runs it through the port's own call convention, and prints that. The two are
# compared here, and a kernel the tool refused is reported as refused rather than as a difference,
# because a refused kernel answers the port's documented error and is not a wrong number.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
# The evidence - the extracted AIR, the generated C, both sides' answers - lands in $work, and $work is
# under this worktree's own run directory, because band output is never written to the system
# temporary directory: that one is wiped out from under a run. A band or a reviewer can be pointed at
# $work/air/m0.bc, $work/port.c, $work/oracle.out and $work/port.out after the fact, and it is durable.
# Set WORK to put it elsewhere.
work=${WORK:-$root/.agent-work/runs/air2cpu/run}
mkdir -p "$work"
run=$work/$(date +%Y%m%d-%H%M%S)
mkdir -p "$run"
work=$run
llvm=${LLVM:-$(brew --prefix llvm)}
mkdir -p "$work"
sdk=$(xcrun --show-sdk-path)
# The port's own sources are compiled the way the host test metalblit compiles them: for Mac
# Catalyst, with the classes of the port renamed so the harness and the port cannot be confused.
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-property-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers -Wno-objc-protocol-method-implementation -Wno-incompatible-property-type -Wmismatched-return-types"
: > "$work/port-build.log"

# 1. Apple's compiler, its answer, and the AIR it wrote.

# The metallib must come from the source in the TREE. A run that reuses a metallib extracted before a
# fixture change is worse than a run that fails: it passes against a kernel that is not the one in the
# tree, which is exactly how a fixture declaring 160 threadgroup slots - more than Metal's 30 - went
# unnoticed. So the source is copied in and its timestamp compared with the metallib's, and a
# metallib older than its source is a refusal rather than a result.
cp "$here/kernels.metal" "$work/kernels.metal"
cp "$here/kernels.metal" "$work/"
xcrun clang -O -fobjc-arc -Wno-deprecated-declarations "$here/oracle.m" -framework Metal -framework Foundation -o "$work/oracle"
(cd "$work" && ./oracle kernels.metallib) > "$work/oracle.out" 2> "$work/oracle.err" || true
# The oracle's answer and the AIR it wrote are the same step, so a missing metallib is the ORACLE'S
# failure and must be reported as one. Without this the run went on to extract.py, which died on the
# missing path with a traceback, and a compiler service that had crashed was reported as a plumbing bug.
if [ ! -f "$work/kernels.metallib" ]; then
    echo "the oracle did not produce $work/kernels.metallib, so there is no AIR to read and the"
    echo "differential has nothing to compare. What the oracle said:"
    sed -n '1,4p' "$work/oracle.err" 2>/dev/null
    exit 1
fi
if [ -f "$work/kernels.metallib" ] && [ "$work/kernels.metallib" -ot "$work/kernels.metal" ]; then
    echo "refusing: the metallib is OLDER than the kernels.metal beside it, so this run would test a"
    echo "kernel that is not the one in the tree. Remove it and run again."
    exit 1
fi
cat "$work/oracle.out"

# 2. The port's own translation of that AIR, and its answer.
# the tool is told where the one call convention lives, and refuses to build without it
"$llvm/bin/clang++" -std=c++17 "-DCHAIR_AIR2CPU_ABI=\"$root/packages/a/apple-backports/air2cpu-abi.h\"" \
    $("$llvm/bin/llvm-config" --cxxflags | sed 's/-fno-exceptions//') \
    "$root/tools/air2cpu/air2cpu.cpp" -o "$work/air2cpu" \
    $("$llvm/bin/llvm-config" --ldflags --libs core irreader bitreader support) -Wl,-rpath,"$llvm/lib"
python3 "$here/extract.py" "$work/kernels.metallib" "$work" > "$work/extract.out"
cat "$work/extract.out"
for bc in "$work"/air/*.bc; do
    "$work/air2cpu" "$bc" "$work/port.c" >> "$work/air2cpu.out" 2>&1 || { echo "air2cpu failed on $bc"; tail -5 "$work/air2cpu.out"; exit 1; }
done
cat "$work/air2cpu.out"
# The generated C's own addressing, as a check and not as a read: every array address must be computed
# with the element's real width, and a base must never be multiplied by itself. This is the class of
# bug that made every array element of every kernel alias onto element zero, silently.
python3 "$here/check-generated-addressing.py" "$work/port.c"
xcrun clang -O2 -Wno-unused-variable -I"$work" -I"$root/packages/a/apple-backports" "$work/port.c" "$here/driver.c" -o "$work/port"
(cd "$work" && ./port) > "$work/port.out"
cat "$work/port.out"

# 3. The port's OWN encoder, compiled from the package and linked in, dispatching the same kernels
#    through the same Metal API. driver.c above is the harness; this is the code that runs on the
#    device, and a rotation of the tid/gid/tg it hands a kernel turns this red.
METAL=$root/packages/a/apple-backports/Metal
STUB=$here/../metalblit/gl-stub
# The three files the dispatch path is made of, and not the device: CharonMetalDevice.m makes an
# EAGL context, which a host has none of, and its two one-line compute methods are what the harness
# itself stands in for - so what runs here is the pipeline, the encoder and the buffer, which is
# where every bug the review found in this path lives.
port_sources="MTLComputeCommandEncoder8.m MTLComputePipeline8.m CharonMetalBuffer.m"
rm -rf "$work/port-obj"
mkdir -p "$work/port-obj"
for source in $port_sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet -I"$STUB" -I"$METAL" -I"$here" \
        -c "$METAL/$source" -o "$work/port-obj/$source.o" 2>>"$work/port-build.log" || {
            echo "harness: the port's $source does not compile for the host:"; tail -5 "$work/port-build.log"; exit 1; }
done
renames=""
for name in $(xcrun nm -gU "$work"/port-obj/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
# The device is not in the list of sources - it makes an EAGL context and a host has none - but the
# pipeline and the buffer both name it, so the fixture's name is renamed the same way as the rest.
renames="$renames -DCharonMetalDevice=CharonHostCharonMetalDevice"
echo "harness renames:$renames"
for source in $port_sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden $quiet $renames -I"$STUB" -I"$METAL" -I"$here" \
        -c "$METAL/$source" -o "$work/port-obj/renamed-$source.o" 2>>"$work/port-build.log" || {
            echo "harness: the port's $source does not compile renamed:"; tail -5 "$work/port-build.log"; exit 1; }
done
xcrun clang $target -fobjc-arc $quiet $renames -I"$work" -I"$root/packages/a/apple-backports" "$work/port.c" "$here/harness.m" "$here/host-fixtures.m" "$work"/port-obj/renamed-*.o \
    -framework Metal -framework Foundation -framework QuartzCore -framework CoreGraphics \
    -o "$work/harness"
"$work/harness" "$here/kernels.metal" > "$work/port.out" 2> "$work/port.err" || {
    echo "harness: the port's encoder did not run; the work directory is $work"; cat "$work/port.err"; exit 1; }
cat "$work/port.out"
grep -a "^refused" "$work/port.err" || true

# 3. The comparison, by kernel name.
python3 "$here/compare.py" "$work/oracle.out" "$work/port.out" "$work/air2cpu.out" "$work/port.c" "$here/kernels.metal"
