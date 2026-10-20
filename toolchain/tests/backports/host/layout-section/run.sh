#!/bin/sh
# run.sh: a differential of NSCollectionLayoutSection's insets references, the port against the host, in two processes.
# LAYOUT_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/frameworks/apple-backports/UIKit
build=${LAYOUT_BUILD:-$(runs_fresh revenant-layout-section)}
. "$here/../../common/twoprocess.sh"
if [ -n "${LAYOUT_PORT_SOURCES:-}" ]; then
    set -- $LAYOUT_PORT_SOURCES
else
    set -- "$uikit/NSCollectionLayoutItems.m" "$uikit/NSCollectionLayoutSection+iOS14.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok layout-section: $result"
else
    echo "FAIL layout-section: $result"
    exit 1
fi
