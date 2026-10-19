#import "CharonAVMetrics18.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@implementation AVMetricDownloadSummaryEvent

@synthesize errorEvent = _errorEvent;
@synthesize recoverableErrorCount = _recoverableErrorCount;
@synthesize mediaResourceRequestCount = _mediaResourceRequestCount;
@synthesize bytesDownloadedCount = _bytesDownloadedCount;
@synthesize downloadDuration = _downloadDuration;
@synthesize variants = _variants;

@end
