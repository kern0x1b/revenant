#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// AVPlayerItem's automatically loaded asset keys, iOS 7.0: the factory and the initializer that take the keys, and
// the readonly property that says which keys an item loads.
//
// **What the release has.** 6.1.3's AVPlayerItem carries +playerItemWithAsset: and -initWithAsset:, and its asset
// carries -loadValuesAsynchronouslyForKeys:completionHandler: and -statusOfValueForKey:error:. So the keys can be
// loaded on this release; what it does not do is remember which ones an item should load. These members are a
// category on the release's own AVPlayerItem, so nothing of the release is replaced: the category adds the three
// members the release does not have.
//
// **What the host measured** (tests/backports/host/avf-player-item-keys):
//  - the factory and the initializer keep the keys they are given, in order, and the property reads them back;
//  - with no keys given, the property reads the release's default list: `duration` and
//    `availableMediaCharacteristicsWithMediaSelectionOptions` (the host's default; the device's was not measured);
//  - a key the asset does not have is kept without an error, and the item is still made;
//  - the keys are loaded when the item goes into a player (their status becomes Loaded and the item becomes ready),
//    and not before; an unattached item's keys stay Unknown.
//
// **Where this port differs from the host.** It loads the keys when the item is made, not when the item goes into a
// player. Before the item is attached, a key's status here is Loading or Loaded, where the host's is Unknown. Once
// the item is in a player the two agree. The difference is the price of loading at the only point this release lets
// the port act; it is an allowance in the probe, and it is written here, not hidden.
//
// The properties are readonly, as the header declares them.

static const char charonAutomaticallyLoadedKeys;

// The release's default, measured on the host; an item made without keys reads this list.
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
    // COPY, because the header's keys are a value the caller may change after making the item.
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
