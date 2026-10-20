#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPContentItem

@synthesize identifier = _identifier;
@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize artwork = _artwork;
@synthesize playbackProgress = _playbackProgress;
@synthesize streamingContent = _streamingContent;
@synthesize explicitContent = _explicitContent;
@synthesize container = _container;
@synthesize playable = _playable;

- (instancetype)initWithIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _playbackProgress = -1.0f;
    }
    return self;
}

- (instancetype)init {
    return [self initWithIdentifier:@""];
}

@end

@implementation MPPlayableContentManager
{
    NSUInteger _reloadCount;
    NSUInteger _updateDepth;
}

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize context = _context;
@synthesize nowPlayingIdentifiers = _nowPlayingIdentifiers;

+ (instancetype)sharedContentManager {
    static MPPlayableContentManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[MPPlayableContentManager alloc] init];
    });
    return shared;
}

- (void)setContext:(MPPlayableContentManagerContext *)context {
    _context = context;
}

- (void)setNowPlayingIdentifiers:(NSArray<NSString *> *)nowPlayingIdentifiers {
    _nowPlayingIdentifiers = [nowPlayingIdentifiers copy];
}

- (NSUInteger)revenantUpdateDepth { return _updateDepth; }
- (NSUInteger)revenantReloadCount { return _reloadCount; }

- (void)reloadData {
    _reloadCount++;
}

- (void)beginUpdates {
    _updateDepth++;
}

- (void)endUpdates {
    if (_updateDepth > 0) {
        _updateDepth--;
    }
}

@end
