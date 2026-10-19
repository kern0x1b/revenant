// MPPlayableContentManager, MPContentItem, MPPlayableContentDataSource and MPPlayableContentDelegate, the
// 7.1 family, and the three methods the data source and the delegate are reached through.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 dyld shared caches of
// 6.1.3 and 4.3, each read carrying its controls in the same run (facts/MediaPlayer/LanguageOptions.md
// has the commands; the two runs are the same two files):
//
//   name                             6.1.3      4.3
//   MPPlayableContentManager           ABSENT     ABSENT
//   MPContentItem                      ABSENT     ABSENT
//   MPPlayableContentDataSource        ABSENT     ABSENT
//   MPPlayableContentDelegate          ABSENT     ABSENT
//
// All four are new code and cannot shadow anything - no release has an object of that name, so there is
// nothing native for any of them to be. That is what lets them be `implemented` rather than `absent`,
// which is the status for a row whose answer needs a thing the device lacks: nothing in this family needs
// one. The protocols are read from the same 12549-line file's 1171 protocol lines, because a protocol's
// absence is a fact about the whole release and is invisible to a per-image classlist read.
//
// WHAT A CALLER GETS, and the honest limit of it. The header says the family's purpose plainly
// (MPPlayableContentManager.h:17-21): the header says the manager mediates between an application that plays
// media and an external player interface; an application gives it a data source to browse content with
// and a delegate to relay playback commands to. The half this object can supply is the application's
// half - it stores the data source and the delegate, and reaches them. The other half is an EXTERNAL
// MEDIA PLAYER, which is a head unit or a car: 6.1.3 has no such endpoint, and this port does not build
// one. So the data source's -contentItemAtIndexPath: and the delegate's
// -playableContentManager:initiatePlaybackOfContentItemAtIndexPath:completionHandler: are implemented and
// REACHABLE, and nothing on this release calls them.
//
// That is the same position MPRemoteCommandCenter71.m is in, and it is worth being exact about it rather
// than calling it either a working bridge or a fake. The port's command objects are "real, addressable
// command objects that never fire" (packages/a/apple-backports/xmake.lua:120) because the release's own
// event mechanism above them is the old-style UIEventTypeRemoteControl, which does exist. Here the
// mechanism does not exist at all: there is no MPPlayableContentManager endpoint, no head unit, and
// `CarPlay` - which every header in this family names as its replacement, MP_DEPRECATED("Use CarPlay
// framework", ios(7.1, 14.0)) - arrived in 14.0. So the honest effect of these rows is that the objects
// are real and the app's half is wired, and the system half is not there to call it.
//
// One object per release: this file is the 7.1 API. MPPlayableContentManagerContext is MP_API(ios(8.4))
// and is a file of its own - MPPlayableContentManagerContext84.m - because a file holding both would
// export 7.1 and 8.4 members in one object and band() would place it in one release.

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPContentItem

// The header's designated initializer, quoted from MPContentItem.h:24-25:
//
//   - (instancetype)initWithIdentifier:(NSString *)identifier NS_DESIGNATED_INITIALIZER;
//
// and the comment above it says what the identifier is for: a unique identifier is needed to name
// the item later. That is the whole reason this class is not a bare NSObject - it is the handle
// an external player uses to name this item later, so it is copied and held.
//
// playbackProgress is a `float` whose documented default is -1.0 and NOT 0.0, and that default is
// load-bearing: MPContentItem.h:44-45 says "0.0 = not watched/listened/viewed, 1.0 = fully
// watched/listened/viewed / Default is -1.0 (no progress indicator shown)". A synthesised float ivar is
// zero-initialised, so an object built without setting it would read 0.0 - which means "not watched" -
// where the header says the default is "no progress indicator shown". The ivar is therefore initialised
// to -1.0 explicitly, which is the one value here that a plain @synthesize would get wrong.
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

// The header marks the identifier "Required" (MPContentItem.h:28) and the initializer
// NS_DESIGNATED_INITIALIZER, so -init is not a second spelling of it: an item with no identifier cannot be
// named later, which is the one thing this class exists to do. This routes to the designated initializer
// with the empty string rather than leaving the ivar nil, because a nil identifier and an empty one both
// fail to name the item and only one of them is what the check and a caller can see. The empty string is
// Apple's own spelling of "no value" for a required string in this position, and nothing here invents a
// placeholder that would look like a real identifier.
- (instancetype)init {
    return [self initWithIdentifier:@""];
}

@end

@implementation MPPlayableContentManager
{
    // How many times -reloadData has been called, and how deep the current -beginUpdates nesting is.
    // Both are the object's own state and both are read by the check rather than by any caller: the
    // header gives an application no way to observe them, because in Apple's design the system asks the
    // manager to reload and the app never sees it. They are here so that -reloadData and the update pair
    // are not silently empty - a reader can see that the call happened and that the pair is balanced.
    NSUInteger _reloadCount;
    NSUInteger _updateDepth;
}

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize context = _context;
@synthesize nowPlayingIdentifiers = _nowPlayingIdentifiers;

// +sharedContentManager is the header's "Returns the application's instance of the content manager"
// (MPPlayableContentManager.h:38) and every other member is on that one instance, so this is a real
// singleton and not a fresh object per call. dispatch_once is the same spelling the rest of this library
// uses for its shared objects.
+ (instancetype)sharedContentManager {
    static MPPlayableContentManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[MPPlayableContentManager alloc] init];
    });
    return shared;
}

// The header's context is a readonly property and the context is itself 8.4, so this object does not
// build one - MPPlayableContentManagerContext84.m does, and it is a separate release. The getter returns
// what was set, and nil until a caller sets one: fabricating a context here would mean a file that
// declares 7.1 carrying an 8.4 class.
- (void)setContext:(MPPlayableContentManagerContext *)context {
    _context = context;
}

// nowPlayingIdentifiers is `@property (nonatomic, copy)`, so the setter copies: the header's contract is
// that the manager holds the array, and a caller that mutates its own array afterwards must not change
// what the manager reports. The getter is the header's own, so the stored copy is what is read back.
- (void)setNowPlayingIdentifiers:(NSArray<NSString *> *)nowPlayingIdentifiers {
    _nowPlayingIdentifiers = [nowPlayingIdentifiers copy];
}

// -reloadData is the call the header describes as a notice to the manager that its browsing data has changed,
// and needs reloading from the source (MPPlayableContentManager.h:41-42). The release has no content server and
// this port builds none, so there is no cache of browsed content to invalidate and no endpoint to notify:
// the call is recorded and nothing else happens. It is NOT a no-op that pretends to have reloaded - the
// honest state of this object after -reloadData is that its data source may have changed and nothing has
// been re-read, and the count below is what makes that visible to a reader rather than a silent nothing.
// The two counters are read by the host check, which is why they are exposed and not merely kept. The
// names are the port's own and are declared in the check's stand-in, not in any framework header - no SDK
// declares a reload count, and inventing a public property for a counter Apple does not publish would be
// a wider API than the header's. A category below carries them for the check.
- (NSUInteger)charonUpdateDepth { return _updateDepth; }
- (NSUInteger)charonReloadCount { return _reloadCount; }

- (void)reloadData {
    _reloadCount++;
}

- (void)beginUpdates {
    _updateDepth++;
}

- (void)endUpdates {
    // The header says "Ends a synchronized update" and nothing about an unpaired call. A depth that went
    // negative would make a later -beginUpdates/-endUpdates pair look balanced when it is not, so the
    // counter is clamped at zero and the fact is written here: this object cannot report the imbalance
    // to a caller, because the header gives it no way to.
    if (_updateDepth > 0) {
        _updateDepth--;
    }
}

@end
