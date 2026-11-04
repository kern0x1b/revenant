#include "../revenant_impl.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUComponent.h>

#define RevenantAudioUnitExtensionUnknownStatus ((OSStatus)0x626E643F)

CFArrayRef BACKPORT_IMPL(AudioUnitExtensionCopyComponentList)(CFStringRef extensionIdentifier)
{
    return NULL;
}

OSStatus BACKPORT_IMPL(AudioUnitExtensionSetComponentList)(CFStringRef extensionIdentifier, CFArrayRef audioComponentInfo)
{
    return RevenantAudioUnitExtensionUnknownStatus;
}
