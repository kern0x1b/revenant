# Alternate application icons, iOS 10.3

Introduced in iOS 10.3: `-[UIApplication supportsAlternateIcons]`, `alternateIconName` and `setAlternateIconName:completionHandler:`.

iOS 6 takes the icon from the application's bundle when SpringBoard reads it and gives an application no call that changes it, so the
port cannot carry the change: `supportsAlternateIcons` is NO, `alternateIconName` is nil, and the change calls its completion handler,
on the main queue and after the call has returned, with `NSCocoaErrorDomain` `NSFeatureUnsupportedError` (3328) and the message
"The requested operation couldn't be completed because the feature is not supported." An application that asks `supportsAlternateIcons`
first shows no such choice; one that does not ask handles the error as it would any failure of the release. A nil completion
handler is accepted. The host (Mac Catalyst) has no alternate icons and never calls the handler, so the answers are held by
`device/smallapis.m` alone.
