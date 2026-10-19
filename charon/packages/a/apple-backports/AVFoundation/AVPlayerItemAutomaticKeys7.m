#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char charonAutomaticallyLoadedKeys;

static NSArray<NSString *> *charonDefaultAutomaticallyLoadedAssetKeys(void)
{
    return @[@"duration", @"availableMediaCharacteristicsWithMediaSelectionOptions"];
}

@implementation AVPlayerItem (CharonAutomaticallyLoadedAssetKeys7)

+ (instancetype)playerItemWithAsset:(AVAsset *)asset automaticallyLoadedAssetKeys:(NSArray<NSString *> *)automaticallyLoadedAssetKeys
{
    return [[self alloc] initWithAsset:asset automaticallyLoadedAssetKeys:automaticallyLoadedAssetKeys];
}

- (instancetype)initWithAsset:(AVAsset *)asset automaticallyLoadedAssetKeys:(NSArray<NSString *> *)automaticallyLoadedAssetKeys
{
    self = [self initWithAsset:asset];
    if (!self)
        return nil;
    objc_setAssociatedObject(self, &charonAutomaticallyLoadedKeys, [automaticallyLoadedAssetKeys copy],
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (automaticallyLoadedAssetKeys.count > 0)
        [asset loadValuesAsynchronouslyForKeys:automaticallyLoadedAssetKeys completionHandler:nil];
    return self;
}

- (NSArray<NSString *> *)automaticallyLoadedAssetKeys
{
    NSArray<NSString *> *keys = objc_getAssociatedObject(self, &charonAutomaticallyLoadedKeys);
    return keys ?: charonDefaultAutomaticallyLoadedAssetKeys();
}

@end
