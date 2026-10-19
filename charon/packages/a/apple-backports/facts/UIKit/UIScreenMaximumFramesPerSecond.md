# How fast a screen can draw, iOS 10.3

Introduced in iOS 10.3: `-[UIScreen maximumFramesPerSecond]`.

Source: UIKit of the armv7s cache of iOS 10.3.4, read method by method, and UIKit of iOS 6.0 for the interval it asks;
the device test `imagescreen.m` reads the value on an iPhone 4S and an iPad 2.

The release asks the screen's display for its refresh interval, in seconds. If that is above 0 it answers the reciprocal
rounded to a whole number, and if not, 60. iOS 6's `UIScreen` has `-_refreshRate`, which answers the same interval from
the same display, so the port asks that and does the same sum. Both devices this port runs on answer an interval of a
sixtieth of a second, so 60.
