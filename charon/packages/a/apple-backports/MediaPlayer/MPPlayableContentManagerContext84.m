// MPPlayableContentManagerContext, the 8.4 class, and the four values it reports about the content
// endpoint's state.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 dyld shared caches of
// 6.1.3 and 4.3 (the commands are in facts/MediaPlayer/LanguageOptions.md): MPPlayableContentManagerContext
// reads ABSENT from both, with the controls in the same two files - MPVolumeView and MPMediaPlaylist
// PRESENT on both ends, MPNowPlayingInfoCenter PRESENT at 6.1.3 and ABSENT at 4.3, so the reader
// discriminates. It is new code and cannot shadow anything, so `implemented` over `absent`.
//
// WHAT IT REPORTS, and why each value is the one it is. The header (MPPlayableContentManagerContext.h)
// says a context "represents the current state of the playable content endpoint" and that "A context is
// retrievable from an instance of MPPlayableContentManager". The endpoint is an external media player -
// a car head unit - and 6.1.3 has none, and this port does not build one. So every value here answers
// the state of an endpoint that is not there, and the four are not the same answer:
//
//   - endpointAvailable          NO. This is the measured state and the only one that is simply true.
//   - contentLimitsEnforced      NO, for the same reason: nothing is enforcing anything because there is
//                                no server to enforce limits.
//   - enforcedContentItemsCount  NSIntegerMax. The header gives this value for the case where the
//                                content server will never cap the number of items, and that is the case here, so this is Apple's own value for
//                                this state rather than a number chosen to look large.
//   - enforcedContentTreeDepth   0, and this is the one value that is NOT a measured state. The header
//                                warns that exceeding this limit results in a crash, so it is a limit the
//                                caller must not exceed rather than a capability. With no endpoint there
//                                is no tree to navigate and nothing calls this, and 0 says the depth
//                                allowed is none - which is the honest reading of a hierarchy nobody walks.
//                                A large number here would claim a capability that does not exist.
//
// The header's fifth member, contentLimitsEnabled, is deprecated in favour of contentLimitsEnforced in
// the same release (MP_DEPRECATED_WITH_REPLACEMENT("contentLimitsEnforced", ios(8.4, 9.0))), so it is
// answered from the same state as its replacement and says so.
//
// One object per release: this file is the 8.4 API. MPPlayableContentManager71.m holds the 7.1 family
// and does not build one of these, because a file exporting both would be one object for two releases and
// band() places an object in exactly one.

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPPlayableContentManagerContext

@synthesize enforcedContentItemsCount = _enforcedContentItemsCount;
@synthesize enforcedContentTreeDepth = _enforcedContentTreeDepth;
@synthesize contentLimitsEnforced = _contentLimitsEnforced;
@synthesize endpointAvailable = _endpointAvailable;

// The header declares no initializer and every property readonly, so the object is built by its own
// -init and configured by nothing. That is deliberate: a context describes an endpoint, and the endpoint
// on this release is absent, so every field has exactly one true value and there is nothing to configure.
// The values are set here rather than defaulted to zero so that each one is visibly a decision:
// enforcedContentItemsCount in particular must NOT be 0, because the header's "never limit" value is
// NSIntegerMax and a zero would claim the opposite - that the server will display no items at all.
- (instancetype)init {
    self = [super init];
    if (self) {
        _enforcedContentItemsCount = NSIntegerMax;
        _enforcedContentTreeDepth = 0;
        _contentLimitsEnforced = NO;
        _endpointAvailable = NO;
    }
    return self;
}

// The deprecated spelling, answered from the same state as the property that replaced it. The header
// replaces contentLimitsEnabled with contentLimitsEnforced at the same availability, so the two cannot
// disagree here and there is no state in which one would be YES and the other NO.
- (BOOL)contentLimitsEnabled {
    return _contentLimitsEnforced;
}

@end
