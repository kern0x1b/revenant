#import <UIKit/UIKit.h>

// iOS 5.0's UIKit exports it from __TEXT,__const as -1.0 (the armv7 cache of 5.0, read through dyld.extract;
// facts/UIKit/UITableViewAutomaticDimension.md). Before 5.0 nothing in UIKit reads it: it is the value the
// package's own table view members answer and compare against.
const CGFloat UITableViewAutomaticDimension = -1.0f;
