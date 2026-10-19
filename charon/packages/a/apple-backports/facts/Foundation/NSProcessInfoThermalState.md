# The thermal state of a process, iOS 11.0

Introduced in iOS 11.0: the level of thermal pressure the system is under, so an
application can back off before the system does it for it - nominal, fair,
serious or critical - and the notification that says it changed.

Source: Foundation of the arm64 shared cache of iOS 12.0, read with the symbols
of the image: `-[NSProcessInfo thermalState]` at `0x18196e7fc` and
`_NSProcessInfoNotifyThermalState` at `0x18196e890`. The name of the
notification is the one the class carries as a string, and the host's Foundation
gives the constant the same value. The caches of iOS 6.0 to 9.0 were searched
for the strings the release would read the level from.

## What the release does

The first call registers for a notification of the system, once, and every call
answers the state that was last stored. When the system's level changes, the
function above reads it and maps it, and posts
`NSProcessInfoThermalStateDidChangeNotification` when the stored state differs
from the new one. The mapping is a table of the level the system reports:

| the system's level | the state |
|---|---|
| 10 | fair, 1 |
| 20 | serious, 2 |
| 30, 40 and 50 | critical, 3 |
| anything else | nominal, 0 |

## What iOS 6 has, and does not

The level it reads is a thermal pressure level the system publishes under the name
`com.apple.system.thermalpressurelevel`. That string is in the caches of iOS 7.0,
8.0 and 9.0 and **not** in that of iOS 6.0. What iOS 6.0 has is the older API,
`OSThermalNotificationCurrentLevel` and `kOSThermalNotificationName`: a level of
behaviours the system asks of a process - torch and backlight percentages - on a
scale that does not map onto the four states, and this package does not invent a
mapping.

## What the port answers

`-thermalState` answers **nominal**, always, and says once in the log that it
does. `NSProcessInfoThermalStateDidChangeNotification` is carried with the
release's string and is never posted, since the state never changes. Nominal is
the state a device answers when it is under no pressure, and an application that
reads it does what it does on any cool device; what it cannot do is be told that
this one is hot. That is why both are `inert`, and why the log line is there.
