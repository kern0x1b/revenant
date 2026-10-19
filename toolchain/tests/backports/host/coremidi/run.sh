#!/bin/sh
# Differential test of the CoreMIDI translation (packages/a/apple-backports/CoreMIDI) against macOS CoreMIDI:
# every answer macOS gave the oracle (oracle/batch-up.txt and oracle/batch-down.txt, from oracle/batch.m) and the probes in
# differential.m. The API files are compiled too, with their functions renamed, so a file that stops compiling
# stops this run instead of hiding in the library.
#
# The host-probe rule (prefs-bracket.sh states it): the differential makes process-lifetime virtual endpoints and connects
# ports to them, and nothing that persists. The whole run is bracketed by a read-only digest of the persistent MIDI
# preferences (the ByHost com.apple.MIDI plist and ~/Library/Audio/MIDI Configurations); the run fails when the digest differs,
# and the check proves first that it can fail (selftest).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/generated.sh"
ensure_generated "$here" CoreMIDI
if [ -z "${COREMIDI_BRACKETED:-}" ]; then
    sh "$here/prefs-bracket.sh" selftest
    COREMIDI_BRACKETED=1 exec sh "$here/prefs-bracket.sh" run sh "$here/run.sh" "$@"
fi
CORE=${COREMIDI:-$here/../../../../packages/a/apple-backports/CoreMIDI}
# the generated layer's protocol header (RevenantCoreMIDIProtocols.h) is in .gen/CoreMIDI, which the package build puts on the path too
CORE_GEN=$here/../../../../packages/a/apple-backports/.gen/CoreMIDI
# The build folder is a run folder of this checkout (.agent-work/runs), never the system temp directory.
build=${COREMIDI_BUILD:-$here/../../../../.agent-work/runs/coremidi-host}
# COREMIDI_SANITIZE=address builds the library and the differential with AddressSanitizer: the buffer overruns of the
# packet readers (MIDISysex17.m) are found by that build, not by the answers.
sanitize=""
if [ -n "${COREMIDI_SANITIZE:-}" ]; then sanitize="-fsanitize=$COREMIDI_SANITIZE -g"; fi
rm -rf "$build"
mkdir -p "$build"
renames=""
for name in MIDIEventListInit MIDIEventListAdd MIDIClientCreateWithBlock MIDIInputPortCreateWithBlock \
    MIDIDestinationCreateWithBlock MIDIInputPortCreateWithProtocol MIDIDestinationCreateWithProtocol \
    MIDISourceCreateWithProtocol MIDISendEventList MIDIReceivedEventList \
    MIDIEventListForEachEvent MIDIEventPacketSysexBytesForGroup MIDIDeviceNewEntity \
    MIDI2DeviceInfo MIDIUMPFunctionBlock MIDIUMPMutableFunctionBlock MIDIUMPEndpoint MIDIUMPMutableEndpoint \
    MIDIUMPEndpointManager MIDICIDevice MIDIUMPCIProfile MIDICIDeviceManager \
    MIDICIDeviceInfo MIDICIProfile MIDICIProfileState MIDICISession MIDICIDiscoveredNode MIDICIDiscoveryManager \
    MIDICIResponder \
    MIDISendUMPSysex MIDISendUMPSysex8 \
    kMIDIPropertyUMPActiveGroupBitmap kMIDIPropertyUMPCanTransmitGroupless kMIDIPropertyAssociatedEndpoint \
    MIDICIDeviceObjectKey MIDICIProfileObjectKey MIDIUMPEndpointObjectKey MIDIUMPFunctionBlockObjectKey \
    MIDICIDeviceWasAddedNotification MIDICIDeviceWasRemovedNotification MIDICIProfileWasRemovedNotification \
    MIDICIProfileWasUpdatedNotification MIDIUMPEndpointWasAddedNotification MIDIUMPEndpointWasRemovedNotification \
    MIDIUMPEndpointWasUpdatedNotification MIDIUMPFunctionBlockWasUpdatedNotification; do
    renames="$renames -D$name=revenant_host_$name"
done
for path in "$CORE"/*.m; do
    source=$(basename "$path")
    xcrun clang $sanitize -fobjc-arc -fvisibility=hidden -Wall -Werror -I"$CORE" -I"$CORE_GEN" $renames -c "$path" -o "$build/$source.o"
done
xcrun clang $sanitize -c -Wall -Werror -I"$CORE" -I"$CORE_GEN" "$CORE/RevenantCoreMIDI.c" -o "$build/RevenantCoreMIDI.o"
# differential-ports.m is compiled without the renames: it calls the release's own MIDISendEventList and friends as the oracle.
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" -c \
    "$here/differential-ports.m" -o "$build/differential-ports.o"
# The visitor's expectations are generated here, into the build folder, from the recorded macOS output (oracle/visit-macos.txt and
# oracle/visit-jr.txt) by oracle/visit-expectations.lua: no generated header is committed, so there is none to go stale.
(cd "$here/oracle" && xmake l ./visit-expectations.lua "$build/visit-expectations.h")
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations -I"$build" -I"$CORE" -I"$CORE_GEN" -I"$here" -I"$here/oracle" $renames \
    "$here/differential.m" "$here/differential-ump.m" "$build/differential-ports.o" "$build/RevenantCoreMIDI.o" "$build"/*.m.o -framework Foundation -framework CoreMIDI -o "$build/differential"
"$build/differential" "$here/oracle" > "$build/log" 2>&1 && result=0 || result=$?
awk '!/^ok /' "$build/log"
echo "log=$build/log"
# The request of MIDISendUMPSysex, against a release that completes the send before it returns (ownership.m): the
# MIDISendSysex of the release route (RevenantMIDIPorts.m, where the bytes are sent) is renamed to the stand-in, and nothing is
# linked from the release for it.
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations \
    -DMIDISendSysex=revenant_test_MIDISendSysex -I"$CORE" -I"$CORE_GEN" -I"$here" -c "$CORE/RevenantMIDIPorts.m" -o "$build/ownership-ports.o"
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations \
    -DMIDISendSysex=revenant_test_MIDISendSysex -I"$CORE" -I"$CORE_GEN" -I"$here" "$here/ownership.m" "$CORE/MIDISysex17.m" \
    "$build/RevenantCoreMIDI.o" "$build/ownership-ports.o" -framework Foundation -framework CoreMIDI -o "$build/ownership"
"$build/ownership" > "$build/ownership.log" 2>&1 && owner=0 || owner=$?
cat "$build/ownership.log"
# MIDIDeviceNewEntity against stand-ins for the three release calls it makes (entity.m): the host forbids a real entity, and the
# release cannot be made to refuse the protocol. MIDIDevice14.m is compiled again here with those calls renamed.
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations \
    -DMIDIDeviceNewEntity=revenant_test_MIDIDeviceNewEntity -DMIDIDeviceAddEntity=revenant_test_MIDIDeviceAddEntity \
    -DMIDIObjectSetIntegerProperty=revenant_test_MIDIObjectSetIntegerProperty -DMIDIDeviceRemoveEntity=revenant_test_MIDIDeviceRemoveEntity \
    -I"$CORE" -I"$CORE_GEN" -I"$here" "$here/entity.m" "$CORE/MIDIDevice14.m" -framework Foundation -framework CoreMIDI -o "$build/entity"
"$build/entity" > "$build/entity.log" 2>&1 && entity=0 || entity=$?
cat "$build/entity.log"
# The rows of RevenantMIDIPorts.m against a release that gives a disposed reference to a new object (staleness.m): the three
# release calls the rows make (the read of an object's property, the write of the library's stamp and the creation of a virtual
# destination) are renamed to stand-ins,
# in the file and in the test.
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations \
    -DMIDIObjectGetIntegerProperty=revenant_test_MIDIObjectGetIntegerProperty \
    -DMIDIObjectSetIntegerProperty=revenant_test_MIDIObjectSetIntegerProperty \
    -DMIDIDestinationCreate=revenant_test_MIDIDestinationCreate -I"$CORE" -I"$CORE_GEN" -I"$here" \
    "$here/staleness.m" "$CORE/RevenantMIDIPorts.m" "$build/RevenantCoreMIDI.o" -framework Foundation -framework CoreMIDI -o "$build/staleness"
"$build/staleness" > "$build/staleness.log" 2>&1 && stale=0 || stale=$?
cat "$build/staleness.log"
# The room MIDIEventPacketSysexBytesForGroup asks for and the status of the UMP endpoints' client (bounds.m): the release's calls the
# two files make are stand-ins, and so are the classes' names, as for the differential.
xcrun clang $sanitize -c -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" $renames \
    -DCFDataCreateMutable=revenant_test_CFDataCreateMutable "$CORE/MIDISysex17.m" -o "$build/bounds-sysex.o"
xcrun clang $sanitize -c -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" $renames \
    -DMIDIClientCreate=revenant_test_MIDIClientCreate -DNSLog=revenant_test_NSLog "$CORE/MIDIUMP18.m" -o "$build/bounds-ump.o"
xcrun clang $sanitize -c -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" \
    -DMIDIDestinationCreate=revenant_test_MIDIDestinationCreate -DMIDISourceCreate=revenant_test_MIDISourceCreate \
    -DMIDIObjectGetIntegerProperty=revenant_test_MIDIObjectGetIntegerProperty \
    -DMIDIObjectSetIntegerProperty=revenant_test_MIDIObjectSetIntegerProperty "$CORE/RevenantMIDIPorts.m" -o "$build/bounds-ports.o"
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" $renames "$here/bounds.m" "$build/bounds-sysex.o" \
    "$build/bounds-ump.o" "$build/bounds-ports.o" "$build/RevenantCoreMIDI.o" "$build/MIDICI14.m.o" "$build/MIDICI12.m.o" \
    -framework Foundation -framework CoreMIDI -o "$build/bounds"
"$build/bounds" > "$build/bounds.log" 2>&1 && bounded=0 || bounded=$?
cat "$build/bounds.log"
# The allocations and property reads of the hot paths (allocations.m): the library's own malloc family is renamed to counting
# wrappers in the two files that make the paths, and the release's calls the paths make are stand-ins.
counted="-Dmalloc=revenant_count_malloc -Dcalloc=revenant_count_calloc -Drealloc=revenant_count_realloc"
# The log is the test's, and the table of refusal reasons is two entries, so that the test can fill it.
logged="-DNSLog=revenant_test_NSLog -DREVENANT_REFUSED_REASONS=2"
standins="-DMIDIInputPortCreate=revenant_test_MIDIInputPortCreate -DMIDIDestinationCreate=revenant_test_MIDIDestinationCreate \
    -DMIDIObjectGetIntegerProperty=revenant_test_MIDIObjectGetIntegerProperty -DMIDIObjectSetIntegerProperty=revenant_test_MIDIObjectSetIntegerProperty \
    -DMIDISend=revenant_test_MIDISend -DMIDIReceived=revenant_test_MIDIReceived -DMIDISendSysex=revenant_test_MIDISendSysex"
xcrun clang $sanitize -c -Wall -Werror -I"$CORE" -I"$CORE_GEN" $counted "$CORE/RevenantCoreMIDI.c" -o "$build/counted-core.o"
xcrun clang $sanitize -c -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" $counted $standins $logged "$CORE/RevenantMIDIPorts.m" -o "$build/counted-ports.o"
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" "$here/allocations.m" "$build/counted-ports.o" \
    "$build/counted-core.o" -framework Foundation -framework CoreMIDI -o "$build/allocations"
"$build/allocations" > "$build/allocations.log" 2>&1 && counted_result=0 || counted_result=$?
cat "$build/allocations.log"
# The in-process deliveries against the dispose of their destination, on the host's own CoreMIDI (delivery.m): the library's
# queue is linked as it is, and the release is the real one. Test E is deterministic; the trials count over 1000 disposes.
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" "$here/delivery.m" "$build/RevenantMIDIPorts.m.o" \
    "$build/RevenantCoreMIDI.o" -framework Foundation -framework CoreMIDI -o "$build/delivery"
"$build/delivery" > "$build/delivery.log" 2>&1 && delivered=0 || delivered=$?
cat "$build/delivery.log"
# The route of a reused reference (reuse.m, review r4 F4 and r5 L1): the release gives a reference an old endpoint (a destination or
# a source) held to a new one, and the new endpoint's first RPN must select its parameter again. RevenantMIDIPorts.m is compiled with the release's send, property
# calls and destination creation renamed to stand-ins (reuse.m); the file's other calls are the release's own.
reuse_standins="-DMIDIDestinationCreate=revenant_test_MIDIDestinationCreate -DMIDISourceCreate=revenant_test_MIDISourceCreate \
    -DMIDIObjectGetIntegerProperty=revenant_test_MIDIObjectGetIntegerProperty -DMIDIObjectSetIntegerProperty=revenant_test_MIDIObjectSetIntegerProperty \
    -DMIDISend=revenant_test_MIDISend -DMIDIReceived=revenant_test_MIDIReceived"
xcrun clang $sanitize -c -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" $reuse_standins "$CORE/RevenantMIDIPorts.m" \
    -o "$build/reuse-ports.o"
xcrun clang $sanitize -fobjc-arc -Wall -Wno-deprecated-declarations -I"$CORE" -I"$CORE_GEN" "$here/reuse.m" "$build/reuse-ports.o" \
    "$build/RevenantCoreMIDI.o" -framework Foundation -framework CoreMIDI -o "$build/reuse"
"$build/reuse" > "$build/reuse.log" 2>&1 && reused=0 || reused=$?
cat "$build/reuse.log"
for step in "$owner" "$entity" "$stale" "$bounded" "$counted_result" "$delivered" "$reused"; do
    if [ "$result" -eq 0 ]; then result=$step; fi
done
exit $result
