#import "CharonAVFAudio.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AUAudioUnit.h>

NS_ASSUME_NONNULL_BEGIN

static inline AUParameterAddress CharonAddress(AudioUnitParameterID identifier, AudioUnitScope scope, AudioUnitElement element)
{
    return ((AUParameterAddress)identifier << 32) | ((AUParameterAddress)scope << 16) | (AUParameterAddress)element;
}

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

@interface AUAudioUnit (CharonRender)
- (OSStatus)charon_renderWithActionFlags:(AudioUnitRenderActionFlags *_Nullable)actionFlags
                               timestamp:(const AudioTimeStamp *_Nullable)timestamp
                              frameCount:(UInt32)frameCount
                                     bus:(UInt32)bus
                                     data:(AudioBufferList *_Nullable)data;
@end

AUParameterTree *_Nullable CharonBuildParameterTree(AUAudioUnit *_Nonnull owner);

extern OSStatus CharonAURenderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                    UInt32 inNumberFrames, AudioBufferList *ioData);

NS_ASSUME_NONNULL_END
