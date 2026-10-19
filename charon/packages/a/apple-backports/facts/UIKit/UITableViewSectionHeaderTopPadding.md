# UITableView sectionHeaderTopPadding, iOS 15

Source: UIKit of iOS 16.0 arm64e, `-[UITableView sectionHeaderTopPadding]` at `0x189cfd810` and `-setSectionHeaderTopPadding:` at
`0x18937053c`, read; the SDK 16.4 header of `UITableView.h`; and iOS 6.0 on the emulator and iOS 6.1.3 on an iPad 2 and an
iPhone 4S, through `tests/backports/device/ios1516.m`.

## What is read of the newest release

The getter answers a stored `CGFloat`. The setter turns a negative number into -1, which is `UITableViewAutomaticDimension`,
stores it when it differs from what is stored and asks the table to lay out again. The header says the padding is the space
"above each section header" and that "the default value is `UITableViewAutomaticDimension`", the system's own padding, which iOS
15 introduced.

## What the port does

A section header of iOS 6 has no padding above it, so there is nothing to lay out: the property is kept and answered back, starts as
`UITableViewAutomaticDimension`, and turns a negative value into that, as the release does. A value of zero, which is what an
application sets to take the padding away, is what the release draws already. A positive value cannot be applied, and the log says
so once, the first time. The property is inert.

## What was measured

A table made on the emulated iOS 6.0, the iPad 2 and the iPhone 4S answers `UITableViewAutomaticDimension` at first, keeps 0 and
12, answers `UITableViewAutomaticDimension` after -5, and the log line appears once, on the first positive value.
