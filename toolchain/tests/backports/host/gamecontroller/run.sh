#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/GameController}
out=${BUILD:-$(runs_fresh revenant-gamecontroller)}
renames=""
for name in GCController GCControllerElement GCControllerTouchpad GCKeyboardInput GCKeyboard GCDeviceBattery GCDeviceLight GCDeviceHaptics GCXboxGamepad GCDualShockGamepad GCDualSenseGamepad GCDualSenseAdaptiveTrigger GCControllerButtonInput GCControllerAxisInput GCControllerDirectionPad GCGamepad GCExtendedGamepad GCMicroGamepad GCPhysicalInputProfile GCMotion GCGamepadSnapshot GCExtendedGamepadSnapshot GCMicroGamepadSnapshot; do
    renames="$renames -D$name=RevenantHost$name"
done
# the ten snapshot functions and the two version constants, so both copies link side by side
for name in GCGamepadSnapShotDataV100FromNSData NSDataFromGCGamepadSnapShotDataV100 \
            GCExtendedGamepadSnapShotDataV100FromNSData NSDataFromGCExtendedGamepadSnapShotDataV100 \
            GCExtendedGamepadSnapshotDataFromNSData NSDataFromGCExtendedGamepadSnapshotData \
            GCMicroGamepadSnapShotDataV100FromNSData NSDataFromGCMicroGamepadSnapShotDataV100 \
            GCMicroGamepadSnapshotDataFromNSData NSDataFromGCMicroGamepadSnapshotData \
            GCCurrentExtendedGamepadSnapshotDataVersion GCCurrentMicroGamepadSnapshotDataVersion; do
    renames="$renames -D$name=revenantHost_$name"
done
objects=""
for source in GCElements7 GCControllerTouchpad14 GCKeyboardInput14 GCDeviceParts14 GCDeviceProtocol14 GCGamepadTouchpads14 GCAdaptiveTrigger145 GCPhysicalInputProfile14 GCGamepads7 GCMicroGamepad9 GCMotion8 GCController RevenantGCTables GCSnapshots7 GCSnapshots9 GCSnapshots16 GCDualSenseAdaptiveTrigger154; do
    xcrun clang -fobjc-arc -w $renames -I"$port" -c "$port/$source.m" -o "$out/$source.o"
    objects="$objects $out/$source.o"
done
xcrun clang -fobjc-arc -w -framework Foundation -framework GameController "$here/differential.m" $objects -o "$out/differential"
"$out/differential"
