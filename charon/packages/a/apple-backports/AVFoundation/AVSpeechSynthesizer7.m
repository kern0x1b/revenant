#import <AVFAudio/AVSpeechSynthesis.h>
#include <dlfcn.h>

// AVSpeechSynthesizer speaks through the release's own synthesizer, VSSpeechSynthesizer (VoiceServices), which the
// port loads by path and finds by name (facts/AVFoundation/AVSpeech.md, the synthesizer section, has every selector
// and the measurements). The release's synthesizer does not queue: a string started while another speaks replaces
// it silently. So the queue, the speaking and paused flags, and the order of the delegate calls are the port's, and
// VoiceServices is sent one string at a time. The order is the host's, measured (the same section).

// The VoiceServices selectors the port sends, declared by name; the class is never named in a message as a symbol.
@protocol CharonVoiceServicesSpeaking <NSObject>
- (id)startSpeakingString:(NSString *)string;
- (id)stopSpeakingAtNextBoundary:(int)boundary;
- (id)pauseSpeakingAtNextBoundary:(int)boundary;
- (void)continueSpeaking;
- (void)setDelegate:(id)delegate;
- (void)setVoice:(NSString *)name;
- (void)setRate:(float)rate;
- (void)setPitch:(float)pitch;
- (void)setVolume:(float)volume;
- (float)rate;
- (float)pitch;
- (float)minimumRate;
- (float)maximumRate;
@end

static NSString *const CharonVoiceServicesPath = @"/System/Library/PrivateFrameworks/VoiceServices.framework/VoiceServices";

// The VoiceServices boundary for an AVSpeechBoundary: the release's 0 stops or pauses at once and its 1 at the next word.
// Both are the asynchronous forms, which give the host's order (the host returns, then calls the delegate).
static int CharonVSBoundary(AVSpeechBoundary boundary)
{
    return boundary == AVSpeechBoundaryImmediate ? 0 : 1;
}

// The rate: the port's 0 maps to the release's minimum, the default 0.5 to the release's default and 1 to its maximum,
// linearly between them. Measured endpoints and default (facts); the middle is a rule. Above 1 it stays at the maximum.
static float CharonVSRate(float rate, float vsMinimum, float vsDefault, float vsMaximum)
{
    if (rate <= AVSpeechUtteranceMinimumSpeechRate) return vsMinimum;
    if (rate >= AVSpeechUtteranceMaximumSpeechRate) return vsMaximum;
    if (rate <= AVSpeechUtteranceDefaultSpeechRate) {
        return vsMinimum + (vsDefault - vsMinimum) * (rate - AVSpeechUtteranceMinimumSpeechRate) /
               (AVSpeechUtteranceDefaultSpeechRate - AVSpeechUtteranceMinimumSpeechRate);
    }
    return vsDefault + (vsMaximum - vsDefault) * (rate - AVSpeechUtteranceDefaultSpeechRate) /
           (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceDefaultSpeechRate);
}

// The engine: the queue, the flags, and the calls to VoiceServices. Its methods are the port's own (the class is a
// helper, not a class of the release), and it is the VoiceServices delegate, so the synthesizer class carries no
// selector the release lacks.
@interface CharonSpeechEngine : NSObject
- (instancetype)initWithSynthesizer:(AVSpeechSynthesizer *)synthesizer;
- (void)speakUtterance:(AVSpeechUtterance *)utterance;
- (BOOL)stopAtBoundary:(AVSpeechBoundary)boundary;
- (BOOL)pauseAtBoundary:(AVSpeechBoundary)boundary;
- (BOOL)continueSpeaking;
- (BOOL)isSpeaking;
- (BOOL)isPaused;
@end

@implementation CharonSpeechEngine {
    __weak AVSpeechSynthesizer *_synthesizer;
    id<CharonVoiceServicesSpeaking> _voiceServices;
    NSMutableArray *_queue;       // AVSpeechUtterance, the head is the one VoiceServices is speaking
    BOOL _inVoiceServices;        // a string is started and has not finished
    BOOL _speaking;               // from the head's didStart until the queue empties (or is cancelled)
    BOOL _paused;                 // from didPause until didContinue
    BOOL _pausing;                // a pause is sent and its didPause has not come
    BOOL _stopping;               // a stop is sent and its didFinish (the cancel) has not come
    float _defaultRate;
    float _defaultPitch;
}

- (instancetype)initWithSynthesizer:(AVSpeechSynthesizer *)synthesizer
{
    if ((self = [super init])) {
        _synthesizer = synthesizer;
        _queue = [NSMutableArray array];
        // The release's class is found by name once VoiceServices is loaded. Without it (no VoiceServices) the
        // synthesizer queues and never speaks; the device always has the framework.
        dlopen([CharonVoiceServicesPath UTF8String], RTLD_LAZY);
        Class cls = NSClassFromString(@"VSSpeechSynthesizer");
        if (cls) {
            _voiceServices = [[cls alloc] init];
            [_voiceServices setDelegate:self];
            _defaultRate = [_voiceServices rate];
            _defaultPitch = [_voiceServices pitch];
        }
    }
    return self;
}

#pragma mark - The synthesizer's calls

- (void)speakUtterance:(AVSpeechUtterance *)utterance
{
    [_queue addObject:utterance];
    if (!_inVoiceServices) [self startHead];
}

- (BOOL)stopAtBoundary:(AVSpeechBoundary)boundary
{
    if (!_speaking || _stopping) return NO;
    _stopping = YES;
    [_voiceServices stopSpeakingAtNextBoundary:CharonVSBoundary(boundary)];
    return YES;
}

- (BOOL)pauseAtBoundary:(AVSpeechBoundary)boundary
{
    if (!_speaking || _stopping) return NO;
    // A pause while paused (or while a pause is on its way) answers YES and does nothing, as the host does (measured).
    if (_paused || _pausing) return YES;
    _pausing = YES;
    [_voiceServices pauseSpeakingAtNextBoundary:CharonVSBoundary(boundary)];
    return YES;
}

- (BOOL)continueSpeaking
{
    if (!_paused) return NO;
    [_voiceServices continueSpeaking];
    return YES;
}

- (BOOL)isSpeaking
{
    return _speaking;
}

- (BOOL)isPaused
{
    return _paused;
}

// Sends the head to VoiceServices with its settings. The utterance's voice is the one VoiceServices names; an utterance
// without one takes the current language's, as the host does.
- (void)startHead
{
    AVSpeechUtterance *utterance = [_queue firstObject];
    if (!utterance || !_voiceServices) return;
    AVSpeechSynthesisVoice *voice = utterance.voice ?: [AVSpeechSynthesisVoice voiceWithLanguage:nil];
    if (voice.name) [_voiceServices setVoice:voice.name];
    [_voiceServices setRate:CharonVSRate(utterance.rate, [_voiceServices minimumRate], _defaultRate,
                                         [_voiceServices maximumRate])];
    // The pitch multiplier is 1 at the release's default pitch. Nothing measured here shows the pitch on the host or
    // the emulator (no audio), so this is the port's rule: the default times the multiplier.
    [_voiceServices setPitch:_defaultPitch * utterance.pitchMultiplier];
    // VoiceServices' volume is a fraction; the port passes the utterance's value up to 1 (the header's range).
    [_voiceServices setVolume:MIN(utterance.volume, 1.0f)];
    _inVoiceServices = YES;
    [_voiceServices startSpeakingString:utterance.speechString];
}

#pragma mark - The delegate calls

- (AVSpeechUtterance *)head
{
    return [_queue firstObject];
}

// The host's delegate, if it is set. The methods are optional, so each call checks for its own selector.
- (id<AVSpeechSynthesizerDelegate>)delegate
{
    return _synthesizer.delegate;
}

// The release's own callbacks, from the VoiceServices delegate. Each one is a state change, then the host's callback.
- (void)speechSynthesizerDidStartSpeaking:(id)voiceServices
{
    AVSpeechUtterance *utterance = [self head];
    if (!utterance) return;
    _speaking = YES;
    id<AVSpeechSynthesizerDelegate> delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(speechSynthesizer:didStartSpeechUtterance:)]) {
        [delegate speechSynthesizer:_synthesizer didStartSpeechUtterance:utterance];
    }
}

- (void)speechSynthesizerDidPauseSpeaking:(id)voiceServices
{
    _pausing = NO;
    _paused = YES;
    AVSpeechUtterance *utterance = [self head];
    id<AVSpeechSynthesizerDelegate> delegate = [self delegate];
    if (utterance && [delegate respondsToSelector:@selector(speechSynthesizer:didPauseSpeechUtterance:)]) {
        [delegate speechSynthesizer:_synthesizer didPauseSpeechUtterance:utterance];
    }
}

- (void)speechSynthesizerDidContinueSpeaking:(id)voiceServices
{
    _paused = NO;
    AVSpeechUtterance *utterance = [self head];
    id<AVSpeechSynthesizerDelegate> delegate = [self delegate];
    if (utterance && [delegate respondsToSelector:@selector(speechSynthesizer:didContinueSpeechUtterance:)]) {
        [delegate speechSynthesizer:_synthesizer didContinueSpeechUtterance:utterance];
    }
}

- (void)speechSynthesizer:(id)voiceServices willSpeakRangeOfSpeechString:(NSRange)range
{
    AVSpeechUtterance *utterance = [self head];
    id<AVSpeechSynthesizerDelegate> delegate = [self delegate];
    if (utterance && [delegate respondsToSelector:@selector(speechSynthesizer:willSpeakRangeOfSpeechString:utterance:)]) {
        [delegate speechSynthesizer:_synthesizer willSpeakRangeOfSpeechString:range utterance:utterance];
    }
}

// VoiceServices calls this one (the phonemes variant) with finished NO for a stop. A stop cancels the head and every
// queued utterance, in queue order, with the speaking flag already cleared, as the host does; otherwise the head
// finishes, and the next one starts with the speaking flag still set.
- (void)speechSynthesizer:(id)voiceServices didFinishSpeaking:(BOOL)finished phonemesSpoken:(id)phonemes withError:(id)error
{
    _inVoiceServices = NO;
    id<AVSpeechSynthesizerDelegate> delegate = [self delegate];
    if (_stopping) {
        _stopping = NO;
        _paused = NO;
        _pausing = NO;
        _speaking = NO;
        NSArray *cancelled = [_queue copy];
        [_queue removeAllObjects];
        for (AVSpeechUtterance *utterance in cancelled) {
            if ([delegate respondsToSelector:@selector(speechSynthesizer:didCancelSpeechUtterance:)]) {
                [delegate speechSynthesizer:_synthesizer didCancelSpeechUtterance:utterance];
            }
        }
        return;
    }
    AVSpeechUtterance *utterance = [self head];
    if (!utterance) return;
    [_queue removeObjectAtIndex:0];
    _paused = NO;
    _pausing = NO;
    if ([delegate respondsToSelector:@selector(speechSynthesizer:didFinishSpeechUtterance:)]) {
        [delegate speechSynthesizer:_synthesizer didFinishSpeechUtterance:utterance];
    }
    if ([_queue count]) {
        [self startHead];
    } else {
        _speaking = NO;
    }
}

@end

@implementation AVSpeechSynthesizer {
    CharonSpeechEngine *_engine;
}

// The two properties the header adds later (outputChannels, iOS 10; usesApplicationAudioSession, iOS 13) are the
// categories in AVSpeechSynthesizer10.m and AVSpeechSynthesizer13.m, one release per file.
@synthesize delegate = _delegate;

- (instancetype)init
{
    if ((self = [super init])) {
        _engine = [[CharonSpeechEngine alloc] initWithSynthesizer:self];
    }
    return self;
}

- (void)speakUtterance:(AVSpeechUtterance *)utterance
{
    [_engine speakUtterance:utterance];
}

- (BOOL)stopSpeakingAtBoundary:(AVSpeechBoundary)boundary
{
    return [_engine stopAtBoundary:boundary];
}

- (BOOL)pauseSpeakingAtBoundary:(AVSpeechBoundary)boundary
{
    return [_engine pauseAtBoundary:boundary];
}

- (BOOL)continueSpeaking
{
    return [_engine continueSpeaking];
}

- (BOOL)isSpeaking
{
    return [_engine isSpeaking];
}

- (BOOL)isPaused
{
    return [_engine isPaused];
}

@end
