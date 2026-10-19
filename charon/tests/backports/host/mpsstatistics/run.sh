#!/bin/sh
# run.sh - is this port's MPSImageStatistics the same arithmetic as MPSImageStatistics.h's own sentence?
#
# statistics-cases.m is compiled twice and run twice: once against the system's own MPS, once against
# this port's classes with the MPS names mapped to Charon names, so the port's implementations are
# reached under names of their own and cannot be the system's.
#
# WHAT THE COMPARISON IS. The system run is kept because "the release could not be asked" belongs on the
# transcript: this host's AGX family lacks computeCommandEncoderWithDispatchType: and the release's own
# kernel dies encoding with '-[AGXG16XFamilyCommandBuffer mtlnext
# computeCommandEncoderWithDispatchType:]': unrecognized selector. So the release is not the oracle here,
# exactly as it is not for the MPSImageReduce or MPSNNReduce rows. What the run establishes is that the
# port's walk agrees with CharonMPSStatisticsReference.h, which is the header's own sentences written as
# arithmetic in plain C and never names the port's class.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mps=${MPS:-$here/../../../../packages/a/apple-backports/MetalPerformanceShaders}
build=${BUILD:-$here/../../../../.agent-work/runs/host/mpsstatistics}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation -Wno-nullability-completeness -Wno-objc-protocol-method-implementation"

# The port side first: the classes the port DEFINES, read out of its compiled objects and not the subset
# a case happens to reach. The host's MPS framework defines nearly all of these names, so a class left
# unrenamed would be two classes of one name in the port's process and which one a superclass pointer
# reaches would be decided by load order.
mkdir -p "$build/plain"
for source in "$mps"/*.m; do
    xcrun clang -fobjc-arc -w $target -c "$source" -o "$build/plain/$(basename "$source" .m).o" 2>/dev/null
done
for object in "$build/plain"/*.o; do xcrun nm -g --defined-only "$object"; done \
    | grep -oE '_OBJC_CLASS_\$_[A-Za-z0-9_]+' | sed 's/_OBJC_CLASS_\$_//' | sort -u > "$build/port-defines.txt"
python3 - "$build/port-defines.txt" "$build/rename.h" <<'PY'
import sys
names = [line.strip() for line in open(sys.argv[1]) if line.strip()]
with open(sys.argv[2], 'w') as out:
    for name in names:
        out.write("#define %s Charon%s\n" % (name, name))
print("classes the port defines: %d" % len(names))
PY
echo "renamed: $(grep -c define "$build/rename.h") classes"

printf '#import <MetalPerformanceShaders/MetalPerformanceShaders.h>\n#import "CharonMPSCnn.h"\n#import <objc/runtime.h>\n#include <stdio.h>\n' > "$build/declarations.h"

# The system build, which has no rename header and no port classes: there is nothing for it to reach.
xcrun clang -fobjc-arc $target $quiet "$here/statistics-cases.m" \
    -I"$here" -framework Foundation -framework Metal -framework MetalPerformanceShaders \
    -o "$build/system"
"$build/system" --system > "$build/system.txt" 2>&1 || true
echo "system: $(grep -c 'reference ' "$build/system.txt" || echo 0) cases, $(grep -c 'unrecognized selector' "$build/system.txt" || echo 0) died on the missing encoder"

# The port build: every MPS source compiled with the rename header in front of it, so the port's classes
# are Charon* and the case's class references - which the header rewrites - reach the port's own.
objects=""
for source in "$mps"/*.m; do
    name=$(basename "$source" .m)
    # NOT `|| true` and NOT `2>/dev/null`: a source that does not compile would leave its classes out
    # of the rename header, and every case that names one would then reach the RELEASE's class - which is
    # the defect mpsimage/image-cases.m:425-433 records.
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$mps" -include "$build/rename.h" \
        -c "$source" -o "$build/$name.o"
    objects="$objects $build/$name.o"
done
echo "compiled: $(echo "$objects" | wc -w) objects"
xcrun clang -fobjc-arc $target $quiet "$here/statistics-cases.m" -I"$here" -I"$mps" \
    -include "$build/rename.h" -include "$build/declarations.h" \
    $objects -framework Foundation -framework Metal -framework MetalPerformanceShaders \
    -o "$build/port"
"$build/port" > "$build/port.txt" 2>&1 || true
cat "$build/port.txt"

# The verdict, read from the transcript rather than from the exit code of the case: the case prints what
# it compared and the check below is what decides pass or fail, so a case that silently compared nothing
# cannot pass by exiting zero.
python3 - "$build/port.txt" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
last = re.findall(r"^compared (\d+) mismatches (\d+)$", text, re.M)
if not last:
    print("FAIL: the case printed no verdict line")
    sys.exit(1)
compared, mismatches = int(last[-1][0]), int(last[-1][1])
if mismatches:
    print("FAIL: %d mismatches over %d compared" % (mismatches, compared))
    sys.exit(1)
if compared < 23:
    # Three kernels over three 3x3x1 sources is (2 + 2 + 1) answers each = 15; over one 3x2x2 source,
    # where the walk must read BOTH channels and not plane 0 alone, another 5; over two 1x1 sources
    # another 3. That is 23, and a run that compared fewer did not reach every kernel over every source.
    print("FAIL: only %d elements compared, which cannot be the three kernels over these sources" % compared)
    sys.exit(1)
print("PASS: %d elements compared, %d mismatches" % (compared, mismatches))
PY