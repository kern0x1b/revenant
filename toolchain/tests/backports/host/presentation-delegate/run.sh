#!/bin/sh
# run.sh: a differential of the popover presentation controller's delegate, the port against the host, in two processes.
# PRESENTATION_DELEGATE_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/frameworks/apple-backports/UIKit
build=${PRESENTATION_DELEGATE_BUILD:-$(runs_fresh revenant-presentation-delegate)}
. "$here/../../common/twoprocess.sh"
if [ -n "${PRESENTATION_DELEGATE_PORT_SOURCES:-}" ]; then
    set -- $PRESENTATION_DELEGATE_PORT_SOURCES
else
    set -- "$uikit/UIPresentationController.m" "$uikit/UIPopoverPresentationController.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok presentation-delegate: $result"
else
    echo "FAIL presentation-delegate: $result"
    exit 1
fi
