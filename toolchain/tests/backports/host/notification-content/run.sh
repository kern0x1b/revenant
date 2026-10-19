#!/bin/sh
# run.sh: a differential of UNNotificationContent and UNMutableNotificationContent's iOS 12 to 16 properties (the summary argument and its
# count, the target content identifier, the interruption level, the relevance score and the filter criteria), the port against the host, in
# two processes. NOTIFICATION_CONTENT_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${NOTIFICATION_CONTENT_BUILD:-$(runs_fresh revenant-notification-content)}
# The port file and the test use UserNotifications, which the two links name.
TWOPROCESS_FRAMEWORKS="-framework UserNotifications"
. "$here/../../common/twoprocess.sh"
if [ -n "${NOTIFICATION_CONTENT_PORT_SOURCES:-}" ]; then
    set -- $NOTIFICATION_CONTENT_PORT_SOURCES
else
    set -- "$uikit/UNNotificationContent.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok notification-content: $result"
else
    echo "FAIL notification-content: $result"
    exit 1
fi
