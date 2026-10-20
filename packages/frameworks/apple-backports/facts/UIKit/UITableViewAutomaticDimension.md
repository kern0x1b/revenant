# UITableViewAutomaticDimension

iOS 5.0's UIKit exports `UITableViewAutomaticDimension` from `__TEXT,__const` with the value -1.0 (a 32-bit float on
armv7): the armv7 cache of 5.0, UIKit extracted with `dyld.extract` and the four bytes at the symbol read
(`000080bf`). The package defines it with that value for releases before 5.0 in
`UIKit/UITableViewAutomaticDimension.m`; the host's UIKit under Mac Catalyst answers the same value
(`tests/backports/host/uikit2`, group `tabledimension`).

Before 5.0 nothing in UIKit reads the constant. The package's own table view members that answer or compare it
(`UITableView+EstimatedHeights.m`, `UITableView+SectionHeaderTopPadding.m`) read a NULL weak import there before.
