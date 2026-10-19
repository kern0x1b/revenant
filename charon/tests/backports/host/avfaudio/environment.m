// AVAudioEnvironmentNode's outputType and listenerHeadTrackingEnabled.
//
// The port's rules are in packages/a/apple-backports/AVFAudio/CharonEnvironmentOutput.h, the header the port's node includes,
// so this probe checks the very mapping the node applies. Checked here:
//   - the resolution of AVAudioEnvironmentOutputTypeAuto over the four route classes, against the header's rule: a wired
//     route is headphones, the built-in hardware is built-in speakers, every other route is external speakers;
//   - an explicit type is kept on every route, whatever the route is;
//   - the host's own outputType keeps the value it is set to, for every type, which is what the port's setter does too;
//   - the port's listenerHeadTrackingEnabled answers NO for both values. The host keeps YES (measured on macOS 27), which
//     is a recorded divergence: it is printed, not counted, because the 6.1.3 device has no head pose for a YES to mean anything.
// The route itself is read from AudioSession on the device, which this host does not have, so the route's class is passed in
// here. That part is not measured by this file.
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


// The mixer parameter the environment node reads back through its own parameter tree, which the host renders from.
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

        // The reverb filter band. The host's band has the defaults the port writes (CharonEnvironmentFilter.h), and the mixer's
        // reverb filter, read through the node's parameter tree, holds the band's values with the enable as the bypass inverted.
        // The band keeps a value as it was given; the mixer clamps it (frequency 10 to 10000, bandwidth 0.05 to 4, gain plus or
        // minus 18), which is why the mixer, not the band, is where the port's values are checked.
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
