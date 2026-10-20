#!/bin/sh
# run.sh: a differential of UIBarButtonItemGroup's alwaysAvailable, menuRepresentation and hidden, the port against the host, in two processes.
# BAR_GROUP_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/frameworks/apple-backports/UIKit
build=${BAR_GROUP_BUILD:-$(runs_fresh revenant-bar-group)}
. "$here/../../common/twoprocess.sh"
if [ -n "${BAR_GROUP_PORT_SOURCES:-}" ]; then
    set -- $BAR_GROUP_PORT_SOURCES
else
    set -- "$uikit/UIBarButtonItemGroup.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok bar-group: $result"
else
    echo "FAIL bar-group: $result"
    exit 1
fi
