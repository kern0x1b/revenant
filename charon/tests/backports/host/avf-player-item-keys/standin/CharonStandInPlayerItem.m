//
//  CharonStandInPlayerItem.m
//  See CharonStandInPlayerItem.h. The item is Apple's own: the stand-in adds no behaviour of its own, so every
//  difference between the two runs is in the port's category.
#import "CharonStandInPlayerItem.h"

@implementation CharonStandInPlayerItem

- (instancetype)initWithAsset:(AVAsset *)asset
{
    self = [super init];
    if (!self)
        return nil;
    _item = [[AVPlayerItem alloc] initWithAsset:asset];
    return self;
}

@end
