#import "CharonAVFAudio.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AUAudioUnit.h>

// Shared private plumbing for the AudioUnit.framework classes this folder carries: AUParameterNode
// with its group, tree and leaf, AUAudioUnitBus and AUAudioUnitBusArray, AUAudioUnitPreset and
// AUAudioUnit itself.
//
// The release has no AudioUnit.framework: on iOS 6.1.3 the whole AudioUnit C API and the whole
// AUGraph API live in AudioToolbox, and they are there in full - AudioComponentInstanceNew for the
// unit, AudioUnitGetProperty/SetProperty for every property, AudioUnitRender for the input a render
// block pulls, AudioUnitScheduleParameters for a scheduled value, and NewAUGraph/AUGraphOpen/
// AUGraphAddNode/AUGraphNodeInfo/AUGraphInitialize for a graph. So the classes below are built
// directly on those. Nothing here is a translation of Apple's, because there is nothing on this
// release to translate.
//
// The AUAudioUnit the modern headers name is a handle of the AudioUnit.framework of iOS 9, and its C
// entry points (AUAudioUnitInitialize, AUAudioUnitRender, AUAudioUnitGetClass) are not exported by
// iOS 6.1.3. The unit this port holds and hands out is therefore the v2 AudioUnit every release
// carries, reached through the same mechanism a v2 host of that release used: a render callback
// installed with kAudioUnitProperty_SetRenderCallback, and AudioUnitRender to pull.

NS_ASSUME_NONNULL_BEGIN

// The address of a parameter is its three v2 coordinates packed into one word, from the top down:
// identifier, then scope, then element. The header's AUParameterAddress, and the packing both ways
// is this file's because both sides of it are here.
static inline AUParameterAddress CharonAddress(AudioUnitParameterID identifier, AudioUnitScope scope, AudioUnitElement element)
{
    return ((AUParameterAddress)identifier << 32) | ((AUParameterAddress)scope << 16) | (AUParameterAddress)element;
}

// AudioUnitParameterInfo is declared by the build SDK itself, field for field, in
// AudioToolbox/AudioUnitProperties.h - SDK 16.4 and SDK 26.2 agree on it - so the port uses the SDK's
// struct and declares nothing of its own. A review of this tree once carried a hand-written copy with a
// citation to an SDK that is not installed; the real header removes both the copy and the citation.

// What one parameter of a real unit is, as that unit describes it. The AUParameter is the header's
// value object; this is what it holds, and the AudioUnit behind it is the unit the value is read
// from and written to.
// The implementation is in CharonAVFAudioCommon.m, with an explicit @synthesize for each property:
// this class is one the package defines, the build compiles with
// -Werror=objc-missing-property-synthesis, and an @implementation in a header is emitted by every
// source that imports it - a duplicate _OBJC_CLASS_$_CharonAUParameterImpl per object at link.
@interface CharonAUParameterImpl : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) AudioUnitParameterID identifier;
@property (nonatomic) AudioUnitScope scope;
@property (nonatomic) AudioUnitElement element;
@property (nonatomic) AUValue minValue;
@property (nonatomic) AUValue maxValue;
@property (nonatomic) AudioUnitParameterUnit unit;
@property (nonatomic) AudioUnitParameterOptions flags;
@property (nonatomic, copy, nullable) NSString *unitName;
@property (nonatomic, copy, nullable) NSArray<NSString *> *valueStrings;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *dependentParameters;
@property (nonatomic, weak, nullable) AUAudioUnit *owner;
@end


// The tree a real unit publishes, built by asking that unit.
@interface AUParameterTree (CharonImpl)
- (instancetype _Nonnull)initWithCharonChildren:(NSArray<AUParameterNode *> *_Nonnull)children;
@end

@interface AUParameterGroup (CharonImpl)
- (instancetype _Nonnull)initWithCharonChildren:(NSArray<AUParameterNode *> *_Nonnull)children;
@end

@interface AUParameter (CharonImpl)
- (instancetype _Nonnull)initWithCharonImpl:(CharonAUParameterImpl *_Nonnull)impl;
- (AudioUnitParameterID)charon_identifier;
- (AudioUnitScope)charon_scope;
- (AudioUnitElement)charon_element;
- (void)charon_apply:(AUValue)value
           originator:(AUParameterObserverToken _Nullable)originator
           atHostTime:(uint64_t)hostTime
            eventType:(AUParameterAutomationEventType)eventType
            automate:(BOOL)automate;
@end

// The parent link and the names of a node: the key path is the identifiers of a node's parents
// joined with periods, which is what the header says a key path is.
@interface AUParameterNode (CharonImpl)
- (void)charon_setParent:(AUParameterNode *_Nullable)parent keyPath:(NSString *_Nonnull)keyPath;
- (void)charon_setDisplayName:(NSString *_Nonnull)displayName;
- (void)charon_setIdentifier:(NSString *_Nonnull)identifier;
- (NSArray<NSValue *> *_Nonnull)charon_observerTokens;
- (void)charon_addAutomationObserver:(id _Nonnull)observer;
- (void)charon_notifyValue:(AUValue)value atAddress:(AUParameterAddress)address;
- (void)charon_notifyRecording:(NSInteger)count events:(const AURecordedParameterEvent *_Nonnull)events;
- (void)charon_notifyAutomation:(NSInteger)count events:(const AUParameterAutomationEvent *_Nonnull)events;
@end

// The real AudioUnit of an AUAudioUnit, and the bus the port builds around one of its elements.
@interface AUAudioUnit (CharonImpl)
@property (nonatomic, readonly) AudioUnit audioUnit;
@end

@interface AUAudioUnitBus (CharonImpl)
- (instancetype _Nonnull)initWithCharonOwner:(AUAudioUnit *_Nonnull)owner
                                       type:(AUAudioUnitBusType)type
                                      index:(NSUInteger)index;
@end

@interface AUAudioUnitPreset (CharonImpl)
- (instancetype _Nonnull)initWithNumber:(NSInteger)number name:(NSString *_Nonnull)name;
@end

// The one call the release's render callback makes. It is on a category of AUAudioUnit so that the
// C shim in CharonAUAudioUnitCommon.c can reach it: the shim is a C function and a C function cannot
// send a message to a method a category declared in a header the shim does not see.
@interface AUAudioUnit (CharonRender)
- (OSStatus)charon_renderWithActionFlags:(AudioUnitRenderActionFlags *_Nullable)actionFlags
                               timestamp:(const AudioTimeStamp *_Nullable)timestamp
                              frameCount:(UInt32)frameCount
                                     bus:(UInt32)bus
                                     data:(AudioBufferList *_Nullable)data;
@end

AUParameterTree *_Nullable CharonBuildParameterTree(AUAudioUnit *_Nonnull owner);

// The C shim the release's AudioUnit calls for audio. Defined in CharonAUAudioUnitCommon.c, which
// exports no API symbol of its own, because a C function shared between backport files is undefined
// in the bands that leave one of them out (charon/AGENTS.md).
extern OSStatus CharonAURenderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                    UInt32 inNumberFrames, AudioBufferList *ioData);

NS_ASSUME_NONNULL_END

