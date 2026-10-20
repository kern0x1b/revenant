#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface MPMusicPlayerQueueDescriptor (RevenantSubclassInit)
- (instancetype)revenantInitAbstractQueueDescriptor;
@end

@implementation MPMusicPlayerQueueDescriptor

- (instancetype)revenantInitAbstractQueueDescriptor {
    return [super init];
}

- (instancetype)init {
    if ([self class] == [MPMusicPlayerQueueDescriptor class]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"%@ is abstract: use MPMusicPlayerMediaItemQueueDescriptor or MPMusicPlayerStoreQueueDescriptor",
                           NSStringFromClass([self class])];
        return nil;
    }
    return [self revenantInitAbstractQueueDescriptor];
}

@end

@implementation MPMusicPlayerMediaItemQueueDescriptor
{
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *_timeWindows;
}

@synthesize query = _query;
@synthesize itemCollection = _itemCollection;
@synthesize startItem = _startItem;

- (instancetype)initWithQuery:(MPMediaQuery *)query {
    self = [self revenantInitAbstractQueueDescriptor];
    if (self) {
        _query = [query copy];
    }
    return self;
}

- (instancetype)initWithItemCollection:(MPMediaItemCollection *)itemCollection {
    self = [self revenantInitAbstractQueueDescriptor];
    if (self) {
        _itemCollection = itemCollection;
    }
    return self;
}

- (MPMediaQuery *)query { return _query; }
- (MPMediaItemCollection *)itemCollection { return _itemCollection; }
- (MPMediaItem *)startItem { return _startItem; }

- (void)setStartTime:(NSTimeInterval)startTime forItem:(MPMediaItem *)mediaItem {
    [self revenantRecordTime:startTime atKey:@"start" forItem:mediaItem];
}

- (void)setEndTime:(NSTimeInterval)endTime forItem:(MPMediaItem *)mediaItem {
    [self revenantRecordTime:endTime atKey:@"end" forItem:mediaItem];
}

- (void)revenantRecordTime:(NSTimeInterval)time
                   atKey:(NSString *)which
                forItem:(MPMediaItem *)mediaItem {
    MPMediaEntityPersistentID persistentID = [mediaItem persistentID];
    if (persistentID == 0) {
        return;
    }
    NSNumber *key = @(persistentID);
    NSMutableDictionary<NSString *, NSNumber *> *window = _timeWindows[key];
    if (!window) {
        window = [NSMutableDictionary dictionary];
        _timeWindows[key] = window;
    }
    window[which] = @(time);
}

@end

@implementation MPMusicPlayerStoreQueueDescriptor
{
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *_timeWindows;
}

@synthesize storeIDs = _storeIDs;
@synthesize startItemID = _startItemID;

- (instancetype)initWithStoreIDs:(NSArray<NSString *> *)storeIDs {
    self = [self revenantInitAbstractQueueDescriptor];
    if (self) {
        _storeIDs = [storeIDs copy];
    }
    return self;
}

- (NSArray<NSString *> *)storeIDs { return _storeIDs; }
- (NSString *)startItemID { return _startItemID; }

- (void)setStartTime:(NSTimeInterval)startTime forItemWithStoreID:(NSString *)storeID {
    if (!storeID) { return; }
    NSMutableDictionary<NSString *, NSNumber *> *window = _timeWindows[storeID];
    if (!window) {
        window = [NSMutableDictionary dictionary];
        _timeWindows[storeID] = window;
    }
    window[@"start"] = @(startTime);
}

- (void)setEndTime:(NSTimeInterval)endTime forItemWithStoreID:(NSString *)storeID {
    if (!storeID) { return; }
    NSMutableDictionary<NSString *, NSNumber *> *window = _timeWindows[storeID];
    if (!window) {
        window = [NSMutableDictionary dictionary];
        _timeWindows[storeID] = window;
    }
    window[@"end"] = @(endTime);
}

@end
