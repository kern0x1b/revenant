#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>

static MIDIClientRef gClient;
static MIDIPortRef gOut;
static volatile int gInCall;
static volatile int gBlockCalls;

static const char *typeName(MIDIObjectType t) {
    switch (t) {
        case kMIDIObjectType_Other: return "Other";
        case kMIDIObjectType_Device: return "Device";
        case kMIDIObjectType_Entity: return "Entity";
        case kMIDIObjectType_Source: return "Source";
        case kMIDIObjectType_Destination: return "Destination";
        case kMIDIObjectType_ExternalDevice: return "ExternalDevice";
        case kMIDIObjectType_ExternalEntity: return "ExternalEntity";
        case kMIDIObjectType_ExternalSource: return "ExternalSource";
        case kMIDIObjectType_ExternalDestination: return "ExternalDestination";
    }
    return "?";
}

static const char *msgName(MIDINotificationMessageID m) {
    switch (m) {
        case kMIDIMsgSetupChanged: return "SetupChanged";
        case kMIDIMsgObjectAdded: return "ObjectAdded";
        case kMIDIMsgObjectRemoved: return "ObjectRemoved";
        case kMIDIMsgPropertyChanged: return "PropertyChanged";
        case kMIDIMsgThruConnectionsChanged: return "ThruConnectionsChanged";
        case kMIDIMsgSerialPortOwnerChanged: return "SerialPortOwnerChanged";
        case kMIDIMsgIOError: return "IOError";
    }
    return "?";
}

static void notifyProc(const MIDINotification *m, void *refCon) {
    printf("    notify: %s (id %d) on %s, inCall=%d", msgName(m->messageID), (int)m->messageID,
           pthread_main_np() ? "main thread" : "other thread", gInCall);
    if (m->messageID == kMIDIMsgObjectRemoved || m->messageID == kMIDIMsgObjectAdded) {
        const MIDIObjectAddRemoveNotification *a = (const MIDIObjectAddRemoveNotification *)m;
        printf(", parentType %d (%s) parent %u, childType %d (%s) child %u", (int)a->parentType,
               typeName(a->parentType), (unsigned)a->parent, (int)a->childType, typeName(a->childType),
               (unsigned)a->child);
    }
    printf("\n");
}

static void settle(void) {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, false);
}

static void liveness(const char *what, MIDIObjectRef ref) {
    SInt32 uid = -1;
    OSStatus s = MIDIObjectGetIntegerProperty(ref, kMIDIPropertyUniqueID, &uid);
    printf("    liveness %s ref %u: MIDIObjectGetIntegerProperty(UniqueID) status %d, value %d\n", what,
           (unsigned)ref, (int)s, (int)uid);
}

static void readBlock(const MIDIPacketList *pl, void *refCon) {
    gBlockCalls++;
    printf("    read block called (packets %u)\n", (unsigned)pl->numPackets);
}

static void sendOneWord(const char *what, MIDIEndpointRef dest) {
    Byte buf[64];
    MIDIEventList *list = (MIDIEventList *)buf;
    MIDIEventPacket *p = MIDIEventListInit(list, kMIDIProtocol_1_0);
    UInt32 word = 0x20903C7Fu;
    MIDIEventListAdd(list, sizeof(buf), p, 0, 1, &word);
    int before = gBlockCalls;
    printf("    MARK before MIDISendEventList to %s (block calls so far %d)\n", what, before);
    gInCall = 1;
    OSStatus s = MIDISendEventList(gOut, dest, list);
    gInCall = 0;
    printf("    MARK after MIDISendEventList returned %d\n", (int)s);
    settle();
    printf("    block calls during send and settle: %d\n", gBlockCalls - before);
}

int main(void) {
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        MIDIClientCreate(CFSTR("removal-notify"), notifyProc, NULL, &gClient);
        MIDIOutputPortCreate(gClient, CFSTR("rn-out"), &gOut);
        settle();

        printf("== destination (MIDIDestinationCreateWithBlock)\n");
        MIDIEndpointRef dest = 0;
        MIDIDestinationCreateWithBlock(gClient, CFSTR("rn-dest"), &dest, ^(const MIDIPacketList *pl, void *ref) { readBlock(pl, ref); });
        settle();
        SInt32 uid = -1;
        OSStatus u = MIDIObjectGetIntegerProperty(dest, kMIDIPropertyUniqueID, &uid);
        printf("    created dest ref %u, UniqueID %d (status %d)\n", (unsigned)dest, (int)uid, (int)u);
        sendOneWord("live destination (control, before dispose)", dest);
        printf("    MARK before MIDIEndpointDispose(dest)\n");
        gInCall = 1;
        OSStatus s = MIDIEndpointDispose(dest);
        gInCall = 0;
        printf("    MARK after MIDIEndpointDispose(dest) returned %d\n", (int)s);
        settle();
        liveness("dest", dest);
        sendOneWord("disposed destination", dest);

        printf("== input port (MIDIInputPortCreateWithBlock)\n");
        MIDIPortRef port = 0;
        MIDIInputPortCreateWithBlock(gClient, CFSTR("rn-in"), &port, ^(const MIDIPacketList *pl, void *ref) { readBlock(pl, ref); });
        settle();
        liveness("live input port (control)", port);
        liveness("live output port (control)", gOut);
        liveness("never-created ref (control)", 0x12345u);
        printf("    MARK before MIDIPortDispose(port)\n");
        gInCall = 1;
        s = MIDIPortDispose(port);
        gInCall = 0;
        printf("    MARK after MIDIPortDispose(port) returned %d\n", (int)s);
        settle();
        liveness("input port", port);

        printf("== virtual source (MIDISourceCreate)\n");
        MIDIEndpointRef src = 0;
        MIDISourceCreate(gClient, CFSTR("rn-src"), &src);
        settle();
        u = MIDIObjectGetIntegerProperty(src, kMIDIPropertyUniqueID, &uid);
        printf("    created source ref %u, UniqueID %d (status %d)\n", (unsigned)src, (int)uid, (int)u);
        printf("    MARK before MIDIEndpointDispose(src)\n");
        gInCall = 1;
        s = MIDIEndpointDispose(src);
        gInCall = 0;
        printf("    MARK after MIDIEndpointDispose(src) returned %d\n", (int)s);
        settle();
        liveness("source", src);

        MIDIPortDispose(gOut);
        MIDIClientDispose(gClient);
        printf("== done, client disposed\n");
    }
    return 0;
}
