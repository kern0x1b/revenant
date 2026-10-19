#!/bin/sh
# boot.sh NAME DEVICE ROOTFS SECONDS [ilemu boot options...]
# Boots an APFS clone of ROOTFS headless with a control FIFO; sends quit after SECONDS.
# PREPARE is a shell snippet run on the clone before boot, with $ROOTFS set to it.
# Runs and caches live in *.noindex folders so Spotlight does not index guest trees.
# UNLOCK=1 slides the lock screen open once SpringBoard reports did-finish-launching
# (a marker charon-inject.dylib writes) or, without the marker, after UNLOCK_AFTER seconds,
# and repeats every ~25 s until events.log matches UNLOCK_UNTIL (default launch-requested).
set -eu
LAB="$HOME/Git/projects/ios/emulator-lab"
name=$1 device=$2 source=$3 seconds=$4; shift 4
run="$LAB/recompile/emu/runs.noindex/$name"
build=$(plutil -extract ProductBuildVersion raw "$source/System/Library/CoreServices/SystemVersion.plist")
cache="$LAB/recompile/emu/cache.noindex/${device}_${build}"
[ -e "$run" ] && { echo "run $run exists" >&2; exit 1; }
mkdir -p "$run" "$LAB/recompile/emu/tmp.noindex" "$cache"
cp -c -R "$source" "$run/rootfs"
if [ -n "${PREPARE:-}" ]; then ROOTFS="$run/rootfs" LAB="$LAB" sh -ec "$PREPARE"; fi
mkfifo "$run/control"
( sleep "$seconds"; echo quit ) > "$run/control" &
if [ "${UNLOCK:-0}" = 1 ]; then
  (
    events="$run/rootfs/private/var/charon/events.log" waited=0
    until grep -qs "did-finish-launching pid=[0-9]* SpringBoard" "$events" || [ "$waited" -ge "${UNLOCK_AFTER:-240}" ]; do
      sleep 2; waited=$((waited + 2))
    done
    until grep -qs "${UNLOCK_UNTIL:-launch-requested}" "$events" || grep -qs '^exit=' "$run/log"; do
      printf 'home\n' > "$run/control"; sleep 3; printf 'unlock\n' > "$run/control"
      waited=0
      until grep -qs "${UNLOCK_UNTIL:-launch-requested}" "$events" || [ "$waited" -ge 20 ]; do
        sleep 1; waited=$((waited + 1))
      done
    done
  ) &
fi
start=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
echo "$start" > "$run/start"
env TMPDIR="$LAB/recompile/emu/tmp.noindex" VK_ICD_FILENAMES="$LAB/deps/build-swiftshader/Darwin/vk_swiftshader_icd.json" \
  "${ILEMU:-$LAB/recompile/emu/ilemu}" boot --rootfs "$run/rootfs" --device "$device" --host-cache "$cache" \
  --display headless --gles-backend software --control-stdin --frame-output "$run/frame.png" "$@" < "$run/control" 2>&1 \
  | perl -MTime::HiRes=time -ne "BEGIN{\$|=1} printf '%8.3f %s', time-$start, \$_" > "$run/log"
echo "exit=$? elapsed=$(perl -MTime::HiRes=time -e "printf '%.1f', time-$start")" >> "$run/log"
exec 3<> "$run/control"
sleep 1
exec 3<&-
rm -f "$run/control"
