#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

#import "CharonCoreMIDI.h"

OSStatus MIDIDeviceNewEntity(MIDIDeviceRef device, CFStringRef name, MIDIProtocolID protocol, Boolean embedded,
                             ItemCount numSourceEndpoints, ItemCount numDestinationEndpoints, MIDIEntityRef *newEntity)
{
    *newEntity = 0;
    if (device == 0 || (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0))
        return charon_paramErr;
    MIDIEntityRef entity = 0;
    OSStatus status = MIDIDeviceAddEntity(device, name, embedded, numSourceEndpoints, numDestinationEndpoints, &entity);
    if (status != noErr)
        return status;
    status = MIDIObjectSetIntegerProperty(entity, CHARON_PROTOCOL_KEY, (SInt32)protocol);
    if (status != noErr) {
        if (MIDIDeviceRemoveEntity(device, entity) != noErr)
            NSLog(@"charon: an entity whose protocol the release refused (status %d) could not be removed from its device", (int)status);
        return status;
    }
    *newEntity = entity;
    return noErr;
}
