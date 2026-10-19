#import <Foundation/Foundation.h>

// The iOS 10.0.1 band's MediaPlayer string constants, 6 of them, one object per release band.
//
// THE BAND IS THE TOOL S ANSWER, NOT THE CORPUS S. dyld.first_releases walked the release ladder symbol by
// symbol and this is the first rung that exports each of these; its answer is kept under $CHARON_HOME/cache
// as first-release-<hash>.tsv, and the whole table is quoted in the commit that introduced it. It disagreed
// with the corpus THREE times and the corpus lost all three: MPNowPlayingInfoCollectionIdentifier and the
// five MPNowPlayingInfoProperty* of that group are 10.0.1 and not 9.3, MPNowPlayingInfoPropertyAssetURL is
// 10.2 and not 10.3, and MPNowPlayingInfoPropertyCurrentPlaybackDate is 12.0 and not 11.1. One object
// carrying two of those would have mixed two releases' symbols, which is what release-split refuses.
//
// The value of every one was READ, never derived. Twelve of the eighteen hold their own symbol s name, which
// is a coincidence and not a rule: in the 9.0 band ten of thirteen were dotted public.* strings and one held
// the SINGULAR form of its name. A mutant per constant is what proves the comparison is live.
//
// iOS 6.1.3 exports NONE of the 36 MediaPlayer constants, read from that release s own armv7 cache, so the
// port carries all of them. They are plain data - a caller compares or passes a string.
//
// They are declared HERE, with the plain extern, and MediaPlayer.h is deliberately NOT imported: with -I on
// the port s own tree that import resolves to the PORT s shim rather than the SDK s.
//
// A constant is READ, never CALLED. Nothing here touches MPMediaLibrary, MPMediaQuery or a library.

extern NSString *const MPNowPlayingInfoCollectionIdentifier;
extern NSString *const MPNowPlayingInfoPropertyExternalContentIdentifier;
extern NSString *const MPNowPlayingInfoPropertyExternalUserProfileIdentifier;
extern NSString *const MPNowPlayingInfoPropertyIsLiveStream;
extern NSString *const MPNowPlayingInfoPropertyMediaType;
extern NSString *const MPNowPlayingInfoPropertyPlaybackProgress;

NSString *const MPNowPlayingInfoCollectionIdentifier = @"MPNowPlayingInfoCollectionIdentifier";
NSString *const MPNowPlayingInfoPropertyExternalContentIdentifier = @"MPNowPlayingInfoPropertyExternalContentIdentifier";
NSString *const MPNowPlayingInfoPropertyExternalUserProfileIdentifier = @"MPNowPlayingInfoPropertyExternalUserProfileIdentifier";
NSString *const MPNowPlayingInfoPropertyIsLiveStream = @"MPNowPlayingInfoPropertyIsLiveStream";
NSString *const MPNowPlayingInfoPropertyMediaType = @"MPNowPlayingInfoPropertyMediaType";
NSString *const MPNowPlayingInfoPropertyPlaybackProgress = @"MPNowPlayingInfoPropertyPlaybackProgress";

