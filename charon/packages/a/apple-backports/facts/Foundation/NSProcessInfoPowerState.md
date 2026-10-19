# Low Power Mode of a process, iOS 9.0

Introduced in iOS 9.0: `-[NSProcessInfo isLowPowerModeEnabled]` says whether the user has turned Low Power Mode on, so
an application can stop background work and animation, and `NSProcessInfoPowerStateDidChangeNotification` says it
changed.

Source: the host's own Foundation, which answers the notification constant and the getter, and the shared caches of
iOS 6.0, 6.1.3, 7.0, 8.0 and 9.0 searched for the getter and for the Low Power Mode setting. Foundation of iOS 9.0 has
`-[NSProcessInfo(NSProcessInfoHardwareState) isLowPowerModeEnabled]` and Settings has the switch
(`PSLowPowerModeSettingsDetail`); none of the caches before 9.0 has either. What iOS 6 has under the name is the
baseband's own low power event, which no process can read or turn on.

## What the port answers

`-isLowPowerModeEnabled` answers **NO**, always, and says once in the log that it does.
`NSProcessInfoPowerStateDidChangeNotification` is carried with the release's string and is never posted, since the
state never changes. NO is what a device answers when the user has not turned the mode on, and an application that
reads it does what it does on any such device. What it cannot do is be told that the mode is on, because there is no
such switch on this release. That is why the log line is there.

The getter is **`implemented`** and the notification `inert`, and the difference is the answer rather than the effect.
The port's own `-isLowPowerModeEnabled` (`Foundation/NSProcessInfo+PowerState.m`) returns that NO and writes the log
line, and `tests/backports/device/foundation2.m` reads it back on a 6.1.3 device, so a name the backports answer is
carried and its availability lowered. The notification has no implementation to speak of: it is the release's own
string, and nothing can change a state this release has none of, so it is `inert` - kept, and never posted. The two
spellings of the getter, the property `NSProcessInfo.lowPowerModeEnabled` and the method that reads it, are one API
and are carried together: the generator's rule lowers the property and its implicit accessor in the same edit, so a status that
disagreed between them would have the one say the call is not available and the other lower it anyway.
