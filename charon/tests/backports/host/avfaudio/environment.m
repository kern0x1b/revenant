#import <AVFoundation/AVFoundation.h>
#include <stdio.h>
#include "../../../../packages/a/apple-backports/AVFAudio/CharonEnvironmentOutput.h"
#include "../../../../packages/a/apple-backports/AVFAudio/CharonEnvironmentFilter.h"

static int checks = 0;
static int failures = 0;

static void check(int passed, const char *name)
{
    checks++;
    if (!passed) {
        failures++;
        printf("FAIL %s\n", name);
    }
}


static float mixerValue(AVAudioEnvironmentNode *node, AUParameterAddress address)
{
    AUParameter *parameter = [node.AUAudioUnit.parameterTree parameterWithAddress:address];
    return parameter ? parameter.value : NAN;
}

int main(void)
{
    @autoreleasepool {
        check(CharonResolveEnvironmentOutputType(AVAudioEnvironmentOutputTypeAuto, CharonEnvironmentRouteClassWired)
              == AVAudioEnvironmentOutputTypeHeadphones, "auto on a wired route is headphones");
        check(CharonResolveEnvironmentOutputType(AVAudioEnvironmentOutputTypeAuto, CharonEnvironmentRouteClassBuiltIn)
              == AVAudioEnvironmentOutputTypeBuiltInSpeakers, "auto on the built-in hardware is built-in speakers");
        check(CharonResolveEnvironmentOutputType(AVAudioEnvironmentOutputTypeAuto, CharonEnvironmentRouteClassExternal)
              == AVAudioEnvironmentOutputTypeExternalSpeakers, "auto on an external route is external speakers");
        check(CharonResolveEnvironmentOutputType(AVAudioEnvironmentOutputTypeAuto, CharonEnvironmentRouteClassUnknown)
              == AVAudioEnvironmentOutputTypeExternalSpeakers, "auto on a route the port does not name is external speakers");

        for (NSInteger requested = AVAudioEnvironmentOutputTypeHeadphones; requested <= AVAudioEnvironmentOutputTypeExternalSpeakers; requested++) {
            for (int route = CharonEnvironmentRouteClassUnknown; route <= CharonEnvironmentRouteClassExternal; route++) {
                check(CharonResolveEnvironmentOutputType((AVAudioEnvironmentOutputType)requested, (CharonEnvironmentRouteClass)route) == requested,
                      "an explicit output type is kept on every route");
            }
        }

        check(CharonEnvironmentHeadTrackingAnswer(YES) == NO, "head tracking answers NO when YES is set");
        check(CharonEnvironmentHeadTrackingAnswer(NO) == NO, "head tracking answers NO when NO is set");

        AVAudioEnvironmentNode *host = [[AVAudioEnvironmentNode alloc] init];
        check(host.outputType == AVAudioEnvironmentOutputTypeAuto, "the host's outputType defaults to auto");
        for (NSInteger type = AVAudioEnvironmentOutputTypeAuto; type <= AVAudioEnvironmentOutputTypeExternalSpeakers; type++) {
            host.outputType = (AVAudioEnvironmentOutputType)type;
            check(host.outputType == type, "the host's outputType reads back the type it was set to");
        }

        host.listenerHeadTrackingEnabled = YES;
        printf("divergence: the host's listenerHeadTrackingEnabled reads %d after YES; the port answers %d\n",
               (int)host.listenerHeadTrackingEnabled, (int)CharonEnvironmentHeadTrackingAnswer(YES));

        AVAudioEngine *engine = [[AVAudioEngine alloc] init];
        AVAudioEnvironmentNode *filterNode = [[AVAudioEnvironmentNode alloc] init];
        [engine attachNode:filterNode];
        AVAudioUnitEQFilterParameters *band = filterNode.reverbParameters.filterParameters;
        check(band.frequency == CharonEnvironmentFilterDefaultFrequency, "the host's filter frequency defaults to 800");
        check(band.bandwidth == CharonEnvironmentFilterDefaultBandwidth, "the host's filter bandwidth defaults to 3");
        check(band.gain == CharonEnvironmentFilterDefaultGain, "the host's filter gain defaults to 0");
        check(band.filterType == AVAudioUnitEQFilterTypeParametric, "the host's filter type defaults to parametric");
        check(band.bypass == NO, "the host's filter is not bypassed by default");
        check(mixerValue(filterNode, kReverbParam_FilterFrequency) == CharonEnvironmentFilterDefaultFrequency,
              "the mixer's filter frequency at the default is the band's");
        check(mixerValue(filterNode, kReverbParam_FilterEnable) == CharonEnvironmentFilterEnableValue(band.bypass),
              "the mixer's filter enable at the default is the band's bypass inverted");

        band.frequency = 2000;
        band.bandwidth = 1.5f;
        band.gain = 6;
        band.filterType = AVAudioUnitEQFilterTypeLowPass;
        band.bypass = NO;
        check(mixerValue(filterNode, kReverbParam_FilterFrequency) == 2000, "a set frequency lands at mixer id 14");
        check(mixerValue(filterNode, kReverbParam_FilterBandwidth) == 1.5f, "a set bandwidth lands at mixer id 15");
        check(mixerValue(filterNode, kReverbParam_FilterGain) == 6, "a set gain lands at mixer id 16");
        check(mixerValue(filterNode, kReverbParam_FilterType) == (float)AVAudioUnitEQFilterTypeLowPass, "a set type lands at mixer id 17");
        check(mixerValue(filterNode, kReverbParam_FilterEnable) == CharonEnvironmentFilterEnableValue(NO), "not bypassed is enable 1");

        band.bypass = YES;
        check(band.bypass == YES, "the band keeps its bypass");
        check(mixerValue(filterNode, kReverbParam_FilterEnable) == CharonEnvironmentFilterEnableValue(YES), "bypassed is enable 0");

        band.frequency = 20000;
        band.bandwidth = 5;
        band.gain = 24;
        check(band.frequency == 20000 && band.bandwidth == 5 && band.gain == 24, "the band keeps the values it was given");
        check(mixerValue(filterNode, kReverbParam_FilterFrequency) == 10000, "the mixer clamps frequency to 10000");
        check(mixerValue(filterNode, kReverbParam_FilterBandwidth) == 4, "the mixer clamps bandwidth to 4");
        check(mixerValue(filterNode, kReverbParam_FilterGain) == 18, "the mixer clamps gain to 18");

        printf("checks=environment-output failures=%d\n", failures);
        return failures == 0 ? 0 : 1;
    }
}
