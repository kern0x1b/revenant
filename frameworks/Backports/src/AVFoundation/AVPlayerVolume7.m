#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char revenant_player_volume_key;
static const char revenant_item_volume_key;

@interface AVPlayerItem (RevenantVolumeAdjustment)
- (float)volumeAdjustment;
- (void)setVolumeAdjustment:(float)volumeAdjustment;
@end

@interface RevenantPlayerVolume : NSObject
@property (nonatomic) float volume;
@property (nonatomic) BOOL muted;
@property (nonatomic, readonly) NSHashTable *items;
@end

@interface RevenantItemVolume : NSObject
@property (nonatomic) float base;
@end

static void revenant_release_item(AVPlayerItem *item)
{
    RevenantItemVolume *record = objc_getAssociatedObject(item, &revenant_item_volume_key);
    if (!record)
        return;
    item.volumeAdjustment = record.base;
    objc_setAssociatedObject(item, &revenant_item_volume_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation RevenantPlayerVolume

@synthesize volume = _volume;
@synthesize muted = _muted;
@synthesize items = _items;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _volume = 1.0f;
        _items = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (float)gain
{
    return self.muted ? 0.0f : self.volume;
}

- (void)dealloc
{
    for (AVPlayerItem *item in _items.allObjects)
        revenant_release_item(item);
}

@end

@implementation RevenantItemVolume

@synthesize base = _base;

@end

static NSArray *revenant_player_items(AVPlayer *player)
{
    if (!player)
        return @[];
    if ([player isKindOfClass:[AVQueuePlayer class]])
        return [(AVQueuePlayer *)player items];
    return player.currentItem ? @[player.currentItem] : @[];
}

static void revenant_apply_item(RevenantPlayerVolume *state, AVPlayerItem *item)
{
    float gain = state.gain;
    RevenantItemVolume *record = objc_getAssociatedObject(item, &revenant_item_volume_key);
    if (!record) {
        if (gain == 1.0f)
            return;
        record = [RevenantItemVolume new];
        record.base = item.volumeAdjustment;
        objc_setAssociatedObject(item, &revenant_item_volume_key, record, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (gain == 1.0f) {
        revenant_release_item(item);
        return;
    }
    item.volumeAdjustment = record.base * gain;
    [state.items addObject:item];
}

static void revenant_apply_player(AVPlayer *player)
{
    RevenantPlayerVolume *state = objc_getAssociatedObject(player, &revenant_player_volume_key);
    if (!state)
        return;
    for (AVPlayerItem *item in revenant_player_items(player))
        revenant_apply_item(state, item);
}

static void revenant_release_absent(AVPlayer *player, NSArray *items)
{
    NSArray *present = revenant_player_items(player);
    for (AVPlayerItem *item in items) {
        if (![present containsObject:item])
            revenant_release_item(item);
    }
}

static RevenantPlayerVolume *revenant_player_state(AVPlayer *player)
{
    RevenantPlayerVolume *state = objc_getAssociatedObject(player, &revenant_player_volume_key);
    if (!state) {
        state = [RevenantPlayerVolume new];
        objc_setAssociatedObject(player, &revenant_player_volume_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

@implementation AVPlayer (RevenantAVFoundationVolume)

- (float)volume
{
    RevenantPlayerVolume *state = objc_getAssociatedObject(self, &revenant_player_volume_key);
    return state ? state.volume : 1.0f;
}

- (void)setVolume:(float)volume
{
    revenant_player_state(self).volume = fminf(fmaxf(volume, 0.0f), 1.0f);
    revenant_apply_player(self);
}

- (BOOL)isMuted
{
    RevenantPlayerVolume *state = objc_getAssociatedObject(self, &revenant_player_volume_key);
    return state ? state.muted : NO;
}

- (void)setMuted:(BOOL)muted
{
    revenant_player_state(self).muted = muted;
    revenant_apply_player(self);
}

@end

static void revenant_wrap(Class cls, SEL selector, id (^make)(IMP original))
{
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        return;
    class_replaceMethod(cls, selector, imp_implementationWithBlock(make(method_getImplementation(method))), method_getTypeEncoding(method));
}

@interface RevenantPlayerVolumeInstaller : NSObject
@end

@implementation RevenantPlayerVolumeInstaller

+ (void)load
{
    SEL replace = @selector(replaceCurrentItemWithPlayerItem:);
    revenant_wrap([AVPlayer class], replace, ^id(IMP original) {
        return ^(AVPlayer *player, AVPlayerItem *item) {
            NSArray *leaving = revenant_player_items(player);
            ((void (*)(id, SEL, id))original)(player, replace, item);
            revenant_release_absent(player, leaving);
            revenant_apply_player(player);
        };
    });
    SEL insert = @selector(insertItem:afterItem:);
    revenant_wrap([AVQueuePlayer class], insert, ^id(IMP original) {
        return ^(AVQueuePlayer *player, AVPlayerItem *item, AVPlayerItem *after) {
            ((void (*)(id, SEL, id, id))original)(player, insert, item, after);
            revenant_apply_player(player);
        };
    });
    SEL remove = @selector(removeItem:);
    revenant_wrap([AVQueuePlayer class], remove, ^id(IMP original) {
        return ^(AVQueuePlayer *player, AVPlayerItem *item) {
            NSArray *leaving = revenant_player_items(player);
            ((void (*)(id, SEL, id))original)(player, remove, item);
            revenant_release_absent(player, leaving);
        };
    });
    SEL clear = @selector(removeAllItems);
    revenant_wrap([AVQueuePlayer class], clear, ^id(IMP original) {
        return ^(AVQueuePlayer *player) {
            NSArray *leaving = revenant_player_items(player);
            ((void (*)(id, SEL))original)(player, clear);
            revenant_release_absent(player, leaving);
        };
    });
    SEL advance = @selector(advanceToNextItem);
    revenant_wrap([AVQueuePlayer class], advance, ^id(IMP original) {
        return ^(AVQueuePlayer *player) {
            NSArray *leaving = revenant_player_items(player);
            ((void (*)(id, SEL))original)(player, advance);
            revenant_release_absent(player, leaving);
        };
    });
}

@end
