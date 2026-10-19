#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPPlayableContentManagerContext

@synthesize enforcedContentItemsCount = _enforcedContentItemsCount;
@synthesize enforcedContentTreeDepth = _enforcedContentTreeDepth;
@synthesize contentLimitsEnforced = _contentLimitsEnforced;
@synthesize endpointAvailable = _endpointAvailable;

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

- (BOOL)contentLimitsEnabled {
    return _contentLimitsEnforced;
}

@end
