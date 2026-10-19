#import "CharonAVMetrics18.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

// AVMetricDownloadSummaryEvent, its own object because it lands in a different band from its sixteen
// siblings and the gate reads the placement off the object. The whole reason is in AVFoundationMetrics18.m's
// comment above and in facts/AVFoundation/Metrics.md: the 18.0 cache exports no
// _OBJC_CLASS_$_AVMetricDownloadSummaryEvent, so nothing measures it at 18.0, and 26.2 annotates this one
// declaration `ios(18)` where the cache says 18.0 for every other class of this surface. Both spellings
// are Apple's.
//
// The class is a container, as every other class of this surface is: the header's properties are
// @property (readonly), so each is a getter over an ivar, and an instance this port has not filled reads
// the empty value its header describes - nil for the two object members, 0 for the counts and the duration.
//
// Open source checked: no candidate. A download summary is a record of what one download did, and no open
// implementation holds AVFoundation's.
@implementation AVMetricDownloadSummaryEvent

@synthesize errorEvent = _errorEvent;
@synthesize recoverableErrorCount = _recoverableErrorCount;
@synthesize mediaResourceRequestCount = _mediaResourceRequestCount;
@synthesize bytesDownloadedCount = _bytesDownloadedCount;
@synthesize downloadDuration = _downloadDuration;
@synthesize variants = _variants;

@end
