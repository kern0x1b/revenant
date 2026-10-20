#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char revenantAutomaticallyLoadedKeys;

static NSArray<NSString *> *revenantDefaultAutomaticallyLoadedAssetKeys(void)
{
    return @[@"duration", @"availableMediaCharacteristicsWithMediaSelectionOptions"];
}

@implementation AVPlayerItem (RevenantAutomaticallyLoadedAssetKeys7)

+ (instancetype)playerItemWithAsset:(AVAsset *)asset automaticallyLoadedAssetKeys:(NSArray<NSString *> *)automaticallyLoadedAssetKeys
{
    return [[self alloc] initWithAsset:asset automaticallyLoadedAssetKeys:automaticallyLoadedAssetKeys];
}

- (instancetype)initWithAsset:(AVAsset *)asset automaticallyLoadedAssetKeys:(NSArray<NSString *> *)automaticallyLoadedAssetKeys
{
    self = [self initWithAsset:asset];
    if (!self)
        return nil;
    objc_setAssociatedObject(self, &revenantAutomaticallyLoadedKeys, [automaticallyLoadedAssetKeys copy],
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (automaticallyLoadedAssetKeys.count > 0)
        [asset loadValuesAsynchronouslyForKeys:automaticallyLoadedAssetKeys completionHandler:nil];
    return self;
}

- (NSArray<NSString *> *)automaticallyLoadedAssetKeys
{
    NSArray<NSString *> *keys = objc_getAssociatedObject(self, &revenantAutomaticallyLoadedKeys);
    return keys ?: revenantDefaultAutomaticallyLoadedAssetKeys();
}

@end
