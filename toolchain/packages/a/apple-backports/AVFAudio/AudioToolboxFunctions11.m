#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUComponent.h>

#define CharonAudioUnitExtensionUnknownStatus ((OSStatus)0x626E643F)

CFArrayRef AudioUnitExtensionCopyComponentList(CFStringRef extensionIdentifier)
{
    return NULL;
}

OSStatus AudioUnitExtensionSetComponentList(CFStringRef extensionIdentifier, CFArrayRef audioComponentInfo)
{
    return CharonAudioUnitExtensionUnknownStatus;
}
