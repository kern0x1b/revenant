// MIDIDeviceNewEntity, of iOS 14: adds an entity with a protocol to a device. macOS CoreMIDI answers paramErr and
// no entity for a device of 0, measured (oracle/newentity2.m); a device that exists is the release's own, and the entity
// is the release's (MIDIDeviceAddEntity). The protocol is written to the entity, as the port's choice: where macOS keeps
// it, and whether its endpoints read it, is not measured (facts/CoreMIDI/Devices.md; a crutch in coordination/crutches.md).
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
    // The release's answer to the protocol is returned. An entity whose protocol was refused is removed again, so the caller
    // does not get an entity without the protocol it asked for.
    status = MIDIObjectSetIntegerProperty(entity, CHARON_PROTOCOL_KEY, (SInt32)protocol);
    if (status != noErr) {
        if (MIDIDeviceRemoveEntity(device, entity) != noErr)
            NSLog(@"charon: an entity whose protocol the release refused (status %d) could not be removed from its device", (int)status);
        return status;
    }
    *newEntity = entity;
    return noErr;
}
