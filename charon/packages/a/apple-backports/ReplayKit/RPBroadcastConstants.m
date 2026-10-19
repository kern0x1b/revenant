#import <ReplayKit/ReplayKit.h>

// The two keys of the broadcast family, each read from the host at run time (facts/ReplayKit/RPBroadcastConstants.md). The error
// domain is in its own object: it arrived in iOS 9, and these keys in a later release, so one object is one release.
NSString *const RPApplicationInfoBundleIdentifierKey = @"RPApplicationInfoBundleIdentifier";
NSString *const RPVideoSampleOrientationKey = @"RPSampleBufferVideoOrientation";
