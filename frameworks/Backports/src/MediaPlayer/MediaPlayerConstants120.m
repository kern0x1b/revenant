#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

extern NSString *const MPNowPlayingInfoPropertyCurrentPlaybackDate;

NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyCurrentPlaybackDate) = @"MPNowPlayingInfoPropertyCurrentPlaybackDate";
