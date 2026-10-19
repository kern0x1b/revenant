#!/bin/sh
# run.sh: a differential of the storage properties of six UIKit classes, the port against the host, in two processes.
# STORAGE_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${STORAGE_BUILD:-$(runs_fresh revenant-storage-config)}
. "$here/../../common/twoprocess.sh"
if [ -n "${STORAGE_PORT_SOURCES:-}" ]; then
    set -- $STORAGE_PORT_SOURCES
else
    set -- "$uikit/UISceneValues.m" "$uikit/UIBackgroundConfiguration.m" "$uikit/UIContextMenuConfiguration.m" \
        "$uikit/UIGraphicsImageRendererFormat.m" "$uikit/UIListContentProperties.m" "$uikit/RevenantLists.m" "$uikit/UIViewConfigurationState.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok storage-config: $result"
else
    echo "FAIL storage-config: $result"
    exit 1
fi
