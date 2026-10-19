// MPMusicPlayerQueueDescriptor, MPMusicPlayerMediaItemQueueDescriptor and MPMusicPlayerStoreQueueDescriptor,
// the 10.1 API, and the per-item playback windows the header's four time setters record.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 dyld shared caches of
// 6.1.3 and 4.3 (the commands are in facts/MediaPlayer/LanguageOptions.md; same two files, read once for
// the band, controls as that page records - MPNowPlayingInfoCenter PRESENT at 6.1.3 and ABSENT at 4.3):
//
//   MPMusicPlayerQueueDescriptor          ABSENT  ABSENT
//   MPMusicPlayerMediaItemQueueDescriptor ABSENT  ABSENT
//   MPMusicPlayerStoreQueueDescriptor     ABSENT  ABSENT
//
// All three are new code and cannot shadow anything, so `implemented` is available and `absent` - the
// status for a row whose answer needs a thing the device lacks - is not the word. What makes a descriptor
// worth carrying is measured separately, in MPMusicPlayerControllerQueueDescriptor101.m, which is where
// the descriptor is actually consumed.
//
// THE BASE CLASS IS ABSTRACT, and how that is enforced is a real decision rather than a convention. The
// header writes MP_INIT_UNAVAILABLE on MPMusicPlayerQueueDescriptor and gives the base NO members at
// all - no query, no IDs, nothing - so an instance of the base describes no queue and no setter could
// consume it. -init therefore refuses on the base itself. It is refused BY CLASS COMPARISON and not
// unconditionally, because BOTH concrete subclasses call [super init] on their way to being an object:
// a base -init that raised always would make both of the header's real initializers throw, which is the
// shape of that mistake and the reason it is written down here.
//
// One object per release: this file is the 10.1 API. The 11.0 pair
// (MPMusicPlayerPlayParameters, MPMusicPlayerPlayParametersQueueDescriptor) is
// MPMusicPlayerPlayParameters11.m; the 10.3 classes are MPMusicPlayerApplicationController103.m.
// release-split reads band points only, so a file mixing these releases would pass that check and still
// be wrong.

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

// The base's one initializer, DECLARED BEFORE THE FIRST @implementation that uses it. That order is not
// tidiness: MPMusicPlayerPlayParameters11.m calls -charonInitAbstractQueueDescriptor from its own
// initializer, and when this declaration sat after the base's @implementation a file compiled on its own
// answered "no visible @interface for 'MPMusicPlayerPlayParametersQueueDescriptor' declares the selector",
// measured. Declared once and implemented once - restating the category in the 11.0 file was tried and
// produced "duplicate definition of category 'CharonSubclassInit' on interface
// 'MPMusicPlayerQueueDescriptor'".
@interface MPMusicPlayerQueueDescriptor (CharonSubclassInit)
- (instancetype)charonInitAbstractQueueDescriptor;
@end

@implementation MPMusicPlayerQueueDescriptor

// MP_INIT_UNAVAILABLE, which MediaPlayerDefines.h:70-73 expands to:
//
//   #define MP_INIT_UNAVAILABLE  + (instancetype)new NS_UNAVAILABLE;  - (instancetype)init NS_UNAVAILABLE;
//
// so the header marks BOTH -init and +new unavailable on the base. That has a consequence that decides
// this whole file: a subclass's initializer cannot call [super init], because the compiler resolves that
// to the base's unavailable -init and rejects the call - measured, three errors, one per initializer here,
// each "'init' is unavailable" at the [super init] line. A base -init that merely refused at RUNTIME
// would compile and would not fix it; the unavailability is a compile-time attribute.
//
// So the base's initializer is declared in a class extension with a name of its own, and both subclasses
// call THAT. It is the one initializer the base has, it is not -init, +new and -init stay unavailable
// exactly as the header writes them, and the base's own -init below still refuses at runtime so that a
// caller reaching it through a subclass-of-subclass or a runtime call cannot construct a descriptor that
// names no queue. The name is registered as a row like any other seam the port owns - see
// registry/MediaPlayer/mpqueuedescriptor.json, which registers it as a row like any other seam the
// port owns - the rule AGENTS.md records after a reviewer's verdict on a helper with no entry, because
// the registry check asks what is built and finds nothing, and it is right.
- (instancetype)charonInitAbstractQueueDescriptor {
    return [super init];
}

- (instancetype)init {
    if ([self class] == [MPMusicPlayerQueueDescriptor class]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"%@ is abstract: use MPMusicPlayerMediaItemQueueDescriptor or MPMusicPlayerStoreQueueDescriptor",
                           NSStringFromClass([self class])];
        return nil;
    }
    return [self charonInitAbstractQueueDescriptor];
}

@end

@implementation MPMusicPlayerMediaItemQueueDescriptor
{
    // The per-item playback windows the four time setters record, keyed by the item's persistent ID.
    //
    // Keyed by ID and NOT by the item, and not with an NSMapTable either way: a map table built with
    // default options RETAINS its keys, so a window would keep a released MPMediaItem alive, and the
    // opaque-pointer options would key by address and make the window unreachable on the next call for an
    // item at the same address. The persistent ID is MPMediaEntity's own stable name for an item and is
    // the release's own notion of "the same item", so a window recorded for a released item is still
    // reachable by the next item that shares the identity.
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *_timeWindows;
}

@synthesize query = _query;
@synthesize itemCollection = _itemCollection;
@synthesize startItem = _startItem;

// The two header initializers, quoted from MPMusicPlayerQueueDescriptor.h:
//
//   - (instancetype)initWithQuery:(MPMediaQuery *)query;
//   - (instancetype)initWithItemCollection:(MPMediaItemCollection *)itemCollection;
//
// Both parameters are nonnull under the header's NS_ASSUME_NONNULL. The query is COPIED because the
// header declares its property `@property (nonatomic, readonly, copy) MPMediaQuery *query` - a `copy`
// property is one whose value a caller cannot mutate behind the object's back, and copying here is what
// makes the property's own contract true of an object built by an initializer rather than a setter. The
// item collection is held STRONGLY because that is what the header declares for it, and copying an
// MPMediaItemCollection is not something a caller can ask for.
- (instancetype)initWithQuery:(MPMediaQuery *)query {
    self = [self charonInitAbstractQueueDescriptor];
    if (self) {
        _query = [query copy];
    }
    return self;
}

- (instancetype)initWithItemCollection:(MPMediaItemCollection *)itemCollection {
    self = [self charonInitAbstractQueueDescriptor];
    if (self) {
        _itemCollection = itemCollection;
    }
    return self;
}

- (MPMediaQuery *)query { return _query; }
- (MPMediaItemCollection *)itemCollection { return _itemCollection; }
- (MPMediaItem *)startItem { return _startItem; }

// The two time setters, quoted from the header:
//
//   - (void)setStartTime:(NSTimeInterval)startTime forItem:(MPMediaItem *)mediaItem;
//   - (void)setEndTime:(NSTimeInterval)endTime forItem:(MPMediaItem *)mediaItem;
//
// What has to be kept is the PAIRING - an item and the window it plays in - because a start without an
// end is not a different thing from an end without a start, and both are legitimate. An item with no
// persistent ID has no identity a window could be recorded against: keying it by object address would make
// the window unreachable on the next call and keying it by anything else would be a value this port
// invented. So such a call is declined and leaves the descriptor exactly as it was, which is a state the
// header's own contract allows - a queue with no explicit window plays the whole item.
- (void)setStartTime:(NSTimeInterval)startTime forItem:(MPMediaItem *)mediaItem {
    [self charonRecordTime:startTime atKey:@"start" forItem:mediaItem];
}

- (void)setEndTime:(NSTimeInterval)endTime forItem:(MPMediaItem *)mediaItem {
    [self charonRecordTime:endTime atKey:@"end" forItem:mediaItem];
}

- (void)charonRecordTime:(NSTimeInterval)time
                   atKey:(NSString *)which
                forItem:(MPMediaItem *)mediaItem {
    // MPMediaEntityPersistentID is uint64_t in BOTH SDKs - measured, MPMediaEntity.h:15 reads
    // "typedef uint64_t MPMediaEntityPersistentID" in 16.4 and in 26.2 - so the window is keyed by the
    // BOXED value and a zero persistent ID is the "no identity" case, which is declined.
    //
    // A first draft read MPMediaItemStandin.h's comment, which says the framework "spells the identifier
    // type as a typedef over NSNumber", and wrote the key as the unboxed value. That comment is WRONG
    // about the framework - the stand-in declares `typedef NSNumber *MPMediaEntityPersistentID` and the
    // SDK declares `uint64_t` - and the draft's two spellings each failed against one of the builds:
    // unboxed against the real SDK ("type argument 'MPMediaEntityPersistentID' (aka 'unsigned long long')
    // is neither an Objective-C object nor a block type") and boxed against the stand-in ("illegal type
    // ... used in a boxed expression"). Boxing satisfies both, because NSNumber is a dictionary key in
    // either build and the value it carries is the same 64-bit number. The stand-in's comment is not
    // corrected here: it is shared with the MPMediaItem family, whose generated getters do depend on it.
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
    // The per-item playback windows, keyed by Store ID. The key is a string the caller owns rather than
    // an object, so there is no lifetime question and no ID to be missing.
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *_timeWindows;
}

@synthesize storeIDs = _storeIDs;
@synthesize startItemID = _startItemID;

- (instancetype)initWithStoreIDs:(NSArray<NSString *> *)storeIDs {
    self = [self charonInitAbstractQueueDescriptor];
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
