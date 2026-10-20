#import "RevenantAVFAudio.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AUAudioUnit.h>

NS_ASSUME_NONNULL_BEGIN

static inline AUParameterAddress RevenantAddress(AudioUnitParameterID identifier, AudioUnitScope scope, AudioUnitElement element)
{
    return ((AUParameterAddress)identifier << 32) | ((AUParameterAddress)scope << 16) | (AUParameterAddress)element;
}

@interface RevenantAUParameterImpl : NSObject
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


@interface AUParameterTree (RevenantImpl)
- (instancetype _Nonnull)initWithRevenantChildren:(NSArray<AUParameterNode *> *_Nonnull)children;
@end

@interface AUParameterGroup (RevenantImpl)
- (instancetype _Nonnull)initWithRevenantChildren:(NSArray<AUParameterNode *> *_Nonnull)children;
@end

@interface AUParameter (RevenantImpl)
- (instancetype _Nonnull)initWithRevenantImpl:(RevenantAUParameterImpl *_Nonnull)impl;
- (AudioUnitParameterID)revenant_identifier;
- (AudioUnitScope)revenant_scope;
- (AudioUnitElement)revenant_element;
- (void)revenant_apply:(AUValue)value
           originator:(AUParameterObserverToken _Nullable)originator
           atHostTime:(uint64_t)hostTime
            eventType:(AUParameterAutomationEventType)eventType
            automate:(BOOL)automate;
@end

@interface AUParameterNode (RevenantImpl)
- (void)revenant_setParent:(AUParameterNode *_Nullable)parent keyPath:(NSString *_Nonnull)keyPath;
- (void)revenant_setDisplayName:(NSString *_Nonnull)displayName;
- (void)revenant_setIdentifier:(NSString *_Nonnull)identifier;
- (NSArray<NSValue *> *_Nonnull)revenant_observerTokens;
- (void)revenant_addAutomationObserver:(id _Nonnull)observer;
- (void)revenant_notifyValue:(AUValue)value atAddress:(AUParameterAddress)address;
- (void)revenant_notifyRecording:(NSInteger)count events:(const AURecordedParameterEvent *_Nonnull)events;
- (void)revenant_notifyAutomation:(NSInteger)count events:(const AUParameterAutomationEvent *_Nonnull)events;
@end

@interface AUAudioUnit (RevenantImpl)
@property (nonatomic, readonly) AudioUnit audioUnit;
@end

@interface AUAudioUnitBus (RevenantImpl)
- (instancetype _Nonnull)initWithRevenantOwner:(AUAudioUnit *_Nonnull)owner
                                       type:(AUAudioUnitBusType)type
                                      index:(NSUInteger)index;
@end

@interface AUAudioUnitPreset (RevenantImpl)
- (instancetype _Nonnull)initWithNumber:(NSInteger)number name:(NSString *_Nonnull)name;
@end

@interface AUAudioUnit (RevenantRender)
- (OSStatus)revenant_renderWithActionFlags:(AudioUnitRenderActionFlags *_Nullable)actionFlags
                               timestamp:(const AudioTimeStamp *_Nullable)timestamp
                              frameCount:(UInt32)frameCount
                                     bus:(UInt32)bus
                                     data:(AudioBufferList *_Nullable)data;
@end

AUParameterTree *_Nullable RevenantBuildParameterTree(AUAudioUnit *_Nonnull owner);

extern OSStatus RevenantAURenderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                    UInt32 inNumberFrames, AudioBufferList *ioData);

NS_ASSUME_NONNULL_END
