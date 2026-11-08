#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>

static const char revenant_player_volume_key;
static const char revenant_item_volume_key;

@interface RevenantPlayerVolume : NSObject
@property (nonatomic, weak) AVPlayer *player;
@property (nonatomic) float volume;
@property (nonatomic) BOOL muted;
@property (nonatomic, readonly) NSHashTable *items;
@end

@interface RevenantItemVolume : NSObject
@property (nonatomic, strong) AVAudioMix *base;
@property (nonatomic, strong) AVAudioMix *ours;
@property (nonatomic) float gain;
@end

static void revenant_release_item(AVPlayerItem *item)
{
    RevenantItemVolume *record = objc_getAssociatedObject(item, &revenant_item_volume_key);
    if (!record)
        return;
    if (record.ours && item.audioMix == record.ours)
        item.audioMix = record.base;
    objc_setAssociatedObject(item, &revenant_item_volume_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation RevenantPlayerVolume

@synthesize player = _player;
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
@synthesize ours = _ours;
@synthesize gain = _gain;

@end

static NSArray *revenant_player_items(AVPlayer *player)
{
    if (!player)
        return @[];
    if ([player isKindOfClass:[AVQueuePlayer class]])
        return [(AVQueuePlayer *)player items];
    return player.currentItem ? @[player.currentItem] : @[];
}

static AVAudioMix *revenant_scaled_mix(AVAudioMix *base, NSArray *tracks, float gain)
{
    NSMutableArray *parameters = [NSMutableArray arrayWithCapacity:tracks.count];
    for (AVAssetTrack *track in tracks) {
        AVAudioMixInputParameters *source = nil;
        for (AVAudioMixInputParameters *candidate in base.inputParameters) {
            if (candidate.trackID == track.trackID) {
                source = candidate;
                break;
            }
        }
        AVMutableAudioMixInputParameters *scaled = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
        BOOL anchored = NO;
        if (source) {
            scaled.audioTapProcessor = source.audioTapProcessor;
            CMTime cursor = kCMTimeZero;
            float start = 0.0f;
            float end = 0.0f;
            CMTimeRange range = kCMTimeRangeZero;
            while ([source getVolumeRampForTime:cursor startVolume:&start endVolume:&end timeRange:&range]) {
                if (!anchored && CMTimeCompare(range.start, kCMTimeZero) > 0)
                    [scaled setVolume:gain atTime:kCMTimeZero];
                anchored = YES;
                if (CMTIME_IS_NUMERIC(range.duration))
                    [scaled setVolumeRampFromStartVolume:start * gain toEndVolume:end * gain timeRange:range];
                else
                    [scaled setVolume:start * gain atTime:range.start];
                CMTime next = CMTimeRangeGetEnd(range);
                if (!CMTIME_IS_NUMERIC(next) || CMTimeCompare(next, cursor) <= 0)
                    break;
                cursor = next;
            }
        }
        if (!anchored)
            [scaled setVolume:gain atTime:kCMTimeZero];
        [parameters addObject:scaled];
    }
    AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
    mix.inputParameters = parameters;
    return mix;
}

static void revenant_install(RevenantPlayerVolume *state, AVPlayerItem *item)
{
    float gain = state.gain;
    RevenantItemVolume *record = objc_getAssociatedObject(item, &revenant_item_volume_key);
    if (!record && gain == 1.0f)
        return;
    if (!record) {
        record = [RevenantItemVolume new];
        objc_setAssociatedObject(item, &revenant_item_volume_key, record, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    AVAudioMix *current = item.audioMix;
    BOOL owned = record.ours && current == record.ours;
    if (!owned)
        record.base = current;
    if (gain == 1.0f) {
        if (owned)
            item.audioMix = record.base;
        objc_setAssociatedObject(item, &revenant_item_volume_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (owned && record.gain == gain)
        return;
    NSArray *tracks = [item.asset tracksWithMediaType:AVMediaTypeAudio];
    if (tracks.count == 0)
        return;
    item.audioMix = revenant_scaled_mix(record.base, tracks, gain);
    record.ours = item.audioMix;
    record.gain = gain;
    [state.items addObject:item];
}

static void revenant_apply_item(RevenantPlayerVolume *state, AVPlayerItem *item)
{
    AVAsset *asset = item.asset;
    if (state.gain == 1.0f || [asset statusOfValueForKey:@"tracks" error:NULL] == AVKeyValueStatusLoaded) {
        revenant_install(state, item);
        return;
    }
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([revenant_player_items(state.player) containsObject:item])
                revenant_install(state, item);
        });
    }];
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
        state.player = player;
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
