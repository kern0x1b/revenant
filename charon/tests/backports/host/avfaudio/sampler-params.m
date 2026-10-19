#import <Foundation/Foundation.h>
#import <AVFAudio/AVFAudio.h>
#import <AudioToolbox/AudioToolbox.h>

@interface charon_host_AVAudioNode : NSObject
- (void)charon_setEngine:(id)engine auNode:(AUNode)node audioUnit:(AudioUnit)unit;
@end

@interface charon_host_AVAudioUnitSampler : NSObject
- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)description;
- (float)masterGain;
- (void)setMasterGain:(float)masterGain;
- (float)globalTuning;
- (void)setGlobalTuning:(float)globalTuning;
- (float)stereoPan;
- (void)setStereoPan:(float)stereoPan;
@property(nonatomic, readonly) AudioUnit audioUnit;
@end

static int checks = 0, failures = 0;
static void check(NSString *what, BOOL held) {
    checks++;
    if (held) { printf("ok %s\n", what.UTF8String); }
    else { failures++; printf("FAIL %s\n", what.UTF8String); }
}
static AudioUnitParameterValue CharonReadParameter(AudioUnit unit, AudioUnitParameterID id) {
    AudioUnitParameterValue value = 0;
    if (unit == NULL || AudioUnitGetParameter(unit, id, kAudioUnitScope_Global, 0, &value) != noErr) { return -12345; }
    return value;
}

int main(void) {
    @autoreleasepool {
        AudioComponentDescription description = {0};
        description.componentType = kAudioUnitType_MusicDevice;
        description.componentSubType = kAudioUnitSubType_Sampler;
        description.componentManufacturer = kAudioUnitManufacturer_Apple;
        AVAudioUnitSampler *theirs = [[AVAudioUnitSampler alloc] initWithAudioComponentDescription:description];
        charon_host_AVAudioUnitSampler *mine = [[charon_host_AVAudioUnitSampler alloc] initWithAudioComponentDescription:description];
        if (theirs == nil || mine == nil) { printf("FAIL a sampler would not instantiate\n"); return 1; }
        [theirs loadInstrumentAtURL:[NSURL URLWithString:@"file:///nonexistent"] error:nil];

        AudioUnit attached = NULL;
        AUGraph graph = NULL;
        if (NewAUGraph(&graph) == noErr && AUGraphOpen(graph) == noErr) {
            AUNode node = 0;
            if (AUGraphAddNode(graph, &description, &node) == noErr) {
                AUGraphNodeInfo(graph, node, NULL, &attached);
                [(charon_host_AVAudioNode *)mine charon_setEngine:nil auNode:node audioUnit:attached];
                printf("stage the port's node is attached: node %d unit %p\n", (int)node, (void *)attached);
            }
        }
        AudioUnit theirUnit = theirs.audioUnit, myUnit = mine.audioUnit;
        printf("stage both are asked about the same component: host %p, port %p\n",
               (void *)theirUnit, (void *)myUnit);

        for (float value = -6.0f; value <= 6.0f; value += 6.0f) {
            theirs.masterGain = value; mine.masterGain = value;
            AudioUnitParameterValue a = CharonReadParameter(theirUnit, kAUSamplerParam_Gain);
            AudioUnitParameterValue b = CharonReadParameter(myUnit, kAUSamplerParam_Gain);
            printf("stage masterGain = %g: host parameter %g, port parameter %g\n",
                   (double)value, (double)a, (double)b);
            check(@"masterGain tells the unit the same value on both", a == b);
        }
        for (float value = -1.0f; value <= 1.0f; value += 1.0f) {
            theirs.stereoPan = value; mine.stereoPan = value;
            AudioUnitParameterValue a = CharonReadParameter(theirUnit, kAUSamplerParam_Pan);
            AudioUnitParameterValue b = CharonReadParameter(myUnit, kAUSamplerParam_Pan);
            printf("stage stereoPan = %g: host parameter %g, port parameter %g\n",
                   (double)value, (double)a, (double)b);
            check(@"stereoPan tells the unit the same value on both", a == b);
        }
        for (float value = -2400.0f; value <= 2400.0f; value += 1200.0f) {
            theirs.globalTuning = value; mine.globalTuning = value;
            AudioUnitParameterValue theirCoarse = CharonReadParameter(theirUnit, kAUSamplerParam_CoarseTuning);
            AudioUnitParameterValue theirFine = CharonReadParameter(theirUnit, kAUSamplerParam_FineTuning);
            AudioUnitParameterValue myCoarse = CharonReadParameter(myUnit, kAUSamplerParam_CoarseTuning);
            AudioUnitParameterValue myFine = CharonReadParameter(myUnit, kAUSamplerParam_FineTuning);
            printf("stage globalTuning = %g cents: host coarse %g fine %g, port coarse %g fine %g\n",
                   (double)value, (double)theirCoarse, (double)theirFine, (double)myCoarse, (double)myFine);
            check(@"globalTuning splits into the same coarse and fine on both",
                  theirCoarse == myCoarse && theirFine == myFine);
        }
        for (float value = -2400.0f; value <= 2400.0f; value += 1200.0f) {
            theirs.globalTuning = value; mine.globalTuning = value;
            printf("stage globalTuning read back: host %g, port %g\n", (double)theirs.globalTuning, (double)mine.globalTuning);
            check(@"globalTuning reads back the value that was set, on both",
                  fabsf(theirs.globalTuning - value) < 0.51f && fabsf(mine.globalTuning - value) < 0.51f);
        }
        if (graph != NULL) {
            AUGraphClose(graph);
            DisposeAUGraph(graph);
        }
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
