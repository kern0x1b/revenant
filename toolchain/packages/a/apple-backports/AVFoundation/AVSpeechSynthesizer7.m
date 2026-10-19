#import <AVFAudio/AVSpeechSynthesis.h>
#include <dlfcn.h>

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

static int CharonVSBoundary(AVSpeechBoundary boundary)
{
    return boundary == AVSpeechBoundaryImmediate ? 0 : 1;
}

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
    NSMutableArray *_queue;
    BOOL _inVoiceServices;
    BOOL _speaking;
    BOOL _paused;
    BOOL _pausing;
    BOOL _stopping;
    float _defaultRate;
    float _defaultPitch;
}

- (instancetype)initWithSynthesizer:(AVSpeechSynthesizer *)synthesizer
{
    if ((self = [super init])) {
        _synthesizer = synthesizer;
        _queue = [NSMutableArray array];
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

- (void)startHead
{
    AVSpeechUtterance *utterance = [_queue firstObject];
    if (!utterance || !_voiceServices) return;
    AVSpeechSynthesisVoice *voice = utterance.voice ?: [AVSpeechSynthesisVoice voiceWithLanguage:nil];
    if (voice.name) [_voiceServices setVoice:voice.name];
    [_voiceServices setRate:CharonVSRate(utterance.rate, [_voiceServices minimumRate], _defaultRate,
                                         [_voiceServices maximumRate])];
    [_voiceServices setPitch:_defaultPitch * utterance.pitchMultiplier];
    [_voiceServices setVolume:MIN(utterance.volume, 1.0f)];
    _inVoiceServices = YES;
    [_voiceServices startSpeakingString:utterance.speechString];
}

#pragma mark - The delegate calls

- (AVSpeechUtterance *)head
{
    return [_queue firstObject];
}

- (id<AVSpeechSynthesizerDelegate>)delegate
{
    return _synthesizer.delegate;
}

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
