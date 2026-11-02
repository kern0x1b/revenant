#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

extern NSString *const MPNowPlayingInfoCollectionIdentifier;
extern NSString *const MPNowPlayingInfoPropertyExternalContentIdentifier;
extern NSString *const MPNowPlayingInfoPropertyExternalUserProfileIdentifier;
extern NSString *const MPNowPlayingInfoPropertyIsLiveStream;
extern NSString *const MPNowPlayingInfoPropertyMediaType;
extern NSString *const MPNowPlayingInfoPropertyPlaybackProgress;

NSString *const BACKPORT_IMPL(MPNowPlayingInfoCollectionIdentifier) = @"MPNowPlayingInfoCollectionIdentifier";
NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyExternalContentIdentifier) = @"MPNowPlayingInfoPropertyExternalContentIdentifier";
NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyExternalUserProfileIdentifier) = @"MPNowPlayingInfoPropertyExternalUserProfileIdentifier";
NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyIsLiveStream) = @"MPNowPlayingInfoPropertyIsLiveStream";
NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyMediaType) = @"MPNowPlayingInfoPropertyMediaType";
NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyPlaybackProgress) = @"MPNowPlayingInfoPropertyPlaybackProgress";
