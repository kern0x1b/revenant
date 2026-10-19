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
