#!/bin/sh
# run.sh: a differential of UIUserNotificationAction's behavior and parameters (iOS 9), and the mutable action's setters for them, the port
# against the host, in two processes. USER_NOTIFICATION_ACTION_PORT_SOURCES replaces the port's files, so a planted wrong port can be run as a
# control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${USER_NOTIFICATION_ACTION_BUILD:-$(runs_fresh revenant-user-notification-action)}
. "$here/../../common/twoprocess.sh"
if [ -n "${USER_NOTIFICATION_ACTION_PORT_SOURCES:-}" ]; then
    set -- $USER_NOTIFICATION_ACTION_PORT_SOURCES
else
    set -- "$uikit/UIUserNotificationSettings.m"
fi
if result=$(twoprocess_run "$here/test.m" "$@"); then
    echo "ok user-notification-action: $result"
else
    echo "FAIL user-notification-action: $result"
    exit 1
fi
