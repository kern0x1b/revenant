#!/bin/sh
# run.sh: a differential of UIPointerAccessory and the accessories of UIPointerStyle, the port against the host, in two processes.
# POINTER_ACCESSORY_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/frameworks/apple-backports/UIKit
build=${POINTER_ACCESSORY_BUILD:-$(runs_fresh revenant-pointer-accessory)}
. "$here/../../common/twoprocess.sh"
if [ -n "${POINTER_ACCESSORY_PORT_SOURCES:-}" ]; then
    set -- $POINTER_ACCESSORY_PORT_SOURCES
else
    set -- "$uikit/UIPointerStyle.m" "$uikit/UIPointerAccessory.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok pointer-accessory: $result"
else
    echo "FAIL pointer-accessory: $result"
    exit 1
fi
