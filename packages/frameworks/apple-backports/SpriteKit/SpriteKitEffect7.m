#import "RevenantSpriteKit.h"

@implementation SKEffectNode {
    CIFilter *_filter;
    BOOL _shouldCenterFilter;
    BOOL _shouldEnableEffects;
    BOOL _shouldRasterize;
    SKBlendMode _blendMode;
}

@synthesize filter = _filter;
@synthesize shouldCenterFilter = _shouldCenterFilter;
@synthesize shouldEnableEffects = _shouldEnableEffects;
@synthesize shouldRasterize = _shouldRasterize;
@synthesize blendMode = _blendMode;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _shouldCenterFilter = YES;
        _shouldEnableEffects = YES;
    }
    return self;
}

@end
