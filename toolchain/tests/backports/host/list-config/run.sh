#!/bin/sh
# run.sh: a differential of UICollectionLayoutListConfiguration's separator configuration, item separator handler and header padding, the port against the host, in two processes.
# LIST_CONFIG_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${LIST_CONFIG_BUILD:-$(runs_fresh revenant-list-config)}
. "$here/../../common/twoprocess.sh"
if [ -n "${LIST_CONFIG_PORT_SOURCES:-}" ]; then
    set -- $LIST_CONFIG_PORT_SOURCES
else
    set -- "$uikit/UICollectionLayoutListConfiguration.m" "$uikit/UIListSeparatorConfiguration145.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok list-config: $result"
else
    echo "FAIL list-config: $result"
    exit 1
fi
