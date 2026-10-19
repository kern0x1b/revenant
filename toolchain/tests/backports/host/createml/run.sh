#!/bin/bash
# The port's CreateML against the host's own CreateML, in one process.
#
# The port's sources are compiled under the module names `PortCreateMLComponents` and `PortCreateML`
# so that Apple's `CreateML` and this port's `CreateML` are two modules declaring the same type
# names, and the differential can hold both in one process. The only edit made to the sources is the
# module's own name: every `CreateMLComponents` becomes `PortCreateMLComponents`, which is the import
# line and every qualified use of the port's own types. The sources keep the qualified spelling
# because it says where each type comes from, and the rename is done here rather than in the sources
# because the sources are the armv7 build's, where the spelling is the right one.
#
# What has to be true for this to be a differential rather than two programs: the same sources, one
# module renamed. What is compared, and what is deliberately not, is in differential.swift's header.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
charon=$(cd "$here/../../../.." && pwd)
files="$charon/packages/c/createml/files"
out=$(runs_fresh charon-createml)
# `KEEP=1` leaves the build directory behind, so a suite that dies can be run again under a debugger:
#
#     KEEP=1 ./run.sh && lldb --batch -o run -o bt "$charon"/.agent-work/runs/charon-createml.*/tabularframe
#
# The reason it is an option rather than a habit: Swift's `print` buffers when stdout is a pipe, and a
# `precondition` or a bounds trap kills the process before the buffer is flushed - so a suite that
# traps right after a diagnostic print prints **nothing at all**, and "printed nothing" says nothing
# about where it trapped. Measured: the first attempt at this trap produced no output, was read as
# "the trap is before the print", and was wrong.
#
# The suites are therefore run with stdout unbuffered, so a print that precedes a trap is evidence.
if [ "${KEEP:-0}" = "1" ]; then
    echo "KEEP=1: keeping $out"
fi
mkdir -p "$out/modules"
# The cleanup is here and nowhere else, so this is the only place that has to know about KEEP. It was
# armed *after* a `trap '' EXIT` in the KEEP branch once, and re-armed the cleanup over it, so KEEP=1
# kept nothing while saying it was keeping something.
[ "${KEEP:-0}" = "1" ] || trap 'rm -rf "$out"' EXIT

cp -R "$files" "$out/files"
xmake l "$here/rename-modules.lua" "$out/files"

# `-enable-testing` so the suite's `@testable import PortTabularData` can reach the members that are
# internal on purpose: `AnyColumn`'s typed initialisers, `presentValues` and `erasedValues` are not
# Apple's, and a suite that cannot reach them has either to stop checking them or to check them through
# a public door that does not exist.
xcrun swiftc -swift-version 5 -wmo -parse-as-library -O -enable-testing \
    -module-name PortTabularData \
    -emit-module -emit-module-path "$out/modules/PortTabularData.swiftmodule" \
    -c -o "$out/tab.o" "$out"/files/TabularData/*.swift

# The TabularData module first: it declares no import of itself, so the module name is the only
# thing that changes and -module-name does it. Apple's TabularData and the port's are then two
# modules declaring the same type names, and the second differential holds both in one process.
# `-enable-testing` so the suite's `@testable import PortTabularData` can reach the members that are
# internal on purpose: `AnyColumn`'s typed initialisers, `presentValues` and `erasedValues` are not
# Apple's, and a suite that cannot reach them has either to stop checking them or to check them through
# a public door that does not exist.
xcrun swiftc -swift-version 5 -wmo -parse-as-library -O -enable-testing \
    -module-name PortTabularData \
    -emit-module -emit-module-path "$out/modules/PortTabularData.swiftmodule" \
    -c -o "$out/tab.o" "$out"/files/TabularData/*.swift

# The CoreML overlay under a name of its own, so the host's `CoreML` and the port's are two modules
# declaring the same type names and the comparison holds both in one process.
# The header is what gives the module the framework's declarations, exactly as the package's own
# build does: the module is named `CoreML` and so is the SDK's clang module, and two modules cannot
# share a name. `-import-objc-header` puts the header's declarations in the module directly.

# The specification writer is part of the CoreML overlay, not a module of its own: on the device
# `packages/c/createml/xmake.lua` builds every `files/CoreML/*.swift` as the one `CoreML` module, and
# a writer that the package never compiles would be a file only the host test can see. It used to be a
# separate `PortProto` module, which is why `CreateMLComponents` could not see it.
xcrun swiftc -swift-version 5 -wmo -parse-as-library -O \
    -module-name PortCoreML \
    -import-objc-header "$out"/files/CoreML/CharonCoreML.h \
    -emit-module -emit-module-path "$out/modules/PortCoreML.swiftmodule" \
    -c -o "$out/coreml.o" "$out"/files/CoreML/ShapedArray.swift \
    "$out"/files/CoreML/Codec.swift "$out"/files/CoreML/ModelWriter.swift

xcrun swiftc -swift-version 5 -wmo -parse-as-library -O \
    -module-name PortCreateMLComponents \
    -I "$out/modules" \
    -emit-module -emit-module-path "$out/modules/PortCreateMLComponents.swiftmodule" \
    -c -o "$out/cmc.o" "$out"/files/CreateMLComponents/*.swift

xcrun swiftc -swift-version 5 -wmo -parse-as-library -O \
    -module-name PortCreateML \
    -I "$out/modules" \
    -emit-module -emit-module-path "$out/modules/PortCreateML.swiftmodule" \
    -c -o "$out/cml.o" "$out"/files/CreateML/*.swift

# The two port modules are linked as the objects just built, with the modules beside them, so the
# differential sees one binary holding Apple's CreateML and the port's under different names.
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/differential.swift" "$out/cmc.o" "$out/cml.o" "$out/tab.o" "$out/coreml.o" \
    -framework Accelerate -framework Foundation -framework CoreFoundation -framework CreateML \
    -o "$out/differential"

xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/tabularframe.swift" "$out/tab.o" \
    -framework Foundation \
    -o "$out/tabularframe"

# The CSV reader, Apple's against the port's over the same bytes (csvreading.swift says what is compared).
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/csvreading.swift" "$out/tab.o" \
    -framework Foundation \
    -o "$out/csvreading"

# The CSV writer, Apple's against the port's over the same frames (csvwriting.swift says what is compared).
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/csvwriting.swift" "$out/tab.o" \
    -framework Foundation \
    -o "$out/csvwriting"

# The CSV date readings, Apple's against the port's over the same cells (csvdates.swift says what is compared).
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/csvdates.swift" "$out/tab.o" \
    -framework Foundation \
    -o "$out/csvdates"

# The `.mlmodel` writer, read back by `model/readback.lua` (a Lua decoder of the schema; its expected
# output is the committed coremltools 9.0 answer, so no python runs here). This reaches the schema and
# the encoding, NOT a load and a predict: on
# this SDK's CoreML surface `prediction(fromFeatures:)` is unavailable on macOS, `prediction(from:)` is
# async over `MLTensor`, and `MLTensor(shape:scalars:)` trips a compiler crash. The file says so and
# makes no claim it did not make.
# `cmc.o` is linked in as well as `coreml.o` so the suite calls the *public* `write(to:)` a caller
# would call, rather than the writer underneath it: the writer is already checked, and what is new is
# that a fitted model reaches it.
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/model/main.swift" "$out/coreml.o" "$out/cmc.o" \
    -framework Foundation \
    -o "$out/model"

# The linear models, in their own file named main.swift because the host's `fitted` is async and a
# top-level `await` is only allowed there.
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/linearmodels/main.swift" "$out/cmc.o" "$out/coreml.o" \
    -framework Accelerate -framework Foundation -framework CoreFoundation \
    -framework CreateMLComponents -framework TabularData \
    -o "$out/linearmodels"

# The transformers, over the port's own table: the host's are declared against a DataFrame and a
# shaped array spelled differently, so these are held to the arithmetic they are named for.
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/transformers/main.swift" "$out/cmc.o" "$out/coreml.o" \
    -framework Accelerate -framework Foundation -framework CoreFoundation \
    -o "$out/transformers"

# The preprocessing wrappers and the estimator protocols, over a table and two small estimators the
# test supplies: a pipeline adds no arithmetic, so what is checked is the two things it does change.
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/preprocessing/main.swift" "$out/cmc.o" "$out/coreml.o" \
    -framework Accelerate -framework Foundation -framework CoreFoundation \
    -o "$out/preprocessing"


# The metrics family, which the host has as `ClassificationMetrics` in its own CreateMLComponents,
# so it is a straight differential: the same pairs into both objects, every count and score compared.
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/metrics/main.swift" "$out/cmc.o" "$out/coreml.o" \
    -framework Accelerate -framework Foundation -framework CoreFoundation \
    -framework CreateMLComponents \
    -o "$out/metrics"

# The L1 fit, against the host's own MLLinearRegressor on the same rows. The host publishes no
# coefficients - they live inside its MLModel - so the comparison the port can make directly is
# predictions, which is also the claim a caller relies on.
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/l1/main.swift" "$out/cmc.o" "$out/coreml.o" \
    -framework Accelerate -framework Foundation -framework CoreFoundation -framework CreateML \
    -o "$out/l1"

# MLLinearRegressor, the port's estimator against the host's own in one process, over the same CSV tables.
# It links the port's CreateML objects as well, because the estimator is the port's own type and not the
# components' linear model.
xcrun swiftc -swift-version 5 -O -I "$out/modules" \
    "$here/linearregressor/main.swift" "$out/cml.o" "$out/cmc.o" "$out/tab.o" "$out/coreml.o" \
    -framework Accelerate -framework Foundation -framework CoreFoundation \
    -framework CreateML -framework TabularData \
    -o "$out/linearregressor"

# All seven, and the *script* fails at the end. `set -e` on the first binary aborted the run at the
# first red suite, so three suites whose state was unknown read as a build failure: the review measured
# a one-line mutation producing exactly one line of output and no `tabularframe`, `linearmodels` or
# `transformers` line at all. Each binary's exit is collected and the first non-zero is the script's.
status=0
for suite in differential tabularframe csvreading csvwriting csvdates linearmodels transformers metrics preprocessing l1 model linearregressor; do
    # `stdbuf` is belt and braces for the buffering above: the suites do their own unbuffering too.
    if ! stdbuf -o0 -e0 "$out/$suite"; then
        echo "FAIL the $suite suite exited non-zero" >&2
        status=1
    fi
done
exit $status
