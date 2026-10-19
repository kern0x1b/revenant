# The availability of Live Activities, and what the module answers where there is none

A Live Activity is not a value the app keeps: it is a registration the system's own activity daemon
(`chronod`) owns, which mints the push token that updates it and draws it on the Lock Screen and, from
iOS 16.1, in the Dynamic Island. Measured on this port's target: the 6.1.3 release carries no
`chronod` image in the dyld cache ladder, has no Live Activity surface at all, and grants no
entitlement for one. `ActivityAuthorizationInfo.areActivitiesEnabled` is therefore the framework's own
answer for a device that does not support Live Activities, which is `false`.

The module asks rather than asserts. `CharonActivitySupport` holds the reader the system's own answer
comes through; with no reader installed - every release this port builds for - it answers what the
release answers. Everything else follows the framework's own way from that one answer:

* `Activity.request(...)` throws `ActivityAuthorizationError.unsupported`, the case the framework
  writes for "this device does not support Live Activities";
* `Activity.activities` is empty and `activityUpdates` carries nothing, because nothing is registered;
* `activityStateUpdates`, `contentStateUpdates`, `contentUpdates` and `pushTokenUpdates` each yield the
  one value there is - the state, the content, or nothing - and then end, as a sequence over an empty
  registry does;
* `pushToken` and `pushToStartToken` are `nil`, because only the daemon mints a token.

What is the app's own and is real, and is not refused:

* the attributes, the content state, the stale date and the relevance score - the score is clipped to
  0...1, as the framework's own initialiser does, rather than refused;
* `ActivityState`'s five cases and the `stale` answer, which the module computes from the stale date
  rather than stores;
* the alert's two texts and its sound, the dismissal policy's three spellings, the styles, the push
  types, and the error's domain, codes, reasons and recovery suggestions;
* the registry: what an app registered is kept, so `activities` and the streams see the same values a
  caller would read back, and the streams are real sequences over it.

The registry is per process. The system's own store is per device and survives a relaunch; this one does
not, and a relaunched app finds its activities through the framework's own answer - which, here, is that
there are none. That is the one dimension of Live Activities this port cannot reach, and it is the
daemon, not the API.
