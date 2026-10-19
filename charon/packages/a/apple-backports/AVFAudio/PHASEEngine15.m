#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>
#import <mach/mach_time.h>

// PHASEEngine, the spatial audio engine: the largest cluster in the PHASE corpus and the class the
// rest of the framework hangs off. PHASE arrived in iOS 15 and the port's releases are 6.1.3 and 4.3,
// so there is no PHASE.framework on either and none of this is a translation of an engine that exists.
//
// What there is to carry is the engine's state, and every value in it is either a documented default
// or the truth about a fresh engine. The four collection-valued properties answer the empty set a
// fresh engine really holds, which is not a stub: a PHASEEngine has no sound events, no groups and no
// duckers until objects are added to it, and the classes those would hold - PHASESoundEvent,
// PHASEGroup, PHASEDucker, PHASEObject, PHASEMedium, PHASEAssetRegistry, PHASEGroupPreset - are
// separate families of the corpus that this delivery does not carry, and the facts file says so
// rather than the properties inventing objects of classes the port does not have.

// rootObject is the SDK's own @property (readonly, strong, nonatomic), and this file used to declare
// BOTH a @synthesize binding for it and a hand-written getter returning the port's ivar. Two
// definitions of one method in one implementation: the object file carried a single
// -[charon_host_PHASEEngine rootObject] and it was
//
//   mov x0, #0x0
//
// a constant nil with no load at all, while -initWithUpdateMode: stored the root into the ivar at
// offset 72 and the slot held a live object at run time. One definition is what a property with a
// hand-written accessor is supposed to have, and the harness reported the nil for as long as there were
// two.
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
    // The render loop's clock: a timer on its own queue renders one quantum per tick, and the frames rendered since
    // the engine was last started are the engine's time. Guarded by @synchronized(self).
    dispatch_source_t _charon_renderTimer;
    AVAudioFramePosition _charon_renderedFrames;
    uint64_t _charon_renderHostTime;
}


- (instancetype)initWithUpdateMode:(PHASEUpdateMode)updateMode
{
    if ((self = [super init])) {
        // The header's documented defaults: unitsPerSecond and unitsPerMeter are 1 each
        // (PHASEEngine.h:123 and :134 clamp each to a range above zero, with 1 as the default), the default
        // reverb preset is PHASEReverbPresetNone (:112) and the default medium is
        // PHASEMediumPresetAir (:104).
        _charon_unitsPerSecond = 1.0;
        _charon_unitsPerMeter = 1.0;
        _charon_defaultReverbPreset = PHASEReverbPresetNone;
        // outputSpatializationMode has no documented numeric default - the header says only that setting it
        // replaces the default output spatializer with the one chosen (PHASEEngine.h:87-90) - and the
        // enumeration's own zero is PHASESpatializationModeAutomatic, which is the mode that means
        // "let the framework choose". That is the answer here, and it is the enumeration's naming
        // rather than a number this port picked.
        _charon_outputSpatializationMode = PHASESpatializationModeAutomatic;
        _charon_renderingState = PHASERenderingStateStopped;
        _charon_updateMode = updateMode;
        // The root object, made the way the header says one is made: against this engine, at the
        // identity transform, with no parent and no children. The engine's own root is a PHASERootObject
        // on this release, and that class has no row in the PHASE corpus - but the property's declared
        // type is PHASEObject *, and the declared type is what an application sees, so what the port
        // answers is a PHASEObject standing as the root rather than nil.
        _charon_rootObject = [[PHASEObject alloc] initWithEngine:self];
    }
    return self;
}

// The engine is not rendering until it is started, and the enumeration's zero is Stopped, so a
// fresh engine and a stopped one answer the same and the flag below only distinguishes the two
// paths that lead there.
- (PHASERenderingState)renderingState
{
    return _charon_renderingState;
}

// Starting a stopped or paused engine starts its clock from zero, which is what the host does (measured: after a
// pause, the clock reads the time since the resume). Starting a running engine changes nothing.
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

// The render loop. A running engine renders one quantum per tick of a timer on its own queue, and its clock is the
// frames those ticks have rendered. The loop renders no audio yet: the engine holds no sound events, groups or
// duckers (their families are not carried), so a quantum has nothing to render into. The clock is the part the
// application can observe, and it is measured against the host in tests/backports/host/phase/clock.sh.
static const double CharonEngineRenderRate = 48000.0;
static const AVAudioFramePosition CharonEngineRenderQuantum = 480;   // 10 ms at the rate above
static const int64_t CharonEngineRenderIntervalNanoseconds = 10 * NSEC_PER_MSEC;

// Caller holds @synchronized(self). A paused or stopped engine has no timer; a started one has exactly one.
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

// Caller holds @synchronized(self).
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

// The time the engine most recently rendered, and nil when it is not running - which is what the header says,
// and what the host answers for a paused engine too (measured: facts/PHASE/PHASEEngine.md).
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

// A manual-update engine is advanced by the caller, and an automatic one by its own loop. The host answers the
// caller of an automatic engine's update with an API Misuse exception and does nothing else (measured), so this
// does the same. For a manual engine the clock keeps its own pace with the wall clock, not with update(): the host's
// update() does not move lastRenderTime (measured), so this one does not either.
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

// The header clamps to (0, inf] and says so: a non-positive value is not a setting the property
// takes, and the host's own clamp is what a caller has to live with, so the port refuses it here
// rather than storing a value the release would clamp.
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

// The default medium, the enumeration's own PHASEMediumPresetAir. It is held as the preset rather
// than as a PHASEMedium, because PHASEMedium is a separate family of the corpus that this delivery
// does not carry: a caller asking for the object gets the value it has rather than an object of a
// class the port does not have, and the facts file says what that costs.
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
    // The root, not nil. A rewrite of this method replaced the comment above it and left the body, so
    // the accessor returned a constant nil - which is why the disassembly was `mov x0, #0x0` while
    // -initWithUpdateMode: stored a live root in the ivar at offset 72, and why @synthesize changed
    // nothing: a hand-written accessor wins over a synthesised one, and this one returned nil.
    return _charon_rootObject;
}

- (id)assetRegistry
{
    // PHASEAssetRegistry is a separate family of the corpus and is not carried here, so this is nil:
    // the empty answer rather than an object of a class the port does not have. The facts file names it.
    return nil;
}

// The engine's sound events. A fresh engine has none, and PHASESoundEvent is a separate family of
// the corpus, so an event added to this engine cannot be held yet; the empty answer is the truth about
// the engine and the framework around it is incomplete.
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
