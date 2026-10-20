#!/bin/sh
# run.sh: a differential of UIPress.key, the port against the host, in two processes.
# PRESS_KEY_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/frameworks/apple-backports/UIKit
build=${PRESS_KEY_BUILD:-$(runs_fresh revenant-press-key)}
. "$here/../../common/twoprocess.sh"
if [ -n "${PRESS_KEY_PORT_SOURCES:-}" ]; then
    set -- $PRESS_KEY_PORT_SOURCES
else
    set -- "$uikit/UIPress.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok press-key: $result"
else
    echo "FAIL press-key: $result"
    exit 1
fi
