# revenant@activitykit

The ActivityKit framework of iOS 16.1, as one Swift module a port writes `import ActivityKit` for,
built against the `revenant@swift-runtime` a port carries.

    target("my-port")
        add_requires("revenant@swift-runtime")
        add_requires("revenant@appintents")
        add_requires("revenant@activitykit")
        add_packages("swift-runtime", "appintents", "activitykit")

## What the module is

`Activity`, its `ActivityAttributes`, `ActivityContent`, `ActivityState`, `ActivityStyle`, `PushType`,
`AlertConfiguration`, `ActivityUIDismissalPolicy`, `ActivityAuthorizationError` and
`ActivityAuthorizationInfo`, with the four update streams (`activityUpdates`, `activityStateUpdates`,
`contentStateUpdates`, `contentUpdates`) and the two push-token streams the framework names.

## The seam: there is no activity daemon

A Live Activity is a registration the system's own daemon (`chronod`) owns; it mints the push token and
draws the activity on the Lock Screen and in the Dynamic Island. iOS 6.1.3 runs no such daemon, has no
Live Activity surface and grants no entitlement for one, so the module gives the framework's own answer
for a device that does not support Live Activities, and gives it by asking:
`RevenantActivitySupport.shared.areActivitiesEnabled` is `false` with no reader installed, and a caller on a
release that does run the daemon installs the system's own answer with
`install(areActivitiesEnabled:frequentPushesEnabled:)`. From that one answer everything else follows the
framework's own way: `request` throws `ActivityAuthorizationError.unsupported`, `activities` is empty,
the streams carry nothing, and `pushToken` and `pushToStartToken` are `nil` because only the daemon
mints one.

What *is* the app's own and is real: the attributes, the content state, the stale date, the relevance
score (clipped to 0...1, as the framework's own initialiser does), the alert's two texts and its
sound, the dismissal policy, and the errors' domain, codes and sentences. `docs/reference/backports/ActivityKit/ActivityKit/Availability.md`.

## The Foundation type it is written in

`AlertConfiguration`'s `title` and `body` are `Foundation.LocalizedStringResource`. Where the runtime's
Foundation has the type, the module uses the platform's; where it does not - it is the swift-5.4.3
overlay, which predates it - the `revenant@appintents` package carries it and this one takes it from
there. The Swift target measures which with a probe each time it configures the module.

## Licence

MIT, the repository's.

## Building it on its own

The Backports build does not include this package; the `Swift` component does:

    ./xmakew f -P . -p iphoneos -a armv7 --component=Swift -y
    ./xmakew require -P . -y revenant@activitykit

`require` builds the package and the packages its recipe declares (here `revenant@swift-runtime` and
`revenant@appintents`), so that one command is enough. The first run also builds swift-runtime and
libcxx from source unless it takes their prebuilt releases; see
[prebuilt packages](../../../guides/prebuilt.md).

If an `xmake` command waits with `package(...) is being accessed by other processes, please wait!`,
another build is using the same package store, `$XMAKE_GLOBALDIR` (default
`~/.revenant/cache/xmake-global`). Wait for it to finish, or give this build its own store by setting
`XMAKE_GLOBALDIR` to another folder.
