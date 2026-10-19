// MIDIDeviceNewEntity (MIDIDevice14.m) answers the release's status for each step it takes, and does not hand out an entity
// whose protocol the release refused. The host forbids a real entity (oracle/newentity2.m: it changes the owner's MIDI setup), and
// the release cannot be made to refuse the protocol, so this test stands in for the three release calls the function makes:
// run.sh renames MIDIDeviceAddEntity, MIDIObjectSetIntegerProperty and MIDIDeviceRemoveEntity in MIDIDevice14.m and in this
// file to the stand-ins defined here, and nothing is linked from the release for them. The device of 0 is the answer macOS gave
// (oracle/newentity2-macos.txt): paramErr, no entity. The unknown protocol is the port's own answer, not measured on macOS
// (facts/CoreMIDI/Devices.md).
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>

#import "CharonCoreMIDI.h"

static OSStatus gAddStatus, gSetStatus, gRemoveStatus;
static int gAdds, gSets, gRemoves;
static MIDIEntityRef gRemovedEntity;
static MIDIObjectRef gSetObject;
static SInt32 gSetValue;
static CFStringRef gSetKey;

static const MIDIEntityRef kStandInEntity = 4242;

OSStatus charon_test_MIDIDeviceAddEntity(MIDIDeviceRef device, CFStringRef name, Boolean embedded, ItemCount numSourceEndpoints,
                                         ItemCount numDestinationEndpoints, MIDIEntityRef *newEntity)
{
    gAdds++;
    if (gAddStatus == noErr)
        *newEntity = kStandInEntity;
    return gAddStatus;
}

OSStatus charon_test_MIDIObjectSetIntegerProperty(MIDIObjectRef obj, CFStringRef propertyID, SInt32 value)
{
    gSets++;
    gSetObject = obj;
    gSetKey = propertyID;
    gSetValue = value;
    return gSetStatus;
}

OSStatus charon_test_MIDIDeviceRemoveEntity(MIDIDeviceRef device, MIDIEntityRef entity)
{
    gRemoves++;
    gRemovedEntity = entity;
    return gRemoveStatus;
}

OSStatus charon_test_MIDIDeviceNewEntity(MIDIDeviceRef device, CFStringRef name, MIDIProtocolID protocol, Boolean embedded,
                                         ItemCount numSourceEndpoints, ItemCount numDestinationEndpoints, MIDIEntityRef *newEntity);

static int gFailures;

static void expect(int passed, const char *name)
{
    printf("%s %s\n", passed ? "ok" : "FAIL", name);
    if (!passed)
        gFailures++;
}

static void reset(OSStatus add, OSStatus set, OSStatus remove)
{
    gAddStatus = add;
    gSetStatus = set;
    gRemoveStatus = remove;
    gAdds = gSets = gRemoves = 0;
    gRemovedEntity = 0;
    gSetObject = 0;
    gSetValue = -1;
    gSetKey = NULL;
}

int main(void)
{
    const OSStatus refused = kMIDINotPermitted;
    MIDIEntityRef entity = 99;

    reset(noErr, noErr, noErr);
    OSStatus status = charon_test_MIDIDeviceNewEntity(7, CFSTR("e"), kMIDIProtocol_2_0, false, 0, 0, &entity);
    expect(status == noErr && entity == kStandInEntity && gAdds == 1 && gSets == 1 && gRemoves == 0 && gSetObject == kStandInEntity &&
           gSetValue == (SInt32)kMIDIProtocol_2_0 && CFEqual(gSetKey, CFSTR("protocol")),
           "entity: the release takes the entity and the protocol: noErr, the entity, the protocol written to it, none removed");

    reset(noErr, refused, noErr);
    entity = 99;
    status = charon_test_MIDIDeviceNewEntity(7, CFSTR("e"), kMIDIProtocol_2_0, false, 0, 0, &entity);
    expect(status == refused && entity == 0 && gRemoves == 1 && gRemovedEntity == kStandInEntity,
           "entity: a refused protocol is the answer, the entity is removed again and none is handed out");

    reset(noErr, refused, refused);
    entity = 99;
    status = charon_test_MIDIDeviceNewEntity(7, CFSTR("e"), kMIDIProtocol_1_0, false, 0, 0, &entity);
    expect(status == refused && entity == 0 && gRemoves == 1,
           "entity: a refused protocol is still the answer when the removal is refused as well (the removal is logged)");

    reset(refused, noErr, noErr);
    entity = 99;
    status = charon_test_MIDIDeviceNewEntity(7, CFSTR("e"), kMIDIProtocol_2_0, false, 0, 0, &entity);
    expect(status == refused && entity == 0 && gSets == 0 && gRemoves == 0,
           "entity: a refused entity is the answer, with no protocol written and nothing to remove");

    reset(noErr, noErr, noErr);
    entity = 99;
    status = charon_test_MIDIDeviceNewEntity(0, CFSTR("e"), kMIDIProtocol_2_0, false, 0, 0, &entity);
    expect(status == charon_paramErr && entity == 0 && gAdds == 0, "entity: device 0 is paramErr and no entity, as macOS answers");

    reset(noErr, noErr, noErr);
    entity = 99;
    status = charon_test_MIDIDeviceNewEntity(7, CFSTR("e"), (MIDIProtocolID)9, false, 0, 0, &entity);
    expect(status == charon_paramErr && entity == 0 && gAdds == 0, "entity: a protocol that is neither 1.0 nor 2.0 is paramErr and no entity (the port's answer, not measured on macOS)");

    printf("entity: failures %d\n", gFailures);
    return gFailures == 0 ? 0 : 1;
}
