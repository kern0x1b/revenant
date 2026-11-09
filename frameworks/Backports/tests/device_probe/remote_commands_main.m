#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <math.h>
#include <unistd.h>

static NSMutableString *REVENANT_LOG;
static NSUInteger REVENANT_FAILURES;
static NSString *const REVENANT_RESULT = @"/var/revenant/remote-commands-probe.txt";

static void revenant_line(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void revenant_line(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    [REVENANT_LOG appendFormat:@"%@\n", [[NSString alloc] initWithFormat:format arguments:arguments]];
    va_end(arguments);
    [REVENANT_LOG writeToFile:REVENANT_RESULT atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void revenant_check(BOOL ok, NSString *name)
{
    if (!ok)
        REVENANT_FAILURES++;
    revenant_line(@"%@ %@", ok ? @"PASS" : @"FAIL", name);
}

static void revenant_wait(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

@interface RevenantRemoteEvent : UIEvent
@property (nonatomic) UIEventType revenantType;
@property (nonatomic) UIEventSubtype revenantSubtype;
@end

@implementation RevenantRemoteEvent
- (UIEventType)type { return self.revenantType; }
- (UIEventSubtype)subtype { return self.revenantSubtype; }
@end

static RevenantRemoteEvent *revenant_event(UIEventType type, UIEventSubtype subtype)
{
    RevenantRemoteEvent *event = [[RevenantRemoteEvent alloc] init];
    event.revenantType = type;
    event.revenantSubtype = subtype;
    return event;
}

static void revenant_send(UIEventSubtype subtype)
{
    [[UIApplication sharedApplication] sendEvent:revenant_event(UIEventTypeRemoteControl, subtype)];
}

@interface RevenantRecorder : NSObject
@property (nonatomic, strong) NSMutableArray<MPRemoteCommandEvent *> *events;
- (void)receive:(MPRemoteCommandEvent *)event;
- (void)receiveAgain:(MPRemoteCommandEvent *)event;
@end

@implementation RevenantRecorder
- (instancetype)init
{
    self = [super init];
    if (self)
        _events = [NSMutableArray array];
    return self;
}
- (void)receive:(MPRemoteCommandEvent *)event { [self.events addObject:event]; }
- (void)receiveAgain:(MPRemoteCommandEvent *)event { [self.events addObject:event]; }
@end

@interface RevenantResponder : UIResponder
@property (nonatomic) NSUInteger remoteControlEvents;
@end

@implementation RevenantResponder
- (BOOL)canBecomeFirstResponder { return YES; }
- (void)remoteControlReceivedWithEvent:(UIEvent *)event { self.remoteControlEvents++; }
@end

@interface RevenantRemoteCommandsDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSMutableArray<MPRemoteCommandEvent *> *real;
@end

@implementation RevenantRemoteCommandsDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(revenantRun) withObject:nil afterDelay:0.5];
    return YES;
}

- (NSData *)revenantTone
{
    enum { rate = 8000, samples = 16000 };
    NSMutableData *wave = [NSMutableData data];
    uint32_t bytes = samples * 2;
    uint32_t chunk = 36 + bytes;
    uint32_t format = 16;
    uint16_t pcm = 1, channels = 1, align = 2, bits = 16;
    uint32_t sample_rate = rate, byte_rate = rate * 2;
    [wave appendBytes:"RIFF" length:4];
    [wave appendBytes:&chunk length:4];
    [wave appendBytes:"WAVEfmt " length:8];
    [wave appendBytes:&format length:4];
    [wave appendBytes:&pcm length:2];
    [wave appendBytes:&channels length:2];
    [wave appendBytes:&sample_rate length:4];
    [wave appendBytes:&byte_rate length:4];
    [wave appendBytes:&align length:2];
    [wave appendBytes:&bits length:2];
    [wave appendBytes:"data" length:4];
    [wave appendBytes:&bytes length:4];
    for (int index = 0; index < samples; index++) {
        int16_t sample = (int16_t)(2000.0 * sin(2.0 * M_PI * 440.0 * index / rate));
        [wave appendBytes:&sample length:2];
    }
    return wave;
}

- (void)revenantClasses
{
    NSArray<NSString *> *names = @[
        @"MPRemoteCommandCenter", @"MPRemoteCommand", @"MPSkipIntervalCommand", @"MPFeedbackCommand", @"MPRatingCommand",
        @"MPChangePlaybackRateCommand", @"MPChangePlaybackPositionCommand", @"MPChangeShuffleModeCommand",
        @"MPChangeRepeatModeCommand", @"MPRemoteCommandEvent", @"MPSkipIntervalCommandEvent", @"MPSeekCommandEvent",
        @"MPRatingCommandEvent", @"MPChangePlaybackRateCommandEvent", @"MPFeedbackCommandEvent",
        @"MPChangeLanguageOptionCommandEvent", @"MPChangePlaybackPositionCommandEvent", @"MPChangeShuffleModeCommandEvent",
        @"MPChangeRepeatModeCommandEvent"];
    for (NSString *name in names) {
        Class cls = NSClassFromString(name);
        revenant_check(cls != Nil, [NSString stringWithFormat:@"%@ exists", name]);
        revenant_line(@"INFO %@ image %s", name, cls ? class_getImageName(cls) : "none");
    }
}

- (void)revenantStorage:(MPRemoteCommandCenter *)center
{
    revenant_check(center != nil && center == [MPRemoteCommandCenter sharedCommandCenter], @"the command center is one shared object");
    revenant_check(center.playCommand == center.playCommand && center.ratingCommand == center.ratingCommand,
                   @"a command property answers the same object every time");
    revenant_check(center.playCommand != center.pauseCommand, @"each command is its own object");
    revenant_check(center.playCommand.isEnabled && center.seekForwardCommand.isEnabled, @"a command starts enabled");

    center.skipForwardCommand.preferredIntervals = @[@15];
    center.skipBackwardCommand.preferredIntervals = @[@30, @60];
    revenant_check([center.skipForwardCommand.preferredIntervals isEqual:@[@15]]
                   && [center.skipBackwardCommand.preferredIntervals isEqual:(@[@30, @60])],
                   @"skip intervals are stored per command");
    center.ratingCommand.minimumRating = 1;
    center.ratingCommand.maximumRating = 5;
    revenant_check(center.ratingCommand.minimumRating == 1 && center.ratingCommand.maximumRating == 5, @"rating bounds are stored");
    center.likeCommand.active = YES;
    center.likeCommand.localizedTitle = @"Like";
    center.likeCommand.localizedShortTitle = @"L";
    revenant_check(center.likeCommand.isActive && [center.likeCommand.localizedTitle isEqualToString:@"Like"]
                   && [center.likeCommand.localizedShortTitle isEqualToString:@"L"] && !center.dislikeCommand.isActive,
                   @"a feedback command stores its state apart from the others");
    center.changePlaybackRateCommand.supportedPlaybackRates = @[@0.5, @1, @2];
    revenant_check([center.changePlaybackRateCommand.supportedPlaybackRates count] == 3, @"supported playback rates are stored");
    center.changeRepeatModeCommand.currentRepeatType = MPRepeatTypeAll;
    center.changeShuffleModeCommand.currentShuffleType = MPShuffleTypeItems;
    revenant_check(center.changeRepeatModeCommand.currentRepeatType == MPRepeatTypeAll
                   && center.changeShuffleModeCommand.currentShuffleType == MPShuffleTypeItems,
                   @"the current repeat and shuffle types are stored");
    revenant_check([center.changePlaybackPositionCommand isKindOfClass:[MPChangePlaybackPositionCommand class]]
                   && [center.enableLanguageOptionCommand isKindOfClass:[MPRemoteCommand class]]
                   && [center.disableLanguageOptionCommand isKindOfClass:[MPRemoteCommand class]],
                   @"the playback position and language commands exist");
}

- (void)revenantDispatch:(MPRemoteCommandCenter *)center
{
    struct {
        UIEventSubtype subtype;
        __unsafe_unretained MPRemoteCommand *command;
        const char *name;
    } table[] = {
        {UIEventSubtypeRemoteControlPlay, center.playCommand, "play"},
        {UIEventSubtypeRemoteControlPause, center.pauseCommand, "pause"},
        {UIEventSubtypeRemoteControlStop, center.stopCommand, "stop"},
        {UIEventSubtypeRemoteControlTogglePlayPause, center.togglePlayPauseCommand, "toggle"},
        {UIEventSubtypeRemoteControlNextTrack, center.nextTrackCommand, "next"},
        {UIEventSubtypeRemoteControlPreviousTrack, center.previousTrackCommand, "previous"},
    };
    NSUInteger count = sizeof(table) / sizeof(table[0]);
    NSMutableArray<RevenantRecorder *> *recorders = [NSMutableArray array];
    for (NSUInteger index = 0; index < count; index++) {
        RevenantRecorder *recorder = [[RevenantRecorder alloc] init];
        [table[index].command addTarget:recorder action:@selector(receive:)];
        [recorders addObject:recorder];
    }
    for (NSUInteger index = 0; index < count; index++) {
        NSTimeInterval before = [[NSProcessInfo processInfo] systemUptime];
        revenant_send(table[index].subtype);
        NSTimeInterval after = [[NSProcessInfo processInfo] systemUptime];
        BOOL only = YES;
        for (NSUInteger other = 0; other < count; other++)
            only = only && recorders[other].events.count == (other <= index ? 1u : 0u);
        MPRemoteCommandEvent *event = recorders[index].events.lastObject;
        revenant_check(only && event.command == table[index].command && [event class] == [MPRemoteCommandEvent class],
                       [NSString stringWithFormat:@"the %s remote control event reaches the %s command and no other", table[index].name, table[index].name]);
        revenant_check(event.timestamp >= before && event.timestamp <= after,
                       [NSString stringWithFormat:@"the %s event carries the uptime at which it was made", table[index].name]);
    }
    for (NSUInteger index = 0; index < count; index++)
        [table[index].command removeTarget:recorders[index]];

    struct {
        UIEventSubtype subtype;
        __unsafe_unretained MPRemoteCommand *command;
        MPSeekCommandEventType type;
        const char *name;
    } seeks[] = {
        {UIEventSubtypeRemoteControlBeginSeekingForward, center.seekForwardCommand, MPSeekCommandEventTypeBeginSeeking, "begin seeking forward"},
        {UIEventSubtypeRemoteControlEndSeekingForward, center.seekForwardCommand, MPSeekCommandEventTypeEndSeeking, "end seeking forward"},
        {UIEventSubtypeRemoteControlBeginSeekingBackward, center.seekBackwardCommand, MPSeekCommandEventTypeBeginSeeking, "begin seeking backward"},
        {UIEventSubtypeRemoteControlEndSeekingBackward, center.seekBackwardCommand, MPSeekCommandEventTypeEndSeeking, "end seeking backward"},
    };
    RevenantRecorder *forward = [[RevenantRecorder alloc] init];
    RevenantRecorder *backward = [[RevenantRecorder alloc] init];
    [center.seekForwardCommand addTarget:forward action:@selector(receive:)];
    [center.seekBackwardCommand addTarget:backward action:@selector(receive:)];
    for (NSUInteger index = 0; index < 4; index++) {
        RevenantRecorder *expected = seeks[index].command == center.seekForwardCommand ? forward : backward;
        NSUInteger before = expected.events.count;
        revenant_send(seeks[index].subtype);
        MPSeekCommandEvent *event = (MPSeekCommandEvent *)expected.events.lastObject;
        revenant_check(expected.events.count == before + 1 && [event isKindOfClass:[MPSeekCommandEvent class]]
                       && event.type == seeks[index].type && event.command == seeks[index].command,
                       [NSString stringWithFormat:@"%s reaches its seek command as a seek event of the right type", seeks[index].name]);
    }
    revenant_check(forward.events.count == 2 && backward.events.count == 2, @"a seek event reaches one seek command only");
    [center.seekForwardCommand removeTarget:forward];
    [center.seekBackwardCommand removeTarget:backward];
}

- (void)revenantTargets:(MPRemoteCommandCenter *)center
{
    MPRemoteCommand *play = center.playCommand;
    RevenantRecorder *first = [[RevenantRecorder alloc] init];
    RevenantRecorder *second = [[RevenantRecorder alloc] init];
    [play addTarget:first action:@selector(receive:)];
    [play addTarget:second action:@selector(receive:)];
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(first.events.count == 1 && second.events.count == 1 && first.events[0] == second.events[0],
                   @"every target of a command receives the one event");

    [play removeTarget:first];
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(first.events.count == 1 && second.events.count == 2, @"a removed target stops receiving");

    [play addTarget:second action:@selector(receiveAgain:)];
    [play removeTarget:second action:@selector(receive:)];
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(second.events.count == 3, @"removeTarget:action: removes that pair only");
    [play removeTarget:second action:@selector(receiveAgain:)];
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(second.events.count == 3, @"removeTarget:action: removes the last pair");

    __block NSUInteger calls = 0;
    __block MPRemoteCommandEvent *seen = nil;
    id token = [play addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        calls++;
        seen = event;
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    revenant_check(token != nil, @"addTargetWithHandler: answers a token");
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(calls == 1 && seen.command == play, @"a handler is called with the event");
    [play removeTarget:token];
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(calls == 1, @"removeTarget: with the token removes a handler");

    RevenantRecorder *survivor = [[RevenantRecorder alloc] init];
    @autoreleasepool {
        RevenantRecorder *gone = [[RevenantRecorder alloc] init];
        [play addTarget:gone action:@selector(receive:)];
        [play addTarget:survivor action:@selector(receive:)];
    }
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(survivor.events.count == 1, @"a target that was released is skipped and the next one still receives");
    [play removeTarget:survivor];

    RevenantRecorder *disabled = [[RevenantRecorder alloc] init];
    [play addTarget:disabled action:@selector(receive:)];
    play.enabled = NO;
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(disabled.events.count == 0 && !play.isEnabled, @"a disabled command delivers nothing");
    play.enabled = YES;
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(disabled.events.count == 1, @"an enabled command delivers again");
    [play removeTarget:disabled];

    RevenantRecorder *others = [[RevenantRecorder alloc] init];
    for (MPRemoteCommand *command in @[center.pauseCommand, center.stopCommand, center.nextTrackCommand, center.seekForwardCommand,
                                       center.skipForwardCommand, center.changePlaybackPositionCommand, center.ratingCommand,
                                       center.likeCommand, center.changeRepeatModeCommand, center.changeShuffleModeCommand,
                                       center.changePlaybackRateCommand])
        [command addTarget:others action:@selector(receive:)];
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_check(others.events.count == 0, @"a play event reaches no other command");
    revenant_send(UIEventSubtypeNone);
    [[UIApplication sharedApplication] sendEvent:revenant_event(UIEventTypeMotion, UIEventSubtypeMotionShake)];
    revenant_check(others.events.count == 0, @"an event with no remote command and a shake reach no command");
    for (MPRemoteCommand *command in @[center.pauseCommand, center.stopCommand, center.nextTrackCommand, center.seekForwardCommand,
                                       center.skipForwardCommand, center.changePlaybackPositionCommand, center.ratingCommand,
                                       center.likeCommand, center.changeRepeatModeCommand, center.changeShuffleModeCommand,
                                       center.changePlaybackRateCommand])
        [command removeTarget:others];
}

- (void)revenantResponder:(MPRemoteCommandCenter *)center
{
    RevenantResponder *responder = [[RevenantResponder alloc] init];
    BOOL first = [responder becomeFirstResponder];
    RevenantRecorder *recorder = [[RevenantRecorder alloc] init];
    [center.playCommand addTarget:recorder action:@selector(receive:)];
    revenant_send(UIEventSubtypeRemoteControlPlay);
    revenant_line(@"INFO responder first %d remoteControlReceivedWithEvent %lu commands %lu", first,
                  (unsigned long)responder.remoteControlEvents, (unsigned long)recorder.events.count);
    revenant_check(recorder.events.count == 1, @"the command receives the event while a first responder exists");
    [center.playCommand removeTarget:recorder];
    [responder resignFirstResponder];
}

- (void)revenantReal:(MPRemoteCommandCenter *)center
{
    void *media = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    revenant_line(@"INFO MediaRemote %s", media ? "loads" : "does not load");
    BOOL (*send)(unsigned, id) = media ? (BOOL (*)(unsigned, id))dlsym(media, "MRMediaRemoteSendCommand") : NULL;
    void (*can_be)(BOOL) = media ? (void (*)(BOOL))dlsym(media, "MRMediaRemoteSetCanBeNowPlayingApplication") : NULL;
    revenant_line(@"INFO MRMediaRemoteSendCommand %s MRMediaRemoteSetCanBeNowPlayingApplication %s", send ? "present" : "absent", can_be ? "present" : "absent");
    if (!send)
        return;
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    [session setActive:YES error:&error];
    self.player = [[AVAudioPlayer alloc] initWithData:[self revenantTone] error:&error];
    self.player.numberOfLoops = -1;
    self.player.volume = 0.05;
    BOOL playing = [self.player play];
    if (can_be)
        can_be(YES);
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{MPMediaItemPropertyTitle: @"Revenant probe", MPNowPlayingInfoPropertyPlaybackRate: @1.0};
    revenant_line(@"INFO player playing %d error %@", playing, error);

    NSMutableArray<MPRemoteCommandEvent *> *real = [NSMutableArray array];
    self.real = real;
    id toggle = [center.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [real addObject:event];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    id next = [center.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [real addObject:event];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    revenant_wait(1.0);
    BOOL sent = send(2, nil);
    NSTimeInterval deadline = [[NSProcessInfo processInfo] systemUptime] + 5.0;
    while (real.count == 0 && [[NSProcessInfo processInfo] systemUptime] < deadline)
        revenant_wait(0.1);
    revenant_line(@"INFO MediaRemote toggle command sent %d, targets called %lu", sent, (unsigned long)real.count);
    revenant_check(real.count == 1 && real[0].command == center.togglePlayPauseCommand,
                   @"a MediaRemote toggle play and pause command reaches the toggle target");
    [real removeAllObjects];
    send(4, nil);
    deadline = [[NSProcessInfo processInfo] systemUptime] + 5.0;
    while (real.count == 0 && [[NSProcessInfo processInfo] systemUptime] < deadline)
        revenant_wait(0.1);
    revenant_check(real.count == 1 && real[0].command == center.nextTrackCommand,
                   @"a MediaRemote next track command reaches the next track target");
    [center.togglePlayPauseCommand removeTarget:toggle];
    [center.nextTrackCommand removeTarget:next];
    [self.player stop];
    [session setActive:NO error:NULL];
}

- (void)revenantRun
{
    REVENANT_LOG = [NSMutableString string];
    revenant_line(@"INFO uid %d system %@", getuid(), [[UIDevice currentDevice] systemVersion]);
    [self revenantClasses];
    MPRemoteCommandCenter *center = [MPRemoteCommandCenter sharedCommandCenter];
    [self revenantStorage:center];
    [self revenantDispatch:center];
    [self revenantTargets:center];
    [self revenantResponder:center];
    [self revenantReal:center];
    revenant_line(@"DONE failures %lu", (unsigned long)REVENANT_FAILURES);
    exit(REVENANT_FAILURES ? 1 : 0);
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantRemoteCommandsDelegate class]));
    }
}
