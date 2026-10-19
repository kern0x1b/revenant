#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>
#import <mach/mach_time.h>

@implementation PHASEEngine {
    double _charon_unitsPerSecond;
    double _charon_unitsPerMeter;
    PHASESpatializationMode _charon_outputSpatializationMode;
    PHASEReverbPreset _charon_defaultReverbPreset;
    PHASERenderingState _charon_renderingState;
    BOOL _charon_started;
    PHASEUpdateMode _charon_updateMode;
    PHASEMediumPreset _charon_defaultMediumPreset;
    PHASEObject *_charon_rootObject;
    dispatch_source_t _charon_renderTimer;
    AVAudioFramePosition _charon_renderedFrames;
    uint64_t _charon_renderHostTime;
}


- (instancetype)initWithUpdateMode:(PHASEUpdateMode)updateMode
{
    if ((self = [super init])) {
        _charon_unitsPerSecond = 1.0;
        _charon_unitsPerMeter = 1.0;
        _charon_defaultReverbPreset = PHASEReverbPresetNone;
        _charon_outputSpatializationMode = PHASESpatializationModeAutomatic;
        _charon_renderingState = PHASERenderingStateStopped;
        _charon_updateMode = updateMode;
        _charon_rootObject = [[PHASEObject alloc] initWithEngine:self];
    }
    return self;
}

- (PHASERenderingState)renderingState
{
    return _charon_renderingState;
}

- (BOOL)startAndReturnError:(NSError **)error
{
    @synchronized (self) {
        if (_charon_renderingState != PHASERenderingStateStarted) {
            _charon_renderedFrames = 0;
            _charon_renderHostTime = mach_absolute_time();
            [self charon_startRenderTimer];
        }
        _charon_started = YES;
        _charon_renderingState = PHASERenderingStateStarted;
    }
    if (error) {
        *error = nil;
    }
    return YES;
}

- (void)dealloc
{
    @synchronized (self) {
        [self charon_stopRenderTimer];
    }
}

static const double CharonEngineRenderRate = 48000.0;
static const AVAudioFramePosition CharonEngineRenderQuantum = 480;
static const int64_t CharonEngineRenderIntervalNanoseconds = 10 * NSEC_PER_MSEC;

- (void)charon_startRenderTimer
{
    if (_charon_renderTimer != NULL) {
        return;
    }
    dispatch_queue_t queue = dispatch_queue_create("charon.PHASEEngine.render", DISPATCH_QUEUE_SERIAL);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), CharonEngineRenderIntervalNanoseconds, NSEC_PER_MSEC);
    __weak PHASEEngine *weakEngine = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakEngine charon_renderQuantum];
    });
    dispatch_resume(timer);
    _charon_renderTimer = timer;
}

- (void)charon_stopRenderTimer
{
    if (_charon_renderTimer != NULL) {
        dispatch_source_cancel(_charon_renderTimer);
        _charon_renderTimer = NULL;
    }
}

- (void)charon_renderQuantum
{
    @synchronized (self) {
        if (_charon_renderTimer == NULL) {
            return;
        }
        _charon_renderedFrames += CharonEngineRenderQuantum;
        _charon_renderHostTime = mach_absolute_time();
    }
}

- (AVAudioTime *)lastRenderTime
{
    @synchronized (self) {
        if (_charon_renderingState != PHASERenderingStateStarted) {
            return nil;
        }
        return [[AVAudioTime alloc] initWithHostTime:_charon_renderHostTime
                                          sampleTime:_charon_renderedFrames
                                              atRate:CharonEngineRenderRate];
    }
}

- (void)update
{
    if (_charon_updateMode == PHASEUpdateModeAutomatic) {
        [NSException raise:@"API Misuse" format:@"Cannot call update while in automatic mode"];
    }
}

- (void)pause
{
    @synchronized (self) {
        if (_charon_started) {
            [self charon_stopRenderTimer];
            _charon_renderingState = PHASERenderingStatePaused;
        }
    }
}

- (void)stop
{
    @synchronized (self) {
        [self charon_stopRenderTimer];
        _charon_started = NO;
        _charon_renderingState = PHASERenderingStateStopped;
    }
}

- (PHASESpatializationMode)outputSpatializationMode
{
    return _charon_outputSpatializationMode;
}

- (void)setOutputSpatializationMode:(PHASESpatializationMode)outputSpatializationMode
{
    _charon_outputSpatializationMode = outputSpatializationMode;
}

- (double)unitsPerSecond
{
    return _charon_unitsPerSecond;
}

- (void)setUnitsPerSecond:(double)unitsPerSecond
{
    if (unitsPerSecond > 0) {
        _charon_unitsPerSecond = unitsPerSecond;
    }
}

- (double)unitsPerMeter
{
    return _charon_unitsPerMeter;
}

- (void)setUnitsPerMeter:(double)unitsPerMeter
{
    if (unitsPerMeter > 0) {
        _charon_unitsPerMeter = unitsPerMeter;
    }
}

- (PHASEReverbPreset)defaultReverbPreset
{
    return _charon_defaultReverbPreset;
}

- (void)setDefaultReverbPreset:(PHASEReverbPreset)defaultReverbPreset
{
    _charon_defaultReverbPreset = defaultReverbPreset;
}

- (id)defaultMedium
{
    return @(PHASEMediumPresetAir);
}

- (PHASEUpdateMode)updateMode
{
    return _charon_updateMode;
}

- (void)setDefaultMedium:(id)defaultMedium
{
    _charon_defaultMediumPreset = [defaultMedium respondsToSelector:@selector(integerValue)]
        ? (PHASEMediumPreset)[defaultMedium integerValue] : PHASEMediumPresetAir;
}

- (PHASEObject *)rootObject
{
    return _charon_rootObject;
}

- (id)assetRegistry
{
    return nil;
}

- (NSArray<PHASESoundEvent *> *)soundEvents
{
    return @[];
}

- (NSDictionary<NSString *, PHASEGroup *> *)groups
{
    return @{};
}

- (NSArray<PHASEDucker *> *)duckers
{
    return @[];
}

- (PHASEGroupPreset *)activeGroupPreset
{
    return nil;
}

@end
