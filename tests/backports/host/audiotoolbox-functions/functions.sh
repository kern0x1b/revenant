#!/bin/sh
# The iOS 7 to 15 AudioToolbox functions this round carries: functions.m checks each port definition against the host's own
# function, called through dlsym, for the same inputs. The port sources are compiled to objects under CharonTest names
# (-D<Name>=CharonTest<Name>), so the host's symbol and the port's can sit in one process; functions.m is compiled without the
# renames, because the macOS header marks some of these names unavailable.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${AUDIOTOOLBOX_FUNCTIONS_BUILD:-$(runs_folder charon-audiotoolbox-functions)}
avfaudio="$here/../../../../packages/a/apple-backports/AVFAudio"
rm -rf "$build"
mkdir -p "$build"

renames="-DAudioComponentGetLastActiveTime=CharonTestAudioComponentGetLastActiveTime \
-DAudioComponentInstantiate=CharonTestAudioComponentInstantiate \
-DAudioServicesPlaySystemSoundWithCompletion=CharonTestAudioServicesPlaySystemSoundWithCompletion \
-DAudioServicesPlayAlertSoundWithCompletion=CharonTestAudioServicesPlayAlertSoundWithCompletion \
-DAudioUnitExtensionCopyComponentList=CharonTestAudioUnitExtensionCopyComponentList \
-DAudioUnitExtensionSetComponentList=CharonTestAudioUnitExtensionSetComponentList \
-DMusicDeviceMIDIEventList=CharonTestMusicDeviceMIDIEventList \
-DAudioFileGetUserDataSize64=CharonTestAudioFileGetUserDataSize64 \
-DAudioFileGetUserDataAtOffset=CharonTestAudioFileGetUserDataAtOffset \
-DAudioQueueNewOutputWithDispatchQueue=CharonTestAudioQueueNewOutputWithDispatchQueue \
-DAudioQueueNewInputWithDispatchQueue=CharonTestAudioQueueNewInputWithDispatchQueue \
-DAudioComponentValidate=CharonTestAudioComponentValidate \
-DAudioComponentValidateWithResults=CharonTestAudioComponentValidateWithResults \
-DAudioConverterNewWithOptions=CharonTestAudioConverterNewWithOptions \
-DAudioConverterPrepare=CharonTestAudioConverterPrepare \
-DAudioConverterFillComplexBufferRealtimeSafe=CharonTestAudioConverterFillComplexBufferRealtimeSafe \
-DAudioConverterFillComplexBufferWithPacketDependencies=CharonTestAudioConverterFillComplexBufferWithPacketDependencies \
-DAudioFileWritePacketsWithDependencies=CharonTestAudioFileWritePacketsWithDependencies"

objects=""
for file in AudioToolboxFunctions7 AudioToolboxFunctions9 AudioToolboxFunctions11 AudioToolboxFunctions10 AudioToolboxFunctions15 AudioToolboxFunctions16 AudioToolboxFunctions17 AudioToolboxFunctions18 AudioToolboxFunctions26; do
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
