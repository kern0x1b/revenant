#!/bin/sh
# run.sh: a differential of UIApplicationShortcutItem's target content identifier, the port against the host, in two processes.
# SHORTCUT_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${SHORTCUT_BUILD:-$(runs_fresh charon-shortcut-item)}
. "$here/../../common/twoprocess.sh"
if [ -n "${SHORTCUT_PORT_SOURCES:-}" ]; then
    set -- $SHORTCUT_PORT_SOURCES
else
    set -- "$uikit/UIApplicationShortcutItem.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok shortcut-item: $result"
else
    echo "FAIL shortcut-item: $result"
    exit 1
fi
