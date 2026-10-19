// SpriteKitEffect7.m - SKEffectNode of iOS 7, carried for the releases that have no SpriteKit at all.
//
// An effect node draws its children through a filter, and its members say how: whether the filter is centred on the
// node, whether the effect runs, whether the result is rasterised, and the blend mode. The members are stored and read
// back, as the host stores them (measured in facts/SpriteKit/SKEffectNode.md): the filter defaults to none, the centring
// and the effect default to on, and rasterisation to off. The effect is not run yet: it is the renderer's, which is owed.
// The shader and the attribute members are owed (registry/SpriteKit/ios8.json and ios10.json).
#import "CharonSpriteKit.h"

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
