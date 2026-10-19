#import <Foundation/Foundation.h>
#import <AVFAudio/AVFAudio.h>
#import <objc/message.h>

#pragma mark - The stub VoiceServices synthesizer

@protocol StubVoiceServicesDelegate <NSObject>
- (void)speechSynthesizerDidStartSpeaking:(id)synthesizer;
- (void)speechSynthesizerDidPauseSpeaking:(id)synthesizer;
- (void)speechSynthesizerDidContinueSpeaking:(id)synthesizer;
- (void)speechSynthesizer:(id)synthesizer willSpeakRangeOfSpeechString:(NSRange)range;
- (void)speechSynthesizer:(id)synthesizer didFinishSpeaking:(BOOL)finished phonemesSpoken:(id)phonemes withError:(id)error;
@end

@interface VSSpeechSynthesizer : NSObject
@end

@implementation VSSpeechSynthesizer {
    __weak id _delegate;
    NSString *_text;
    NSMutableArray *_wordRanges;
    NSUInteger _nextWord;
    double _elapsed;
    BOOL _running, _paused, _startPending, _continuePending;
    int _pendingStop, _pendingPause;
    double _requestedAt;
    NSTimer *_timer;
    float _rate, _pitch, _volume;
    NSString *_voice;
}

+ (NSArray *)availableLanguageCodes { return @[ @"en-US" ]; }
+ (NSArray *)availableVoicesForLanguageCode:(NSString *)code { return @[ @"Samantha" ]; }

- (instancetype)init
{
    if ((self = [super init])) {
        _rate = 1.0f; _pitch = 0.5f; _volume = 0.8f;
        _pendingStop = -1; _pendingPause = -1;
    }
    return self;
}

- (void)setDelegate:(id)delegate { _delegate = delegate; }
- (void)setVoice:(NSString *)name { _voice = [name copy]; }
- (void)setRate:(float)rate { _rate = rate; }
- (void)setPitch:(float)pitch { _pitch = pitch; }
- (void)setVolume:(float)volume { _volume = volume; }
- (float)rate { return _rate; }
- (float)pitch { return _pitch; }
- (float)volume { return _volume; }
- (float)minimumRate { return 0.5f; }
- (float)maximumRate { return 4.0f; }
- (BOOL)isSpeaking { return _running && !_paused; }

- (id)startSpeakingString:(NSString *)string
{
    [_timer invalidate];
    _text = [string copy];
    _wordRanges = [NSMutableArray array];
    [_text enumerateSubstringsInRange:NSMakeRange(0, _text.length) options:NSStringEnumerationByWords
                           usingBlock:^(NSString *w, NSRange r, NSRange e, BOOL *stop) { [_wordRanges addObject:[NSValue valueWithRange:r]]; }];
    _nextWord = 0; _elapsed = 0; _running = YES; _paused = NO; _startPending = YES; _continuePending = NO;
    _pendingStop = -1; _pendingPause = -1;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    return nil;
}

- (id)stopSpeakingAtNextBoundary:(int)boundary
{
    if (!_running) return [NSError errorWithDomain:@"VSErrorDomain" code:-4003 userInfo:nil];
    if (_pendingStop < 0) { _pendingStop = boundary; _requestedAt = _elapsed; }
    return nil;
}

- (id)pauseSpeakingAtNextBoundary:(int)boundary
{
    if (!_running || _paused || _pendingPause >= 0) return [NSError errorWithDomain:@"VSErrorDomain" code:-4003 userInfo:nil];
    _pendingPause = boundary; _requestedAt = _elapsed;
    return nil;
}

- (void)continueSpeaking
{
    if (_paused) _continuePending = YES;
}

- (void)finish:(BOOL)finished
{
    [_timer invalidate];
    _timer = nil;
    _running = NO; _paused = NO; _pendingStop = -1; _pendingPause = -1;
    [(id<StubVoiceServicesDelegate>)_delegate speechSynthesizer:self didFinishSpeaking:finished phonemesSpoken:nil withError:nil];
}

- (void)tick
{
    _elapsed += 0.02;
    if (_startPending && _elapsed >= 0.05) {
        _startPending = NO;
        [(id<StubVoiceServicesDelegate>)_delegate speechSynthesizerDidStartSpeaking:self];
    }
    if (_continuePending) {
        _continuePending = NO; _paused = NO;
        [(id<StubVoiceServicesDelegate>)_delegate speechSynthesizerDidContinueSpeaking:self];
    }
    if (!_running || _startPending) return;
    if (_pendingStop == 0 && _elapsed - _requestedAt >= 0.1) { [self finish:NO]; return; }
    if (_pendingPause == 0 && _elapsed - _requestedAt >= 0.1) {
        _pendingPause = -1; _paused = YES;
        [(id<StubVoiceServicesDelegate>)_delegate speechSynthesizerDidPauseSpeaking:self];
        return;
    }
    if (_paused) return;
    if (_nextWord < _wordRanges.count && _elapsed >= 0.2 * (_nextWord + 1)) {
        NSRange r = [_wordRanges[_nextWord] rangeValue];
        _nextWord++;
        [(id<StubVoiceServicesDelegate>)_delegate speechSynthesizer:self willSpeakRangeOfSpeechString:r];
        if (_pendingStop == 1) { [self finish:NO]; return; }
        if (_pendingPause == 1) {
            _pendingPause = -1; _paused = YES;
            [(id<StubVoiceServicesDelegate>)_delegate speechSynthesizerDidPauseSpeaking:self];
            return;
        }
    }
    if (_nextWord >= _wordRanges.count) [self finish:YES];
}

@end

#pragma mark - The driver

@protocol DriverSynthesizer <NSObject>
- (void)speakUtterance:(id)utterance;
- (BOOL)stopSpeakingAtBoundary:(AVSpeechBoundary)boundary;
- (BOOL)pauseSpeakingAtBoundary:(AVSpeechBoundary)boundary;
- (BOOL)continueSpeaking;
@end

static NSMutableString *gLog;
static id gSynth;

static void spin(NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([until timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

static void waitFor(BOOL (^cond)(void), NSTimeInterval limit)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:limit];
    while (!cond() && [until timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

static NSString *flags(void)
{
    return [NSString stringWithFormat:@" speaking=%d paused=%d", [[gSynth valueForKey:@"speaking"] boolValue],
            [[gSynth valueForKey:@"paused"] boolValue]];
}

@interface DriverDelegate : NSObject
@end

@implementation DriverDelegate
- (void)speechSynthesizer:(id)s didStartSpeechUtterance:(id)u { [gLog appendFormat:@"didStart %@%@\n", [u speechString], flags()]; }
- (void)speechSynthesizer:(id)s didPauseSpeechUtterance:(id)u { [gLog appendFormat:@"didPause %@%@\n", [u speechString], flags()]; }
- (void)speechSynthesizer:(id)s didContinueSpeechUtterance:(id)u { [gLog appendFormat:@"didContinue %@%@\n", [u speechString], flags()]; }
- (void)speechSynthesizer:(id)s didFinishSpeechUtterance:(id)u { [gLog appendFormat:@"didFinish %@ paused=%d\n", [u speechString], [[gSynth valueForKey:@"paused"] boolValue]]; }
- (void)speechSynthesizer:(id)s didCancelSpeechUtterance:(id)u { [gLog appendFormat:@"didCancel %@%@\n", [u speechString], flags()]; }
- (void)speechSynthesizer:(id)s willSpeakRangeOfSpeechString:(NSRange)r utterance:(id)u { }
@end

static NSString *const kLong = @"one two three four five six seven eight nine ten eleven twelve.";

static id laterChannels(void)
{
    id session = [NSClassFromString(@"AVAudioSession") performSelector:NSSelectorFromString(@"sharedInstance")];
    id route = [session performSelector:NSSelectorFromString(@"currentRoute")];
    NSMutableArray *channels = [NSMutableArray array];
    for (id port in [route performSelector:NSSelectorFromString(@"outputs")])
        [channels addObjectsFromArray:[port performSelector:NSSelectorFromString(@"channels")]];
    return channels;
}

static id channelsOf(id synth)
{
    return ((id (*)(id, SEL))objc_msgSend)(synth, NSSelectorFromString(@"outputChannels"));
}

static void setChannelsOf(id synth, id channels)
{
    ((void (*)(id, SEL, id))objc_msgSend)(synth, NSSelectorFromString(@"setOutputChannels:"), channels);
}

static BOOL usesApplicationAudioSessionOf(id synth)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(synth, NSSelectorFromString(@"usesApplicationAudioSession"));
}

static void setUsesApplicationAudioSessionOf(id synth, BOOL uses)
{
    ((void (*)(id, SEL, BOOL))objc_msgSend)(synth, NSSelectorFromString(@"setUsesApplicationAudioSession:"), uses);
}

static NSString *describeChannels(id answer, id set)
{
    if (!answer) return @"nil";
    if (answer == set) return @"the array that was set";
    return [NSString stringWithFormat:@"an array of %lu", (unsigned long)[answer count]];
}

static NSArray *transcripts(Class synthClass, Class utteranceClass, NSArray **names)
{
    NSMutableArray *out = [NSMutableArray array];
    NSMutableArray *scenarioNames = [NSMutableArray array];
    DriverDelegate *delegate = [DriverDelegate new];
    void (^begin)(NSString *) = ^(NSString *name) {
        [scenarioNames addObject:name];
        gLog = [NSMutableString string];
        [gSynth setValue:nil forKey:@"delegate"];
        gSynth = [[synthClass alloc] init];
        [gSynth setValue:delegate forKey:@"delegate"];
    };
    void (^end)(void) = ^{ [out addObject:[gLog copy]]; };
    id (^utt)(NSString *) = ^id(NSString *s) { return [utteranceClass speechUtteranceWithString:s]; };
    #define SYNTH ((id<DriverSynthesizer>)gSynth)

    begin(@"short");
    [SYNTH speakUtterance:utt(@"Hi there.")];
    waitFor(^BOOL{ return [gLog containsString:@"didFinish"]; }, 60);
    spin(0.3);
    end();

    begin(@"stop immediate");
    [SYNTH speakUtterance:utt(kLong)];
    waitFor(^BOOL{ return [gLog containsString:@"didStart"]; }, 30);
    spin(0.5);
    [gLog appendFormat:@"stop -> %d\n", [SYNTH stopSpeakingAtBoundary:AVSpeechBoundaryImmediate]];
    waitFor(^BOOL{ return [gLog containsString:@"didCancel"]; }, 30);
    spin(0.3);
    end();

    begin(@"stop word");
    [SYNTH speakUtterance:utt(kLong)];
    waitFor(^BOOL{ return [gLog containsString:@"didStart"]; }, 30);
    spin(0.5);
    [gLog appendFormat:@"stop -> %d\n", [SYNTH stopSpeakingAtBoundary:AVSpeechBoundaryWord]];
    waitFor(^BOOL{ return [gLog containsString:@"didCancel"]; }, 30);
    spin(0.3);
    end();

    begin(@"pause and continue immediate");
    [SYNTH speakUtterance:utt(kLong)];
    waitFor(^BOOL{ return [gLog containsString:@"didStart"]; }, 30);
    spin(0.5);
    [gLog appendFormat:@"pause -> %d\n", [SYNTH pauseSpeakingAtBoundary:AVSpeechBoundaryImmediate]];
    waitFor(^BOOL{ return [gLog containsString:@"didPause"]; }, 30);
    [gLog appendFormat:@"pause again -> %d\n", [SYNTH pauseSpeakingAtBoundary:AVSpeechBoundaryImmediate]];
    spin(1.0);
    [gLog appendFormat:@"continue -> %d\n", [SYNTH continueSpeaking]];
    waitFor(^BOOL{ return [gLog containsString:@"didFinish"]; }, 60);
    [gLog appendFormat:@"continue when idle -> %d\n", [SYNTH continueSpeaking]];
    end();

    begin(@"pause word then stop while paused");
    [SYNTH speakUtterance:utt(kLong)];
    waitFor(^BOOL{ return [gLog containsString:@"didStart"]; }, 30);
    spin(0.5);
    [gLog appendFormat:@"pause -> %d\n", [SYNTH pauseSpeakingAtBoundary:AVSpeechBoundaryWord]];
    waitFor(^BOOL{ return [gLog containsString:@"didPause"]; }, 30);
    [gLog appendFormat:@"stop -> %d\n", [SYNTH stopSpeakingAtBoundary:AVSpeechBoundaryImmediate]];
    waitFor(^BOOL{ return [gLog containsString:@"didCancel"]; }, 30);
    spin(0.3);
    end();

    begin(@"queue");
    [SYNTH speakUtterance:utt(kLong)];
    [SYNTH speakUtterance:utt(@"Second short.")];
    waitFor(^BOOL{ return [gLog containsString:@"didFinish Second"]; }, 120);
    spin(0.3);
    end();

    begin(@"stop with a queued second");
    [SYNTH speakUtterance:utt(kLong)];
    [SYNTH speakUtterance:utt(@"Second short.")];
    waitFor(^BOOL{ return [gLog containsString:@"didStart"]; }, 30);
    spin(0.5);
    [gLog appendFormat:@"stop -> %d\n", [SYNTH stopSpeakingAtBoundary:AVSpeechBoundaryImmediate]];
    waitFor(^BOOL{ return [gLog containsString:@"didCancel Second"]; }, 30);
    spin(2.0);
    end();

    begin(@"same object twice");
    id same = utt(@"Same object.");
    [SYNTH speakUtterance:same];
    [SYNTH speakUtterance:same];
    waitFor(^BOOL{ return [[gLog componentsSeparatedByString:@"didFinish"] count] > 2; }, 60);
    spin(0.3);
    end();

    begin(@"idle");
    [gLog appendFormat:@"stop -> %d pause -> %d continue -> %d\n", [SYNTH stopSpeakingAtBoundary:AVSpeechBoundaryImmediate],
     [SYNTH pauseSpeakingAtBoundary:AVSpeechBoundaryImmediate], [SYNTH continueSpeaking]];
    end();

    begin(@"later properties");
    id routeChannels = laterChannels();
    [gLog appendFormat:@"outputChannels fresh: %@\n", describeChannels(channelsOf(gSynth), nil)];
    setChannelsOf(gSynth, @[]);
    [gLog appendFormat:@"set empty, get: %@\n", describeChannels(channelsOf(gSynth), @[])];
    setChannelsOf(gSynth, nil);
    [gLog appendFormat:@"set nil, get: %@\n", describeChannels(channelsOf(gSynth), nil)];
    setChannelsOf(gSynth, routeChannels);
    [gLog appendFormat:@"set route channels (%lu), get: %@\n", (unsigned long)[routeChannels count],
     describeChannels(channelsOf(gSynth), routeChannels)];
    [gLog appendFormat:@"usesApplicationAudioSession fresh: %d\n", usesApplicationAudioSessionOf(gSynth)];
    setUsesApplicationAudioSessionOf(gSynth, NO);
    [gLog appendFormat:@"set NO, get: %d\n", usesApplicationAudioSessionOf(gSynth)];
    setUsesApplicationAudioSessionOf(gSynth, YES);
    [gLog appendFormat:@"set YES, get: %d\n", usesApplicationAudioSessionOf(gSynth)];
    end();

    #undef SYNTH
    if (names) *names = scenarioNames;
    return out;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSArray *names = nil;
        NSArray *host = transcripts(NSClassFromString(@"AVSpeechSynthesizer"), NSClassFromString(@"AVSpeechUtterance"), &names);
        NSArray *port = transcripts(NSClassFromString(@"charon_host_AVSpeechSynthesizer"),
                                    NSClassFromString(@"charon_host_AVSpeechUtterance"), NULL);
        int checks = 0, failures = 0;
        for (NSUInteger i = 0; i < names.count; i++) {
            BOOL same = [host[i] length] > 0 && [host[i] isEqualToString:port[i]];
            checks++;
            if (!same) failures++;
            printf("%s %s\n", same ? "ok  " : "FAIL", [names[i] UTF8String]);
            if (!same) {
                printf("  host:\n%s  port:\n%s", [host[i] UTF8String], [port[i] UTF8String]);
            }
        }
        printf("checks=%d failures=%d\n", checks, failures);
        return failures ? 1 : 0;
    }
    return 0;
}
