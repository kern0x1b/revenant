#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUComponent.h>

// AudioToolbox functions of iOS 11, which the release this port runs on does not export.

// The status the host answers when it is asked to set the component list of an extension it does not know. It is the answer
// for every identifier measured, unknown or NULL, with an empty list or a list with one component description in it
// ('bnd?', 0x626E643F). A port cannot register an app extension, so no identifier is known to it, and this is the answer
// for every one.
#define CharonAudioUnitExtensionUnknownStatus ((OSStatus)0x626E643F)

// AudioUnitExtensionCopyComponentList. The host answers NULL for every identifier it does not know. This port can register no
// extension, so it knows none, and the answer is NULL for every identifier.
CFArrayRef AudioUnitExtensionCopyComponentList(CFStringRef extensionIdentifier)
{
    return NULL;
}

// AudioUnitExtensionSetComponentList. The same answer as the host for an identifier it does not know (see above).
OSStatus AudioUnitExtensionSetComponentList(CFStringRef extensionIdentifier, CFArrayRef audioComponentInfo)
{
    return CharonAudioUnitExtensionUnknownStatus;
}
