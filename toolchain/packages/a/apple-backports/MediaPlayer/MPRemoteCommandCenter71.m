#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>
#endif
#import <objc/runtime.h>
#import <objc/message.h>

typedef MPRemoteCommandHandlerStatus (^MPRemoteCommandHandler)(MPRemoteCommandEvent *event);

@interface MPRemoteCommandEvent ()
@property (nonatomic, strong, readwrite) MPRemoteCommand *command;
@end

@implementation MPRemoteCommandEvent
@synthesize command = _command;

- (instancetype)initWithCommand:(MPRemoteCommand *)command
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self)
        _command = command;
    return self;
}
@end

@interface MPSeekCommandEvent ()
@property (nonatomic, readwrite) MPSeekCommandEventType type;
@end

@implementation MPSeekCommandEvent
@synthesize type = _type;
@end

@interface CharonRemoteCommandTarget : NSObject
@property (nonatomic, copy) MPRemoteCommandHandler handler;
@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;
@end

@implementation CharonRemoteCommandTarget
@synthesize handler = _handler;
@synthesize target = _target;
@synthesize action = _action;
@end

@interface MPRemoteCommand ()
@property (nonatomic, strong) NSMutableArray<CharonRemoteCommandTarget *> *charonTargets;
@end

@implementation MPRemoteCommand

@synthesize enabled = _enabled;
@synthesize charonTargets = _charonTargets;

- (instancetype)initCharon
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _enabled = YES;
        _charonTargets = [NSMutableArray array];
    }
    return self;
}

- (void)addTarget:(id)target action:(SEL)action
{
    CharonRemoteCommandTarget *entry = [[CharonRemoteCommandTarget alloc] init];
    entry.target = target;
    entry.action = action;
    @synchronized (self.charonTargets) {
        [self.charonTargets addObject:entry];
    }
}

- (void)removeTarget:(id)target action:(SEL)action
{
    @synchronized (self.charonTargets) {
        NSMutableArray *doomed = [NSMutableArray array];
        for (CharonRemoteCommandTarget *entry in self.charonTargets) {
            if (entry.target == target && (!action || entry.action == action))
                [doomed addObject:entry];
        }
        [self.charonTargets removeObjectsInArray:doomed];
    }
}

- (void)removeTarget:(id)target
{
    [self removeTarget:target action:NULL];
}

- (id)addTargetWithHandler:(MPRemoteCommandHandler)handler
{
    CharonRemoteCommandTarget *entry = [[CharonRemoteCommandTarget alloc] init];
    entry.handler = [handler copy];
    @synchronized (self.charonTargets) {
        [self.charonTargets addObject:entry];
    }
    return entry;
}

- (void)charon_dispatch:(MPRemoteCommandEvent *)event
{
    if (!self.isEnabled)
        return;
    NSArray<CharonRemoteCommandTarget *> *targets;
    @synchronized (self.charonTargets) {
        targets = [self.charonTargets copy];
    }
    for (CharonRemoteCommandTarget *entry in targets) {
        if (entry.handler) {
            entry.handler(event);
        } else if (entry.target) {
            ((void (*)(id, SEL, id))objc_msgSend)(entry.target, entry.action, event);
        }
    }
}

@end

@implementation MPSkipIntervalCommand
@synthesize preferredIntervals = _preferredIntervals;
@end

@implementation MPFeedbackCommand
@synthesize active = _active;
@synthesize localizedTitle = _localizedTitle;
@synthesize localizedShortTitle = _localizedShortTitle;
@end

@implementation MPRatingCommand
@synthesize minimumRating = _minimumRating;
@synthesize maximumRating = _maximumRating;
@end

@implementation MPChangePlaybackRateCommand
@synthesize supportedPlaybackRates = _supportedPlaybackRates;
@end

static id charon_command(Class cls, id __strong *storage)
{
    if (!*storage)
        *storage = ((id (*)(id, SEL))objc_msgSend)((id)[cls alloc], sel_registerName("initCharon"));
    return *storage;
}

@interface MPRemoteCommandCenter ()
{
    id _pauseCommand, _playCommand, _stopCommand, _togglePlayPauseCommand;
    id _enableLanguageOptionCommand, _disableLanguageOptionCommand;
    id _changePlaybackRateCommand, _changeRepeatModeCommand, _changeShuffleModeCommand;
    id _nextTrackCommand, _previousTrackCommand;
    id _skipForwardCommand, _skipBackwardCommand;
    id _seekForwardCommand, _seekBackwardCommand;
    id _changePlaybackPositionCommand;
    id _ratingCommand;
    id _likeCommand, _dislikeCommand, _bookmarkCommand;
}
@end

@implementation MPRemoteCommandCenter

+ (MPRemoteCommandCenter *)sharedCommandCenter
{
    static MPRemoteCommandCenter *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = ((id (*)(id, SEL))objc_msgSend)((id)[self alloc], sel_registerName("init"));
    });
    return shared;
}

- (MPRemoteCommand *)pauseCommand { return charon_command([MPRemoteCommand class], &_pauseCommand); }
- (MPRemoteCommand *)playCommand { return charon_command([MPRemoteCommand class], &_playCommand); }
- (MPRemoteCommand *)stopCommand { return charon_command([MPRemoteCommand class], &_stopCommand); }
- (MPRemoteCommand *)togglePlayPauseCommand { return charon_command([MPRemoteCommand class], &_togglePlayPauseCommand); }
- (MPRemoteCommand *)enableLanguageOptionCommand { return charon_command([MPRemoteCommand class], &_enableLanguageOptionCommand); }
- (MPRemoteCommand *)disableLanguageOptionCommand { return charon_command([MPRemoteCommand class], &_disableLanguageOptionCommand); }
- (MPChangePlaybackRateCommand *)changePlaybackRateCommand { return charon_command([MPChangePlaybackRateCommand class], &_changePlaybackRateCommand); }
- (MPChangeRepeatModeCommand *)changeRepeatModeCommand { return charon_command([MPChangeRepeatModeCommand class], &_changeRepeatModeCommand); }
- (MPChangeShuffleModeCommand *)changeShuffleModeCommand { return charon_command([MPChangeShuffleModeCommand class], &_changeShuffleModeCommand); }
- (MPRemoteCommand *)nextTrackCommand { return charon_command([MPRemoteCommand class], &_nextTrackCommand); }
- (MPRemoteCommand *)previousTrackCommand { return charon_command([MPRemoteCommand class], &_previousTrackCommand); }
- (MPSkipIntervalCommand *)skipForwardCommand { return charon_command([MPSkipIntervalCommand class], &_skipForwardCommand); }
- (MPSkipIntervalCommand *)skipBackwardCommand { return charon_command([MPSkipIntervalCommand class], &_skipBackwardCommand); }
- (MPRemoteCommand *)seekForwardCommand { return charon_command([MPRemoteCommand class], &_seekForwardCommand); }
- (MPRemoteCommand *)seekBackwardCommand { return charon_command([MPRemoteCommand class], &_seekBackwardCommand); }
- (MPChangePlaybackPositionCommand *)changePlaybackPositionCommand { return charon_command([MPChangePlaybackPositionCommand class], &_changePlaybackPositionCommand); }
- (MPRatingCommand *)ratingCommand { return charon_command([MPRatingCommand class], &_ratingCommand); }
- (MPFeedbackCommand *)likeCommand { return charon_command([MPFeedbackCommand class], &_likeCommand); }
- (MPFeedbackCommand *)dislikeCommand { return charon_command([MPFeedbackCommand class], &_dislikeCommand); }
- (MPFeedbackCommand *)bookmarkCommand { return charon_command([MPFeedbackCommand class], &_bookmarkCommand); }

@end

@implementation UIApplication (CharonRemoteCommandBridge)

+ (void)load
{
    Method original = class_getInstanceMethod(self, @selector(sendEvent:));
    Method replacement = class_getInstanceMethod(self, @selector(charon_sendEvent:));
    method_exchangeImplementations(original, replacement);
}

- (void)charon_sendEvent:(UIEvent *)event
{
    if (event.type == UIEventTypeRemoteControl) {
        MPRemoteCommandCenter *center = [MPRemoteCommandCenter sharedCommandCenter];
        MPRemoteCommand *command = nil;
        Class eventClass = [MPRemoteCommandEvent class];
        MPSeekCommandEventType seekType = MPSeekCommandEventTypeBeginSeeking;
        switch (event.subtype) {
            case UIEventSubtypeRemoteControlPlay: command = center.playCommand; break;
            case UIEventSubtypeRemoteControlPause: command = center.pauseCommand; break;
            case UIEventSubtypeRemoteControlStop: command = center.stopCommand; break;
            case UIEventSubtypeRemoteControlTogglePlayPause: command = center.togglePlayPauseCommand; break;
            case UIEventSubtypeRemoteControlNextTrack: command = center.nextTrackCommand; break;
            case UIEventSubtypeRemoteControlPreviousTrack: command = center.previousTrackCommand; break;
            case UIEventSubtypeRemoteControlBeginSeekingForward:
                command = center.seekForwardCommand;
                eventClass = [MPSeekCommandEvent class];
                seekType = MPSeekCommandEventTypeBeginSeeking;
                break;
            case UIEventSubtypeRemoteControlEndSeekingForward:
                command = center.seekForwardCommand;
                eventClass = [MPSeekCommandEvent class];
                seekType = MPSeekCommandEventTypeEndSeeking;
                break;
            case UIEventSubtypeRemoteControlBeginSeekingBackward:
                command = center.seekBackwardCommand;
                eventClass = [MPSeekCommandEvent class];
                seekType = MPSeekCommandEventTypeBeginSeeking;
                break;
            case UIEventSubtypeRemoteControlEndSeekingBackward:
                command = center.seekBackwardCommand;
                eventClass = [MPSeekCommandEvent class];
                seekType = MPSeekCommandEventTypeEndSeeking;
                break;
            default:
                break;
        }
        if (command) {
            MPRemoteCommandEvent *commandEvent = ((id (*)(id, SEL, id))objc_msgSend)((id)[eventClass alloc], sel_registerName("initWithCommand:"), command);
            if (eventClass == [MPSeekCommandEvent class])
                ((MPSeekCommandEvent *)commandEvent).type = seekType;
            [command charon_dispatch:commandEvent];
        }
    }
    [self charon_sendEvent:event];
}

@end
