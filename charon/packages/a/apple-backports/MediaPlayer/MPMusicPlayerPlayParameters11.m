#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface MPMusicPlayerQueueDescriptor (CharonSubclassInit11)
- (instancetype)charonInitAbstractQueueDescriptor;
@end

@implementation MPMusicPlayerPlayParameters

@synthesize dictionary = _dictionary;

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
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *_timeWindows;
}

@synthesize playParametersQueue = _playParametersQueue;
@synthesize startItemPlayParameters = _startItemPlayParameters;

- (instancetype)initWithPlayParametersQueue:(NSArray<MPMusicPlayerPlayParameters *> *)playParametersQueue {
    self = [self charonInitAbstractQueueDescriptor];
    if (self) {
        _playParametersQueue = [playParametersQueue copy];
    }
    return self;
}

- (NSArray<MPMusicPlayerPlayParameters *> *)playParametersQueue { return _playParametersQueue; }
- (MPMusicPlayerPlayParameters *)startItemPlayParameters { return _startItemPlayParameters; }

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
