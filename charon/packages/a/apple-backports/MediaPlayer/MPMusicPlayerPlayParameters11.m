// MPMusicPlayerPlayParameters and MPMusicPlayerPlayParametersQueueDescriptor, the 11.0 API.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 dyld shared caches of
// 6.1.3 and 4.3 (commands in facts/MediaPlayer/LanguageOptions.md, controls as that page records - the
// same reader, the same two files, MPNowPlayingInfoCenter PRESENT at 6.1.3 and ABSENT at 4.3):
// both classes read ABSENT at both ends, so they are new code and cannot shadow anything and
// `implemented` is available where the object has a job to do.
//
// WHAT A PLAY-PARAMETERS IS, which is why it is a value holder and not a bridge. The header's only
// initializer is:
//
//   - (nullable instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary;
//
// and its only property is `@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *dictionary`.
// So the whole class is a typed wrapper around a dictionary of AVFoundation playback settings, and the
// dictionary is the object: this stores it, copies it, and reads it back. The header types the
// initializer `nullable`, which is the one place in this family where Apple itself says the initializer
// may produce nothing - and the case is a dictionary that is not a dictionary of play parameters, which
// this file decides by asking the question the header's type allows rather than by guessing.
//
// The queue descriptor holds an ORDERED ARRAY of these and a start item, plus the two time setters per
// entry. It is the same shape as MPMusicPlayerMediaItemQueueDescriptor, keyed here by the entry's own
// index rather than by an item's identity, because a play-parameters entry has no persistent ID of its
// own - it is a dictionary, and indexing it by position is the identity the header gives it (the header
// calls the array a "queue", and a queue's entries are ordered).
//
// One object per release: this file is the 11.0 API. The 10.1 descriptors are
// MPMusicPlayerQueueDescriptor101.m, the 10.1 setters that consume them are
// MPMusicPlayerControllerQueueDescriptor101.m, and the 10.3 classes are
// MPMusicPlayerApplicationController103.m. release-split reads band points only, so a file mixing these
// would pass that check and still be wrong.

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

// The base's named initializer, declared in the 10.1 object
// (MPMusicPlayerQueueDescriptor101.m) because the header marks the base's -init MP_INIT_UNAVAILABLE and
// a subclass in a different file then has no visible way to reach a superclass initializer. Without a
// declaration the call below is rejected with "no visible @interface for
// 'MPMusicPlayerPlayParametersQueueDescriptor' declares the selector", which is measured, not assumed.
//
// THE DECLARATION IS RESTATED HERE, AND THAT IS WHAT THE LAST MEASUREMENT FORCED. Two attempts are
// recorded because both failed and the failures are different:
//
//   Declared ONLY in MPMusicPlayerQueueDescriptor101.m - correct as a category, since it is declared once
//   and implemented once - but this file calls the selector from its own initializer, and a file compiled
//   on its own then answers "no visible @interface for 'MPMusicPlayerPlayParametersQueueDescriptor'
//   declares the selector", measured. Every object in this library is compiled on its own by the
//   syntax pass and included individually by the stand-in checks, so a declaration that only exists in
//   another file is not enough.
//
//   Restated here under the SAME category name - which was the second attempt - and when both objects were
//   compiled into one check clang answered "duplicate definition of category 'CharonSubclassInit' on
//   interface 'MPMusicPlayerQueueDescriptor'", measured.
//
// So it is restated under a name of its own. A CATEGORY DECLARATION MAY APPEAR IN MORE THAN ONE FILE -
// that is what a header is - and only the IMPLEMENTATION must be unique, which it is: it lives in
// MPMusicPlayerQueueDescriptor101.m alone. Two declarations of the same selector under different category
// names is the ordinary shape for a method a subclass in another object needs.

@interface MPMusicPlayerQueueDescriptor (CharonSubclassInit11)
- (instancetype)charonInitAbstractQueueDescriptor;
@end

@implementation MPMusicPlayerPlayParameters

@synthesize dictionary = _dictionary;

// The header's only initializer, quoted from MPMusicPlayerQueueDescriptor.h:
//
//   - (nullable instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary;
//
// IT IS TYPED NULLABLE, which is Apple's own statement that this can decline, and the decline is
// honoured: a nil argument produces nil rather than an object holding nothing, because the class's
// entire content IS the dictionary and an instance with a nil dictionary is not a play-parameters object
// at all. The header's own nullability is the only reason this file returns nil for anything.
//
// A dictionary argument is required to be a dictionary and is copied, because the property is `copy` and
// a caller that mutated its own dictionary afterwards must not change what these parameters say.
- (instancetype)initWithDictionary:(NSDictionary<NSString *,id> *)dictionary {
    if (!dictionary) {
        return nil;
    }
    self = [super init];
    if (self) {
        _dictionary = [dictionary copy];
    }
    return self;
}

- (NSDictionary<NSString *,id> *)dictionary { return _dictionary; }

@end

@implementation MPMusicPlayerPlayParametersQueueDescriptor
{
    // The per-entry playback windows, keyed by the entry's index in the queue - a play-parameters entry is
    // a dictionary and has no persistent ID, so its position is the identity the header's "queue" gives
    // it. An index key also cannot go stale the way an object key would when the queue is replaced.
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *_timeWindows;
}

@synthesize playParametersQueue = _playParametersQueue;
@synthesize startItemPlayParameters = _startItemPlayParameters;

// The header's initializer, quoted from MPMusicPlayerQueueDescriptor.h:
//
//   - (instancetype)initWithPlayParametersQueue:(NSArray<MPMusicPlayerPlayParameters *> *)playParametersQueue;
//
// The superclass is MPMusicPlayerQueueDescriptor, whose -init the header marks MP_INIT_UNAVAILABLE, so
// this cannot call [super init] - measured, "'init' is unavailable" - and calls the named initializer
// that file declares for exactly this purpose.
- (instancetype)initWithPlayParametersQueue:(NSArray<MPMusicPlayerPlayParameters *> *)playParametersQueue {
    self = [self charonInitAbstractQueueDescriptor];
    if (self) {
        _playParametersQueue = [playParametersQueue copy];
    }
    return self;
}

// The header declares this `@property (nonatomic, copy)`, readwrite, so the synthesised setter already
// copies. It is left to the synthesiser rather than written out, which is the one place in this band
// where that is right: a `copy` property's setter is exactly `[value copy]` and writing it by hand would
// be the same code with a chance of the two drifting apart.
- (NSArray<MPMusicPlayerPlayParameters *> *)playParametersQueue { return _playParametersQueue; }
- (MPMusicPlayerPlayParameters *)startItemPlayParameters { return _startItemPlayParameters; }

// The two time setters, quoted from the header:
//
//   - (void)setStartTime:(NSTimeInterval)startTime forItemWithPlayParameters:(MPMusicPlayerPlayParameters *)playParameters;
//   - (void)setEndTime:(NSTimeInterval)endTime forItemWithPlayParameters:(MPMusicPlayerPlayParameters *)playParameters;
//
// A play-parameters entry is a dictionary, so it has no identity of its own and the window is recorded
// against its INDEX in the queue - the identity the header's "queue" gives it. Looking the entry up by
// -indexOfObject: is the release-independent way to find it, and an entry that is not in the queue is
// declined rather than appended to the search: a window recorded against an entry the queue does not
// contain names nothing the queue can play.
- (void)setStartTime:(NSTimeInterval)startTime forItemWithPlayParameters:(MPMusicPlayerPlayParameters *)playParameters {
    [self charonRecordTime:startTime atKey:@"start" forEntry:playParameters];
}

- (void)setEndTime:(NSTimeInterval)endTime forItemWithPlayParameters:(MPMusicPlayerPlayParameters *)playParameters {
    [self charonRecordTime:endTime atKey:@"end" forEntry:playParameters];
}

- (void)charonRecordTime:(NSTimeInterval)time
                   atKey:(NSString *)which
                 forEntry:(MPMusicPlayerPlayParameters *)playParameters {
    if (!playParameters || !_playParametersQueue) {
        return;
    }
    NSUInteger at = [_playParametersQueue indexOfObject:playParameters];
    if (at == NSNotFound) {
        return;
    }
    NSNumber *key = @(at);
    NSMutableDictionary<NSString *, NSNumber *> *window = _timeWindows[key];
    if (!window) {
        window = [NSMutableDictionary dictionary];
        _timeWindows[key] = window;
    }
    window[which] = @(time);
}

@end
