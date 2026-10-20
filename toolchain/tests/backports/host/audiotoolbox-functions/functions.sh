#!/bin/sh
# The iOS 7 to 15 AudioToolbox functions this round carries: functions.m checks each port definition against the host's own
# function, called through dlsym, for the same inputs. The port sources are compiled to objects under RevenantTest names
# (-D<Name>=RevenantTest<Name>), so the host's symbol and the port's can sit in one process; functions.m is compiled without the
# renames, because the macOS header marks some of these names unavailable.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${AUDIOTOOLBOX_FUNCTIONS_BUILD:-$(runs_folder revenant-audiotoolbox-functions)}
avfaudio="$here/../../../../packages/frameworks/apple-backports/AVFAudio"
rm -rf "$build"
mkdir -p "$build"

renames="-DAudioComponentGetLastActiveTime=RevenantTestAudioComponentGetLastActiveTime \
-DAudioComponentInstantiate=RevenantTestAudioComponentInstantiate \
-DAudioServicesPlaySystemSoundWithCompletion=RevenantTestAudioServicesPlaySystemSoundWithCompletion \
-DAudioServicesPlayAlertSoundWithCompletion=RevenantTestAudioServicesPlayAlertSoundWithCompletion \
-DAudioUnitExtensionCopyComponentList=RevenantTestAudioUnitExtensionCopyComponentList \
-DAudioUnitExtensionSetComponentList=RevenantTestAudioUnitExtensionSetComponentList \
-DMusicDeviceMIDIEventList=RevenantTestMusicDeviceMIDIEventList \
-DAudioFileGetUserDataSize64=RevenantTestAudioFileGetUserDataSize64 \
-DAudioFileGetUserDataAtOffset=RevenantTestAudioFileGetUserDataAtOffset \
-DAudioQueueNewOutputWithDispatchQueue=RevenantTestAudioQueueNewOutputWithDispatchQueue \
-DAudioQueueNewInputWithDispatchQueue=RevenantTestAudioQueueNewInputWithDispatchQueue \
-DAudioComponentValidate=RevenantTestAudioComponentValidate \
-DAudioComponentValidateWithResults=RevenantTestAudioComponentValidateWithResults \
-DAudioConverterNewWithOptions=RevenantTestAudioConverterNewWithOptions \
-DAudioConverterPrepare=RevenantTestAudioConverterPrepare \
-DAudioConverterFillComplexBufferRealtimeSafe=RevenantTestAudioConverterFillComplexBufferRealtimeSafe \
-DAudioConverterFillComplexBufferWithPacketDependencies=RevenantTestAudioConverterFillComplexBufferWithPacketDependencies \
-DAudioFileWritePacketsWithDependencies=RevenantTestAudioFileWritePacketsWithDependencies \
-DAudioOutputUnitPublish=RevenantTestAudioOutputUnitPublish \
-DCopyNameFromSoundBank=RevenantTestCopyNameFromSoundBank \
-DCopyInstrumentInfoFromSoundBank=RevenantTestCopyInstrumentInfoFromSoundBank"

objects=""
for file in AudioToolboxFunctions7 AudioToolboxFunctions14 AudioToolboxFunctions9 AudioToolboxFunctions11 AudioToolboxFunctions10 AudioToolboxFunctions15 AudioToolboxFunctions16 AudioToolboxFunctions17 AudioToolboxFunctions18 AudioToolboxFunctions26; do
    # The renames are split on the spaces between them, as separate arguments, on purpose.
    xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I "$avfaudio" $renames \
        -c "$avfaudio/$file.m" -o "$build/$file.o" 2> "$build/$file.err" || { echo "FAIL building $file"; head -10 "$build/$file.err"; exit 1; }
    objects="$objects $build/$file.o"
done

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I "$avfaudio" \
    "$here/functions.m" $objects \
    -framework Foundation -framework AudioToolbox -framework AudioUnit -framework AVFoundation -framework CoreMIDI \
    -o "$build/functions" 2> "$build/build.err" || { echo "FAIL building functions"; head -10 "$build/build.err"; exit 1; }
"$build/functions" "$build" > "$build/log" 2>&1 && result=0 || result=$?
cat "$build/log"
echo "log=$build/log"
exit "$result"
