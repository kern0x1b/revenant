#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

extern NSString *const MPNowPlayingInfoPropertyAdTimeRanges;
extern NSString *const MPNowPlayingInfoPropertyCreditsStartTime;

NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyAdTimeRanges) = @"MPNowPlayingInfoPropertyAdTimeRanges";
NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyCreditsStartTime) = @"MPNowPlayingInfoPropertyCreditsStartTime";
