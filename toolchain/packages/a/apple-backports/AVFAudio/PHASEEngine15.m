#import "RevenantAVFAudio.h"
#import <PHASE/PHASE.h>
#import <mach/mach_time.h>

@implementation PHASEEngine {
    double _revenant_unitsPerSecond;
    double _revenant_unitsPerMeter;
    PHASESpatializationMode _revenant_outputSpatializationMode;
    PHASEReverbPreset _revenant_defaultReverbPreset;
    PHASERenderingState _revenant_renderingState;
    BOOL _revenant_started;
    PHASEUpdateMode _revenant_updateMode;
    PHASEMediumPreset _revenant_defaultMediumPreset;
    PHASEObject *_revenant_rootObject;
    dispatch_source_t _revenant_renderTimer;
    AVAudioFramePosition _revenant_renderedFrames;
    uint64_t _revenant_renderHostTime;
}


- (instancetype)initWithUpdateMode:(PHASEUpdateMode)updateMode
{
    if ((self = [super init])) {
        _revenant_unitsPerSecond = 1.0;
        _revenant_unitsPerMeter = 1.0;
        _revenant_defaultReverbPreset = PHASEReverbPresetNone;
        _revenant_outputSpatializationMode = PHASESpatializationModeAutomatic;
        _revenant_renderingState = PHASERenderingStateStopped;
        _revenant_updateMode = updateMode;
        _revenant_rootObject = [[PHASEObject alloc] initWithEngine:self];
    }
    return self;
}

- (PHASERenderingState)renderingState
{
    return _revenant_renderingState;
}

- (BOOL)startAndReturnError:(NSError **)error
{
    @synchronized (self) {
        if (_revenant_renderingState != PHASERenderingStateStarted) {
            _revenant_renderedFrames = 0;
            _revenant_renderHostTime = mach_absolute_time();
            [self revenant_startRenderTimer];
        }
        _revenant_started = YES;
        _revenant_renderingState = PHASERenderingStateStarted;
    }
    if (error) {
        *error = nil;
    }
    return YES;
}

- (void)dealloc
{
    @synchronized (self) {
        [self revenant_stopRenderTimer];
    }
}

static const double RevenantEngineRenderRate = 48000.0;
static const AVAudioFramePosition RevenantEngineRenderQuantum = 480;
static const int64_t RevenantEngineRenderIntervalNanoseconds = 10 * NSEC_PER_MSEC;

- (void)revenant_startRenderTimer
{
    if (_revenant_renderTimer != NULL) {
        return;
    }
    dispatch_queue_t queue = dispatch_queue_create("revenant.PHASEEngine.render", DISPATCH_QUEUE_SERIAL);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), RevenantEngineRenderIntervalNanoseconds, NSEC_PER_MSEC);
    __weak PHASEEngine *weakEngine = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakEngine revenant_renderQuantum];
    });
    dispatch_resume(timer);
    _revenant_renderTimer = timer;
}

- (void)revenant_stopRenderTimer
{
    if (_revenant_renderTimer != NULL) {
        dispatch_source_cancel(_revenant_renderTimer);
        _revenant_renderTimer = NULL;
    }
}

- (void)revenant_renderQuantum
{
    @synchronized (self) {
        if (_revenant_renderTimer == NULL) {
            return;
        }
        _revenant_renderedFrames += RevenantEngineRenderQuantum;
        _revenant_renderHostTime = mach_absolute_time();
    }
}

- (AVAudioTime *)lastRenderTime
{
    @synchronized (self) {
        if (_revenant_renderingState != PHASERenderingStateStarted) {
            return nil;
        }
        return [[AVAudioTime alloc] initWithHostTime:_revenant_renderHostTime
                                          sampleTime:_revenant_renderedFrames
                                              atRate:RevenantEngineRenderRate];
    }
}

- (void)update
{
    if (_revenant_updateMode == PHASEUpdateModeAutomatic) {
        [NSException raise:@"API Misuse" format:@"Cannot call update while in automatic mode"];
    }
}

- (void)pause
{
    @synchronized (self) {
        if (_revenant_started) {
            [self revenant_stopRenderTimer];
            _revenant_renderingState = PHASERenderingStatePaused;
        }
    }
}

- (void)stop
{
    @synchronized (self) {
        [self revenant_stopRenderTimer];
        _revenant_started = NO;
        _revenant_renderingState = PHASERenderingStateStopped;
    }
}

- (PHASESpatializationMode)outputSpatializationMode
{
    return _revenant_outputSpatializationMode;
}

- (void)setOutputSpatializationMode:(PHASESpatializationMode)outputSpatializationMode
{
    _revenant_outputSpatializationMode = outputSpatializationMode;
}

- (double)unitsPerSecond
{
    return _revenant_unitsPerSecond;
}

- (void)setUnitsPerSecond:(double)unitsPerSecond
{
    if (unitsPerSecond > 0) {
        _revenant_unitsPerSecond = unitsPerSecond;
    }
}

- (double)unitsPerMeter
{
    return _revenant_unitsPerMeter;
}

- (void)setUnitsPerMeter:(double)unitsPerMeter
{
    if (unitsPerMeter > 0) {
        _revenant_unitsPerMeter = unitsPerMeter;
    }
}

- (PHASEReverbPreset)defaultReverbPreset
{
    return _revenant_defaultReverbPreset;
}

- (void)setDefaultReverbPreset:(PHASEReverbPreset)defaultReverbPreset
{
    _revenant_defaultReverbPreset = defaultReverbPreset;
}

- (id)defaultMedium
{
    return @(PHASEMediumPresetAir);
}

- (PHASEUpdateMode)updateMode
{
    return _revenant_updateMode;
}

- (void)setDefaultMedium:(id)defaultMedium
{
    _revenant_defaultMediumPreset = [defaultMedium respondsToSelector:@selector(integerValue)]
        ? (PHASEMediumPreset)[defaultMedium integerValue] : PHASEMediumPresetAir;
}

- (PHASEObject *)rootObject
{
    return _revenant_rootObject;
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
