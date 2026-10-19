#import <AVFAudio/AVFAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <mach/mach_time.h>

// Shared private plumbing for the AVFAudio classes this folder carries. Nothing here is API: every
// name is Charon-prefixed, so modules/apple/backports.lua's internal_symbol() keeps it out of the
// library's exports, and a helper that exports none of its own takes the lowest minimum among the
// objects that name it (backports.lua's minimums(), third answer) - which is what lets a helper be
// reached from every band of the package.
//
// The C base is what the release already carries, measured against the real armv7 shared cache of
// iOS 6.1.3 (`dyld.load`, ~580 libraries): AudioToolbox exports the whole AudioComponent
// discovery family (AudioComponentCount, AudioComponentFindNext, AudioComponentGetDescription,
// AudioComponentCopyName, AudioComponentGetVersion, AudioComponentInstanceCanDo, AudioComponentCopyTags,
// AudioComponentRegister), the whole AudioUnit C API, the whole AUGraph API
// (NewAUGraph, AUGraphOpen, AUGraphAddNode, AUGraphNodeInfo, AUGraphConnectNodeInput,
// AUGraphSetNodeInputCallback, AUGraphInitialize, AUGraphStart, AUGraphStop) and AudioFile /
// ExtAudioFile; CoreAudio exports the whole AudioObject* family. So nothing below is answered with a
// value the release cannot produce.
//
// Host time is mach_absolute_time(), which is what AudioGetCurrentHostTime() returns and what an
// AudioTimeStamp's mHostTime holds - the SDK 26.2 CoreAudio.framework ships no header at all
// (Headers/CoreAudioTypes.h is its only one, and neither AudioGetCurrentHostTime nor
// AudioGetHostClockFrequency is declared in any header of the SDK), so the clock is read through
// libSystem's own mach_time.h rather than through a declaration this port would have to write out
// for itself. The two are the same clock: AudioFileSecondsToHostTime is documented as
// seconds * mach_frequency().

NS_ASSUME_NONNULL_BEGIN

// AudioChannelLayout for a tag, and the number of channels the tag means. The release's
// AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutForTag) is the authority; where it
// declines, the layouts AVFAudio names by tag are counted here, which is the same table
// kAudioFormatProperty_ChannelLayoutForTagAnswersFor on the current release.
NSUInteger CharonChannelsForLayoutTag(AudioChannelLayoutTag tag);
AudioChannelLayoutTag CharonTagForChannelCount(AVAudioChannelCount channels);
AudioChannelLayoutTag CharonTagFromName(NSString *name);

// The private initializer the manager below hands its own objects: an AVAudioUnitComponent over one
// real AudioComponent. It is a genuine -init-family method (ARC requires the selector to begin with
// "init"), declared here rather than in the class extension so both the manager and the class agree
// on its shape, and never called from outside this dylib - the public path to a component is
// -[AVAudioUnitComponentManager componentsMatchingDescription:] and its two siblings.
@interface AVAudioUnitComponent (CharonImpl)
- (instancetype)initWithCharonComponent:(AudioComponent)component;
@end

// The walk every search of the manager is built on, and the one a search that has to see a component
// registered after this process started needs; not API, so it is not a selector of the class.
@interface AVAudioUnitComponentManager (CharonImpl)
- (NSArray<AVAudioUnitComponent *> *)charon_allComponents;
@end

// The AVAudioNode hooks libAVFoundationBackports carries, with the signatures its own
// CharonAVAudioEngine.h gives them: set the node's engine, AUNode and AudioUnit, and its schedule queue.
@interface AVAudioNode (CharonAVFAudioImpl)
- (void)charon_setEngine:(nullable AVAudioEngine *)engine auNode:(AUNode)node audioUnit:(nullable AudioUnit)unit;
- (NSMutableArray *_Nonnull)charon_queue;
@end

// AVAudioMixingDestination's private initializer and the once-in-a-log note, both declared here so
// the environment node and the units can reach them without each declaring them again.
@interface AVAudioMixingDestination (CharonInit)
- (instancetype _Nonnull)initWithCharonNode:(AVAudioNode *_Nullable)node
                                     mixer:(AVAudioNode *_Nullable)mixer
                                        bus:(AVAudioNodeBus)bus;
@end

@interface AUAudioUnit (CharonNote)
+ (void)charon_noteInert:(NSString *)member why:(NSString *)why;
@end

// The environment node's own plumbing. AVAudioEnvironmentNode carries a graph of its own - the
// release's kAudioUnitSubType_SpatialMixer (which the SDK renames from the deprecated
// kAudioUnitSubType_AU3DMixerEmbedded, same value, iOS 2.0) terminated into a generic output - so that
// it can be rendered offline without an engine, which is what makes its own output measurable.
@interface AVAudioEnvironmentNode (CharonImpl)
// Render the node's output by hand, the way AudioUnitRender pulls an output unit, and write the frames
// into buffer.
- (OSStatus)charon_renderOfflineToBuffer:(AudioBufferList *)buffer frames:(AVAudioFrameCount)frames;
- (void)charon_applyEnvironmentParameters;
@end

// The two parameter classes of the environment, and the node they belong to. They are the header's own
// value objects; the node is what they apply to.
@interface AVAudioEnvironmentDistanceAttenuationParameters (CharonImpl)
- (instancetype)initWithCharonOwner:(AVAudioEnvironmentNode *)owner;
- (float)charon_gainForDistance:(float)distance;
@end

@interface AVAudioEnvironmentReverbParameters (CharonImpl)
- (instancetype)initWithCharonOwner:(AVAudioEnvironmentNode *)owner;
@end

NS_ASSUME_NONNULL_END
