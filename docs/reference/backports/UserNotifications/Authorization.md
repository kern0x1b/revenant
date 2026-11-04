# UserNotifications authorization on iOS 6

`UNUserNotificationCenter` answers authorization from what the system holds, and no longer says "granted" for every
request. The code is in `frameworks/Backports/src/UserNotifications/UNUserNotificationCenter.m`.

## Status

The system's answer is `UIApplication.enabledRemoteNotificationTypes`: each of alert, badge and sound that is enabled
maps to the matching `UNAuthorizationOption`. The status is:

- authorized, when any of the three types is enabled: the settings carry the enabled options;
- denied, when none is enabled but the application has asked before (the requested options are stored under
  `org.revenant.backports.UIUserNotificationTypes`);
- not determined, when none is enabled and the application has not asked.

`getNotificationSettingsWithCompletionHandler:` reports that status on the main queue.

## Request

`requestAuthorizationWithOptions:completionHandler:` maps the requested options to `UIRemoteNotificationType` and calls
`registerForRemoteNotificationTypes:`. The completion handler reports `granted` as "some type is enabled now".

- A request with no options registers nothing and reports the current state.
- When the status was not determined, iOS shows its prompt. The backport waits for the application to resign and then
  become active again, which is how iOS 6 shows the prompt, and then reports what the system holds.
- If no prompt appears within 3 seconds, the completion reports the state at that time and stops waiting. A prompt that
  shows later is not reported to that request; the next `getNotificationSettingsWithCompletionHandler:` reads the answer.
- When the status was already decided, the completion reports at once.

## Limits

The 3-second wait is a choice of this backport and not a value Apple documents. iOS 6 gives no callback for a denied
prompt, so a denial is seen only when the application becomes active again. Nothing has been run on a device.
